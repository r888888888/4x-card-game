extends "res://tests/lib/test_case.gd"
## Food upkeep for population (backlog 011): pop eats food after production at the start of each turn. A shortfall
## brings a Famine (083): test_famine.gd covers what it kills and where.


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
