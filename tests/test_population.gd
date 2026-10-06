extends "res://tests/lib/test_case.gd"
## Population on territories (backlog 009): territory housing, the config population block,
## starting and settled pop, total_pop and pop VP in the score.


## A population block. food_upkeep is 0 so these tests don't depend on starvation (backlog 011).
func population(start := 2, vp_per_pop := 1) -> Dictionary:
	return {"start": start, "food_upkeep": 0, "vp_per_pop": vp_per_pop}


func parse_test_cards(extra: Array, errors: Array[String], warnings: Array[String]) -> Dictionary:
	var list: Array = TEST_CARDS.cards.duplicate()
	list.append_array(extra)
	return DataLoader.parse_cards({"cards": list}, resources(), "cards.json", errors, warnings, keywords())


## Loads TEST_CARDS and a test config with overrides; returns {config, errors, warnings}.
func load_config(overrides: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := parse_test_cards([], errors, warnings)
	check(errors.is_empty(), "TEST_CARDS should load: %s" % [errors])
	var config := DataLoader.parse_config(raw_config({"farm": 1}, overrides), resources(), cards, "config.json", errors, warnings)
	return {"config": config, "errors": errors, "warnings": warnings}


## A game with population overrides whose frontier holds one Grassland and whose hand is Pioneers.
func pioneer_engine(overrides: Dictionary) -> GameEngine:
	var o := {"territory_deck": {"grassland": 1}}
	o.merge(overrides, true)
	var e := make_engine({"pioneer": 10}, o)
	to_frontier(e, ["grassland"])
	e.resources.food = 3
	return e


# --- AC1: territory housing ---

func test_housing_defaults_to_slots_plus_2() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := parse_test_cards([], errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(cards.grassland.housing, 4, "grassland: 2 slots + 2")
	eq(cards.homeland.housing, 7, "homeland: 5 slots + 2")


func test_housing_loads_when_given() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := parse_test_cards([{"id": "bog", "name": "Bog", "type": "territory", "slots": 1, "housing": 3}], errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.bog.housing, 3, "housing")


func test_housing_validation() -> void:
	check_cases([
		["housing 0", {"id": "bog", "name": "Bog", "type": "territory", "slots": 1, "housing": 0},
			"cards.json: card 'bog': 'housing' must be an integer >= 1"],
		["housing not an int", {"id": "bog", "name": "Bog", "type": "territory", "slots": 1, "housing": "x"},
			"cards.json: card 'bog': 'housing' must be an integer >= 1"],
		["housing on an action", {"id": "hut", "name": "Hut", "type": "action", "housing": 2},
			"card 'hut': 'housing' only applies to territories", "warning_only"],
	], card_load)


# --- AC2: config population block ---

func test_population_block_defaults() -> void:
	var r := load_config({"population": {}})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.config.population, {"start": 2, "food_upkeep": 1, "vp_per_pop": 1, "tiers": []}, "defaults (no tiers: 281)")


func test_population_block_values_load() -> void:
	var r := load_config({"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 2}})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	eq(r.config.population, {"start": 3, "food_upkeep": 0, "vp_per_pop": 2, "tiers": []}, "values (no tiers: 281)")


func test_no_population_block_leaves_population_off() -> void:
	var r := load_config({})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.config.population, {}, "no population block -> empty (off)")


func test_population_block_validation() -> void:
	check_cases([
		["start 0", {"start": 0}, "config.json: 'population.start' must be an integer >= 1"],
		["negative food_upkeep", {"food_upkeep": -1}, "config.json: 'population.food_upkeep' must be an integer >= 0"],
		["vp_per_pop not an int", {"vp_per_pop": "x"}, "config.json: 'population.vp_per_pop' must be an integer >= 0"],
		["not an object", 3, "config.json: 'population' must be an object"],
		["unknown key", {"growth": 1}, "config.json: population: unknown field 'growth'", "warning_only"],
		["start above starting housing (homeland: 5 slots -> housing 7)", {"start": 8}, ["population.start", "housing"]],
	], func(population): return load_config({"population": population}))


func test_population_start_equal_to_starting_housing_loads() -> void:
	eq(load_config({"population": {"start": 7}}).errors, [] as Array[String], "start == housing is fine")


# --- AC3: starting pop ---

func test_new_game_gives_starting_territory_start_pop() -> void:
	var e := make_engine({"farm": 10}, {"population": population(2)})
	var home := home_uid(e)
	eq(e.pop(home), 2, "homeland pop")
	eq(e.housing(home), 7, "homeland housing")
	eq(e.total_pop(), 2, "total pop")


func test_unsettled_territories_have_no_pop() -> void:
	var e := make_engine({"explorer": 10}, {"population": population(2), "territory_deck": {"grassland": 2, "hills": 1}})
	for c in e.zone("territory_deck").cards:
		eq(e.pop(c.uid), 0, "territory deck pop")
	check(e.play_card(first_in_hand(e)), "explore")
	for c in e.zone("reveal").cards:
		eq(e.pop(c.uid), 0, "revealed pop")
	e.choose(e.pending().options[0])
	eq(e.pop(e.zone("frontier").cards[0].uid), 0, "frontier pop")
	eq(e.total_pop(), 2, "only homeland counts")


# --- AC4: settling gives 1 pop ---

func test_settle_gives_new_territory_1_pop() -> void:
	var e := pioneer_engine({"population": population(2)})
	var territory: int = e.zone("frontier").cards[0].uid
	check(e.play_card(first_in_hand(e), territory), "settle")
	eq(e.pop(territory), 1, "settled territory pop")
	eq(e.total_pop(), 3, "total pop 2 + 1")


# --- AC5: pop counts toward the score ---

func test_score_adds_vp_per_pop() -> void:
	var e := make_engine({"farm": 10}, {"population": population(3, 1)})
	eq(e.score(), 5, "Capital 2 VP + 3 pop x 1")


func test_score_uses_vp_per_pop_rate() -> void:
	var e := make_engine({"farm": 10}, {"population": population(3, 2)})
	eq(e.score(), 8, "Capital 2 VP + 3 pop x 2")


func test_final_score_includes_pop_vp() -> void:
	var e := make_engine({"farm": 10}, {"population": population(3, 1), "turn_limit": 1})
	var final_scores := []
	e.game_over.connect(func(s): final_scores.append(s))
	e.end_turn()
	eq(final_scores, [5], "game_over final score: Capital 2 + 3 pop")


# --- AC6: no population block ---

func test_without_population_block_pop_is_always_0() -> void:
	var e := pioneer_engine({})
	var home := home_uid(e)
	var territory: int = e.zone("frontier").cards[0].uid
	eq(e.pop(home), 0, "homeland pop")
	check(e.play_card(first_in_hand(e), territory), "settle")
	eq(e.pop(territory), 0, "settled pop")
	eq(e.total_pop(), 0, "total pop")
	eq(e.score(), 4, "Capital 2 + City 2, no pop VP")
