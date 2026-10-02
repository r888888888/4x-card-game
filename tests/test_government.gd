extends "res://tests/lib/test_case.gd"
## Government cards (backlog 065): the `government` type, config `starting.government`, and the ruling government's
## upkeep, VP and forecast. A government is chosen from the government deck (154), never played from hand (155 AC9). Fixtures in TEST_GOVS: Council (no effects)
## and Kingdom (cost 2 food, 1 VP, play +1 wealth, upkeep +1 food).


## Loader errors for gov_db() plus extra cards.
func card_errors(extra: Array) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS + extra}, resources(), "cards.json", errors, warnings, keywords())
	return errors


func starting_with(gov: Variant) -> Dictionary:
	return {"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": gov}}


# --- AC1: the government type and starting.government ---

func test_government_cards_load() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := gov_db(errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(cards.kingdom.type, "government", "Kingdom type")
	eq(cards.kingdom.vp, 1, "Kingdom VP")


func test_government_outside_its_place_is_a_load_error() -> void:
	check_cases([
		["in deck", {"deck": {"kingdom": 1}}, "config.json: deck: 'kingdom' is a government"],
		["in supply", {"supply": {"kingdom": {"price": 1, "count": 1}}}, "config.json: supply: 'kingdom' is a government"],
		["in territory_deck", {"territory_deck": {"kingdom": 1}}, "config.json: territory_deck: 'kingdom' is not a territory"],
		["in research_deck", {"research_deck": {"kingdom": 1}}, "config.json: research_deck: 'kingdom' is not a tech"],
	], func(overrides): return config_errors(overrides, [TEST_GOVS]))


func test_starting_government_validation() -> void:
	check_cases([
		["unknown id", starting_with("zzz"), "config.json: starting.government: unknown card 'zzz'", "one_error"],
		["not a government", starting_with("farm"), "config.json: starting.government: 'farm' is not a government", "one_error"],
		["not a string", starting_with(3), "config.json: starting.government", "one_error"],
	], func(overrides): return config_errors(overrides, [TEST_GOVS]))


func test_starting_government_is_optional() -> void:
	eq(config_errors({}, [TEST_GOVS]), [] as Array[String], "no starting.government")
	eq(config_errors(starting_with("council"), [TEST_GOVS]), [] as Array[String], "starting.government council")


func test_government_effect_needing_a_target_is_a_load_error() -> void:
	var settle := {"id": "junta", "name": "Junta", "type": "government", "effects": [{"op": "settle", "card": "city"}]}
	has_msg(card_errors([settle]), "cards.json: card 'junta': effects[0]: a government effect can't need a target")


# --- AC2: setup ---

func test_starting_government_is_in_the_government_zone() -> void:
	var e: GameEngine = gov_engine("council")
	eq(card_ids(e.zone("government")), ["council"] as Array[String], "government zone")
	eq(e.government(), uid_of(e.zone("government"), "council"), "government() is Council's uid")
	check(e.government() >= 0, "a real uid")


func test_without_a_starting_government_the_zone_is_empty() -> void:
	var e: GameEngine = gov_engine("")
	eq(e.zone("government").size(), 0, "government zone empty")
	eq(e.government(), -1, "government()")


# --- 155 AC9: a government is chosen, not played ---

func test_a_government_in_hand_cant_be_played() -> void:
	var e: GameEngine = gov_engine("council")
	var kingdom := put_in_hand(e, "kingdom")
	e.resources.food = 10
	eq(e.play_error(kingdom), "A government is chosen, not played.", "play_error")
	check(not e.play_card(kingdom), "play_card refuses")
	eq(card_ids(e.zone("government")), ["council"] as Array[String], "Council still rules")


# --- AC4: the ruling government's bonuses ---

func test_ruling_government_gives_its_upkeep_and_forecast() -> void:
	var e: GameEngine = gov_engine("kingdom")
	eq(e.upkeep_forecast().food, 3, "Capital +2, Kingdom +1")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, food + 3, "Capital 2 + Kingdom 1")


func test_score_counts_the_ruling_government_vp() -> void:
	eq(gov_engine("council").score(), 2, "Capital 2, Council 0")
	eq(gov_engine("kingdom").score(), 3, "Capital 2 + Kingdom 1")


# --- AC6: fork ---

func test_fork_copies_the_government() -> void:
	var e: GameEngine = gov_engine("kingdom")
	var f: GameEngine = e.fork()
	eq(card_ids(f.zone("government")), ["kingdom"] as Array[String], "fork government zone")
	eq(f.government(), e.government(), "same uid")
	check(f.zone("government").cards[0] != e.zone("government").cards[0], "a copy, not the same card")
