extends "res://tests/lib/test_case.gd"
## Territory defence (backlog 161): `defense` on buildings and cities, config `terrain_defense`, and
## `defense` / `defense_parts`: the units stationed on a settled territory plus its working walls, its cities and its
## terrain.

## Levy: a unit of strength 2; Palisade: a building with defense 2; Town: a city with defense 1.
const TEST_DEFENCE := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2},
	{"id": "palisade", "name": "Palisade", "type": "building", "defense": 2},
	{"id": "town", "name": "Town", "type": "city", "vp": 1, "tags": ["city"], "defense": 1},
]
const KEYWORDS := ["mountain", "fresh_water", "flood_plain"]


## TEST_CARDS plus TEST_DEFENCE and extra, parsed: {cards, errors, warnings}.
func defence_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_DEFENCE])


## The config errors for TEST_CARDS + TEST_DEFENCE with the config keywords and overrides.
func defence_config_errors(overrides: Dictionary) -> Array[String]:
	var o := {"keywords": KEYWORDS}
	o.merge(overrides, true)
	return config_errors_for(defence_load().cards, o)


## A new game on TEST_CARDS + TEST_DEFENCE with population on (start 1), Hills and River in the territory deck, the
## config keywords, terrain_defense {mountain: 1} unless overrides say otherwise, and 50 food; null (after a failed
## check) when the data doesn't load.
func defence_engine(overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(defence_load(), errors, warnings)
	var o := {"population": {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}, "keywords": KEYWORDS,
		"territory_deck": {"hills": 1, "river": 1}, "terrain_defense": {"mountain": 1}}
	o.merge(overrides, true)
	var config := DataLoader.parse_config(raw_config({"levy": 10}, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var engine := GameEngine.new(cards, config)
	engine.new_game(1)
	engine.resources.food = 50
	return engine


## Settles Hills at 2 pop with a Town and a Palisade on it, then recruits a Levy there; returns Hills' uid.
func fortify_hills(e: GameEngine) -> int:
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	e.zone("tableau").find(hills).pop = 2
	build_on(e, hills, ["town", "palisade"])
	check(e.play_card(first_in_hand(e), hills), "Levy recruited on Hills")
	return hills


# --- AC1: loading ---

func test_defense_loads_on_buildings_and_cities() -> void:
	var r := defence_load()
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if r.cards.has("palisade"):
		eq(r.cards.palisade.defense, 2, "Palisade")
		eq(r.cards.town.defense, 1, "Town")


func test_bad_defense_is_a_load_error() -> void:
	check_cases([
		["0 on a building", [{"id": "x", "name": "X", "type": "building", "defense": 0}], ["card 'x'", "defense"], "one_error"],
		["0 on a city", [{"id": "x", "name": "X", "type": "city", "defense": 0}], ["card 'x'", "defense"], "one_error"],
		["not an int", [{"id": "x", "name": "X", "type": "building", "defense": "two"}], ["card 'x'", "defense"], "one_error"],
		["on an action", [{"id": "x", "name": "X", "type": "action", "defense": 2}],
			"card 'x': 'defense' only applies to buildings", "warning_only"],
	], defence_load)


func test_terrain_defense_config() -> void:
	eq(defence_config_errors({"terrain_defense": {"mountain": 1, "fresh_water": 2}}), [] as Array[String], "valid")
	check_cases([
		["unknown keyword", {"terrain_defense": {"swamp": 1}}, "terrain_defense: unknown keyword 'swamp'"],
		["below 1", {"terrain_defense": {"mountain": 0}}, "terrain_defense: 'mountain' must be an integer >= 1"],
		["not an int", {"terrain_defense": {"mountain": "one"}}, "terrain_defense: 'mountain' must be an integer >= 1"],
		["not an object", {"terrain_defense": ["mountain"]}, "'terrain_defense' must be an object"],
	], defence_config_errors)


# --- AC2: the total ---

func test_defense_adds_units_buildings_cities_and_terrain() -> void:
	var e: GameEngine = defence_engine()
	if e == null:
		return
	var hills := fortify_hills(e)
	eq(e.defense(hills), 6, "defense")
	eq(e.defense_parts(hills), {"units": 2, "buildings": 2, "cities": 1, "terrain": 1, "total": 6}, "parts")


# --- AC3: idle cards add nothing ---

func test_idle_walls_and_units_add_no_defense() -> void:
	var e: GameEngine = defence_engine()
	if e == null:
		return
	var hills := fortify_hills(e)
	e.zone("tableau").find(hills).pop = 0
	check(e.is_idle(uid_of(e.zone("tableau"), "palisade")) and e.is_idle(uid_of(e.zone("tableau"), "levy")), "both idle")
	eq(e.defense(hills), 2, "the Town and the mountain")


# --- AC4: a unit counts where it is stationed ---

func test_unit_counts_on_its_station_not_its_home() -> void:
	var e: GameEngine = defence_engine()
	if e == null:
		return
	var hills := fortify_hills(e)
	var home := home_uid(e)
	var before: int = e.defense(home)
	e.zone("tableau").find(uid_of(e.zone("tableau"), "levy")).station_uid = home
	eq(e.defense(hills), 4, "Hills without the Levy")
	eq(e.defense(home) - before, 2, "Homeland with it")
	eq(e.defense_parts(home).units, 2, "Homeland's units")


# --- AC5: terrain and edges ---

func test_terrain_sums_every_matching_keyword_rolled_ones_included() -> void:
	var e: GameEngine = defence_engine({"resource_keywords": ["gold"],
		"terrain_defense": {"fresh_water": 1, "flood_plain": 2, "mountain": 1, "gold": 3}})
	if e == null:
		return
	settle(e, ["river", "hills"])
	var river := uid_of(e.zone("tableau"), "river")
	var hills: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "hills"))
	hills.keywords.append("gold")
	eq(e.defense_parts(river).terrain, 3, "fresh water 1 + flood plain 2")
	eq(e.defense_parts(hills.uid).terrain, 4, "mountain 1 + rolled gold 3")


func test_no_terrain_defense_without_the_config() -> void:
	var e: GameEngine = defence_engine({"terrain_defense": {}})
	if e == null:
		return
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	eq(e.defense_parts(hills).terrain, 0, "terrain")
	eq(e.defense(hills), 0, "nothing on Hills")


func test_defense_is_0_for_anything_but_a_settled_territory() -> void:
	var e: GameEngine = defence_engine()
	if e == null:
		return
	to_frontier(e, ["hills"])
	for uid in [uid_of(e.zone("frontier"), "hills"), uid_of(e.zone("tableau"), "capital"), first_in_hand(e), 9999]:
		eq(e.defense(uid), 0, "defense of %d" % uid)
		eq(e.defense_parts(uid), {}, "parts of %d" % uid)


# --- AC7: the territory's tooltip ---

func test_territory_tooltip_breaks_down_its_defence() -> void:
	var e: GameEngine = defence_engine()
	if e == null:
		return
	var hills := fortify_hills(e)
	check("Defence 6: units 2, walls 2, cities 1, terrain 1" in e.territory_tooltip(hills), e.territory_tooltip(hills))


# --- AC6: text ---

func test_defense_text() -> void:
	var db: Dictionary = defence_load().cards
	for id in ["palisade", "town"]:
		check(db.has(id), "%s loaded" % id)
	if not db.has("palisade"):
		return
	check("Defence 2" in db.palisade.rules_text(db), "face: %s" % db.palisade.rules_text(db))
	check("Defence 2" in db.palisade.rules_tooltip(db), "tooltip: %s" % db.palisade.rules_tooltip(db))
	check("Defence 1" in db.town.rules_text(db), "city face: %s" % db.town.rules_text(db))
	check("Defence 1" in db.town.rules_tooltip(db), "city tooltip: %s" % db.town.rules_tooltip(db))
