extends "res://tests/lib/test_case.gd"
## Upkeep forecast (backlog 035): upkeep_forecast() predicts how food and wealth on hand change at the
## next upkeep, net of what pop eats, and how many pop would starve.


## Population on (start 2, vp_per_pop 0), then Homeland set to pop, with food and wealth on hand.
func forecast_engine(pop: int, food := 5, wealth := 0, food_upkeep := 1) -> GameEngine:
	var e := make_engine({"scout": 10}, {"population": {"start": 2, "food_upkeep": food_upkeep, "vp_per_pop": 0}})
	e.zone("tableau").find(home_uid(e)).pop = pop
	e.resources.food = food
	e.resources.wealth = wealth
	return e


## Puts buildings card_ids on Homeland, in order (the last ones go idle first).
func build(e: GameEngine, card_ids: Array[String]) -> void:
	for id in card_ids:
		var card := CardInstance.new(1000 + e.zone("tableau").size(), e.card_db[id])
		card.territory_uid = home_uid(e)
		e.zone("tableau").add(card)


# --- AC1: production minus what pop eats, with no side effects ---

func test_forecast_is_production_minus_upkeep() -> void:
	var e := forecast_engine(2)
	build(e, ["farm", "stall"])
	eq(e.upkeep_forecast(), {"food": 1, "wealth": 1, "starve": 0}, "2 + 1 made, 2 eaten; 1 wealth")


func test_forecast_changes_nothing() -> void:
	var e := forecast_engine(2, 5, 3)
	build(e, ["farm", "stall", "granary"])
	e.zone("tableau").find(home_uid(e)).pop = 3
	var changes := []
	e.changed.connect(func(): changes.append(true))
	var log_size := e.log_lines.size()
	var score := e.score()
	var zone_sizes := {}
	for z in GameEngine.ZONES:
		zone_sizes[z] = e.zone(z).size()
	e.upkeep_forecast()
	eq(e.resources, {"food": 5, "wealth": 3}, "resources unchanged")
	eq(e.pop(home_uid(e)), 3, "pop unchanged (Granary didn't grow it)")
	eq(e.score(), score, "score unchanged")
	eq(e.log_lines.size(), log_size, "nothing logged")
	for z in GameEngine.ZONES:
		eq(e.zone(z).size(), zone_sizes[z], "zone %s unchanged" % z)
	eq(changes.size(), 0, "changed not emitted")


# --- AC2: idle buildings don't count ---

func test_forecast_skips_idle_buildings() -> void:
	var e := forecast_engine(1)
	build(e, ["farm", "stall"])
	eq(e.upkeep_forecast(), {"food": 2, "wealth": 0, "starve": 0}, "Stall idle: 2 + 1 made, 1 eaten")


# --- AC3: pop added at upkeep eats that upkeep ---

func test_forecast_counts_pop_grown_at_upkeep() -> void:
	var e := forecast_engine(2)
	build(e, ["granary"])
	eq(e.upkeep_forecast().food, -1, "2 made, 3 eaten after Granary adds a pop")


func test_forecast_no_growth_at_housing_cap() -> void:
	var e := forecast_engine(7)
	build(e, ["granary"])
	eq(e.upkeep_forecast().food, -5, "2 made, 7 eaten: Homeland is full")


# --- AC4: a shortfall shows plain net food and the pop that would starve ---

func test_forecast_starve_with_no_food() -> void:
	var e := forecast_engine(2, 0, 0, 2)
	eq(e.upkeep_forecast(), {"food": -2, "wealth": 0, "starve": 2}, "2 made, 4 needed, 2 short")


func test_forecast_starve_with_some_food() -> void:
	var e := forecast_engine(2, 1, 0, 2)
	eq(e.upkeep_forecast(), {"food": -2, "wealth": 0, "starve": 1}, "1 + 2 on hand, 4 needed, 1 short")


# --- AC5: population off ---

func test_forecast_without_population_is_production() -> void:
	var e := make_engine({"scout": 10})
	build(e, ["farm"])
	var f: Dictionary = e.upkeep_forecast()
	eq(f.food, 3, "Capital 2 + Farm 1, nobody eats")
	eq(f.starve, 0, "no starvation")


# --- AC6: matches the real upkeep; empty when there is no next turn ---

func test_forecast_matches_next_upkeep() -> void:
	var e := forecast_engine(2, 5, 0)
	build(e, ["farm", "stall"])
	var f: Dictionary = e.upkeep_forecast()
	e.end_turn()
	eq(e.resources.food, 5 + f.food, "food changed by the forecast")
	eq(e.resources.wealth, 0 + f.wealth, "wealth changed by the forecast")


func test_forecast_shortfall_matches_next_upkeep() -> void:
	var e := forecast_engine(2, 1, 0, 2)
	var f: Dictionary = e.upkeep_forecast()
	e.end_turn()
	eq(e.resources.food, 0, "food clamped at 0")
	eq(e.total_pop(), 2 - f.starve, "forecast starve count died")


func test_forecast_empty_on_last_turn() -> void:
	var e := make_engine({"scout": 10}, {"turn_limit": 2})
	e.end_turn()
	eq(e.turn, 2, "last turn")
	eq(e.upkeep_forecast(), {}, "no next upkeep")


func test_forecast_empty_after_game_over() -> void:
	var e := make_engine({"scout": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	eq(e.upkeep_forecast(), {}, "no next upkeep")
