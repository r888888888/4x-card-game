extends "res://tests/lib/test_case.gd"
## Balance sim strategies (backlog 134): ScriptedBot plays a named strategy, and SimStats runs one per civilization.
## The bot and stats scripts are loaded untyped so this file parses before the new API exists.

var BOT: Variant = load("res://sim/bot.gd")
var STATS: Variant = load("res://sim/sim_stats.gd")
const STRATEGIES := ["baseline", "growth", "wealth", "wide", "tall"]


## A population block where nobody eats unless food_upkeep says so.
func pop_block(food_upkeep := 0, start := 1) -> Dictionary:
	return {"start": start, "food_upkeep": food_upkeep, "vp_per_pop": 1, "famine": FAMINE}


## A game with population on, this food, and a hand of unplayable Pioneers (no frontier); extra overrides.
func strategy_engine(food: int, overrides := {}) -> GameEngine:
	var o := {"population": pop_block(), "territory_deck": {"grassland": 2, "hills": 2},
		"starting": {"resources": {"food": food}, "tableau": ["capital"], "territory": "homeland"}}
	return make_engine({"pioneer": 10}, o.merged(overrides, true))


## The card ids engine plays during call, in order.
func played_ids(engine: GameEngine, call: Callable) -> Array[String]:
	var ids := {}
	for z in ["hand", "deck"]:
		for c in engine.zone(z).cards:
			ids[c.uid] = c.def.id
	var out: Array[String] = []
	var record := func(outcome: Dictionary): out.append(ids.get(outcome.get("uid", -1), "?"))
	engine.card_played.connect(record)
	call.call()
	engine.card_played.disconnect(record)
	return out


## Settles one Grassland from the territory deck at pop pop, and returns its uid.
func settle_grassland(engine: GameEngine, pop: int) -> int:
	settle(engine, ["grassland"])
	var uid := -1
	for c in engine.zone("tableau").cards:
		if c.def.id == "grassland":
			uid = c.uid
	engine.zone("tableau").find(uid).pop = pop
	return uid


# --- AC1: named strategies, baseline is today's bot ---

func test_bot_strategies_are_named() -> void:
	eq(BOT.get_script_constant_map().get("STRATEGIES"), STRATEGIES, "ScriptedBot.STRATEGIES")


func test_baseline_is_the_default_bot() -> void:
	var deck := {"farm": 3, "shrine": 3, "pioneer": 2, "explorer": 2}
	var o := {"turn_limit": 6, "population": pop_block(1, 2), "territory_deck": {"grassland": 3, "hills": 3}}
	for s in [1, 2, 3]:
		var a := make_engine(deck, o, s)
		var b := make_engine(deck, o, s)
		BOT.play(a)
		BOT.play(b, "baseline")
		eq(b.score(), a.score(), "seed %d: score" % s)
		eq(b.resources, a.resources, "seed %d: resources" % s)
		eq(card_ids(b.zone("tableau")), card_ids(a.zone("tableau")), "seed %d: tableau" % s)


func test_unknown_strategy_plays_nothing() -> void:
	var e := make_engine({"shrine": 10}, {"turn_limit": 3})
	var hand := card_ids(e.zone("hand"))
	eq(BOT.play(e, "chaos"), false, "play returns false")
	eq(e.turn, 1, "no turn played")
	eq(card_ids(e.zone("hand")), hand, "hand untouched")


# --- AC3: growth ---

func test_growth_plays_food_upkeep_cards_first() -> void:
	var e := strategy_engine(2)
	put_in_hand(e, "shrine")
	put_in_hand(e, "farm")
	var order := played_ids(e, func(): BOT.take_turn(e, "growth"))
	eq(order.slice(0, 2), ["farm", "shrine"] as Array[String], "Farm (food on upkeep) before Shrine")


# --- AC4: wealth ---

func test_wealth_plays_wealth_cards_first() -> void:
	var e := strategy_engine(0)
	put_in_hand(e, "shrine")
	put_in_hand(e, "stall")
	var order := played_ids(e, func(): BOT.take_turn(e, "wealth"))
	eq(order.slice(0, 2), ["stall", "shrine"] as Array[String], "Stall (wealth on upkeep) before Shrine")


func test_wealth_buys_the_cheapest_wealth_card_once_a_turn() -> void:
	var e := strategy_engine(0, {"supply": {"scout": {"price": 1, "count": 3}, "stall": {"price": 2, "count": 3},
		"bazaar": {"price": 3, "count": 3}}})
	e.resources.wealth = 5
	BOT.take_turn(e, "wealth")
	eq(e.supply_left("stall"), 2, "one Stall bought (cheapest card that makes wealth)")
	eq(e.supply_left("bazaar"), 3, "no Bazaar")
	eq(e.supply_left("scout"), 3, "no Scout (makes no wealth)")


# --- 239: growth and tall buy food cards ---

## A strategy_engine game with 5 wealth and supply piles: Farm (⟳ +1 food) at farm_price, Paddy (⟳ food) at 3 and
## Scout (no food) at 1; Paddy listed before Farm when paddy_first.
func food_supply_engine(farm_price := 2, paddy_first := false) -> GameEngine:
	var farm := {"price": farm_price, "count": 3}
	var paddy := {"price": 3, "count": 3}
	var supply := {"paddy": paddy, "farm": farm} if paddy_first else {"farm": farm, "paddy": paddy}
	supply["scout"] = {"price": 1, "count": 3}
	var e := strategy_engine(0, {"supply": supply})
	e.resources.wealth = 5
	return e


func test_growth_and_tall_buy_the_cheapest_food_card_once_a_turn() -> void:
	for strategy in ["growth", "tall"]:
		var e := food_supply_engine()
		BOT.take_turn(e, strategy)
		eq(e.supply_left("farm"), 2, "%s: one Farm bought (cheapest card that makes food on upkeep)" % strategy)
		eq(e.supply_left("paddy"), 3, "%s: no Paddy" % strategy)
		eq(e.supply_left("scout"), 3, "%s: no Scout (makes no food)" % strategy)
		eq(e.resources.wealth, 3, "%s: 5 − 2" % strategy)


func test_a_food_card_price_tie_goes_to_the_pile_listed_first() -> void:
	var e := food_supply_engine(3, true)
	BOT.take_turn(e, "growth")
	eq(e.supply_left("paddy"), 2, "Paddy, listed first, bought")
	eq(e.supply_left("farm"), 3, "no Farm")


func test_growth_buys_no_food_card_it_cant_afford_or_that_isnt_open() -> void:
	var poor := food_supply_engine()
	poor.resources.wealth = 1
	BOT.take_turn(poor, "growth")
	eq(poor.supply_left("farm"), 3, "1 wealth buys no Farm")
	eq(poor.supply_left("scout"), 3, "nor a Scout")
	var no_food := strategy_engine(0, {"supply": {"scout": {"price": 1, "count": 3}}})
	no_food.resources.wealth = 5
	BOT.take_turn(no_food, "growth")
	eq(no_food.supply_left("scout"), 3, "no food pile: nothing bought")


func test_baseline_and_wide_buy_nothing_on_a_turn_with_no_anarchy_ahead() -> void:
	for strategy in ["baseline", "wide"]:
		var e := food_supply_engine()
		BOT.take_turn(e, strategy)
		eq([e.supply_left("farm"), e.supply_left("paddy"), e.supply_left("scout")], [3, 3, 3], "%s buys nothing" % strategy)
		eq(e.resources.wealth, 5, "%s keeps its wealth" % strategy)


# --- AC5: wide vs tall ---

func test_wide_plays_explore_and_settle_cards_first() -> void:
	var e := strategy_engine(0)
	put_in_hand(e, "shrine")
	put_in_hand(e, "explorer")
	var order := played_ids(e, func(): BOT.take_turn(e, "wide"))
	eq(order.slice(0, 2), ["explorer", "shrine"] as Array[String], "Explorer before Shrine")


func test_tall_stops_settling_at_two_territories() -> void:
	for strategy in ["wide", "tall"]:
		var e := strategy_engine(10, {"population": pop_block(0, 7)})
		settle_grassland(e, 4)
		to_frontier(e, ["hills"])
		var order := played_ids(e, func(): BOT.take_turn(e, strategy))
		eq(order.has("pioneer"), strategy == "wide", "%s settles a third territory" % strategy)


func test_tall_plays_food_cards_first() -> void:
	var e := strategy_engine(0)  # turn 1's upkeep: 2 food from the Capital, all spent on the Farm
	put_in_hand(e, "shrine")
	put_in_hand(e, "farm")
	var order := played_ids(e, func(): BOT.take_turn(e, "tall"))
	eq(order.slice(0, 2), ["farm", "shrine"] as Array[String], "Farm before Shrine")


# --- AC6: stats per strategy and civilization ---

## TEST_CARDS + TEST_CIVS and a config listing Tribe and Nomads, with this deck and overrides.
func civ_sim_data(deck: Dictionary, overrides := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := civ_db(errors, warnings)
	var o := {"civilizations": ["tribe", "nomads"]}
	var config := DataLoader.parse_config(raw_config(deck, o.merged(overrides, true)), resources(), cards, "test",
		errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return {"cards": cards, "config": config}


func test_sim_stats_runs_a_strategy() -> void:
	var d := civ_sim_data({"shrine": 10}, {"turn_limit": 2, "population": pop_block(),
		"starting": {"resources": {"food": 30}, "tableau": ["capital"], "territory": "homeland"}})
	var baseline: Dictionary = STATS.run(d.cards, d.config, [1], "baseline")
	var growth: Dictionary = STATS.run(d.cards, d.config, [1], "growth")
	for stats in [baseline, growth]:
		eq(stats.get("pop", {}).get("min"), 1, "pop stats, and no strategy grows pop itself (260): %s" % [stats.get("pop")])


func test_sim_stats_plays_as_a_civilization() -> void:
	var d := civ_sim_data({"shrine": 10}, {"turn_limit": 3})
	var plain: Dictionary = STATS.run(d.cards, d.config, [1], "baseline", "")
	var nomads: Dictionary = STATS.run(d.cards, d.config, [1], "baseline", "nomads")
	# Nomads: vp 1 and +1 score each upkeep (3 turns).
	eq(nomads.get("score", {}).get("min", 0) - plain.get("score", {}).get("min", 0), 4, "Nomads' score over no civ")
