extends "res://tests/lib/tech_case.gd"
## Tech eras (backlog 027): the add_era op, era-2 techs waiting in future_techs, and (140) learning the last tech of
## the research deck adding the next era.

const ERA_CARDS := [
	{"id": "philosophy", "name": "Philosophy", "type": "tech", "cost": {"insight": 3},
	 "effects": [{"op": "add_era", "era": 2}]},
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2},
	{"id": "academy", "name": "Academy", "type": "building", "cost": {"food": 1},
	 "effects": [{"op": "add_era", "era": 2}]},
]
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}


## Loads fixture cards plus a card 'x' with fields and effects; returns {cards, errors, warnings}.
func load_x(fields: Dictionary, type := "tech", effects: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "effects": effects}
	if type == "tech":
		x["cost"] = {"insight": 2}
	x.merge(fields, true)
	var cards := tech_db([x], errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## A game whose research deck starts with the era-1 techs in order_top_first (top first) and whose
## era-2 techs (optics, astronomy) wait in future_techs. deck is the main deck.
func era_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}) -> Object:
	var counts := {"optics": 1, "astronomy": 1}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {"research_deck": counts}
	config.merge(overrides, true)
	return tech_engine(order_top_first, deck, config, ERA_CARDS)


# --- AC1: loader and card text ---

func test_era_defaults_to_1_and_loads() -> void:
	eq(load_x({}).cards.x.era, 1, "default era")
	var r := load_x({"era": 2})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.cards.x.era, 2, "era")


func test_era_field_validation() -> void:
	check_cases([
		["era 0", [{"era": 0}, "tech", []], "cards.json: card 'x': era"],
		["era on a building", [{"era": 2}, "building", []], "cards.json: card 'x': 'era' only applies to techs", "warning_only"],
		["add_era without era", [{}, "tech", [{"op": "add_era"}]], "cards.json: card 'x': effects[0]: missing 'era'"],
		["add_era 1", [{}, "tech", [{"op": "add_era", "era": 1}]], "cards.json: card 'x': effects[0]: 'era' must be an integer >= 2"],
	], func(args): return load_x(args[0], args[1], args[2]))


func test_add_era_loads() -> void:
	var r := load_x({}, "tech", [{"op": "add_era", "era": 2}])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_era_card_text() -> void:
	var db := tech_db(ERA_CARDS)
	eq(db.philosophy.rules_text(db), "Adds era 2 techs", "add_era short")


# --- AC2: setup ---

func test_only_era_1_techs_start_in_the_research_deck() -> void:
	var e := era_engine(["philosophy", "pottery"])
	var deck := card_ids(e.zone("research_deck"))
	deck.sort()
	eq(deck, ["philosophy", "pottery"], "research deck")
	var future := card_ids(e.zone("future_techs"))
	future.sort()
	eq(future, ["astronomy", "optics"], "future_techs")
	eq(e.era(), 1, "era")


# --- AC3: add an era, once ---

func test_buying_an_era_tech_adds_the_next_era() -> void:
	var e := era_engine(["philosophy", "pottery"])
	check(e.buy_tech(uid_of(e.zone("research_deck"), "philosophy")), "learn Philosophy")
	var deck := card_ids(e.zone("research_deck"))
	deck.sort()
	eq(deck, ["astronomy", "optics", "pottery"], "research deck")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")
	eq(e.era(), 2, "era")


## Backlog 116: an era's techs added is a notice.
func test_an_eras_techs_added_is_a_notice() -> void:
	var e := era_engine(["philosophy", "pottery"])
	var recorded := record_messages(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "philosophy")), "learn Philosophy")
	check_noticed(recorded, "techs added to the tech deck")


func test_an_era_is_only_added_once() -> void:
	var e := era_engine(["philosophy", "pottery"], {"academy": 10})
	check(e.buy_tech(uid_of(e.zone("research_deck"), "philosophy")), "learn Philosophy")
	var size: int = e.zone("research_deck").size()
	check(e.play_card(first_in_hand(e)), "play Academy")
	eq(e.zone("research_deck").size(), size, "research deck unchanged")
	eq(e.era(), 2, "era")


func test_a_building_can_add_an_era() -> void:
	var e := era_engine(["philosophy", "pottery"], {"academy": 10})
	check(e.play_card(first_in_hand(e)), "play Academy")
	eq(e.zone("research_deck").size(), 4, "2 era-1 + 2 era-2 techs")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")
	eq(e.era(), 2, "era")


# --- AC4 (140 replaces the reveal's): learning the last tech adds the next era ---

func test_learning_the_last_era_tech_adds_the_next_era() -> void:
	var e := era_engine(["pottery"])
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	eq(e.era(), 2, "era")
	eq(sorted(card_ids(e.zone("research_deck"))), ["astronomy", "optics"], "era-2 techs in the research deck")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")


func test_learning_the_last_tech_with_no_eras_left_adds_nothing() -> void:
	var e := tech_engine(["pottery"])
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	eq(e.era(), 1, "still era 1")
	eq(e.zone("research_deck").size(), 0, "research deck empty")


# --- Era unlock thresholds (backlog 029) ---

## A game with era-2 techs waiting, population on (start 2) and era_unlocks; starting resources as given.
func threshold_engine(unlocks: Dictionary, start_resources := {"food": 10, "wealth": 0}, tableau: Array = ["capital"]) -> Object:
	var overrides := {
		"era_unlocks": unlocks,
		"starting": {"resources": start_resources, "tableau": tableau, "territory": "homeland"},
	}
	overrides.merge(POP)
	return era_engine(["pottery", "writing"], {"farm": 10}, overrides)


func threshold_config_errors(unlocks: Variant) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db(ERA_CARDS)
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {"era_unlocks": unlocks}), resources(), cards, "config.json", errors, warnings)
	return {"config": config, "errors": errors, "warnings": warnings}


func set_home_pop(e: Object, n: int) -> void:
	e.zone("tableau").find(home_uid(e)).pop = n


# AC1: config

func test_era_unlocks_is_normalized() -> void:
	var r := threshold_config_errors({"2": {"pop": 8.0, "wealth": 15}})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.config.get("era_unlocks"), {2: {"pop": 8, "wealth": 15}}, "era_unlocks")


func test_era_unlocks_defaults_to_empty() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), tech_db(ERA_CARDS), "config.json", errors, warnings)
	eq(config.get("era_unlocks"), {}, "default")


func test_era_unlocks_validation() -> void:
	check_cases([
		["era key 1", {"1": {"pop": 8}}, "config.json: era_unlocks"],
		["era key 0", {"0": {"pop": 8}}, "config.json: era_unlocks"],
		["era key not a number", {"two": {"pop": 8}}, "config.json: era_unlocks"],
		["value not an object", {"2": 8}, "config.json: era_unlocks"],
		["no threshold", {"2": {}}, "config.json: era_unlocks"],
		["pop 0", {"2": {"pop": 0}}, "config.json: era_unlocks"],
		["wealth not an int", {"2": {"wealth": "lots"}}, "config.json: era_unlocks"],
		["unknown field", {"2": {"pop": 8, "food": 3}}, "config.json: era_unlocks", "warning_only"],
	], threshold_config_errors)


func test_era_unlocks_query_returns_the_config() -> void:
	var e := threshold_engine({"2": {"pop": 4}})
	eq(e.era_unlocks(), {2: {"pop": 4}}, "era_unlocks()")


# AC2: pop threshold

func test_reaching_the_pop_threshold_adds_the_era() -> void:
	var e := threshold_engine({"2": {"pop": 4}})
	set_home_pop(e, 4)
	e.end_turn()
	eq(e.era(), 2, "era")
	var deck := card_ids(e.zone("research_deck"))
	check(deck.has("optics") and deck.has("astronomy"), "era-2 techs in the research deck: %s" % [deck])
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")


func test_below_the_pop_threshold_nothing_happens() -> void:
	var e := threshold_engine({"2": {"pop": 4}})
	set_home_pop(e, 3)
	e.end_turn()
	eq(e.era(), 1, "era")
	eq(e.zone("future_techs").size(), 2, "era-2 techs still waiting")


# AC3: wealth threshold, not spent

func test_reaching_the_wealth_threshold_adds_the_era_without_spending() -> void:
	var e := threshold_engine({"2": {"wealth": 15}})
	e.resources.wealth = 15
	e.end_turn()
	eq(e.era(), 2, "era")
	eq(e.resources.wealth, 15, "wealth not spent")


func test_below_the_wealth_threshold_nothing_happens() -> void:
	var e := threshold_engine({"2": {"wealth": 15}})
	e.resources.wealth = 14
	e.end_turn()
	eq(e.era(), 1, "era")


# AC4: either is enough

func test_either_threshold_is_enough() -> void:
	var e := threshold_engine({"2": {"pop": 99, "wealth": 15}})
	e.resources.wealth = 15
	e.end_turn()
	eq(e.era(), 2, "era")


# AC5: checked at the start of the turn only

func test_the_threshold_is_checked_at_the_start_of_turn_1() -> void:
	var e := threshold_engine({"2": {"wealth": 15}}, {"food": 10, "wealth": 20})
	eq(e.turn, 1, "turn")
	eq(e.era(), 2, "era on turn 1")


func test_reaching_the_threshold_mid_turn_waits_for_the_next_turn() -> void:
	var e := threshold_engine({"2": {"wealth": 15}})
	e.resources.wealth = 15
	eq(e.era(), 1, "still era 1 mid-turn")
	e.end_turn()
	eq(e.era(), 2, "era 2 next turn")


func test_upkeep_gains_count_toward_the_threshold() -> void:
	var e := threshold_engine({"2": {"wealth": 15}}, {"food": 10, "wealth": 0}, ["capital", "stall"])
	e.resources.wealth = 14
	e.end_turn()
	eq(e.resources.wealth, 15, "14 + Stall 1")
	eq(e.era(), 2, "era")


func test_pop_that_starves_does_not_count() -> void:
	var e := threshold_engine({"2": {"pop": 4}}, {"food": 0, "wealth": 0})
	set_home_pop(e, 4)
	e.resources.food = 0
	e.end_turn()
	eq(e.total_pop(), 3, "Capital +2 food feeds 2 of 4: a new Famine kills 1 (083)")
	eq(e.era(), 1, "era")


# AC6: once per era

func test_an_era_added_by_a_tech_is_not_added_again() -> void:
	var e := era_engine(["philosophy", "pottery"], {"farm": 10}, {"era_unlocks": {"2": {"pop": 4}}, "population": POP.population})
	check(e.buy_tech(uid_of(e.zone("research_deck"), "philosophy")), "learn Philosophy")
	eq(e.era(), 2, "era 2 from Philosophy")
	var size: int = e.zone("research_deck").size()
	set_home_pop(e, 4)
	e.resources.food = 10
	e.end_turn()
	eq(e.zone("research_deck").size(), size, "research deck unchanged")
	e.end_turn()
	eq(e.zone("research_deck").size(), size, "still unchanged a turn later")
	eq(e.era(), 2, "era")


func test_an_era_added_by_an_empty_deck_is_not_added_again() -> void:
	var e := threshold_engine({"2": {"wealth": 15}}, {"food": 10, "wealth": 0, "insight": 20})
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	check(e.buy_tech(uid_of(e.zone("research_deck"), "writing")), "learn Writing: the deck is empty, era 2 comes")
	var size: int = e.zone("research_deck").size()
	e.resources.wealth = 15
	e.end_turn()
	eq(e.zone("research_deck").size(), size, "research deck unchanged")
	eq(e.era(), 2, "era")
