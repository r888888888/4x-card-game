extends "res://tests/lib/test_case.gd"
## Storage buildings (backlog 060): a building's housing adds to its territory, and its famine_guard saves that many
## of the Famine's deaths on its territory each upkeep (083), while it works. Uses the Silo fixture (+1 housing, guard 1).
## Engines are held as Object so the file parses before the loader knows the new fields.


## Population on (start 3, food_upkeep 1, vp_per_pop 1): Homeland has 5 slots, so housing 7.
func pop_config(tableau: Array = ["capital"]) -> Dictionary:
	return {
		"population": {"start": 3, "food_upkeep": 1, "vp_per_pop": 1},
		"starting": {"resources": {"food": 100}, "tableau": tableau, "territory": "homeland"},
		"territory_deck": {"river": 1},
	}


## A game with Homeland at home_pop holding buildings card_ids (in order), and food on hand.
func home_engine(home_pop: int, card_ids: Array, food := 0, deck := {"farm": 10}, tableau: Array = ["capital"]) -> Object:
	var e: Object = make_engine(deck, pop_config(tableau))
	e.zone("tableau").find(home_uid(e)).pop = home_pop
	build_on(e, home_uid(e), card_ids)
	e.resources.food = food
	return e


# --- AC1: loading housing and famine_guard ---

func test_building_housing_and_famine_guard_load() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "cards.json", errors, warnings, keywords())
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.silo.housing, 1, "Silo housing")
	eq(cards.silo.get("famine_guard"), 1, "Silo famine_guard")
	eq(cards.farm.get("famine_guard"), 0, "no famine_guard by default")
	eq(cards.farm.housing, 0, "no housing on a building by default")
	eq(cards.homeland.housing, 7, "territory housing still defaults to slots + 2")


## Loads TEST_CARDS plus one extra card; returns {errors, warnings}.
func card_messages(card: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": TEST_CARDS.cards + [card]}, resources(), "cards.json", errors, warnings, keywords())
	return {"errors": errors, "warnings": warnings}


func test_building_housing_and_famine_guard_validation() -> void:
	check_cases([
		["building housing 0", {"id": "hut", "name": "Hut", "type": "building", "housing": 0},
			"cards.json: card 'hut': 'housing' must be an integer >= 1", "one_error"],
		["building housing not an int", {"id": "hut", "name": "Hut", "type": "building", "housing": "x"},
			"cards.json: card 'hut': 'housing' must be an integer >= 1", "one_error"],
		["famine_guard 0", {"id": "pit", "name": "Pit", "type": "building", "famine_guard": 0},
			"cards.json: card 'pit': 'famine_guard' must be an integer >= 1", "one_error"],
		["famine_guard not an int", {"id": "pit", "name": "Pit", "type": "building", "famine_guard": "x"},
			"cards.json: card 'pit': 'famine_guard' must be an integer >= 1", "one_error"],
		["famine_guard on an action", {"id": "fast", "name": "Fast", "type": "action", "famine_guard": 1},
			"card 'fast': 'famine_guard' only applies to buildings", "warning_only"],
		["famine_guard on a territory", {"id": "bog", "name": "Bog", "type": "territory", "slots": 1, "famine_guard": 1},
			"card 'bog': 'famine_guard' only applies to buildings", "warning_only"],
	], card_messages)


# --- AC2: a building's housing adds to its territory ---

func test_silo_adds_1_housing_to_its_territory() -> void:
	var e: Object = home_engine(3, ["silo"])
	eq(e.housing(home_uid(e)), 8, "7 + 1 Silo")


func test_silo_lets_homeland_grow_to_8() -> void:
	var e: Object = home_engine(7, ["silo"], 100)
	var home := home_uid(e)
	check(e.grow(home), "grow 7 -> 8")
	eq(e.pop(home), 8, "pop")
	check(e.grow_error(home) != "", "then at housing 8")


func test_silo_housing_caps_card_growth_at_8() -> void:
	var e: Object = home_engine(7, ["silo"], 0, {"festival": 10})
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home), 8, "Festival grows Homeland to 8")
	check(e.play_card(first_in_hand(e)), "play another Festival")
	eq(e.pop(home), 8, "stops at housing 8")


func test_idle_silo_still_adds_housing() -> void:
	var e: Object = home_engine(3, ["guildhall", "guildhall", "guildhall", "silo"])
	check(e.is_idle(uid_of(e.zone("tableau"), "silo")), "Silo idle: 3 pop, 4 buildings")
	eq(e.housing(home_uid(e)), 8, "7 + 1 idle Silo")


# --- AC3: the guard saves the first starving pop on its territory ---

func test_silo_saves_the_first_starving_pop() -> void:
	var e: Object = home_engine(4, ["silo"])
	e.end_turn()  # Capital +2, 4 pop eat 4: short, a new Famine (1 counter) would kill 1 (083)
	eq(e.pop(home_uid(e)), 4, "the famine's death is saved")
	eq(e.resources.food, 0, "food")


func test_without_silo_the_famine_kills_1() -> void:
	var e: Object = home_engine(4, [])
	e.end_turn()  # Capital +2, 4 pop eat 4: short, a new Famine (1 counter) kills 1 (083)
	eq(e.pop(home_uid(e)), 3, "1 dies")
	eq(e.resources.food, 0, "food")


# --- AC4: the guard only protects its own territory ---

func test_silo_on_another_territory_does_not_save_homeland() -> void:
	var e: Object = home_engine(3, [])
	settle(e, ["river"])
	var river := uid_of(e.zone("tableau"), "river")
	e.zone("tableau").find(river).pop = 1
	build_on(e, river, ["silo"])
	check(not e.is_idle(uid_of(e.zone("tableau"), "silo")), "river Silo works")
	e.end_turn()  # Capital +2, 4 pop eat 4: short, the Famine's 1 death is on the biggest (Homeland, 083)
	eq(e.pop(home_uid(e)), 2, "Homeland 3 -> 2")
	eq(e.pop(river), 1, "river keeps 1")


# --- AC5: guards stack; an idle guard saves none ---

func test_two_silos_save_2_pop() -> void:
	var e: Object = home_engine(4, ["silo", "silo"])
	e.end_turn()  # Capital +2, 4 pop eat 4: 2 short
	eq(e.pop(home_uid(e)), 4, "the Famine's death is saved")


func test_idle_silo_saves_none() -> void:
	# Village makes no food: 2 pop eat 2, 2 short. The Silo is the third building on 2 pop, so idle.
	var e: Object = home_engine(2, ["guildhall", "guildhall", "silo"], 0, {"farm": 10}, ["village"])
	check(e.is_idle(uid_of(e.zone("tableau"), "silo")), "Silo idle")
	e.end_turn()
	eq(e.pop(home_uid(e)), 1, "the Famine's 1 death isn't saved (083)")


# --- AC6: the forecast counts only the pop that would die ---

func test_forecast_starve_counts_the_guard() -> void:
	var e: Object = home_engine(4, ["silo"])
	eq(e.upkeep_forecast(), {"food": -2, "wealth": 0, "starve": 0}, "2 made, 4 needed, short: the Famine's 1 death is saved (083)")


func test_forecast_starve_without_guard() -> void:
	var e: Object = home_engine(4, [])
	eq(e.upkeep_forecast(), {"food": -2, "wealth": 0, "starve": 1}, "2 made, 4 needed, short: a new Famine kills 1 (083)")


# --- AC7: card text ---

func test_silo_short_text() -> void:
	var e: Object = make_engine({"farm": 10})
	eq(e.card_db.silo.rules_text(e.card_db), "+1 housing\nSaves 1 pop from famine", "rules_text")


func test_silo_tooltip() -> void:
	var e: Object = make_engine({"farm": 10})
	eq(e.card_db.silo.rules_tooltip(e.card_db),
		"+1 housing on its territory\nEach upkeep, 1 pop here that would starve survives", "rules_tooltip")


func test_silo_details_explain_housing_and_famine_guard() -> void:
	var e: Object = make_engine({"farm": 10})
	var terms: Array[String] = []
	for t in e.def_details("silo").terms:
		terms.append(t.term)
		check(t.text != "", "%s has text" % t.term)
	check(terms.has("Housing"), "Housing term in %s" % [terms])
	check(terms.has("Famine Guard"), "Famine Guard term in %s" % [terms])
