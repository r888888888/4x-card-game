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


func test_explore_defaults_to_reveal_2() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "explore"}]}]}, resources(), "t", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	if cards.has("x"):
		eq(cards.x.rules_tooltip(cards), "Explore: reveal 2 territories, keep 1", "card text")


func test_explore_reveal_0_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "explore", "reveal": 0}]}]}, resources(), "t", errors, warnings)
	has_msg(errors, "card 'x': effects[0]: 'reveal' must be an integer >= 1")


const CITY := {"id": "city", "name": "City", "type": "city"}
const FARM := {"id": "farm", "name": "Farm", "type": "building"}


func test_settle_text() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [CITY, {"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "settle", "card": "city"}]}]}, resources(), "t", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	if cards.has("x"):
		eq(cards.x.rules_tooltip(cards), "Settle a discovered territory with a City", "card text")


func test_settle_non_city_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [FARM, {"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "settle", "card": "farm"}]}]}, resources(), "t", errors, warnings)
	has_msg(errors, "card 'x': 'settle' effect: 'card' must be a city card (got 'farm')")


func test_settle_unknown_card_is_error() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "settle", "card": "nowhere"}]}]}, resources(), "t", errors, warnings)
	has_msg(errors, "card 'x': 'settle' effect refers to unknown card 'nowhere'")


func test_json_syntax_error_reports_line() -> void:
	var path := "user://broken.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\n  \"cards\": [\n    {\"id\" \"x\"}\n  ]\n}")
	f.close()
	var errors: Array[String] = []
	DataLoader.read_json(path, errors)
	check(has_message(errors, "broken.json: JSON syntax error on line"), str(errors))


# --- grow op (backlog 013) ---

func grow_card_errors(effect: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "effects": [effect]}]},
		resources(), "cards.json", errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


func test_grow_op_loads() -> void:
	var r := grow_card_errors({"op": "grow", "amount": 2, "where": "each"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_grow_where_defaults_to_here() -> void:
	var r := grow_card_errors({"op": "grow", "amount": 1})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.cards.x.rules_text(r.cards), "+1 pop here", "text")


func test_grow_bad_where_is_error() -> void:
	has_msg(grow_card_errors({"op": "grow", "amount": 1, "where": "everywhere"}).errors,
		"cards.json: card 'x': effects[0]: 'where' must be one of")


func test_grow_amount_below_1_is_error() -> void:
	has_msg(grow_card_errors({"op": "grow", "amount": 0}).errors,
		"cards.json: card 'x': effects[0]: 'amount' must be an integer >= 1")


func test_grow_missing_amount_is_error() -> void:
	has_msg(grow_card_errors({"op": "grow"}).errors, "cards.json: card 'x': effects[0]: missing 'amount'")


func test_grow_text() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	eq(cards.granary.rules_tooltip(cards), "Each upkeep: +1 pop here", "Granary")
	eq(cards.festival.rules_tooltip(cards), "+1 pop in each territory", "Festival")
	eq(grow_card_errors({"op": "grow", "amount": 2, "where": "each"}).cards.x.rules_tooltip({}), "+2 pop in each territory", "amount 2")


func test_city_slots_loads() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "hub", "name": "Hub", "type": "city", "slots": 4}]},
		resources(), "t", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.hub.slots, 4, "slots")


func test_city_slots_must_be_a_non_negative_integer() -> void:
	for bad in [-1, 1.5, "four"]:
		var errors: Array[String] = []
		var warnings: Array[String] = []
		DataLoader.parse_cards({"cards": [{"id": "hub", "name": "Hub", "type": "city", "slots": bad}]},
			resources(), "t", errors, warnings)
		check(has_message(errors, "card 'hub'") and has_message(errors, "slots"), "slots %s: %s" % [bad, errors])


func test_slots_on_a_building_still_warns() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "building", "slots": 2}]},
		resources(), "t", errors, warnings)
	check(has_message(warnings, "'slots' only applies to territories (ignored)"), str(warnings))
