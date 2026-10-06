extends "res://tests/lib/test_case.gd"
## A civilization's start building (backlog 133): a start `create` into the tableau puts a building on the home, the
## territory the starting tableau sits on. Fixtures: Farmers start on River (2 slots) with a Farm; Settlers start on
## River with nothing (as in test_civ_home.gd). The fixture Capital adds no slots.

const START_CIVS := [
	{"id": "farmers", "name": "Farmers", "type": "civilization", "home": "river", "effects": [
		{"op": "create", "card": "farm", "zone": "tableau", "trigger": "start"}]},
	{"id": "settlers", "name": "Settlers", "type": "civilization", "home": "river"},
]


## TEST_CARDS + TEST_CIVS + START_CIVS + extra, parsed.
func start_db(extra: Array = [], errors: Array[String] = []) -> Dictionary:
	return cards_of(fixture_load(START_CIVS + extra, [TEST_CIVS]), errors, [])


## A game on start_db as civ: population on (start 2, nobody eats), seed 1.
func start_engine(civ: String) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := start_db()
	var config := DataLoader.parse_config(raw_config({"scout": 10}, {
		"civilizations": ["tribe", "farmers", "settlers"],
		"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE},
	}), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e: GameEngine = GameEngine.new(cards, config)
	e.new_game(1, civ)
	return e


## Config errors for start_db + extra cards with the civilizations listed.
func listed_errors(extra: Array, civs: Array) -> Array[String]:
	var cards := start_db(extra)
	return config_errors_for(cards, {"civilizations": civs})


# --- AC1: the building is on the home ---

func test_start_create_puts_the_building_on_the_home() -> void:
	var e := start_engine("farmers")
	var land := capital_land(e)
	var farms: Array = e.zone("tableau").cards.filter(func(c): return c.def.id == "farm")
	eq(farms.size(), 1, "one Farm on the tableau")
	check(land != null and not farms.is_empty() and farms[0].territory_uid == land.uid, "the Farm is on the home")
	var without := start_engine("settlers")
	eq(e.free_slots(land.uid) if land != null else -1, without.free_slots(capital_land(without).uid) - 1,
		"the Farm takes one of the home's slots")


# --- AC2: it works from the first turn ---

func test_start_building_works_from_the_first_turn() -> void:
	var e := start_engine("farmers")
	var farm := uid_of(e.zone("tableau"), "farm")
	check(farm != -1 and not e.is_idle(farm), "the home's starting pop works the Farm")
	var without := start_engine("settlers")
	eq(e.upkeep_forecast().get("food", 0), without.upkeep_forecast().get("food", 0) + 1,
		"the forecast counts the Farm's +1 food")


# --- AC3: only a building can start in the tableau ---

func test_start_create_into_the_tableau_must_name_a_building() -> void:
	var errors: Array[String] = []
	start_db([{"id": "scouts", "name": "Scouts", "type": "civilization", "effects": [
		{"op": "create", "card": "scout", "zone": "tableau", "trigger": "start"}]}], errors)
	has_msg(errors, "card 'scouts'")
	check(errors.any(func(m): return "effects[0]" in m and "'scout'" in m),
		"an error names the effect and the created card: %s" % [errors])


# --- AC4: the home meets the building's requires ---

func test_start_building_must_fit_the_home_keywords() -> void:
	var errors := listed_errors([
		{"id": "diggers", "name": "Diggers", "type": "civilization", "home": "hills", "effects": [
			{"op": "create", "card": "well", "zone": "tableau", "trigger": "start"}]},
		{"id": "drifters", "name": "Drifters", "type": "civilization", "effects": [
			{"op": "create", "card": "well", "zone": "tableau", "trigger": "start"}]},
	], ["farmers", "diggers", "drifters"])
	check(errors.any(func(m): return "diggers" in m and "well" in m and "hills" in m),
		"an error names Diggers, the Well and Hills: %s" % [errors])
	check(errors.any(func(m): return "drifters" in m and "well" in m and "homeland" in m),
		"with no home, an error names Drifters, the Well and starting.territory Homeland: %s" % [errors])
	check(not errors.any(func(m): return "farmers" in m), "Farmers' Farm fits River: %s" % [errors])


# --- AC5: the home has room ---

func test_start_buildings_must_fit_the_home_slots() -> void:
	var errors := listed_errors([
		{"id": "crowders", "name": "Crowders", "type": "civilization", "home": "jungle", "effects": [
			{"op": "create", "card": "farm", "zone": "tableau", "trigger": "start"},
			{"op": "create", "card": "temple", "zone": "tableau", "trigger": "start"}]},
	], ["farmers", "crowders"])
	check(errors.any(func(m): return "crowders" in m and "jungle" in m),
		"an error names Crowders and Jungle (1 slot, 2 buildings): %s" % [errors])
	check(not errors.any(func(m): return "farmers" in m), "River has room for Farmers' Farm: %s" % [errors])
