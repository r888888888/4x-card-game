class_name ScriptedBot
extends RefCounted
## A fixed-policy bot for smoke tests and the balance simulator (backlog 042). Each step it resolves an
## explore choice with its first option, learns the cheapest tech it can afford (140),
## otherwise plays the first playable hand card on its first valid target (Research cards last),
## otherwise relieves a Famine it can pay for when the next upkeep would still starve (084), discards the hand
## (dead cards never cycle otherwise, backlog 024) and ends the turn. After MAX_PLAYS_PER_TURN plays it ends the
## turn anyway: free cards that draw can redraw each other forever (058).
##
## Strategies (134) change which playable card goes first and add end-of-turn steps; "baseline" is the bot above.
## They read what cards do from their effects, never their ids: growth and tall play cards that make food on upkeep
## first, wealth plays cards that make wealth first and buys one from the supply each turn, wide plays cards that
## explore or settle first, and tall stops settling at TALL_TERRITORIES. Every strategy but baseline then grows pop
## while the next upkeep would still feed everyone: growth and wealth the cheapest territory first, wide the lowest pop,
## tall the most housing. Every strategy plays around the unrest limit (144): see _unrest_ok; under Anarchy it plays a
## government first (145).

const MAX_STEPS := 2000
const MAX_PLAYS_PER_TURN := 40
const STRATEGIES: Array[String] = ["baseline", "growth", "wealth", "wide", "tall"]
## The settled territories the tall strategy stops at.
const TALL_TERRITORIES := 2
## How far below the unrest limit the bot still plays cards that calm unrest (144).
const CALM_MARGIN := 2


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
		if engine.relieve_famine_error() == "" and engine.upkeep_forecast().get("starve", 0) > 0:
			engine.relieve_famine()
		for card in engine.zone("hand").cards.duplicate():
			engine.discard_card(card.uid)
		engine.end_turn()
		steps += 1
	return engine.is_over


## Plays one turn with strategy up to, not including, discarding and ending it: choices, techs and hand cards, then
## the strategy's buy and growth. Returns the steps it took.
static func take_turn(engine: GameEngine, strategy: String) -> int:
	var steps := 0
	var plays := 0
	while not engine.is_over and steps < MAX_STEPS:
		steps += 1
		if not engine.pending_choice.is_empty():
			engine.choose(engine.pending_choice.options[0])
		elif learn_cheapest_tech(engine):
			pass
		elif plays >= MAX_PLAYS_PER_TURN or not _play_first_playable(engine, strategy):
			break
		else:
			plays += 1
	if strategy == "wealth":
		_buy_wealth_card(engine)
	if strategy != "baseline":
		_grow(engine, strategy)
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


## Plays the first hand card that can be played, on its first valid target, in strategy's order (under Anarchy,
## governments first: 145). Returns whether one was played.
static func _play_first_playable(engine: GameEngine, strategy := "baseline") -> bool:
	var order := _hand_order(engine, strategy)
	if engine.anarchy() != -1:
		var govs := order.filter(func(c): return c.def.type == CardDef.GOVERNMENT)
		order = govs + order.filter(func(c): return c.def.type != CardDef.GOVERNMENT)
	for card in order:
		if strategy == "tall" and _settles(card.def) and _settled_count(engine) >= TALL_TERRITORIES:
			continue
		if not _unrest_ok(engine, card.def):
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
			return def.effects.any(func(e): return e.trigger == "upkeep" and e.get("resource") == GameEngine.FOOD)
		"wealth":
			return _makes_wealth(def)
		"wide":
			return def.effects.any(func(e): return e.op == "explore" or e.op == "settle")
	return false


## Whether playing def is sensible for unrest (144), with a limit set: next = unrest + the next upkeep's change + 1 (a
## margin for the event). A card that gains unrest is skipped when next plus its gain reaches the limit, and one that
## loses unrest while next is below the limit − CALM_MARGIN.
static func _unrest_ok(engine: GameEngine, def: CardDef) -> bool:
	var change := 0
	for e in def.effects:
		if e.trigger == "play" and e.get("resource") == GameEngine.UNREST:
			change += e.amount if e.op == "gain" else -e.amount if e.op == "lose" else 0
	var limit := engine.unrest_limit()
	if change == 0 or limit < 0:
		return true
	var next: int = engine.resources.get(GameEngine.UNREST, 0) + engine.upkeep_forecast().get(GameEngine.UNREST, 0) + 1
	return next + change < limit if change > 0 else next >= limit - CALM_MARGIN


static func _makes_wealth(def: CardDef) -> bool:
	return def.effects.any(func(e): return e.get("resource") == GameEngine.WEALTH)


static func _settles(def: CardDef) -> bool:
	return def.effects.any(func(e): return e.op == "settle")


static func _settled_count(engine: GameEngine) -> int:
	return engine.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size()


## Buys the cheapest open supply card that makes wealth and that the engine allows, if any.
static func _buy_wealth_card(engine: GameEngine) -> void:
	var best := ""
	for id in engine.open_supply_piles():
		if _makes_wealth(engine.card_db[id]) and engine.buy_error(id) == "" \
				and (best == "" or engine.buy_price(id) < engine.buy_price(best)):
			best = id
	if best != "":
		engine.buy(best)


## Grows one pop at a time, on the first territory in strategy's order whose growth leaves the next upkeep fed, until
## none does.
static func _grow(engine: GameEngine, strategy: String) -> void:
	var grew := true
	while grew:
		grew = false
		for uid in _growth_order(engine, strategy):
			if engine.grow_error(uid) != "":
				continue
			var trial := engine.fork()
			trial.grow(uid)
			if trial.upkeep_forecast().get("starve", 0) == 0:
				engine.grow(uid)
				grew = true
				break


## The settled territories' uids in the order strategy grows them (ties: tableau order).
static func _growth_order(engine: GameEngine, strategy: String) -> Array:
	var lands := engine.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY)
	var key := func(c: CardInstance) -> int:
		match strategy:
			"wide":
				return engine.pop(c.uid)
			"tall":
				return -engine.housing(c.uid)
		return engine.grow_cost(c.uid)
	var order := range(lands.size())
	order.sort_custom(func(i, j): return key.call(lands[i]) < key.call(lands[j]) \
			or (key.call(lands[i]) == key.call(lands[j]) and i < j))
	return order.map(func(i): return lands[i].uid)
