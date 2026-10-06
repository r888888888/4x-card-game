extends "res://tests/lib/test_case.gd"
## The trade op (backlog 055): needs min_cities cities, gives per_root_city × ⌊√cities⌋ plus 1 per pop_per total pop.


const TRADE := {"op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2}


## Loads one action card x with effect; returns {cards, errors, warnings}.
func trade_card(effect: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "effects": [effect]}]},
		resources(), "cards.json", errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## TRADE with key set to value (or removed when value is null).
func trade_with(key: String, value: Variant) -> Dictionary:
	var effect := TRADE.duplicate()
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


## A game with a hand of Traders, the Capital plus cities - 1 more cities in the tableau, total_pop pop on the
## Homeland (population on) and 3 food, 0 wealth.
func trade_engine(cities: int, total_pop: int, population := true) -> GameEngine:
	var o := {}
	if population:
		o["population"] = {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}
	var e := make_engine({"trader": 10}, o)
	for i in cities - 1:
		e.create_card("city", "tableau", null)
	if population:
		e.zone("tableau").find(home_uid(e)).pop = total_pop
	e.resources.food = 3
	e.resources.wealth = 0
	return e


# --- AC1: loading ---

func test_trade_op_loads() -> void:
	check_loads([
		["Trade", TRADE, {}],
	], trade_card)


func test_trade_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["missing resource", trade_with("resource", null), prefix + "missing 'resource'"],
		["unknown resource", trade_with("resource", "gold"), prefix + "'resource' must be one of"],
		["missing per_root_city", trade_with("per_root_city", null), prefix + "missing 'per_root_city'"],
		["per_root_city 0", trade_with("per_root_city", 0), prefix + "'per_root_city' must be an integer >= 1"],
		["missing pop_per", trade_with("pop_per", null), prefix + "missing 'pop_per'"],
		["pop_per not an integer", trade_with("pop_per", 2.5), prefix + "'pop_per' must be an integer >= 1"],
		["pop_per a string", trade_with("pop_per", "5"), prefix + "'pop_per' must be an integer >= 1"],
		["missing min_cities", trade_with("min_cities", null), prefix + "missing 'min_cities'"],
		["min_cities 0", trade_with("min_cities", 0), prefix + "'min_cities' must be an integer >= 1"],
	], trade_card)


# --- AC2: too few cities ---

func test_trade_with_too_few_cities_is_refused() -> void:
	var e := trade_engine(1, 5)
	var trader := first_in_hand(e)
	eq(e.play_error(trader), "Trader needs 2 cities (you have 1).", "play_error")
	check(not e.play_card(trader), "play_card refuses")
	check(e.zone("hand").find(trader) != null, "Trader stays in the hand")
	eq(e.resources.food, 3, "food unchanged")
	eq(e.resources.wealth, 0, "wealth unchanged")


# --- AC3, AC4: payout ---

func test_trade_with_2_cities_and_5_pop_gives_3_wealth() -> void:
	var e := trade_engine(2, 5)
	check(e.play_card(first_in_hand(e)), "play Trader")
	eq(e.resources.wealth, 3, "2×⌊√2⌋ + ⌊5/5⌋")
	eq(e.resources.food, 2, "costs 1 food")


func test_trade_scales_with_root_cities_and_pop() -> void:
	for row in [[3, 10, 4], [4, 16, 7], [2, 4, 2]]:
		var e := trade_engine(row[0], row[1])
		check(e.play_card(first_in_hand(e)), "play Trader with %d cities" % row[0])
		eq(e.resources.wealth, row[2], "%d cities, %d pop" % [row[0], row[1]])


func test_trade_without_population_counts_no_pop() -> void:
	var e := trade_engine(2, 0, false)
	check(e.play_card(first_in_hand(e)), "play Trader")
	eq(e.resources.wealth, 2, "2×⌊√2⌋, no pop")


# --- AC5: text ---

func test_trade_text() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	eq(cards.trader.rules_text(cards), "Needs 2 cities\n+2 wealth ×√cities, +1 per 5 pop", "short text")
	eq(cards.trader.rules_tooltip(cards),
		"Needs 2 cities. Gain 2 wealth × √cities (rounded down), plus 1 wealth per 5 pop.", "tooltip")
