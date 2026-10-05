class_name GenericBot
extends RefCounted
## A sim bot with no rule for any one mechanic (313, from spike/generic-bot). Each step it takes the engine's
## legal_actions() (an owed decision's options when one is owed), tries each on a sample fork (311: hidden orders drawn
## from a seed, so it never knows the future), values the fork with value() and does the best, stopping when nothing
## beats doing nothing. A new action reaches it through legal_actions with no change here.
##
## value() = score + turns ahead × the next turn's score (turn_forecast, 309) + Σ weight × concave(stock + turns ahead ×
## its forecast change) for food, wealth and insight − weight × unrest − a squared penalty as unrest nears its limit +
## the deck's worth (what its cards would add if played, 0 for one with nothing to act on, 310) + the printed cost of
## the techs learned. Turns ahead = min(HORIZON, turns left): income counts early, only points at the end.

## The strategy name SimStats plays it under.
const STRATEGY := "generic"
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
## The most renewal combinations tried.
const RENEWAL_COMBOS := 40
## Actions the bot never takes itself: play ends the turn; revolts are weighed by rollouts (314).
const SKIPPED := ["end_turn", "revolt"]
## Each strategy's weights: per unit of food, wealth and insight (projected, diminishing), per unrest (0: unrest costs
## through its risk only), the deck's worth (× turns ahead × plays a turn), the unrest risk (squared) and each point of
## learned techs' printed cost.
const WEIGHTS := {
	"generic": {"food": 0.5, "wealth": 0.7, "insight": 0.5, "unrest": 0.0, "deck": 0.05, "risk": 3.0, "owned": 0.5},
}


## What one game's choices share: the weights, measured card values ({id: [turn, value]}), a step counter for sample
## seeds, and whether a card value is being measured (the deck's worth is then left out, or it would recurse).
class Context:
	var w: Dictionary
	var card_values := {}
	var step := 0
	var valuing := false

	func _init(strategy: String) -> void:
		w = WEIGHTS[strategy]


## Plays engine's game to the end with strategy: each turn take_turn, then the hand discarded (it never cycles
## otherwise, 024) and the turn ended. Returns whether it ended within MAX_STEPS.
static func play(engine: GameEngine, strategy := STRATEGY) -> bool:
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
	return steps


## The entry ([action, args…]) to do next, [] for none: the owed decision's option whose fork values most, else the
## candidate whose fork beats doing nothing by most. Changes nothing in engine.
static func best_action(engine: GameEngine, strategy := STRATEGY, ctx: Context = null, look_on := true) -> Array:
	ctx = ctx if ctx != null else Context.new(strategy)
	var deciding: bool = engine.pending().get("kind", "") != ""
	var seed := hash([engine.seed_value, engine.turn, ctx.step])
	ctx.step += 1
	var base := value(engine, ctx)
	var best: Array = []
	var best_v := -INF if deciding else base + EPS
	for c in _candidates(engine, ctx):
		var f := engine.sample_fork(seed)
		if not _do(f, c):
			continue
		_settle(f, ctx)
		var v := value(f, ctx)
		if look_on and not deciding and absf(v - base) < QUIET and _refunds(engine, f, c):
			var next := best_action(f, strategy, ctx, false)
			if not next.is_empty():
				var g := f.fork()
				_do(g, next)
				_settle(g, ctx)
				v = maxf(v, value(g, ctx))
		if v > best_v:
			best = c
			best_v = v
	return best


## The entries the bot tries: legal_actions() but SKIPPED, the buys cut to BUYS_TRIED, a renewal expanded to its
## combinations.
static func _candidates(e: GameEngine, ctx: Context) -> Array:
	var out := []
	var buys := []
	for entry in e.legal_actions():
		if SKIPPED.has(entry[0]):
			continue
		if entry[0] == "buy":
			buys.append(entry)
		elif entry[0] == "renew":
			for combo in _combos(entry[1], entry[2]):
				out.append(["renew", combo])
		else:
			out.append(entry)
	var rank := func(entry: Array) -> float: return card_value(e, entry[1], ctx) / maxf(1.0, e.buy_price(entry[1]))
	buys.sort_custom(func(a, b): return rank.call(a) > rank.call(b))
	return out + buys.slice(0, BUYS_TRIED)


## Whether c is a play that gave back some of what a play spends: a card (a draw) or an action.
static func _refunds(before: GameEngine, after: GameEngine, c: Array) -> bool:
	if c[0] != "play_card":
		return false
	var spent := before.zone("hand").size() + before.actions_left() - after.zone("hand").size() - after.actions_left()
	return spent < 2


## Calls entry's action on e; false when it refused.
static func _do(e: GameEngine, entry: Array) -> bool:
	return e.callv(entry[0], entry.slice(1)) != false


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
	var next := e.turn_forecast()
	var v: float = e.score() + ahead * next.get("score", 0)
	for r in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT]:
		v += w[r] * _concave(e.resources.get(r, 0) + ahead * next.get(r, 0))
	var unrest: int = e.resources.get(GameEngine.UNREST, 0)
	v += w.unrest * unrest
	var limit := e.unrest_limit()
	if limit >= 0:
		var over: int = unrest + 2 * next.get(GameEngine.UNREST, 0) + 1 - (limit - RISK_MARGIN)
		if over > 0:
			v -= w.risk * over * over
	if not ctx.valuing:
		v += w.deck * ahead * mini(e.hand_size(), maxi(e.actions_per_turn(), 1)) * _deck_worth(e, ctx)
	for tech in e.zone("researched").cards:
		for r in tech.def.cost:
			v += w.owned * tech.def.cost[r]
	return v


## A stock's worth: linear and steep below 0, with diminishing returns above STOCK_SCALE.
static func _concave(s: float) -> float:
	return 3.0 * s if s < 0 else STOCK_SCALE * log(1.0 + s / STOCK_SCALE)


## The average card_value of the cards drawn from (deck, hand and discard), 0 for a card with nothing to act on now.
static func _deck_worth(e: GameEngine, ctx: Context) -> float:
	var total := 0.0
	var n := 0
	var live := {}  # card id → whether it has something to act on (the same for every copy)
	for z in ["deck", "hand", "discard"]:
		for card in e.zone(z).cards:
			n += 1
			if not live.has(card.def.id):
				live[card.def.id] = not e.would_need_target(card.uid) or not e.would_target(card.uid).is_empty()
			if live[card.def.id]:
				total += card_value(e, card.def.id, ctx)
	return total / n if n > 0 else 0.0


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


## The combinations of k of items, in order, at most RENEWAL_COMBOS.
static func _combos(items: Array, k: int) -> Array:
	var out := []
	_combos_into(items, k, 0, [], out)
	return out


static func _combos_into(items: Array, k: int, start: int, picked: Array, out: Array) -> void:
	if out.size() >= RENEWAL_COMBOS:
		return
	if picked.size() == k:
		out.append(picked.duplicate())
		return
	for i in range(start, items.size()):
		picked.append(items[i])
		_combos_into(items, k, i + 1, picked, out)
		picked.pop_back()
