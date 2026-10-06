extends "res://tests/lib/test_case.gd"
## Population on territories (backlog 009): territory housing, the config population block,
## starting and settled pop, total_pop and pop VP in the score.


## A population block. food_upkeep is 0 so these tests don't depend on starvation (backlog 011).
func population(start := 2, vp_per_pop := 1) -> Dictionary:
	return {"start": start, "food_upkeep": 0, "vp_per_pop": vp_per_pop}


## Loads TEST_CARDS and a test config with overrides (through raw_config, so a population block gets FAMINE); returns
## {cards, config, errors, warnings}.
func load_config(overrides: Dictionary) -> Dictionary:
	var r := fixture_load()
	var errors: Array[String] = r.errors.duplicate()
	var warnings: Array[String] = r.warnings.duplicate()
	var config := DataLoader.parse_config(raw_config({"farm": 1}, overrides), resources(), r.cards, "config.json", errors,
		warnings)
	return {"cards": r.cards, "config": config, "errors": errors, "warnings": warnings}


## A game with population overrides whose frontier holds one Grassland and whose hand is Pioneers.
func pioneer_engine(overrides: Dictionary) -> GameEngine:
	var o := {"territory_deck": {"grassland": 1}}
	o.merge(overrides, true)
	var e := make_engine({"pioneer": 10}, o)
	to_frontier(e, ["grassland"])
	e.resources.food = 3
	return e


# --- AC1: territory housing ---

func test_housing_loads_and_defaults_to_slots_plus_2() -> void:
	check_loads([
		["defaults: grassland 2 slots + 2, homeland 5 slots + 2", [], {"cards.grassland.housing": 4, "cards.homeland.housing": 7}],
		["given", [{"id": "bog", "name": "Bog", "type": "territory", "slots": 1, "housing": 3}], {"cards.bog.housing": 3}],
	], fixture_load)


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

func test_population_block_loads() -> void:
	check_loads([
		["defaults (no tiers: 281)", {"population": {}},
			{"config.population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1, "tiers": []}}],
		["values (no tiers: 281)", {"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 2}},
			{"config.population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 2, "tiers": []}}],
		["no population block -> empty (off)", {}, {"config.population": {}}],
		["start == starting housing is fine", {"population": {"start": 7}}, {}],
	], load_config)


func test_population_block_validation() -> void:
	check_cases([
		["start 0", {"start": 0}, "config.json: 'population.start' must be an integer >= 1"],
		["negative food_upkeep", {"food_upkeep": -1}, "config.json: 'population.food_upkeep' must be an integer >= 0"],
		["vp_per_pop not an int", {"vp_per_pop": "x"}, "config.json: 'population.vp_per_pop' must be an integer >= 0"],
		["not an object", 3, "config.json: 'population' must be an object"],
		["unknown key", {"growth": 1}, "config.json: population: unknown field 'growth'", "warning_only"],
		["start above starting housing (homeland: 5 slots -> housing 7)", {"start": 8}, ["population.start", "housing"]],
	], func(population): return load_config({"population": population}))


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
