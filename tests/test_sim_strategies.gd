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


# --- AC2: safe growth ---

func test_strategies_grow_to_housing_when_nobody_eats() -> void:
	for strategy in STRATEGIES:
		var e := strategy_engine(30)
		BOT.take_turn(e, strategy)
		# Homeland houses 7 (5 slots + 2); growing 1 -> 7 costs 2 + 3 + ... + 7 = 27 food.
		eq(e.pop(home_uid(e)), 1 if strategy == "baseline" else 7, "%s: home pop" % strategy)


func test_strategies_stop_growing_before_the_next_upkeep_would_starve() -> void:
	var e := strategy_engine(9, {"population": pop_block(1)})
	BOT.take_turn(e, "growth")
	# Turn 1's upkeep: 9 + 2 (Capital) - 1 = 10 food. Pop 1 -> 2 (food 8) -> 3 (food 5): next upkeep 5 + 2 feeds 3.
	# Pop 4 would leave 1 + 2 for 4.
	eq(e.pop(home_uid(e)), 3, "home pop")
	eq(e.upkeep_forecast().get("starve", -1), 0, "nobody starves next upkeep")


# --- AC3: growth ---

func test_growth_plays_food_upkeep_cards_first() -> void:
	var e := strategy_engine(2)
	put_in_hand(e, "shrine")
	put_in_hand(e, "farm")
	var order := played_ids(e, func(): BOT.take_turn(e, "growth"))
	eq(order.slice(0, 2), ["farm", "shrine"] as Array[String], "Farm (food on upkeep) before Shrine")


func test_growth_grows_the_cheapest_territory_first() -> void:
	var e := strategy_engine(2)
	e.zone("tableau").find(home_uid(e)).pop = 3
	var grassland := settle_grassland(e, 1)
	BOT.take_turn(e, "growth")
	eq(e.pop(grassland), 2, "Grassland (cost 2) grew")
	eq(e.pop(home_uid(e)), 3, "Homeland (cost 4) didn't")


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


# --- AC5: wide vs tall ---

func test_wide_plays_explore_and_settle_cards_first() -> void:
	var e := strategy_engine(0)
	put_in_hand(e, "shrine")
	put_in_hand(e, "explorer")
	var order := played_ids(e, func(): BOT.take_turn(e, "wide"))
	eq(order.slice(0, 2), ["explorer", "shrine"] as Array[String], "Explorer before Shrine")


func test_wide_grows_the_lowest_pop_territory_first() -> void:
	var e := strategy_engine(2)
	e.zone("tableau").find(home_uid(e)).pop = 3
	var grassland := settle_grassland(e, 1)
	BOT.take_turn(e, "wide")
	eq(e.pop(grassland), 2, "Grassland (pop 1) grew")
	eq(e.pop(home_uid(e)), 3, "Homeland (pop 3) didn't")


func test_tall_stops_settling_at_two_territories() -> void:
	for strategy in ["wide", "tall"]:
		var e := strategy_engine(10, {"population": pop_block(0, 7)})
		settle_grassland(e, 4)
		to_frontier(e, ["hills"])
		var order := played_ids(e, func(): BOT.take_turn(e, strategy))
		eq(order.has("pioneer"), strategy == "wide", "%s settles a third territory" % strategy)


func test_tall_plays_food_cards_first_and_grows_the_roomiest_territory() -> void:
	var e := strategy_engine(0)  # turn 1's upkeep: 2 food from the Capital, all spent on the Farm
	var grassland := settle_grassland(e, 1)
	put_in_hand(e, "shrine")
	put_in_hand(e, "farm")
	var order := played_ids(e, func(): BOT.take_turn(e, "tall"))
	eq(order.slice(0, 2), ["farm", "shrine"] as Array[String], "Farm before Shrine")
	e.resources.food = 2
	BOT.take_turn(e, "tall")
	eq(e.pop(home_uid(e)), 2, "Homeland (houses 7) grew")
	eq(e.pop(grassland), 1, "Grassland (houses 4) didn't")


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
	eq(baseline.get("pop", {}).get("min"), 1, "baseline never grows")
	check(growth.get("pop", {}).get("min", 0) > 1, "growth grows: %s" % [growth.get("pop")])


func test_sim_stats_plays_as_a_civilization() -> void:
	var d := civ_sim_data({"shrine": 10}, {"turn_limit": 3})
	var plain: Dictionary = STATS.run(d.cards, d.config, [1], "baseline", "")
	var nomads: Dictionary = STATS.run(d.cards, d.config, [1], "baseline", "nomads")
	# Nomads: vp 1 and +1 score each upkeep (3 turns).
	eq(nomads.get("score", {}).get("min", 0) - plain.get("score", {}).get("min", 0), 4, "Nomads' score over no civ")


func test_sim_run_files_reports_every_strategy_and_civilization() -> void:
	var out: Dictionary = STATS.run_files("res://data/cards.json", "res://data/config.json", 1, "all")
	eq(out.get("code"), 0, "exit code")
	var text := "\n".join(out.get("lines", []))
	for strategy in STRATEGIES:
		check(strategy in text, "the report names %s" % strategy)
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	for civ in r.config.civilizations:
		check(civ in text, "the report names %s" % civ)
