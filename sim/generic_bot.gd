class_name GenericBot
extends RefCounted
## A sim bot with no rule for any one mechanic (313, from spike/generic-bot). Each step it takes the engine's
## legal_actions() (an owed decision's options when one is owed), tries each on a sample fork (311: hidden orders drawn
## from a seed, so it never knows the future), values the fork with value() and does the best, stopping when nothing
## beats doing nothing. A new action reaches it through legal_actions with no change here.
##
## value() = score + turns ahead × the next turn's score (turn_forecast, 309) + Σ weight × concave(stock + turns ahead ×
## its forecast change) for food, wealth and insight − weight × unrest − weight × the unrest coming in over the turns
## ahead (321) − a squared penalty as unrest nears its limit + the deck's worth (what the best plays of a drawn hand
## would add, each card worth what playing it adds and never below 0, 0 for one with nothing to act on: 310, 376) + the
## printed cost of the techs learned (+ a weight per settled territory up to the admin cap for wide, 321). Turns ahead =
## min(HORIZON, turns left): income counts early, only points at the end.
## A position's forecast is computed once: value() looks it up by what it reads (forecast_key, 315).
##
## Choices that pay off over many turns are weighed by rollouts (314): the government choice when owed, and every
## REVOLT_EVERY turns whether to revolt. A rollout plays a sample fork ROLLOUT_TURNS turns on in cheap mode (no card
## values, no extra lookahead step), never revolting and choosing the government it was opened for, and returns its
## value then. Strategies (STRATEGIES): generic; wide (weighs each settled territory up to the admin cap); tall (settles
## only when nothing else is worth doing, and never past TALL_TERRITORIES, 390).

## The strategy played when none is named.
const STRATEGY := "generic"
## The strategies SimStats plays (all of them for "all").
const STRATEGIES: Array[String] = ["generic", "wide", "tall"]
## The settled territories tall stops at.
const TALL_TERRITORIES := 3
## How often, in turns, a revolt is weighed, and how many turns a rollout plays.
const REVOLT_EVERY := 4
const ROLLOUT_TURNS := 12
const MAX_STEPS := 2000
const MAX_ACTIONS_PER_TURN := 40
## Turns of income a value counts.
const HORIZON := 10
## How much an action must beat doing nothing by.
const EPS := 0.01
## A play within this of doing nothing that gave back a card or an action (a draw, +1 action) is worth the best it
## leads to one step later.
const QUIET := 0.5
## Buys tried each step: the best by card value per wealth of price.
const BUYS_TRIED := 3
## Targets a card's value is measured on.
const TARGETS_TRIED := 3
## Turns a measured card value stands.
const REVALUE_TURNS := 4
## Where a stock's diminishing returns set in.
const STOCK_SCALE := 8.0
## How far below the unrest limit projected unrest starts to cost.
const RISK_MARGIN := 2
## The most single-card renewals tried each step (385: renewal is optional, so the bot renews a card at a time while it
## pays).
const RENEWALS_TRIED := 40
## Actions the bot never takes itself: play ends the turn; revolts are weighed by rollouts (314).
const SKIPPED := ["end_turn", "revolt"]
## Each strategy's weights: per unit of food, wealth and insight (projected, diminishing), per unrest held (0: held
## unrest costs through its risk only), per unrest coming in over the turns ahead (321), the deck's worth (× turns
## ahead), the unrest risk (squared) and each point of learned techs' printed cost, and per settled territory
## up to the admin cap (321).
const WEIGHTS := {
	"generic": {"food": 0.5, "wealth": 0.7, "insight": 0.5, "unrest": 0.0, "unrest_rate": 0.5, "deck": 0.05,
		"risk": 3.0, "owned": 0.5, "land": 0.0},
	"wide": {"food": 0.5, "wealth": 0.7, "insight": 0.5, "unrest": 0.0, "unrest_rate": 0.5, "deck": 0.05, "risk": 3.0,
		"owned": 0.5, "land": 20.0},
	"tall": {"food": 0.5, "wealth": 0.7, "insight": 0.5, "unrest": 0.0, "unrest_rate": 0.5, "deck": 0.05, "risk": 3.0,
		"owned": 0.5, "land": 0.0},
}

## The turns rollouts played (for the sim's lookahead_turns): SimStats resets it before each game.
static var lookahead_turns := 0
## The forecast cache (315): value() looks each position's turn_forecast up by what the forecast reads (forecast_key),
## so a position already forecast isn't forecast again. Off: every lookup is computed. check_forecasts
## computes a fresh forecast at every hit too and counts the ones that differ (a test of the key).
static var forecast_cache := true
static var check_forecasts := false
## Forecasts looked up, computed, checked and found to differ (check mode) since the last play() or
## reset_forecast_counts().
static var forecast_lookups := 0
static var forecasts_computed := 0
static var forecast_checks := 0
static var forecast_mismatches := 0
## The GameState and CardInstance fields forecast_key reads (336); the suite fails on a field in neither these nor the
## UNREAD lists, so a new field upkeep reads can't leave the cache serving stale forecasts.
const KEY_STATE_FIELDS: Array[String] = ["turn", "is_over", "bonus_score", "era", "eras_added", "revolt_pending",
	"last_raid_turn", "resources", "zones"]
const KEY_CARD_FIELDS: Array[String] = ["uid", "def", "territory_uid", "base_uid", "station_uid", "pop", "keywords",
	"turns_left", "counters", "progress", "given_this_turn", "raid_strength"]
## The fields the key leaves out, each with why the forecast doesn't depend on it.
const UNREAD_STATE_FIELDS := {
	"seed_value": "the rng is already seeded; the forecast only shuffles decks, which changes none of its numbers",
	"rng": "the forecast only shuffles decks (an era unlock), which changes none of its numbers",
	"log_lines": "upkeep writes the log but never reads it",
	"pending": "forecasts are taken between decisions, and starting a turn opens none before the draw",
	"actions_used": "reset as the turn begins",
	"actions_gained": "reset as the turn begins",
	"renewed": "reset as the turn begins (385)",
	"moved_units": "reset as the turn begins",
	"supply": "only buying reads it",
	"locked_supply": "only buying and unlocking read it",
	"locked_builds": "only building and unlocking read it",
	"built_once": "only building reads it",
	"next_uid": "a new card's uid changes none of the forecast's numbers",
	"names_given": "only naming a settled territory reads it",
	"seen_techs": "only the new-tech marks read it",
	"seen_supply": "only the new-pile marks read it",
}
const UNREAD_CARD_FIELDS := {
	"city_name": "a name: no rule reads it",
}


## What one game's choices share: the strategy and its weights, measured card values ({id: [turn, value]}), a step
## counter for sample seeds, whether a card value is being measured (the deck's worth is then left out, or it would
## recurse), in a rollout: cheap mode and the government it was opened for ("" for the best by value), and the forecast
## cache: {turn: {forecast_key: turn_forecast}}, dropping the turns already past when the game's turn moves on (a
## rollout's shared one only by its parent: rollouts from later turns revisit the positions of earlier ones), and the
## zones the key reads (315).
class Context:
	var strategy: String
	var w: Dictionary
	var card_values := {}
	var step := 0
	var valuing := false
	var rollout := false
	var government := ""
	var forecasts := {}
	var forecast_turn := -1
	var shared_forecasts := false  # a rollout using its parent's cache, which only the parent clears
	var forecast_zones: Array[String] = []

	func _init(p_strategy: String) -> void:
		strategy = p_strategy
		w = WEIGHTS[p_strategy]


## Plays engine's game to the end with strategy: each turn take_turn, then the hand discarded (it never cycles
## otherwise, 024) and the turn ended. Returns whether it ended within MAX_STEPS.
static func play(engine: GameEngine, strategy := STRATEGY) -> bool:
	reset_forecast_counts()
	var ctx := Context.new(strategy)
	var steps := 0
	while not engine.is_over and steps < MAX_STEPS:
		steps += take_turn(engine, strategy, ctx)
		for card in engine.zone("hand").cards.duplicate():
			engine.discard_card(card.uid)
		engine.end_turn()
		steps += 1
	return engine.is_over


## Does best_action until there is none (or MAX_ACTIONS_PER_TURN were done); the turn is left for play to end.
## Returns the steps taken.
static func take_turn(engine: GameEngine, strategy := STRATEGY, ctx: Context = null) -> int:
	ctx = ctx if ctx != null else Context.new(strategy)
	var steps := 0
	while not engine.is_over and steps < MAX_ACTIONS_PER_TURN:
		steps += 1
		var best := best_action(engine, strategy, ctx)
		if best.is_empty() or not _do(engine, best):
			break
	if not ctx.rollout:
		_weigh_revolt(engine, strategy, ctx)
	return steps


## Every REVOLT_EVERY turns, outside a rollout and before the last ROLLOUT_TURNS ÷ 2 turns, revolts when a rollout that
## revolts (then chooses some government in the deck) values more than one that doesn't.
static func _weigh_revolt(engine: GameEngine, strategy: String, ctx: Context) -> void:
	if engine.turn % REVOLT_EVERY != 0 or engine.revolt_error() != "" or engine.zone("governments").is_empty():
		return
	if engine.turn > engine.turn_limit() - ROLLOUT_TURNS / 2:
		return
	var stay := rollout(engine, strategy, "", false, ctx)
	for g in engine.zone("governments").cards:
		if rollout(engine, strategy, g.def.id, true, ctx) > stay:
			engine.revolt()
			return


## Plays a sample fork of engine ROLLOUT_TURNS turns on (or to the game's end) in cheap mode with strategy and returns
## its value then. The fork revolts first when revolt is true and chooses government_id whenever the government choice
## is owed ("" for the best by value); it never revolts. engine is untouched. The seed is the same for every rollout
## of a turn, so options are compared on the same future. Rollouts share parent's forecast cache (315): they revisit
## many of the same positions, within a turn and from one turn's rollouts to the next.
static func rollout(engine: GameEngine, strategy := STRATEGY, government_id := "", revolt := false,
		parent: Context = null) -> float:
	var f := engine.sample_fork(hash([engine.seed_value, engine.turn, "rollout"]))
	var ctx := Context.new(strategy)
	ctx.rollout = true
	if parent != null:
		ctx.forecasts = parent.forecasts
		ctx.shared_forecasts = true
	ctx.government = government_id
	if revolt:
		f.revolt()
	var end := mini(f.turn + ROLLOUT_TURNS, f.turn_limit())
	var steps := 0
	while not f.is_over and f.turn < end and steps < MAX_STEPS:
		steps += take_turn(f, strategy, ctx)
		if f.is_over or f.turn >= end:
			break
		for card in f.zone("hand").cards.duplicate():
			f.discard_card(card.uid)
		f.end_turn()
		steps += 1
	lookahead_turns += f.turn - engine.turn
	return value(f, ctx)


## The entry ([action, args…]) to do next, [] for none: the owed decision's option whose fork values most, else the
## candidate whose fork beats doing nothing by most. Tall tries its settle plays only when no other candidate beats
## doing nothing (390). Changes nothing in engine.
static func best_action(engine: GameEngine, strategy := STRATEGY, ctx: Context = null, look_on := true) -> Array:
	ctx = ctx if ctx != null else Context.new(strategy)
	var deciding: bool = engine.pending().get("kind", "") != ""
	if engine.pending().get("kind", "") == GameEngine.PENDING_GOVERNMENT:
		return _government(engine, strategy, ctx)
	var seed := hash([engine.seed_value, engine.turn, ctx.step])
	ctx.step += 1
	var candidates := _candidates(engine, ctx)
	var held := []
	if ctx.strategy == "tall" and not deciding:
		held = candidates.filter(func(c): return _settles(engine, c))
		candidates = candidates.filter(func(c): return not _settles(engine, c))
	var best := _best_of(engine, candidates, seed, deciding, ctx, look_on)
	return best if not best.is_empty() or held.is_empty() else _best_of(engine, held, seed, deciding, ctx, look_on)


## Of candidates, the one whose fork (sample seed) values most: any when deciding, else only one beating doing nothing
## by EPS; [] for none. A quiet play that refunded is worth the best it leads to one step later (look_on).
static func _best_of(engine: GameEngine, candidates: Array, seed: int, deciding: bool, ctx: Context,
		look_on: bool) -> Array:
	var base := value(engine, ctx)
	var best: Array = []
	var best_v := -INF if deciding else base + EPS
	for c in candidates:
		var f := engine.sample_fork(seed)
		if not _do(f, c):
			continue
		_settle(f, ctx)
		var v := value(f, ctx)
		if look_on and not ctx.rollout and not deciding and absf(v - base) < QUIET and _refunds(engine, f, c):
			var next := best_action(f, ctx.strategy, ctx, false)
			if not next.is_empty():
				var g := f.fork()
				_do(g, next)
				_settle(g, ctx)
				v = maxf(v, value(g, ctx))
		if v > best_v:
			best = c
			best_v = v
	return best


## The government to choose when the choice is owed: outside a rollout, the option whose rollout values most (ties to
## deck order; the only one without a rollout); in a rollout, the one it was opened for, else the best by value.
static func _government(engine: GameEngine, strategy: String, ctx: Context) -> Array:
	var options: Array = _candidates(engine, ctx)
	if options.size() <= 1:
		return options[0] if options.size() == 1 else []
	if ctx.rollout:
		for c in options:
			if engine.zone("governments").find(c[1]).def.id == ctx.government:
				return c
		var best: Array = []
		var best_v := -INF
		for c in options:
			var f := engine.fork()
			_do(f, c)
			var v := value(f, ctx)
			if v > best_v:
				best = c
				best_v = v
		return best
	var best: Array = []
	var best_v := -INF
	for c in options:
		var v := rollout(engine, strategy, engine.zone("governments").find(c[1]).def.id, false, ctx)
		if v > best_v:
			best = c
			best_v = v
	return best


## The entries the bot tries: legal_actions() but SKIPPED, the buys cut to BUYS_TRIED, a renewal expanded to one card
## each, the least valuable first (373, 385).
static func _candidates(e: GameEngine, ctx: Context) -> Array:
	var out := []
	var buys := []
	for entry in e.legal_actions():
		if SKIPPED.has(entry[0]) or (ctx.strategy == "tall" and _settles_too_far(e, entry)):
			continue
		if entry[0] == "buy":
			buys.append(entry)
		elif entry[0] == "renew":
			for uid in _least_valuable_first(e, entry[1], ctx).slice(0, RENEWALS_TRIED):
				out.append(["renew", [uid]])
		else:
			out.append(entry)
	if not ctx.rollout:  # cheap mode measures no card values: the first piles
		var rank := func(entry: Array) -> float: return card_value(e, entry[1], ctx) / maxf(1.0, e.buy_price(entry[1]))
		buys.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	return out + buys.slice(0, BUYS_TRIED)


## A renewal's options (uids), the least valuable card first by card_value (ties in listing order), so the cards tried
## are those worth least (373); listing order in a rollout, which measures no card values.
static func _least_valuable_first(e: GameEngine, options: Array, ctx: Context) -> Array:
	if ctx.rollout:
		return options
	var worth := {}
	for i in options.size():
		var card := e.zone(e.zone_of(options[i])).find(options[i])
		worth[options[i]] = [card_value(e, card.def.id, ctx), i]
	var out := options.duplicate()
	out.sort_custom(func(a, b): return worth[a] < worth[b])  # [value, index]: ties keep listing order
	return out


## Whether entry plays a card that settles while TALL_TERRITORIES are already settled (tall's limit).
static func _settles_too_far(e: GameEngine, entry: Array) -> bool:
	return _settles(e, entry) and _settled(e) >= TALL_TERRITORIES


## Whether entry plays a card from hand that settles (read from its effects).
static func _settles(e: GameEngine, entry: Array) -> bool:
	if entry[0] != "play_card":
		return false
	var card := e.zone("hand").find(entry[1])
	return card != null and card.def.effects.any(func(effect): return effect.op == "settle")


## The settled territories (in the tableau).
static func _settled(e: GameEngine) -> int:
	return Territories.count_settled(e)


## The settled territories wide's land weight counts: up to the admin cap (321), all of them without one.
static func _land(e: GameEngine) -> int:
	var cap := e.admin_cap()
	return _settled(e) if cap < 0 else mini(_settled(e), cap)


## Whether c is a play that gave back some of what a play spends: a card (a draw) or an action.
static func _refunds(before: GameEngine, after: GameEngine, c: Array) -> bool:
	if c[0] != "play_card":
		return false
	var spent := before.zone("hand").size() + before.actions_left() - after.zone("hand").size() - after.actions_left()
	return spent < 2


## Calls entry's action on e; false when it refused.
static func _do(e: GameEngine, entry: Array) -> bool:
	return LegalActions.apply(e, entry)


## Answers e's owed decisions, up to 3 deep, each with the option whose fork values most: for valuing a fork whose
## action left a decision owed (an explore's choice, say).
static func _settle(e: GameEngine, ctx: Context) -> void:
	for i in 3:
		if e.is_over or e.pending().get("kind", "") == "":
			return
		var best: Array = []
		var best_v := -INF
		for c in _candidates(e, ctx):
			var f := e.fork()
			if _do(f, c):
				var v := value(f, ctx)
				if v > best_v:
					best = c
					best_v = v
		if best.is_empty() or not _do(e, best):
			return


## The value of e's position (see the class doc).
static func value(e: GameEngine, ctx: Context) -> float:
	if e.is_over:
		return e.score()
	var w := ctx.w
	var ahead := mini(HORIZON, e.turn_limit() - e.turn)
	var next := _forecast(e, ctx)
	var v: float = e.score() + ahead * next.get("score", 0)
	for r in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT]:
		v += w[r] * _concave(e.resources.get(r, 0) + ahead * next.get(r, 0))
	var unrest: int = e.resources.get(GameEngine.UNREST, 0)
	v += w.unrest * unrest
	v -= w.unrest_rate * maxi(ahead * next.get(GameEngine.UNREST, 0), -unrest)  # calming counts only what there is
	var limit := e.unrest_limit()
	if limit >= 0:
		var over: int = unrest + 2 * next.get(GameEngine.UNREST, 0) + 1 - (limit - RISK_MARGIN)
		if over > 0:
			v -= w.risk * over * over
	if not ctx.valuing and not ctx.rollout:
		v += w.deck * ahead * _deck_worth(e, ctx)
	for tech in e.zone("researched").cards:
		for r in tech.def.cost:
			v += w.owned * tech.def.cost[r]
	return v + w.land * _land(e)


## Zeroes the forecast counters (315).
static func reset_forecast_counts() -> void:
	forecast_lookups = 0
	forecasts_computed = 0
	forecast_checks = 0
	forecast_mismatches = 0


## e's turn_forecast(), from ctx's cache when a position with the same forecast_key has been forecast before.
static func _forecast(e: GameEngine, ctx: Context) -> Dictionary:
	forecast_lookups += 1
	if not forecast_cache:
		forecasts_computed += 1
		return e.turn_forecast()
	if ctx.forecast_turn != e.turn and not ctx.shared_forecasts:
		for turn in ctx.forecasts.keys():
			if turn < e.turn:
				ctx.forecasts.erase(turn)
		ctx.forecast_turn = e.turn
	if not ctx.forecasts.has(e.turn):
		ctx.forecasts[e.turn] = {}
	var cache: Dictionary = ctx.forecasts[e.turn]
	var key := forecast_key(e, ctx)
	var cached: Variant = cache.get(key)
	if cached != null:
		if check_forecasts:
			forecast_checks += 1
			if e.turn_forecast() != cached:
				forecast_mismatches += 1
		return cached
	forecasts_computed += 1
	var fresh := e.turn_forecast()
	cache[key] = fresh
	return fresh


## What turn_forecast reads of e (315, 336): KEY_STATE_FIELDS (the turn, resources, effect score, eras, Anarchy and
## raid state) and each card in the engine's forecast_zones() with KEY_CARD_FIELDS. The hand, deck, supply and the
## unturned decks aren't in it, nor a zone no effect counts.
static func forecast_key(e: GameEngine, ctx: Context) -> Array:
	if ctx.forecast_zones.is_empty():
		ctx.forecast_zones = e.forecast_zones()
	var key := [e.turn, e.is_over, e.state.bonus_score, e.state.era, e.state.revolt_pending,
		e.state.last_raid_turn, e.state.eras_added.size()]
	key.append_array(e.state.eras_added)  # the arrays' contents, flattened: a key mustn't hold a live array
	for r in e.state.resources:
		key.append_array([r, e.resources[r]])
	for z in ctx.forecast_zones:
		key.append(z)
		for c in e.state.zones[z].cards:
			key.append_array([c.uid, c.def.id, c.territory_uid, c.base_uid, c.station_uid, c.pop, c.turns_left, c.counters,
				c.progress, c.given_this_turn, c.raid_strength, c.keywords.size()])
			key.append_array(c.keywords)
	return key


## The cards a turn can play: the actions a turn, at most the hand size (the hand size for unlimited actions).
static func _plays_a_turn(e: GameEngine) -> int:
	var actions := e.actions_per_turn()
	return e.hand_size() if actions < 0 else mini(e.hand_size(), actions)


## A stock's worth: linear and steep below 0, with diminishing returns above STOCK_SCALE.
static func _concave(s: float) -> float:
	return 3.0 * s if s < 0 else STOCK_SCALE * log(1.0 + s / STOCK_SCALE)


## What a turn's plays from the cards drawn from (deck, hand and discard) are worth (376): turn_worth of their
## card_values, 0 for a card with nothing to act on now, with a hand of hand_size and _plays_a_turn plays.
static func _deck_worth(e: GameEngine, ctx: Context) -> float:
	var values := []
	var live := {}  # card id → whether it has something to act on (the same for every copy)
	for z in ["deck", "hand", "discard"]:
		for card in e.zone(z).cards:
			if not live.has(card.def.id):
				live[card.def.id] = not e.would_need_target(card.uid) or not e.would_target(card.uid).is_empty()
			values.append(card_value(e, card.def.id, ctx) if live[card.def.id] else 0.0)
	return turn_worth(values, e.hand_size(), _plays_a_turn(e))


## The expected sum of the best plays of a hand of hand cards drawn from cards worth values, each floored at 0 (a card
## the bot wouldn't play costs a draw, not value; 376). Sorted best first, the card with i better ones is played when
## it is drawn and fewer than plays of those are drawn with it (hypergeometric).
static func turn_worth(values: Array, hand: int, plays: int) -> float:
	var sorted: Array[float] = []
	for v in values:
		sorted.append(maxf(0.0, v))
	sorted.sort()
	sorted.reverse()
	var n := sorted.size()
	if n == 0:
		return 0.0
	var h := mini(hand, n)
	var others := _choose(n - 1, h - 1)  # the ways to draw the rest of a hand holding a given card
	var total := 0.0
	for i in n:
		if sorted[i] <= 0.0:
			break
		var played := 0.0
		for k in mini(plays, h):
			played += _choose(i, k) * _choose(n - 1 - i, h - 1 - k)
		total += sorted[i] * h / n * played / others
	return total


## n choose k, 0 outside 0..n.
static func _choose(n: int, k: int) -> float:
	if k < 0 or k > n:
		return 0.0
	var out := 1.0
	for j in mini(k, n - k):
		out = out * (n - j) / (j + 1)
	return out


## What playing a copy of card id now adds to the value (the deck's worth left out), measured on a sample fork where
## it is in the hand with an action to spare and its cost on hand, on its best of TARGETS_TRIED targets, owed decisions
## settled. Kept REVALUE_TURNS turns; with nothing to play it on (not kept), or while a decision is owed, the last
## value measured (0 if none).
static func card_value(e: GameEngine, id: String, ctx: Context) -> float:
	var cached: Array = ctx.card_values.get(id, [])
	if not cached.is_empty() and (e.turn - cached[0] < REVALUE_TURNS or ctx.valuing):
		return cached[1]
	var fallback: float = cached[1] if not cached.is_empty() else 0.0
	if e.is_over or e.pending().get("kind", "") != "":
		return fallback
	var f := e.sample_fork(hash([e.seed_value, e.turn, id]))
	var card := f.create_card(id, "hand", null)
	f.state.actions_gained += 1
	var cost := f.play_cost(card.uid)
	for r in cost:
		f.resources[r] = maxi(f.resources.get(r, 0), cost[r])
	var targets: Array = f.valid_targets(card.uid) if f.needs_target(card.uid) else [-1]
	if targets.is_empty():
		return fallback
	ctx.valuing = true
	var base := value(f, ctx)
	var best := -INF
	for t in targets.slice(0, TARGETS_TRIED):
		var g := f.fork()
		if g.play_card(card.uid, t):
			_settle(g, ctx)
			best = maxf(best, value(g, ctx))
	ctx.valuing = false
	var v := best - base if best > -INF else fallback
	ctx.card_values[id] = [e.turn, v]
	return v
