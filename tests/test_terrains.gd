extends "res://tests/lib/test_case.gd"
## Terrain keywords (backlog 130): config `terrains` names the keywords that are terrains; with it set, every
## territory prints exactly one, and territory_resources tables may be keyed by terrain.
## Fixtures: terrains plain and mountain; features fresh_water and flood_plain; resource keywords gold and tin.

const KEYWORDS := ["plain", "mountain", "fresh_water", "flood_plain"]
const TERRAINS := ["plain", "mountain"]
const RESOURCE_KEYWORDS := ["gold", "tin"]
## Homeland and Meadow are plain, Hills and Peak mountain; River and Peak have features.
const TERRAIN_CARDS := [
	{"id": "capital", "name": "Capital", "type": "city", "tags": ["city"]},
	{"id": "farm", "name": "Farm", "type": "building", "cost": {"food": 1}},
	{"id": "scout", "name": "Scout", "type": "action", "effects": [{"op": "draw", "amount": 1}]},
	{"id": "homeland", "name": "Homeland", "type": "territory", "slots": 3, "keywords": ["plain"]},
	{"id": "meadow", "name": "Meadow", "type": "territory", "slots": 2, "keywords": ["plain"]},
	{"id": "hills", "name": "Hills", "type": "territory", "slots": 2, "keywords": ["mountain"]},
	{"id": "peak", "name": "Peak", "type": "territory", "slots": 1, "keywords": ["mountain", "fresh_water"]},
	{"id": "river", "name": "River", "type": "territory", "slots": 2, "keywords": ["plain", "fresh_water", "flood_plain"]},
	{"id": "mill", "name": "Mill", "type": "building", "requires": ["mountain"]},
	{"id": "weir", "name": "Weir", "type": "building", "effects": [
		{"op": "score", "amount": 1, "keyword": "fresh_water"}]},
]


func kw(list: Array) -> Array[String]:
	var out: Array[String] = []
	out.assign(list)
	return out


## TERRAIN_CARDS plus extra, parsed with KEYWORDS and RESOURCE_KEYWORDS.
func terrain_cards(extra: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TERRAIN_CARDS + extra}, resources(), "cards.json", errors, warnings,
		kw(KEYWORDS), kw(RESOURCE_KEYWORDS))
	check(errors.is_empty(), "terrain cards should parse: %s" % [errors])
	return cards


## Config overrides with the fixture keywords, terrains and resource keywords, plus more.
func terrain_config(more := {}) -> Dictionary:
	return {
		"keywords": KEYWORDS, "terrains": TERRAINS, "resource_keywords": RESOURCE_KEYWORDS,
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"},
	}.merged(more, true)


## Config errors for TERRAIN_CARDS + extra_cards with terrain_config(overrides).
func terrain_errors(overrides: Dictionary, extra_cards: Array = []) -> Array[String]:
	return config_errors_for(terrain_cards(extra_cards), terrain_config(overrides))


## A game on TERRAIN_CARDS with territory_resources tables and the territory deck.
func terrain_engine(tables: Dictionary, territory_deck: Dictionary, starting := "homeland", seed_value := 1) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config({"scout": 10})
	raw.merge(terrain_config({
		"territory_resources": tables,
		"territory_deck": territory_deck,
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": starting},
	}), true)
	var config := DataLoader.parse_config(raw, resources(), terrain_cards(), "test", errors, warnings)
	check(errors.is_empty(), "terrain config should load: %s" % [errors])
	var engine := GameEngine.new(terrain_cards(), config)
	engine.new_game(seed_value)
	return engine


## Every territory copy in the game (tableau and territory deck) with this card id.
func copies(e: GameEngine, id: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for zone in ["tableau", "territory_deck"]:
		for c in e.zone(zone).cards:
			if c.def.id == id:
				out.append(c)
	return out


func ids(zone: Zone) -> Array[String]:
	return card_ids(zone)


# --- AC1: the terrains list ---

func test_terrains_list_loads_into_the_config() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config({"farm": 1})
	raw.merge(terrain_config(), true)
	var config := DataLoader.parse_config(raw, resources(), terrain_cards(), "config.json", errors, warnings)
	eq(errors, [] as Array[String], "no errors")
	eq(config.get("terrains"), kw(TERRAINS), "normalized terrains")


func test_terrains_default_to_empty() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), terrain_cards(), "config.json", errors, warnings)
	eq(config.get("terrains"), [] as Array[String], "no terrains")


func test_terrains_validation() -> void:
	check_cases([
		["terrain not a keyword", {"terrains": ["swamp"]}, ["config.json", "terrains", "'swamp'"]],
		["terrains not an array", {"terrains": "mountain"}, ["config.json", "terrains"]],
	], terrain_errors)


# --- AC2: exactly one terrain per territory ---

func test_each_territory_needs_exactly_one_terrain() -> void:
	var none := {"id": "spring", "name": "Spring", "type": "territory", "slots": 1, "keywords": ["fresh_water"]}
	var bare := {"id": "void", "name": "Void", "type": "territory", "slots": 1}
	var two := {"id": "ridge", "name": "Ridge", "type": "territory", "slots": 1, "keywords": ["mountain", "plain"]}
	check_cases([
		["a feature only", [none], ["card 'spring'", "keywords", "needs exactly one terrain"]],
		["no keywords", [bare], ["card 'void'", "keywords", "needs exactly one terrain"]],
		["two terrains", [two], ["card 'ridge'", "keywords", "'mountain'", "'plain'"]],
	], func(extra): return terrain_errors({}, extra))


func test_one_terrain_with_features_loads() -> void:
	eq(terrain_errors({}), [] as Array[String], "Peak and River (a terrain plus features) load")


func test_without_terrains_a_territory_needs_none() -> void:
	var bare := {"id": "void", "name": "Void", "type": "territory", "slots": 1}
	eq(terrain_errors({"terrains": []}, [bare]), [] as Array[String], "no terrains configured: no terrain needed")


# --- AC3: roll tables keyed by terrain ---

func test_terrain_table_rolls_on_every_territory_of_that_terrain() -> void:
	var e := terrain_engine({"mountain": [{"keywords": ["gold"], "weight": 1}]},
		{"hills": 2, "peak": 1, "meadow": 2, "river": 1})
	for id in ["hills", "peak"]:
		for c in copies(e, id):
			check(e.territory_keywords(c.uid).has("gold"), "%s copy %d has gold" % [id, c.uid])
	for id in ["homeland", "meadow", "river"]:
		for c in copies(e, id):
			check(not e.territory_keywords(c.uid).has("gold"), "%s copy %d has no gold" % [id, c.uid])


func test_starting_territory_rolls_from_its_terrain_table() -> void:
	var e := terrain_engine({"mountain": [{"keywords": ["gold"], "weight": 1}]}, {"meadow": 1}, "hills")
	var start := copies(e, "hills")
	eq(start.size(), 1, "the starting Hills")
	check(e.territory_keywords(start[0].uid).has("gold"), "starting Hills has gold")


func test_terrain_table_key_validation() -> void:
	var gold := [{"keywords": ["gold"], "weight": 1}]
	var clash := {"id": "plain", "name": "Plain", "type": "territory", "slots": 1, "keywords": ["plain"]}
	check_cases([
		["neither a territory nor a terrain", {"territory_resources": {"nowhere": gold}},
			"config.json: territory_resources: unknown card 'nowhere'"],
		["a feature is not a terrain", {"territory_resources": {"fresh_water": gold}},
			"config.json: territory_resources: unknown card 'fresh_water'"],
	], terrain_errors)
	has_msg(terrain_errors({"territory_resources": {"plain": gold}}, [clash]), "territory_resources: 'plain'")


# --- AC4: a territory's own table wins ---

func test_own_table_overrides_the_terrain_table() -> void:
	var e := terrain_engine({
		"hills": [{"keywords": ["tin"], "weight": 1}],
		"mountain": [{"keywords": ["gold"], "weight": 1}],
	}, {"hills": 3, "peak": 1})
	for c in copies(e, "hills"):
		var k := e.territory_keywords(c.uid)
		check(k.has("tin") and not k.has("gold"), "Hills copy %d rolls only its own table: %s" % [c.uid, k])
	for c in copies(e, "peak"):
		check(e.territory_keywords(c.uid).has("gold"), "Peak uses the mountain table")


func test_territories_without_a_table_use_no_rng() -> void:
	var with_table := terrain_engine({"mountain": [{"keywords": ["gold"], "weight": 1}, {"keywords": [], "weight": 1}]},
		{"meadow": 3, "river": 2}, "homeland", 7)
	var without := terrain_engine({}, {"meadow": 3, "river": 2}, "homeland", 7)
	eq(ids(with_table.zone("hand")), ids(without.zone("hand")), "same hand: no plain territory rolled")
	eq(with_table.rng.randi_range(1, 1000000), without.rng.randi_range(1, 1000000), "same rng state")


# --- AC5: keyword details say terrain or feature ---

func test_keyword_details_name_terrains_and_features() -> void:
	var e := terrain_engine({}, {"meadow": 1})
	var mountain := term(e.def_details("mill"), "Mountain")
	check(mountain.begins_with("A terrain."), "Mountain is a terrain: '%s'" % mountain)
	check("Mill" in mountain, "still names Mill, which needs it: '%s'" % mountain)
	var water := term(e.def_details("weir"), "Fresh Water")
	check(water.begins_with("A territory feature."), "Fresh Water is a feature: '%s'" % water)
	check("Weir" in water, "still names Weir, which gets a bonus on it: '%s'" % water)


func test_keyword_details_without_terrains_say_territory_keyword() -> void:
	var e := make_engine({"farm": 10})
	var water := term(e.def_details("well"), "Fresh Water")
	check(water.begins_with("A territory keyword."), "no terrains configured: '%s'" % water)


## The text of term in details, or "".
func term(details: Dictionary, name: String) -> String:
	for t in details.get("terms", []):
		if t.term == name:
			return t.text
	return ""
