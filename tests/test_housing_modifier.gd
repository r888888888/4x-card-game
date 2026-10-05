extends "res://tests/lib/test_case.gd"
## Housing as a modifier (backlog 110): `modifiers: {"housing": n}` (129's field) adds to every settled territory's
## housing while its card works. Local fixtures, so other tests load while the key is missing: Founders
## (civilization, +1), Aqueduct (free building, +1) and Flood (1-turn event, −20). Silo (TEST_CARDS) has its own
## `housing` +1 on its territory. Population on, home pop 2.

const FOUNDERS := {"id": "founders", "name": "Founders", "type": "civilization", "modifiers": {"housing": 1}}
const AQUEDUCT := {"id": "aqueduct", "name": "Aqueduct", "type": "building", "modifiers": {"housing": 1}}
const FLOOD := {"id": "flood", "name": "Flood", "type": "event", "discard": {"turns": 1}, "modifiers": {"housing": -20}}
const FIXTURES := [FOUNDERS, AQUEDUCT, FLOOD]
const POP := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}


## A new game on TEST_CARDS and the fixtures, as civilization civ ("" for none), with 50 food and Grassland in the
## frontier.
func housing_game(civ: String) -> GameEngine:
	var r := fixture_load(FIXTURES)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var starting := {"resources": {"food": 50}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config({"farm": 10}, {"starting": starting, "population": POP, "territory_deck": {"grassland": 1}})
	var config := DataLoader.parse_config(raw, resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## The printed housing of e's home territory.
func printed(e: GameEngine) -> int:
	return e.zone("tableau").find(home_uid(e)).def.housing


# --- AC1: the key ---

func test_housing_is_a_modifier_key() -> void:
	var r := fixture_load(FIXTURES)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


# --- AC2: housing everywhere ---

func test_a_housing_modifier_adds_to_every_settled_territory() -> void:
	var e: GameEngine = housing_game("founders")
	var home := home_uid(e)
	eq(e.housing(home), printed(e) + 1, "printed + 1")
	build_on(e, home, ["silo"])
	eq(e.housing(home), printed(e) + 2, "and Silo's own +1")
	to_frontier(e, ["grassland"])
	eq(e.housing(uid_of(e.zone("frontier"), "grassland")), 0, "an unsettled territory has none")
	var plain: GameEngine = housing_game("")
	eq(plain.housing(home_uid(plain)), printed(plain), "no modifier")


func test_housing_never_drops_below_1_on_a_settled_territory() -> void:
	var e: GameEngine = housing_game("")
	var flood: CardInstance = e.create_card("flood", "active_events", null)
	flood.turns_left = 1
	eq(e.housing(home_uid(e)), 1, "−20 stops at 1")


# --- AC3: growth stops at the raised cap ---

func test_growth_stops_at_the_raised_cap() -> void:
	var e: GameEngine = housing_game("founders")
	var home := home_uid(e)
	var cap: int = e.housing(home)
	e.zone("tableau").find(home).pop = cap - 1
	var festival := put_in_hand(e, "festival")
	check(e.play_card(festival), "play Festival: %s" % e.play_error(festival))
	eq(e.pop(home), cap, "Festival grows to the raised cap")
	var another := put_in_hand(e, "festival")
	check(e.play_error(another).contains("room"), "another Festival is blocked at the cap (276): %s" % e.play_error(another))
	check(not e.play_card(another), "another Festival can't be played")
	eq(e.pop(home), cap, "stays at the raised cap")


# --- AC4: an idle building's modifier stops ---

func test_an_idle_buildings_housing_modifier_stops_but_its_own_housing_doesnt() -> void:
	var e: GameEngine = housing_game("")
	var home := home_uid(e)
	build_on(e, home, ["silo", "lookout", "aqueduct"])
	check(e.is_idle(uid_of(e.zone("tableau"), "aqueduct")), "Aqueduct is the third building on 2 pop")
	eq(e.housing(home), printed(e) + 1, "only Silo's own +1")
	e.zone("tableau").find(home).pop += 1
	check(not e.is_idle(uid_of(e.zone("tableau"), "aqueduct")), "staffed")
	eq(e.housing(home), printed(e) + 2, "and Aqueduct's +1")


# --- AC5: population.start checks printed housing ---

func test_population_start_is_checked_against_printed_housing() -> void:
	var cards: Dictionary = fixture_load(FIXTURES).cards
	var home_housing: int = cards.homeland.housing
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "civilization": "founders"}
	var errors := config_errors_for(cards, {"starting": starting,
		"population": {"start": home_housing + 1, "food_upkeep": 1, "vp_per_pop": 1, "famine": FAMINE}})
	check(has_message(errors, "population.start"), "printed housing + 1 is too many, Founders or not: %s" % [errors])


# --- AC6: text ---

func test_housing_modifier_text() -> void:
	var cards: Dictionary = fixture_load(FIXTURES).cards
	if not cards.has("founders"):
		check(false, "Founders should load")
		return
	eq(cards.founders.rules_text(cards), "Every territory houses 1 more pop", "Founders")
