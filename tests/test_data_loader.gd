extends "res://tests/lib/test_case.gd"
## DataLoader: JSON parsing and validation of cards and config.


func test_real_data_loads() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	check(r.errors.is_empty(), "errors: %s" % [r.errors])


## Parses a card list (no keywords config); returns {cards, errors, warnings}.
func parse(cards: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var parsed := DataLoader.parse_cards({"cards": cards}, resources(), "t", errors, warnings)
	return {"cards": parsed, "errors": errors, "warnings": warnings}


func test_card_validation() -> void:
	var hub := func(slots): return [{"id": "hub", "name": "Hub", "type": "city", "slots": slots}]
	check_cases([
		["unknown op", [{"id": "x", "name": "X", "type": "action", "effects": [{"op": "explode"}]}],
			"card 'x': effects[0]: unknown op 'explode'"],
		["bad fields all reported", [{"id": "x", "type": "monster", "vp": "lots", "cost": {"gold": 1}}],
			["missing 'name'", "'type' must be one of", "'vp' must be an integer", "unknown resource 'gold'"]],
		["bad effect fields", [{"id": "x", "name": "X", "type": "action",
			"effects": [{"op": "gain", "resource": "food", "amount": 1.5, "trigger": "sometimes"}]}],
			["'amount' must be an integer", "'trigger' must be one of"]],
		["unknown card reference", [{"id": "x", "name": "X", "type": "action", "effects": [{"op": "create", "card": "nowhere"}]}],
			"unknown card 'nowhere'"],
		["duplicate id", [{"id": "x", "name": "X", "type": "action"}, {"id": "x", "name": "X", "type": "action"}], "duplicate id"],
		["unknown field", [{"id": "x", "name": "X", "type": "action", "flavour": "Hmm."}], "unknown field 'flavour'", "warning_only"],
		["city slots -1", hub.call(-1), ["card 'hub'", "slots"]],
		["city slots 1.5", hub.call(1.5), ["card 'hub'", "slots"]],
		["city slots \"four\"", hub.call("four"), ["card 'hub'", "slots"]],
		["slots on a building", [{"id": "x", "name": "X", "type": "building", "slots": 2}],
			"'slots' only applies to territories (ignored)", "warnings"],
	], parse)


## A card 'x' whose only effect creates a Farm in zone.
func creator(zone: String) -> Array:
	return [{"id": "farm", "name": "Farm", "type": "building"},
		{"id": "x", "name": "X", "type": "action", "effects": [{"op": "create", "card": "farm", "zone": zone}]}]


func test_bug_048_create_refuses_zones_where_a_new_card_makes_no_sense() -> void:
	var cases := []
	for zone in ["reveal", "frontier", "territory_deck", "research_deck", "researched", "future_techs"]:
		cases.append([zone, creator(zone),
			"card 'x': effects[0]: 'zone' must be one of: tableau, hand, discard, deck (got '%s')" % zone, "one_error"])
	check_cases(cases, parse)


func test_config_unknown_deck_card() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	DataLoader.parse_config(raw_config({"dragon": 1}), resources(), cards, "config.json", errors, warnings)
	check(has_message(errors, "config.json: deck: unknown card 'dragon'"), str(errors))


func test_json_syntax_error_reports_line() -> void:
	var path := "user://broken.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\n  \"cards\": [\n    {\"id\" \"x\"}\n  ]\n}")
	f.close()
	var errors: Array[String] = []
	DataLoader.read_json(path, errors)
	check(has_message(errors, "broken.json: JSON syntax error on line"), str(errors))


func test_cards_load() -> void:
	check_loads([
		["city slots", [{"id": "hub", "name": "Hub", "type": "city", "slots": 4}], {"cards.hub.slots": 4}],
		["048: create into the tableau", creator("tableau"), {}],
		["048: create into the hand", creator("hand"), {}],
		["048: create into the discard", creator("discard"), {}],
		["048: create into the deck", creator("deck"), {}],
	], parse)


# --- 338: per-type fields from one table ---

const LOADER_PATH := "res://engine/data_loader.gd"
## The extra fields a card of each type needs to load.
const BASE_FIELDS := {
	CardDef.ACTION: {}, CardDef.BUILDING: {}, CardDef.CITY: {}, CardDef.TERRITORY: {"slots": 1},
	CardDef.UNIT: {"strength": 1}, CardDef.TECH: {"cost": {"insight": 1}}, CardDef.EVENT: {},
	CardDef.CIVILIZATION: {}, CardDef.GOVERNMENT: {},
}
## Each integer per-type field on each type it applies to: [field, type, minimum, default], the default "missing" when
## the field is required and "slots + 2" for a territory's housing (BASE_FIELDS' territory has 1 slot: 3).
const INT_FIELD_CASES := [
	["slots", CardDef.TERRITORY, 0, "missing"], ["slots", CardDef.CITY, 0, 0],
	["housing", CardDef.TERRITORY, 1, 3], ["housing", CardDef.BUILDING, 1, 0],
	["famine_guard", CardDef.BUILDING, 1, 0],
	["strength", CardDef.UNIT, 1, "missing"],
	["defense", CardDef.BUILDING, 1, 0], ["defense", CardDef.CITY, 1, 0],
	["training", CardDef.BUILDING, 1, 0],
	["era", CardDef.TECH, 1, 1], ["era", CardDef.EVENT, 1, 1],
	["actions", CardDef.GOVERNMENT, 1, 0], ["unrest_limit", CardDef.GOVERNMENT, 1, 0],
	["administers", CardDef.GOVERNMENT, 1, 0],
]


## A card 'x' of type with BASE_FIELDS' fields and fields merged in, a field set to null left out.
func card_x(type: String, fields := {}) -> Dictionary:
	var card := {"id": "x", "name": "X", "type": type}.merged(BASE_FIELDS[type]).merged(fields, true)
	for key in fields:
		if fields[key] == null:
			card.erase(key)
	return card


## The number of lines of static func name in the script at path, from its signature to the line before the next
## top-level declaration or doc comment.
func function_lines(path: String, name: String) -> int:
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var start := -1
	for i in lines.size():
		if start == -1 and lines[i].begins_with("static func %s(" % name):
			start = i
		elif start != -1 and (lines[i].begins_with("static func ") or lines[i].begins_with("func ") or lines[i].begins_with("##")):
			var end := i
			while lines[end - 1].strip_edges() == "":
				end -= 1
			return end - start
	return -1 if start == -1 else lines.size() - start


func test_requires_on_a_card_that_is_not_a_building_is_ignored_with_a_warning() -> void:
	for type in [CardDef.ACTION, CardDef.CITY, CardDef.TERRITORY, CardDef.TECH, CardDef.EVENT, CardDef.CIVILIZATION,
			CardDef.GOVERNMENT]:
		var r := card_load(card_x(type, {"requires": ["mountain"]}))
		eq(r.errors, [] as Array[String], "%s: errors" % type)
		check(has_message(r.warnings, "card 'x': 'requires' only applies to buildings (ignored)"),
			"%s: the warning, in %s" % [type, r.warnings])
		eq(r.cards.x.requires if r.cards.has("x") else null, [] as Array[String], "%s: requires" % type)


func test_requires_loads_on_a_building_and_is_an_error_on_a_unit() -> void:
	check_loads([
		["a building", card_x(CardDef.BUILDING, {"requires": ["mountain"]}), {"cards.x.requires": ["mountain"] as Array[String]}],
	], card_load)
	var unit := card_load(card_x(CardDef.UNIT, {"requires": ["mountain"]}))
	has_msg(unit.errors, "card 'x': a unit can't have 'requires' (it can move, so it has no fixed land)")
	check(not has_message(unit.warnings, "only applies to buildings"), "no warning besides: %s" % [unit.warnings])


func test_every_int_field_on_every_type_has_its_minimum_and_default() -> void:
	var pairs: Array = []
	for field in DataLoader.INT_FIELDS:
		for type in DataLoader.TYPE_FIELDS[field]:
			pairs.append([field, type])
	eq(pairs, INT_FIELD_CASES.map(func(c: Array) -> Array: return [c[0], c[1]]), "the int fields and their types")
	for case in INT_FIELD_CASES:
		var field: String = case[0]
		var type: String = case[1]
		var label := "%s on a %s" % [field, type]
		var low: int = case[2] - 1
		has_msg(card_load(card_x(type, {field: low})).errors,
			"card 'x': '%s' must be an integer >= %d, not %d" % [field, case[2], low])
		var r := card_load(card_x(type, {field: null}))
		if case[3] is String and case[3] == "missing":
			has_msg(r.errors, "card 'x': missing '%s'" % field)
		else:
			eq(r.cards.x.get(field) if r.cards.has("x") else r.errors, case[3], "%s: the default" % label)


func test_parse_card_is_short_and_the_loader_under_550_lines() -> void:
	var lines := function_lines(LOADER_PATH, "_parse_card")
	check(lines > 0 and lines <= 60, "_parse_card is %d lines (at most 60)" % lines)
	var total := FileAccess.get_file_as_string(LOADER_PATH).split("\n").size()
	check(total <= 550, "engine/data_loader.gd is %d lines (at most 550)" % total)


# --- 339: the population rules in their own loader ---

const CONFIG_LOADER_PATH := "res://engine/config_loader.gd"
const POPULATION_CONFIG_PATH := "res://engine/population_config.gd"
## The functions that move out of ConfigLoader, by their name there.
const POPULATION_FUNCS: Array[String] = ["_parse_population", "_parse_tiers", "_parse_famine", "_parse_relief",
	"_parse_unrest", "_check_homes_house_start", "_check_tolerates", "_check_building_tiers", "_check_start_buildings"]


func test_population_rules_parse_in_population_config_not_config_loader() -> void:
	check(FileAccess.file_exists(POPULATION_CONFIG_PATH), "%s exists" % POPULATION_CONFIG_PATH)
	var source := FileAccess.get_file_as_string(POPULATION_CONFIG_PATH)
	check(source.begins_with("class_name PopulationConfig\n"), "population_config.gd declares class PopulationConfig")
	for name in POPULATION_FUNCS:
		eq(function_lines(CONFIG_LOADER_PATH, name), -1, "config_loader.gd declares no %s" % name)
	check(FileAccess.get_file_as_string(CONFIG_LOADER_PATH).contains("PopulationConfig."), "ConfigLoader calls PopulationConfig")


func test_config_loader_under_450_lines_and_population_config_under_350() -> void:
	var total := FileAccess.get_file_as_string(CONFIG_LOADER_PATH).split("\n").size()
	check(total <= 450, "engine/config_loader.gd is %d lines (at most 450)" % total)
	var lines := FileAccess.get_file_as_string(POPULATION_CONFIG_PATH).split("\n").size()
	check(lines > 1 and lines <= 350, "engine/population_config.gd is %d lines (more than 1, at most 350)" % lines)
