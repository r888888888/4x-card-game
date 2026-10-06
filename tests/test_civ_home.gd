extends "res://tests/lib/test_case.gd"
## Civilization home territories (backlog 111): a civilization's optional `home` names the territory it starts on in
## place of config `starting.territory`. Fixtures: Settlers start on River (housing 4), Highlanders on Hills (housing 5,
## rolls gold half the time), Tribe (TEST_CIVS) has no home and starts on Homeland (housing 7).

const HOME_CIVS := [
	{"id": "settlers", "name": "Settlers", "type": "civilization", "home": "river"},
	{"id": "highlanders", "name": "Highlanders", "type": "civilization", "home": "hills"},
]
const LISTED := ["tribe", "settlers", "highlanders"]
const HALF_GOLD := {"hills": [{"keywords": ["gold"], "weight": 1}, {"keywords": [], "weight": 1}]}


## TEST_CARDS + TEST_CIVS + HOME_CIVS + extra, loaded with resource keyword gold (fixture_load).
func home_load(extra := []) -> Dictionary:
	var gold: Array[String] = ["gold"]
	return fixture_load(HOME_CIVS + extra, [TEST_CIVS], [], gold)


## home_load's cards, after appending its errors to errors.
func home_db(extra: Array = [], errors: Array[String] = []) -> Dictionary:
	return cards_of(home_load(extra), errors, [])


## Config overrides: the civilizations list, population start 2 and the overrides.
func home_config(overrides := {}) -> Dictionary:
	return {
		"civilizations": LISTED, "resource_keywords": ["gold"],
		"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE},
		"territory_deck": {"river": 2, "hills": 2, "grassland": 2},
	}.merged(overrides, true)


## A game on home_db as civilization civ with seed_value.
func home_engine(civ: String, seed_value := 1, overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := home_db()
	var config := DataLoader.parse_config(raw_config({"farm": 3, "scout": 3, "temple": 3, "settler": 3}, home_config(overrides)),
		resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e: GameEngine = GameEngine.new(cards, config)
	e.new_game(seed_value, civ)
	return e


## home_load() and a config with home_config(overrides) (config_load_on).
func home_config_load(overrides: Dictionary) -> Dictionary:
	return config_load_on(home_load(), home_config(overrides))


# --- AC1: the home field ---

func test_home_loads_on_a_civilization() -> void:
	check_loads([
		["the fixture civilizations", [], {"cards.settlers.home": "river", "cards.tribe.home": ""}],
	], home_load)


func test_home_validation() -> void:
	check_cases([
		["unknown territory", [{"id": "lost", "name": "Lost", "type": "civilization", "home": "nowhere"}],
			["cards.json: card 'lost'", "home", "'nowhere'"]],
		["not a territory", [{"id": "farmers", "name": "Farmers", "type": "civilization", "home": "farm"}],
			["cards.json: card 'farmers'", "home", "'farm'"]],
		["on a building", [{"id": "hut", "name": "Hut", "type": "building", "home": "river"}],
			"card 'hut': 'home' only applies to civilizations", "warning_only"],
	], home_load)


func test_home_config_validation() -> void:
	check_cases([
		["population.start must fit each listed home (River houses 4; Hills 5, no error for Highlanders)",
			{"population": {"start": 5, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE}},
			["config.json", "'population.start' (5)", "civilization 'settlers'"], "one_error"],
	], home_config_load)


func test_home_is_on_the_card_text() -> void:
	var cards := home_db()
	check("Starts on: River" in cards.settlers.rules_text(cards), "rules text: '%s'" % cards.settlers.rules_text(cards))
	check(not "Starts on" in cards.tribe.rules_text(cards), "no home, no line")


# --- AC2: the game starts on the home ---

func test_new_game_settles_the_home() -> void:
	var e := home_engine("settlers")
	var land := capital_land(e)
	check(land != null and land.def.id == "river", "the Capital is on River")
	eq(land.pop if land != null else -1, 2, "pop population.start")
	check(uid_of(e.zone("tableau"), "homeland") == -1, "Homeland is not settled")


func test_without_a_home_the_game_starts_on_starting_territory() -> void:
	var e := home_engine("tribe")
	var land := capital_land(e)
	check(land != null and land.def.id == "homeland", "the Capital is on Homeland")


# --- AC3: the seed deals the same whatever the home ---

func test_same_seed_same_decks_with_or_without_a_home() -> void:
	for s in [3, 11, 42]:
		var a := home_engine("tribe", s)
		var b := home_engine("settlers", s)
		for z in ["deck", "hand", "territory_deck", "research_deck"]:
			eq(card_ids(a.zone(z)), card_ids(b.zone(z)), "seed %d: %s order" % [s, z])
		eq(b.zone("territory_deck").cards.filter(func(c): return c.def.id == "river").size(), 2,
			"seed %d: both River copies stay in the territory deck" % s)


# --- AC4: the home roll doesn't shift later rolls ---

func test_home_roll_does_not_shift_the_rng() -> void:
	for s in [3, 11, 42]:
		var a := home_engine("tribe", s, {"territory_resources": HALF_GOLD})
		var b := home_engine("highlanders", s, {"territory_resources": HALF_GOLD})
		var rolls_a := []
		var rolls_b := []
		for c in a.zone("territory_deck").cards:
			rolls_a.append(a.territory_keywords(c.uid))
		for c in b.zone("territory_deck").cards:
			rolls_b.append(b.territory_keywords(c.uid))
		eq(rolls_a, rolls_b, "seed %d: territory deck rolls" % s)
		eq(a.rng.randi_range(1, 1000000), b.rng.randi_range(1, 1000000), "seed %d: next rng value" % s)


func test_home_rolls_from_its_table() -> void:
	var seen := {}
	for s in range(1, 21):
		var e := home_engine("highlanders", s, {"territory_resources": HALF_GOLD})
		var land := capital_land(e)
		seen[e.territory_keywords(land.uid).has("gold")] = true
	eq(seen.size(), 2, "over 20 seeds the Hills home rolls gold sometimes and not other times")
