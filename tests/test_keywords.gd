extends "res://tests/lib/test_case.gd"
## Territory keywords: building `requires`, keyword-conditioned effects, validation and text (backlog 005).
## Fixtures: River (fresh_water, flood_plain), Hills (mountain), Homeland (no keywords, 5 slots).


## A game with the Capital on starting_territory, extra territories settled straight into the
## tableau, a hand of deck_id cards, and plenty of food.
func keyword_engine(deck_id: String, settled: Array[String], starting_territory := "homeland") -> GameEngine:
	var counts := {}
	for id in settled:
		counts[id] = counts.get(id, 0) + 1
	var e := make_engine({deck_id: 10}, {
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": starting_territory},
		"territory_deck": counts,
	})
	settle(e, settled)
	e.resources.food = 20
	return e


func load_one(card: Dictionary, extra: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [card] + extra}, resources(), "t", errors, warnings, keywords())
	return {"cards": cards, "errors": errors, "warnings": warnings}


# --- AC1 / AC2: requires ---

func test_requires_limits_targets_to_keyword_territories() -> void:
	var e := keyword_engine("well", ["river", "hills"])
	var river := uid_of(e.zone("tableau"), "river")
	var well := first_in_hand(e)
	eq(e.valid_targets(well), [river] as Array[int], "valid_targets")
	check(e.play_card(well), "play Well with no target")
	var placed := e.zone("tableau").find(well)
	check(placed != null and placed.territory_uid == river, "Well on River")


func test_requires_with_no_keyword_territory_fails() -> void:
	var e := keyword_engine("well", [], "hills")
	var well := first_in_hand(e)
	var food: int = e.resources.food
	eq(e.play_error(well), "Well needs a territory with Fresh Water.", "play_error")
	check(not e.play_card(well), "play fails")
	check(e.zone("hand").find(well) != null, "Well stays in hand")
	eq(e.resources.food, food, "food unchanged")


func test_requires_error_for_target_without_keyword() -> void:
	var e := keyword_engine("well", ["river", "hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	eq(e.play_error(first_in_hand(e), hills), "Well needs a territory with Fresh Water.", "play_error on Hills")


# --- AC3: keyword-conditioned upkeep ---

func test_keyword_upkeep_applies_on_matching_territory() -> void:
	var e := keyword_engine("paddy", ["river"])
	check(e.play_card(first_in_hand(e), uid_of(e.zone("tableau"), "river")), "Paddy on River")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, food + 2 + 2, "capital 2 + paddy 1 + flood plain 1")


func test_keyword_upkeep_skipped_elsewhere() -> void:
	var e := keyword_engine("paddy", ["hills"])
	check(e.play_card(first_in_hand(e), uid_of(e.zone("tableau"), "hills")), "Paddy on Hills")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, food + 2 + 1, "capital 2 + paddy 1")


# --- AC4: keyword-conditioned play effect ---

func test_keyword_play_effect_applies_on_matching_territory() -> void:
	var e := keyword_engine("lookout", ["river", "hills"])
	var score := e.score()
	check(e.play_card(first_in_hand(e), uid_of(e.zone("tableau"), "hills")), "Lookout on Hills")
	eq(e.score(), score + 1, "+1 VP on Mountain")


func test_keyword_play_effect_skipped_elsewhere() -> void:
	var e := keyword_engine("lookout", ["river", "hills"])
	var score := e.score()
	check(e.play_card(first_in_hand(e), uid_of(e.zone("tableau"), "river")), "Lookout on River")
	eq(e.score(), score, "no VP off Mountain")


# --- AC5: validation ---

func test_keyword_validation() -> void:
	check_cases([
		["unknown requires keyword", {"id": "x", "name": "X", "type": "building", "requires": ["lava"]},
			"t: card 'x': unknown keyword 'lava' in 'requires'"],
		["unknown effect keyword", {"id": "x", "name": "X", "type": "building", "effects": [{"op": "score", "amount": 1, "keyword": "lava"}]},
			"t: card 'x': effects[0]: unknown keyword 'lava' in 'keyword'"],
	], load_one)


func test_keyword_fields_load_without_warnings() -> void:
	var r := load_one({"id": "x", "name": "X", "type": "building", "requires": ["mountain"],
		"effects": [{"op": "score", "amount": 1, "keyword": "mountain"}]})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


# --- AC6: card text ---

func test_keyword_effect_text() -> void:
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", [] as Array[String], [] as Array[String], keywords())
	eq(cards.paddy.rules_tooltip(cards), "Each upkeep: +1 food\nEach upkeep: +1 food (on Flood Plain)", "Paddy text")


func test_requires_text() -> void:
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", [] as Array[String], [] as Array[String], keywords())
	check("Requires Fresh Water" in cards.well.rules_tooltip(cards), "Well text: %s" % cards.well.rules_tooltip(cards))


func test_requires_several_keywords_text() -> void:
	var r := load_one({"id": "x", "name": "X", "type": "building", "requires": ["fresh_water", "flood_plain"]})
	var cards: Dictionary = r.cards
	check(cards.has("x"), "loads: %s" % [r.errors])
	if cards.has("x"):
		var text: String = cards.x.rules_tooltip(cards)
		check("Requires Fresh Water or Flood Plain" in text, "text: %s" % text)
