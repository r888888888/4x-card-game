extends "res://tests/lib/test_case.gd"
## Government cards (backlog 065): the `government` type, config `starting.government`, playing one to replace the
## ruling government, and the ruling government's upkeep, VP and forecast. Fixtures in TEST_GOVS: Council (no effects)
## and Kingdom (cost 2 food, 1 VP, play +1 wealth, upkeep +1 food). Engines are held as Object so the file parses
## before the API.


## Loader errors for gov_db() plus extra cards.
func card_errors(extra: Array) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS + extra}, resources(), "cards.json", errors, warnings, keywords())
	return errors


## Loader errors for a config (on gov_db) with overrides.
func config_errors(overrides: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := gov_db(errors, warnings)
	check(errors.is_empty(), "cards should load: %s" % [errors])
	DataLoader.parse_config(raw_config({"farm": 1}, overrides), resources(), cards, "config.json", errors, warnings)
	return errors


func starting_with(gov: Variant) -> Dictionary:
	return {"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": gov}}


## A Council game with Kingdom in hand; returns [engine, Kingdom's uid].
func with_kingdom_in_hand() -> Array:
	var e: Object = gov_engine("council")
	return [e, put_in_hand(e, "kingdom")]


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
	], config_errors)


func test_starting_government_validation() -> void:
	check_cases([
		["unknown id", starting_with("zzz"), "config.json: starting.government: unknown card 'zzz'", "one_error"],
		["not a government", starting_with("farm"), "config.json: starting.government: 'farm' is not a government", "one_error"],
		["not a string", starting_with(3), "config.json: starting.government", "one_error"],
	], config_errors)


func test_starting_government_is_optional() -> void:
	eq(config_errors({}), [] as Array[String], "no starting.government")
	eq(config_errors(starting_with("council")), [] as Array[String], "starting.government council")


func test_government_effect_needing_a_target_is_a_load_error() -> void:
	var settle := {"id": "junta", "name": "Junta", "type": "government", "effects": [{"op": "settle", "card": "city"}]}
	has_msg(card_errors([settle]), "cards.json: card 'junta': effects[0]: a government effect can't need a target")


# --- AC2: setup ---

func test_starting_government_is_in_the_government_zone() -> void:
	var e: Object = gov_engine("council")
	eq(card_ids(e.zone("government")), ["council"] as Array[String], "government zone")
	eq(e.government(), uid_of(e.zone("government"), "council"), "government() is Council's uid")
	check(e.government() >= 0, "a real uid")


func test_without_a_starting_government_the_zone_is_empty() -> void:
	var e: Object = gov_engine("")
	eq(e.zone("government").size(), 0, "government zone empty")
	eq(e.government(), -1, "government()")


# --- AC3: playing a government ---

func test_playing_a_government_replaces_the_ruling_one() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	var kingdom: int = setup[1]
	eq(e.resources.food, 4, "2 starting + 2 Capital upkeep")
	check(e.play_card(kingdom), "play Kingdom: %s" % e.play_error(kingdom))
	eq(e.resources.food, 2, "paid 2 food")
	eq(e.resources.wealth, 1, "Kingdom's play +1 wealth")
	eq(card_ids(e.zone("government")), ["kingdom"] as Array[String], "government zone")
	eq(e.government(), kingdom, "government() is Kingdom's uid")
	eq(card_ids(e.zone("removed")), ["council"] as Array[String], "Council left the game")
	for z in ["hand", "discard", "tableau"]:
		check(not card_ids(e.zone(z)).has("kingdom"), "no Kingdom in %s" % z)


func test_playing_a_government_reports_the_government_zone() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	var outcomes: Array = []
	e.card_played.connect(func(o): outcomes.append(o))
	e.play_card(setup[1])
	eq(outcomes.size(), 1, "one card_played")
	if outcomes.size() == 1:
		eq(outcomes[0].to_zone, "government", "outcome to_zone")


# --- AC4: the ruling government's bonuses ---

func test_ruling_government_gives_its_upkeep_and_forecast() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	e.play_card(setup[1])
	eq(e.upkeep_forecast().food, 3, "Capital +2, Kingdom +1")
	e.end_turn()
	eq(e.resources.food, 5, "2 left + Capital 2 + Kingdom 1")


func test_score_counts_the_ruling_government_vp() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	eq(e.score(), 2, "Capital 2, Council 0")
	e.play_card(setup[1])
	eq(e.score(), 3, "Capital 2 + Kingdom 1")


func test_replaced_government_bonuses_stop() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	e.play_card(setup[1])
	var council := put_in_hand(e, "council")
	check(e.play_card(council), "play Council: %s" % e.play_error(council))
	eq(card_ids(e.zone("removed")), ["council", "kingdom"] as Array[String], "old Council and Kingdom removed")
	eq(e.score(), 2, "Capital 2, no Kingdom VP")
	eq(e.upkeep_forecast().food, 2, "Capital +2 only")


# --- AC5: errors ---

func test_playing_the_ruling_government_again_is_an_error() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	e.play_card(setup[1])
	e.resources.food = 10
	var again := put_in_hand(e, "kingdom")
	eq(e.play_error(again), "Kingdom is already your government.", "play_error")
	check(not e.play_card(again), "play_card refuses")
	eq(e.government(), setup[1], "the first Kingdom still rules")


func test_government_cost_is_checked_like_any_card() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	e.resources.food = 1
	eq(e.play_error(setup[1]), "Kingdom needs 2 food (you have 1).", "play_error")
	check(not e.play_card(setup[1]), "play_card refuses")
	eq(card_ids(e.zone("government")), ["council"] as Array[String], "Council still rules")


# --- AC6: fork ---

func test_fork_copies_government_and_removed() -> void:
	var setup := with_kingdom_in_hand()
	var e: Object = setup[0]
	e.play_card(setup[1])
	var f: Object = e.fork()
	eq(card_ids(f.zone("government")), ["kingdom"] as Array[String], "fork government zone")
	eq(card_ids(f.zone("removed")), ["council"] as Array[String], "fork removed zone")
	eq(f.government(), e.government(), "same uid")
	check(f.zone("government").cards[0] != e.zone("government").cards[0], "a copy, not the same card")
