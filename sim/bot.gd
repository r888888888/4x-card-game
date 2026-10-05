class_name ScriptedBot
extends RefCounted
## A fixed-policy bot for smoke tests and the balance simulator (backlog 042). Each step it resolves an
## explore choice with its first option, learns the cheapest tech it can afford (140),
## otherwise plays the first playable hand card on its first valid target (Research cards last; never a card that
## only explores with nothing left to explore, 238),
## otherwise relieves a Famine it can pay for when the next upkeep would still starve (084), discards the hand
## (dead cards never cycle otherwise, backlog 024) and ends the turn. After MAX_PLAYS_PER_TURN plays it ends the
## turn anyway: free cards that draw can redraw each other forever (058).
##
## Strategies (134) change which playable card goes first and add end-of-turn steps; "baseline" is the bot above.
## They read what cards do from their effects, never their ids: growth and tall play cards that make food on upkeep
## (and growth cards, 262) first and buy one from the supply each turn (239), wealth does the same with cards that make
## wealth, wide plays cards that explore or settle first, and tall stops settling at TALL_TERRITORIES. Every strategy
## plays a growth card only when it adds pop and the next upkeep still nets food (see _growth_ok), and plays around the
## unrest limit (144): see _unrest_ok; under Anarchy it pays to restore order from the second turn with 2+ counters
## left or a starving upkeep ahead (155), renews the card worth least to keep (147), and chooses governments and
## revolts by lookahead: playing forks LOOKAHEAD_TURNS on (159), valued by score and the insight they gathered (240).
## Before Anarchy rules, a seeded coin decides whether it spends its wealth on the supply instead of letting the drain
## take it (239): see _spend_before_drain.

const MAX_STEPS := 2000
const MAX_PLAYS_PER_TURN := 40
const STRATEGIES: Array[String] = ["baseline", "growth", "wealth", "wide", "tall"]
## The settled territories the tall strategy stops at.
const TALL_TERRITORIES := 2
## How far below the unrest limit the bot still plays cards that calm unrest (144).
const CALM_MARGIN := 2
## How many turns a lookahead plays (159), and how often, in turns, the bot weighs a revolution.
const LOOKAHEAD_TURNS := 12
const REVOLT_EVERY := 4
## The wealth the bot keeps when it spends before Anarchy's drain (239): enough to buy order with 2 turns left.
const SPEND_RESERVE := 6
## The insight a lookahead's fork gathers that is worth 1 point of its value (240): research pays off past the horizon.
const INSIGHT_PER_POINT := 4

static var _depth := 0  # > 0 while a lookahead plays (159): no revolts, the forced government chosen
## The turns lookahead forks have played (294), for the sim's lookahead_turns: SimStats resets it before each game.
static var lookahead_turns := 0
static var _forced_government := ""  # the government a lookahead was opened for ("" for the ranking)


## Plays engine's game to the end with strategy. Returns whether it ended within MAX_STEPS; false, without playing,
## for an unknown strategy.
static func play(engine: GameEngine, strategy := "baseline") -> bool:
	if not STRATEGIES.has(strategy):
		return false
	var steps := 0
	while not engine.is_over and steps < MAX_STEPS:
		steps += take_turn(engine, strategy)
		if engine.is_over:
			break
		_close_turn(engine)
		steps += 1
	return engine.is_over


## Relieves a Famine the next upkeep would still starve under (084), discards the hand and ends the turn.
static func _close_turn(engine: GameEngine) -> void:
	if engine.relieve_famine_error() == "" and engine.upkeep_forecast().get("starve", 0) > 0:
		engine.relieve_famine()
	for card in engine.zone("hand").cards.duplicate():
		engine.discard_card(card.uid)
	engine.end_turn()


## Plays a fork of engine LOOKAHEAD_TURNS turns on (or to the game's end) with strategy and returns its value then:
## its score (159) + 1 point per INSIGHT_PER_POINT insight it gathered (240). The fork revolts first when revolt is true,
## answers the owed event choice with option first when it isn't -1 (269), chooses government_id whenever the government
## choice is owed ("" for best_government), and never revolts; engine itself is untouched.
static func lookahead(engine: GameEngine, strategy: String, government_id := "", revolt := false, option := -1) -> int:
	var f := engine.fork()
	var saved := _forced_government
	_depth += 1
	_forced_government = government_id
	if revolt:
		f.revolt()
	if option != -1:
		f.choose_option(option)
	var end := mini(f.turn + LOOKAHEAD_TURNS, f.turn_limit())
	var steps := 0
	while not f.is_over and f.turn < end and steps < MAX_STEPS:
		steps += take_turn(f, strategy)
		if f.is_over or f.turn >= end:
			break
		_close_turn(f)
		steps += 1
	lookahead_turns += f.turn - engine.turn
	_depth -= 1
	_forced_government = saved
	return f.score() + insight_gathered(engine, f) / INSIGHT_PER_POINT


## The insight end gathered since start (240): the insight it holds minus what start held, plus the printed insight
## cost of each tech it learned that start hadn't.
static func insight_gathered(start: GameEngine, end: GameEngine) -> int:
	var gathered: int = end.resources.get(GameEngine.INSIGHT, 0) - start.resources.get(GameEngine.INSIGHT, 0)
	for tech in end.zone("researched").cards:
		if start.zone("researched").find(tech.uid) == null:
			gathered += tech.def.cost.get(GameEngine.INSIGHT, 0)
	return gathered


## Plays one turn with strategy up to, not including, discarding and ending it: choices, techs and hand cards, then
## the strategy's buy. Returns the steps it took.
static func take_turn(engine: GameEngine, strategy: String) -> int:
	var steps := 0
	var plays := 0
	while not engine.is_over and steps < MAX_STEPS:
		steps += 1
		if engine.pending().get("kind", "") == GameEngine.PENDING_GOVERNMENT:
			engine.choose_government(_pick_government(engine, strategy).uid)
		elif engine.pending().get("kind", "") == GameEngine.PENDING_RENEWAL:
			engine.renew(_renewal_picks(engine))
		elif engine.pending().get("kind", "") == GameEngine.PENDING_EVENT_CHOICE:
			engine.choose_option(pick_option(engine, strategy))
		elif engine.pending().get("kind", "") == GameEngine.PENDING_EXPLORE:
			engine.choose(engine.pending().options[0])
		elif _restore_order(engine):
			pass
		elif learn_cheapest_tech(engine):
			pass
		elif plays >= MAX_PLAYS_PER_TURN or not _play_first_playable(engine, strategy):
			break
		else:
			plays += 1
	if strategy in ["wealth", "growth", "tall"]:
		_buy_cheapest(engine, func(def): return _prefers(strategy, def))
	_revolt(engine, strategy)
	_spend_before_drain(engine, strategy)
	return steps


## Learns the cheapest tech the engine allows (140: any tech in the open tree); a tie goes to the lower era, then the
## one listed first in config research_deck (tech_tree()'s order). Returns whether it learned one. Looks only at the
## research deck, without building tech_tree() (151).
static func learn_cheapest_tech(engine: GameEngine) -> bool:
	var listed: Array = engine.config.get("research_deck", {}).keys()
	var insight: int = engine.resources.get(GameEngine.INSIGHT, 0)
	var best: CardInstance = null
	var best_key := []
	for tech in engine.zone("research_deck").cards:
		var cost := engine.tech_cost(tech.uid)
		if cost > insight or engine.buy_tech_error(tech.uid) != "":  # the price first: most steps can't afford any
			continue
		var key := [cost, tech.def.era, listed.find(tech.def.id)]
		if best == null or key < best_key:
			best = tech
			best_key = key
	return best != null and engine.buy_tech(best.uid)


## Plays the first hand card that can be played, on its first valid target, in strategy's order. Returns whether one
## was played.
static func _play_first_playable(engine: GameEngine, strategy := "baseline") -> bool:
	var order := _hand_order(engine, strategy)
	var forecast := []  # see _unrest_ok: nothing changes until a card is played
	for card in order:
		if strategy == "tall" and _settles(card.def) and _settled_count(engine) >= TALL_TERRITORIES:
			continue
		if not _unrest_ok(engine, card.def, forecast) or _explores_nothing(engine, card.def) or not _growth_ok(engine, card):
			continue
		var targets := engine.valid_targets(card.uid)
		var target: int = targets[0] if engine.needs_target(card.uid) and not targets.is_empty() else -1
		if engine.play_error(card.uid, target) == "":
			return engine.play_card(card.uid, target)
	return false


## The hand in the order strategy tries it: Research cards last; the strategy's preferred cards first, each group in
## hand order.
static func _hand_order(engine: GameEngine, strategy: String) -> Array:
	var hand := engine.zone("hand").cards.duplicate()
	if strategy == "baseline":
		hand.sort_custom(func(a, b): return a.def.id != "research" and b.def.id == "research")
		return hand
	var first := []
	var rest := []
	var last := []
	for card in hand:
		if card.def.effects.any(func(e): return e.get("resource") == GameEngine.INSIGHT):
			last.append(card)
		elif _prefers(strategy, card.def):
			first.append(card)
		else:
			rest.append(card)
	return first + rest + last


static func _prefers(strategy: String, def: CardDef) -> bool:
	match strategy:
		"growth", "tall":
			return _grows(def) or def.effects.any(func(e): return e.trigger == "upkeep" and e.get("resource") == GameEngine.FOOD)
		"wealth":
			return _makes_wealth(def)
		"wide":
			return def.effects.any(func(e): return e.op == "explore" or e.op == "settle")
	return false


## Whether playing card is sensible for growth (262): a card that grows pop is played only when, played on a fork, it
## adds pop and the next upkeep still nets at least 1 food. Any other card is fine; play_error decides the rest.
static func _growth_ok(engine: GameEngine, card: CardInstance) -> bool:
	if not _grows(card.def):
		return true
	var trial := engine.fork()
	var pop := trial.total_pop()
	if not trial.play_card(card.uid):
		return true
	return trial.total_pop() > pop and trial.upkeep_forecast().get(GameEngine.FOOD, 0) >= 1


static func _grows(def: CardDef) -> bool:
	return def.effects.any(func(e): return e.op == "grow")


## Whether playing def is sensible for unrest (144), with a limit set: next = unrest + the next upkeep's change + 1 (a
## margin for the event). A card that gains unrest is skipped when next plus its gain reaches the limit, and one that
## loses unrest while next is below the limit − CALM_MARGIN. forecast holds the upkeep forecast once made ([] until a
## card needs it), so one scan of the hand makes it at most once (294).
static func _unrest_ok(engine: GameEngine, def: CardDef, forecast := []) -> bool:
	var change := 0
	for e in def.effects:
		if e.trigger == "play" and e.get("resource") == GameEngine.UNREST:
			change += e.amount if e.op == "gain" else -e.amount if e.op == "lose" else 0
	var limit := engine.unrest_limit()
	if change == 0 or limit < 0:
		return true
	if forecast.is_empty():
		forecast.append(engine.upkeep_forecast())
	var next: int = engine.resources.get(GameEngine.UNREST, 0) + forecast[0].get(GameEngine.UNREST, 0) + 1
	return next + change < limit if change > 0 else next >= limit - CALM_MARGIN


## Under Anarchy, from its second turn, pays to restore order (155) when it can and 2+ counters are left or the next
## upkeep would starve. Returns whether it did.
static func _restore_order(engine: GameEngine) -> bool:
	if engine.restore_order_error() != "":
		return false
	if engine.anarchy_counters() < 2 and engine.upkeep_forecast().get("starve", 0) == 0:
		return false
	return engine.restore_order()


## At the end of every REVOLT_EVERY-th turn, outside a lookahead and before the last LOOKAHEAD_TURNS ÷ 2 turns,
## revolts (159) when a lookahead that revolts and then chooses some government in the deck outscores one that doesn't.
static func _revolt(engine: GameEngine, strategy: String) -> void:
	if _depth > 0 or engine.turn % REVOLT_EVERY != 0 or engine.revolt_error() != "":
		return
	if engine.zone("governments").is_empty() or engine.turn > engine.turn_limit() - LOOKAHEAD_TURNS / 2:
		return
	var stay := lookahead(engine, strategy)
	for g in engine.zone("governments").cards:
		if lookahead(engine, strategy, g.def.id, true) > stay:
			engine.revolt()
			return


## The government to choose when the choice is owed (159): the one whose lookahead scores most, ties to the first in
## the government deck, and the only one without looking ahead. Inside a lookahead: the government it was opened for,
## else best_government.
## The option the bot answers the owed event choice with (269): of those choose_option_error allows, the one whose
## lookahead scores most, ties to the lowest index; inside a lookahead, the first allowed.
static func pick_option(engine: GameEngine, strategy: String) -> int:
	var allowed: Array = engine.pending().get("options", []).filter(func(i): return engine.choose_option_error(i) == "")
	if allowed.is_empty():
		return -1
	if _depth > 0 or allowed.size() == 1:
		return allowed[0]
	var best: int = allowed[0]
	var best_score := lookahead(engine, strategy, "", false, best)
	for i in allowed.slice(1):
		var score := lookahead(engine, strategy, "", false, i)
		if score > best_score:
			best = i
			best_score = score
	return best


static func _pick_government(engine: GameEngine, strategy: String) -> CardInstance:
	var options: Array = engine.zone("governments").cards
	if _depth > 0:
		for g in options:
			if g.def.id == _forced_government:
				return g
		return best_government(options)
	if options.size() == 1:
		return options[0]
	var best: CardInstance = null
	var best_score := 0
	for g in options:
		var score := lookahead(engine, strategy, g.def.id)
		if best == null or score > best_score:
			best = g
			best_score = score
	return best


## 154's ranking of govs, used inside a lookahead: the most actions, then the highest unrest limit; ties go to the
## first.
static func best_government(govs: Array) -> CardInstance:
	var best: CardInstance = null
	for g in govs:
		if best == null or _rank(g.def) > _rank(best.def):
			best = g
	return best


## A government's rank for best_government (154): its actions, then its unrest limit.
static func _rank(def: CardDef) -> Array:
	return [def.actions, def.unrest_limit]


## The count's renewal options worth least to keep (147, 255, see _keep_value); a tie goes to the earlier option.
static func _renewal_picks(engine: GameEngine) -> Array:
	var p := engine.pending()
	var options: Array = p.options.duplicate()
	var value := func(uid: int) -> int: return _keep_value(engine, engine.zone(engine.zone_of(uid)).find(uid).def)
	options.sort_custom(func(a, b):
		var va: int = value.call(a)
		var vb: int = value.call(b)
		return va < vb or (va == vb and p.options.find(a) < p.options.find(b)))
	return options.slice(0, p.count)


## A rough worth of keeping def in the deck: its cost + 2 × VP, +4 for a building, +3 for a card that loses unrest,
## +3 for one that explores or settles while territories remain, +3 for one that gains insight.
static func _keep_value(engine: GameEngine, def: CardDef) -> int:
	var v := 2 * def.vp
	for r in def.cost:
		v += def.cost[r]
	if def.type == CardDef.BUILDING:
		v += 4
	if def.effects.any(func(e): return e.op == "lose" and e.get("resource") == GameEngine.UNREST):
		v += 3
	var lands_left := not engine.zone("territory_deck").is_empty() or not engine.zone("frontier").is_empty()
	if lands_left and def.effects.any(func(e): return e.op == "explore" or e.op == "settle"):
		v += 3
	if def.effects.any(func(e): return e.get("resource") == GameEngine.INSIGHT):
		v += 3
	return v


## Whether def only explores while the territory deck is empty (238): playing it would spend an action for nothing.
static func _explores_nothing(engine: GameEngine, def: CardDef) -> bool:
	return engine.zone("territory_deck").is_empty() and not def.effects.is_empty() \
			and def.effects.all(func(e): return e.op == "explore")


static func _makes_wealth(def: CardDef) -> bool:
	return def.effects.any(func(e): return e.get("resource") == GameEngine.WEALTH)


static func _settles(def: CardDef) -> bool:
	return def.effects.any(func(e): return e.op == "settle")


static func _settled_count(engine: GameEngine) -> int:
	return engine.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size()


## Buys the cheapest open supply card whose def wanted accepts, that the engine allows and that leaves at least
## reserve wealth; a tie goes to the pile listed first. Returns whether it bought one.
static func _buy_cheapest(engine: GameEngine, wanted: Callable, reserve := 0) -> bool:
	var best := ""
	var best_price := 0
	var wealth: int = engine.resources.get(GameEngine.WEALTH, 0)
	for id in engine.open_supply_piles():  # the cheap tests first
		var price := engine.buy_price(id)
		if wealth - price < reserve or (best != "" and price >= best_price):
			continue
		if wanted.call(engine.card_db[id]) and engine.buy_error(id) == "":
			best = id
			best_price = price
	return best != "" and engine.buy(best)


## Whether the bot spends its wealth before Anarchy's drain (239): a coin from engine's seed and turn, the same on a
## fork, that never touches the game's rng.
static func spends_before_drain(engine: GameEngine) -> bool:
	return posmod(hash([engine.seed_value, engine.turn]), 2) == 0


## When Anarchy will rule next turn and spends_before_drain says so, buys supply cards down to SPEND_RESERVE wealth
## (239): the cheapest card strategy buys (wealth: makes wealth; growth and tall: makes food on upkeep; any for the
## others), then the cheapest of any.
static func _spend_before_drain(engine: GameEngine, strategy: String) -> void:
	if not spends_before_drain(engine) or not (Anarchy.rules_next_turn(engine) or engine.anarchy_ahead()):
		return
	var preferred := func(def): return strategy in ["baseline", "wide"] or _prefers(strategy, def)
	while _buy_cheapest(engine, preferred, SPEND_RESERVE) or _buy_cheapest(engine, func(_def): return true, SPEND_RESERVE):
		pass
