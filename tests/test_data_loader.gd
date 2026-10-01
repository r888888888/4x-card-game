extends "res://tests/lib/test_case.gd"
## DataLoader: JSON parsing and validation of cards and config.


func test_real_data_loads() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	check(r.errors.is_empty(), "errors: %s" % [r.errors])


## Parses a card list (no keywords config); returns {errors, warnings}.
func parse(cards: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": cards}, resources(), "t", errors, warnings)
	return {"errors": errors, "warnings": warnings}


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


func test_bug_048_create_loads_into_tableau_hand_discard_and_deck() -> void:
	for zone in ["tableau", "hand", "discard", "deck"]:
		eq(parse(creator(zone)).errors, [] as Array[String], "%s: errors" % zone)


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


func test_city_slots_loads() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "hub", "name": "Hub", "type": "city", "slots": 4}]},
		resources(), "t", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.hub.slots, 4, "slots")
