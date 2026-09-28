extends "res://tests/lib/test_case.gd"
## Territory cards: loading, config (keywords, territory deck, starting territory) and game setup.

const HILLS := {"id": "hills", "name": "Hills", "type": "territory", "slots": 3, "keywords": ["mountain"]}


## Writes cards and config to temp files and runs the full DataLoader.load_all.
func load_raw(cards: Array, config: Dictionary) -> Dictionary:
	var cards_path := "user://territory_cards.json"
	var config_path := "user://territory_config.json"
	var f := FileAccess.open(cards_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"cards": cards}))
	f.close()
	f = FileAccess.open(config_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(config))
	f.close()
	return DataLoader.load_all(cards_path, config_path)


## TEST_CARDS without its territories, plus extra.
func base_cards(extra: Array) -> Array:
	var out: Array = []
	for c in TEST_CARDS.cards:
		if c.get("type") != "territory":
			out.append(c)
	return out + extra


func load_with_keywords(cards: Array) -> Dictionary:
	return load_raw(base_cards(cards), raw_config({"farm": 1}, {"keywords": ["mountain", "fresh_water"]}))


func territory_config() -> Dictionary:
	return {
		"territory_deck": {"hills": 2, "grassland": 1},
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "grassland"},
	}


func config_errors(overrides: Dictionary, deck := {"farm": 1}) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	check(errors.is_empty(), "TEST_CARDS should load: %s" % [errors])
	DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "config.json", errors, warnings)
	return errors


# --- AC1: territory cards load ---

func test_territory_card_loads_with_slots_and_keywords() -> void:
	var r := load_with_keywords([HILLS])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	var hills: CardDef = r.cards.get("hills")
	check(hills != null, "hills loaded")
	if hills == null:
		return
	eq(hills.slots, 3, "slots")
	eq(hills.keywords, ["mountain"] as Array[String], "keywords")
	check(hills.is_permanent(), "territories are permanent")


# --- AC2: bad territories ---

func test_territory_missing_slots_is_error() -> void:
	var r := load_with_keywords([{"id": "bog", "name": "Bog", "type": "territory"}])
	eq(r.errors.size(), 1, "one error: %s" % [r.errors])
	has_msg(r.errors, "card 'bog': missing 'slots'")


func test_territory_negative_slots_is_error() -> void:
	var r := load_with_keywords([{"id": "bog", "name": "Bog", "type": "territory", "slots": -1}])
	eq(r.errors.size(), 1, "one error: %s" % [r.errors])
	has_msg(r.errors, "card 'bog': 'slots' must be an integer >= 0")


func test_territory_unknown_keyword_is_error() -> void:
	var r := load_with_keywords([{"id": "volcano", "name": "Volcano", "type": "territory", "slots": 1,
		"keywords": ["mountain", "lava"]}])
	eq(r.errors.size(), 1, "one error: %s" % [r.errors])
	has_msg(r.errors, "card 'volcano': unknown keyword 'lava'")


# --- AC3: territory fields on other cards ---

func test_territory_fields_on_non_territory_are_warnings() -> void:
	var r := load_with_keywords([{"id": "mill", "name": "Mill", "type": "building", "slots": 2,
		"keywords": ["mountain"]}])
	eq(r.errors, [] as Array[String], "errors")
	has_msg(r.warnings, "card 'mill': 'slots'")
	has_msg(r.warnings, "card 'mill': 'keywords'")


# --- AC4: territory deck and starting territory in config ---

func test_territory_deck_is_normalized() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {"territory_deck": {"hills": 2.0, "grassland": 1}}),
		resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(config.territory_deck, {"hills": 2, "grassland": 1}, "territory_deck")


func test_territory_deck_unknown_card_is_error() -> void:
	has_msg(config_errors({"territory_deck": {"dragon": 1}}), "config.json: territory_deck: unknown card 'dragon'")


func test_territory_deck_non_territory_is_error() -> void:
	has_msg(config_errors({"territory_deck": {"farm": 1}}), "config.json: territory_deck: 'farm' is not a territory")


func test_territory_in_main_deck_is_error() -> void:
	has_msg(config_errors({}, {"farm": 1, "hills": 1}), "config.json: deck: 'hills' is a territory")


func test_starting_territory_must_be_a_territory() -> void:
	var start := {"resources": {}, "tableau": ["capital"], "territory": "farm"}
	has_msg(config_errors({"starting": start}), "config.json: starting.territory: 'farm' is not a territory")


func test_starting_territory_unknown_card_is_error() -> void:
	var start := {"resources": {}, "tableau": ["capital"], "territory": "atlantis"}
	has_msg(config_errors({"starting": start}), "config.json: starting.territory: unknown card 'atlantis'")


# --- AC5: new game with territories ---

func test_new_game_shuffles_territory_deck() -> void:
	var e := make_engine({"farm": 10}, territory_config())
	var ids := card_ids(e.zone("territory_deck"))
	eq(ids.size(), 3, "territory deck size")
	ids.sort()
	eq(ids, ["grassland", "hills", "hills"] as Array[String], "territory deck contents")
	eq(e.zone("frontier").size(), 0, "frontier empty")


func test_territory_deck_order_follows_seed() -> void:
	var big := {"territory_deck": {"hills": 5, "grassland": 5}}
	var a := make_engine({"farm": 10}, big, 7)
	var b := make_engine({"farm": 10}, big, 7)
	eq(card_ids(a.zone("territory_deck")), card_ids(b.zone("territory_deck")), "same seed, same order")
	var unshuffled := card_ids(a.zone("territory_deck"))
	unshuffled.sort()
	var shuffled := false
	for s in range(1, 6):
		if card_ids(make_engine({"farm": 10}, big, s).zone("territory_deck")) != unshuffled:
			shuffled = true
	check(shuffled, "some seed in 1..5 gives an order other than sorted")


func test_capital_starts_on_starting_territory() -> void:
	var e := make_engine({"farm": 10}, territory_config())
	var tableau := e.zone("tableau").cards
	eq(card_ids(e.zone("tableau")), ["grassland", "capital"] as Array[String], "tableau")
	if tableau.size() < 2:
		return
	check(e.territory_of(tableau[1]) == tableau[0], "capital's territory is the Grassland instance")
	eq(tableau[1].territory_uid, tableau[0].uid, "capital territory_uid")


func test_starting_territory_does_not_change_score() -> void:
	var e := make_engine({"farm": 10}, territory_config())
	eq(e.score(), 2, "capital 2 + grassland 0")


# --- AC6: configs without territories ---

func test_config_without_territories_loads_cleanly() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(config.get("keywords"), [] as Array[String], "keywords default")
	eq(config.get("territory_deck"), {}, "territory_deck default")
	eq(config.get("starting", {}).get("territory"), "", "starting.territory default")


func test_game_without_territories_is_unchanged() -> void:
	var e := make_engine({"farm": 10})
	eq(e.zone("territory_deck").size(), 0, "territory deck empty")
	eq(card_ids(e.zone("tableau")), ["capital"] as Array[String], "tableau")
	eq(e.territory_of(e.zone("tableau").cards[0]), null, "capital has no territory")
