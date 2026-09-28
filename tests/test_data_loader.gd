extends "res://tests/lib/test_case.gd"
## DataLoader: JSON parsing and validation of cards and config.


func test_real_data_loads() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	check(r.errors.is_empty(), "errors: %s" % [r.errors])
	check(r.warnings.is_empty(), "warnings: %s" % [r.warnings])


func test_unknown_op_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "effects": [{"op": "explode"}]}]},
		resources(), "t", errors, warnings)
	check(has_message(errors, "card 'x': effects[0]: unknown op 'explode'"), str(errors))


func test_bad_fields_all_reported() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "type": "monster", "vp": "lots", "cost": {"gold": 1}}]},
		resources(), "t", errors, warnings)
	check(has_message(errors, "missing 'name'"), str(errors))
	check(has_message(errors, "'type' must be one of"), str(errors))
	check(has_message(errors, "'vp' must be an integer"), str(errors))
	check(has_message(errors, "unknown resource 'gold'"), str(errors))


func test_effect_field_errors() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "gain", "resource": "food", "amount": 1.5, "trigger": "sometimes"}]}]},
		resources(), "t", errors, warnings)
	check(has_message(errors, "'amount' must be an integer"), str(errors))
	check(has_message(errors, "'trigger' must be one of"), str(errors))


func test_unknown_card_reference() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "effects": [{"op": "create", "card": "nowhere"}]}]},
		resources(), "t", errors, warnings)
	check(has_message(errors, "unknown card 'nowhere'"), str(errors))


func test_duplicate_id() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var card := {"id": "x", "name": "X", "type": "action"}
	DataLoader.parse_cards({"cards": [card, card]}, resources(), "t", errors, warnings)
	check(has_message(errors, "duplicate id"), str(errors))


func test_unknown_field_is_warning_only() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "flavour": "Hmm."}]},
		resources(), "t", errors, warnings)
	check(errors.is_empty(), str(errors))
	check(has_message(warnings, "unknown field 'flavour'"), str(warnings))


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
