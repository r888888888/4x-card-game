extends "res://tests/lib/test_case.gd"
## Civilization cards (backlog 062): the `civilization` card type, the `start` trigger, config
## `starting.civilization`, and the civilization's upkeep, VP and forecast. Fixtures in TEST_CIVS: Tribe (start +3 food,
## upkeep +1 wealth) and Nomads (1 VP, upkeep score 1).


## Loader errors for civ_db() plus extra cards.
func card_errors(extra: Array) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_CIVS + extra}, resources(), "cards.json", errors, warnings, keywords())
	return errors


## A card of type with one effect.
func one_effect(id: String, type: String, effect: Dictionary) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "type": type, "effects": [effect]}


func starting_with(civ: Variant) -> Dictionary:
	return {"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "civilization": civ}}


# --- AC1: the civilization type and starting.civilization ---

func test_civilization_cards_load() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := civ_db(errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.tribe.type, "civilization", "Tribe type")
	eq(cards.nomads.vp, 1, "Nomads VP")


func test_civilization_outside_its_place_is_a_load_error() -> void:
	check_cases([
		["in deck", {"deck": {"tribe": 1}}, "config.json: deck: 'tribe' is a civilization"],
		["in supply", {"supply": {"tribe": {"price": 1, "count": 1}}}, "config.json: supply: 'tribe' is a civilization"],
		["in territory_deck", {"territory_deck": {"tribe": 1}}, "config.json: territory_deck: 'tribe' is not a territory"],
		["in research_deck", {"research_deck": {"tribe": 1}}, "config.json: research_deck: 'tribe' is not a tech"],
		["in event_deck", {"event_deck": {"tribe": 1}}, "config.json: event_deck: 'tribe' is not a"],
	], func(overrides): return config_errors(overrides, [TEST_CIVS]))


func test_starting_civilization_validation() -> void:
	check_cases([
		["unknown id", starting_with("zzz"), "config.json: starting.civilization: unknown card 'zzz'", "one_error"],
		["not a civilization", starting_with("farm"), "config.json: starting.civilization: 'farm' is not a civilization", "one_error"],
		["not a string", starting_with(3), "config.json: starting.civilization", "one_error"],
	], func(overrides): return config_errors(overrides, [TEST_CIVS]))


func test_starting_civilization_is_optional() -> void:
	eq(config_errors({}, [TEST_CIVS]), [] as Array[String], "no starting.civilization")
	eq(config_errors(starting_with("tribe"), [TEST_CIVS]), [] as Array[String], "starting.civilization tribe")


# --- AC2: the start trigger ---

func test_start_trigger_only_on_civilizations() -> void:
	var gain := {"op": "gain", "resource": "food", "amount": 1, "trigger": "start"}
	check_cases([
		["on an action", [one_effect("feast", "action", gain)], "cards.json: card 'feast': effects[0]: trigger 'start' only works on civilizations"],
		["on a building", [one_effect("hut", "building", gain)], "cards.json: card 'hut': effects[0]: trigger 'start' only works on civilizations"],
		["on a tech", [one_effect("lore", "tech", gain)], "cards.json: card 'lore': effects[0]: trigger 'start' only works on civilizations"],
	], card_errors)
	eq(card_errors([one_effect("kin", "civilization", gain)]), [] as Array[String], "start gain on a civilization")


func test_start_effect_needing_a_target_or_choice_is_a_load_error() -> void:
	check_cases([
		["settle", [one_effect("kin", "civilization", {"op": "settle", "card": "city", "trigger": "start"})],
			"cards.json: card 'kin': effects[0]: 'settle' can't trigger on start"],
		["explore", [one_effect("kin", "civilization", {"op": "explore", "trigger": "start"})],
			"cards.json: card 'kin': effects[0]: 'explore' can't trigger on start"],
	], card_errors)


# --- AC3: setup ---

func test_starting_civilization_is_in_the_civilization_zone() -> void:
	var e: GameEngine = civ_engine("tribe")
	eq(card_ids(e.zone("civilization")), ["tribe"] as Array[String], "civilization zone")
	eq(e.civilization(), uid_of(e.zone("civilization"), "tribe"), "civilization() is Tribe's uid")
	check(e.civilization() >= 0, "a real uid")


func test_start_effects_resolve_once_before_the_first_upkeep() -> void:
	var e: GameEngine = civ_engine("tribe")
	eq(e.resources.food, 7, "2 starting + 3 start + 2 Capital upkeep")
	eq(e.resources.wealth, 1, "Tribe upkeep on turn 1")
	e.end_turn()
	eq(e.resources.food, 9, "start doesn't resolve again: + 2 Capital")


func test_civilization_is_not_in_the_deck_or_tableau() -> void:
	var e: GameEngine = civ_engine("tribe")
	for z in ["deck", "hand", "discard", "tableau"]:
		check(not card_ids(e.zone(z)).has("tribe"), "no Tribe in %s" % z)


# --- AC4: upkeep, forecast and score ---

func test_civilization_upkeep_every_turn() -> void:
	var e: GameEngine = civ_engine("tribe")
	e.end_turn()
	e.end_turn()
	eq(e.resources.wealth, 3, "+1 wealth on each of 3 upkeeps")


func test_forecast_includes_the_civilization() -> void:
	var e: GameEngine = civ_engine("tribe")
	eq(e.upkeep_forecast(), {"food": 2, "wealth": 1, "insight": 0, "starve": 0}, "Capital +2 food, Tribe +1 wealth")


func test_score_includes_civilization_vp_and_upkeep_score() -> void:
	var e: GameEngine = civ_engine("nomads")
	eq(e.score(), 4, "Capital 2 + Nomads 1 + 1 upkeep")
	e.end_turn()
	eq(e.score(), 5, "+1 more upkeep")


# --- AC5: no civilization ---

func test_without_a_civilization_play_is_as_before() -> void:
	var e: GameEngine = civ_engine("")
	eq(e.zone("civilization").size(), 0, "civilization zone empty")
	eq(e.civilization(), -1, "civilization()")
	eq(e.resources.food, 4, "2 + 2 Capital")
	eq(e.resources.wealth, 0, "wealth")
	eq(e.score(), 2, "Capital 2")


# --- AC6: fork ---

func test_fork_copies_the_civilization() -> void:
	var e: GameEngine = civ_engine("tribe")
	var f: GameEngine = e.fork()
	eq(card_ids(f.zone("civilization")), ["tribe"] as Array[String], "fork civilization zone")
	eq(f.civilization(), e.civilization(), "same uid")
	check(f.zone("civilization").cards[0] != e.zone("civilization").cards[0], "a copy, not the same card")


# --- Design note: card text for start effects ---

func test_start_effects_are_marked_on_the_card_text() -> void:
	var cards := civ_db()
	eq(cards.tribe.rules_text(cards), "Start: +3 food\n⟳ +1 wealth", "rules_text")
	eq(cards.tribe.rules_tooltip(cards), "When the game starts: +3 food\nEach upkeep: +1 wealth", "rules_tooltip")
