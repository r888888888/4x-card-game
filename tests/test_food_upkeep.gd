extends "res://tests/lib/test_case.gd"
## Food upkeep for population (backlog 011): pop eats food after production at the start of each turn,
## and each unpaid food starves 1 pop from the biggest territory (ties: the one settled first).


## Config overrides: population on with start pop and food_upkeep, and starting food on Homeland under
## the starting tableau cards.
func pop_overrides(start: int, food: int, food_upkeep := 1, tableau: Array = ["capital"]) -> Dictionary:
	return {
		"population": {"start": start, "food_upkeep": food_upkeep, "vp_per_pop": 1},
		"starting": {"resources": {"food": food}, "tableau": tableau, "territory": "homeland"},
	}


# --- AC1: pop eats food at upkeep ---

func test_pop_eats_food_at_upkeep() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(2, 2))
	eq(e.resources.food, 2, "food: 2 start + 2 Capital - 2 eaten")
	eq(e.pop(home_uid(e)), 2, "homeland pop")


func test_pop_eats_every_turn() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(2, 2))
	e.end_turn()
	eq(e.resources.food, 2, "food: 2 + 2 Capital - 2 eaten")
	eq(e.turn, 2, "turn")


# --- AC2: eating happens after production ---

func test_pop_eats_after_production() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(2, 0))
	eq(e.resources.food, 0, "food: 0 + 2 Capital - 2 eaten")
	eq(e.pop(home_uid(e)), 2, "no starvation: production paid for it")


# --- AC3: a shortfall starves pop ---

func test_shortfall_starves_pop() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(3, 0))
	eq(e.pop(home_uid(e)), 2, "homeland pop: 3 - 1 starved")
	eq(e.total_pop(), 2, "total pop")
	eq(e.resources.food, 0, "food: 0 + 2 Capital - 2 eaten, never below 0")


# --- AC4: starve from the biggest territory, ties to the one settled first ---

## Homeland (Capital, +2) and a settled Grassland (City, +1), with pops home_pop and t_pop and 0 food.
## Returns [engine, grassland uid].
func two_territories(home_pop: int, t_pop: int) -> Array:
	var o := pop_overrides(home_pop, 10)
	o["territory_deck"] = {"grassland": 1}
	var e := make_engine({"pioneer": 10}, o)
	e.zone("frontier").add(e.zone("territory_deck").take_top())
	var t: int = e.zone("frontier").cards[0].uid
	check(e.play_card(first_in_hand(e), t), "settle grassland")
	e.zone("tableau").find(t).pop = t_pop
	e.resources.food = 0
	return [e, t]


func test_starvation_hits_the_biggest_territory() -> void:
	var r := two_territories(1, 3)
	var e: GameEngine = r[0]
	e.end_turn()  # produce 3, eat 4: 1 short
	eq(e.pop(r[1]), 2, "grassland (biggest) loses 1")
	eq(e.pop(home_uid(e)), 1, "homeland untouched")
	eq(e.resources.food, 0, "food")


func test_each_unpaid_food_rechecks_the_biggest_territory() -> void:
	var r := two_territories(2, 3)
	var e: GameEngine = r[0]
	e.end_turn()  # produce 3, eat 5: 2 short
	eq(e.pop(r[1]), 2, "grassland 3 -> 2 (biggest)")
	eq(e.pop(home_uid(e)), 1, "then a 2-2 tie: homeland (settled first) 2 -> 1")


func test_starvation_tie_goes_to_the_territory_settled_first() -> void:
	var r := two_territories(2, 2)
	var e: GameEngine = r[0]
	e.end_turn()  # produce 3, eat 4: 1 short
	eq(e.pop(home_uid(e)), 1, "homeland (settled first) loses 1")
	eq(e.pop(r[1]), 2, "grassland keeps 2")


# --- AC5: pop can drop to 0; the city stays; 0 pop eats nothing ---

func test_pop_can_starve_to_0_and_the_city_stays() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(1, 0, 1, ["village"]))  # Village produces nothing
	eq(e.pop(home_uid(e)), 0, "homeland pop: 1 - 1 starved")
	check(card_ids(e.zone("tableau")).has("village"), "village stays on the tableau")
	e.resources.food = 5
	e.end_turn()
	eq(e.resources.food, 5, "0 pop eats nothing")


# --- AC6: no eating when food_upkeep is 0 or population is off ---

func test_food_upkeep_0_eats_nothing() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(3, 2, 0))
	eq(e.resources.food, 4, "food: 2 + 2 Capital")
	eq(e.pop(home_uid(e)), 3, "pop")


func test_without_population_upkeep_eats_nothing() -> void:
	var e := make_engine({"farm": 10})
	eq(e.resources.food, 4, "food: 2 + 2 Capital")
