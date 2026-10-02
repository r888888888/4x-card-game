extends "res://tests/lib/test_case.gd"
## Hand size as a modifier (backlog 109): `modifiers: {"hand_size": n}` (129's field) raises or lowers the hand you
## draw up to each turn. Config hand_size 5, hand_limit 7. Local fixtures, so other tests load while the key is
## missing: Sages (civilization, +1), Scrolls (tech, +1), Archive (free building, +1), Drought (1-turn event, −1) and
## Oracles (civilization, +3: too many for hand_limit 7).

const SAGES := {"id": "sages", "name": "Sages", "type": "civilization", "modifiers": {"hand_size": 1}}
const SCROLLS := {"id": "scrolls", "name": "Scrolls", "type": "tech", "cost": {"insight": 1}, "modifiers": {"hand_size": 1}}
const ARCHIVE := {"id": "archive", "name": "Archive", "type": "building", "modifiers": {"hand_size": 1}}
const DROUGHT := {"id": "drought", "name": "Drought", "type": "event", "discard": {"turns": 1}, "modifiers": {"hand_size": -1}}
const ORACLES := {"id": "oracles", "name": "Oracles", "type": "civilization", "modifiers": {"hand_size": 3}}
const FIXTURES := [SAGES, SCROLLS, ARCHIVE, DROUGHT]
const DECK := {"farm": 4, "scout": 4, "shrine": 4, "temple": 4}


## A new game (seed 1, DECK) on TEST_CARDS and the fixtures, as civilization civ ("" for none).
func hand_size_game(civ: String) -> GameEngine:
	var r := fixture_load(FIXTURES)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config(DECK, {"starting": starting}), resources(), r.cards, "config.json",
		errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


# --- AC1: loading ---

func test_hand_size_is_a_modifier_key() -> void:
	var r := fixture_load(FIXTURES)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_a_hand_size_past_the_hand_limit_is_a_config_error() -> void:
	var r := fixture_load(FIXTURES + [ORACLES])
	eq(r.errors, [] as Array[String], "the card itself loads")
	var errors := config_errors_for(r.cards, {})
	check(has_message(errors, "card 'oracles'") and has_message(errors, "modifiers.hand_size"),
		"names the card and the field: %s" % [errors])
	eq(config_errors_for(fixture_load(FIXTURES).cards, {}), [] as Array[String], "+1 fits")


# --- AC2: the query ---

func test_hand_size_adds_the_modifier_within_1_and_the_hand_limit() -> void:
	eq(hand_size_game("").hand_size(), 5, "no modifier")
	var e: GameEngine = hand_size_game("sages")
	eq(e.hand_size(), 6, "Sages +1")
	e.create_card("scrolls", "researched", null)
	eq(e.hand_size(), 7, "and Scrolls +1")
	build_on(e, home_uid(e), ["archive"])
	eq(e.hand_size(), 7, "never above hand_limit 7")
	var d: GameEngine = hand_size_game("")
	var drought: CardInstance = d.create_card("drought", "active_events", null)
	drought.turns_left = 1
	eq(d.hand_size(), 4, "Drought −1")


# --- AC3: drawing ---

func test_the_opening_hand_and_each_refill_draw_up_to_hand_size() -> void:
	var e: GameEngine = hand_size_game("sages")
	eq(e.zone("hand").size(), 6, "opening hand")
	for i in 2:
		e.discard_card(first_in_hand(e))
	e.end_turn()
	eq(e.zone("hand").size(), 6, "refilled to 6")


# --- AC4: the deal ---

## The hand in the order drawn, then the deck from its top (the deck's last card).
func draw_order(e: GameEngine) -> Array[String]:
	var deck := card_ids(e.zone("deck"))
	deck.reverse()
	return card_ids(e.zone("hand")) + deck


func test_the_same_seed_deals_the_same_order_with_or_without_the_bonus() -> void:
	var plain: GameEngine = hand_size_game("")
	var sages: GameEngine = hand_size_game("sages")
	eq(draw_order(sages), draw_order(plain), "the cards drawn, then the deck from the top")
	eq(sages.zone("hand").size(), plain.zone("hand").size() + 1, "only the number drawn differs")


# --- AC5: text ---

func test_hand_size_modifier_text() -> void:
	var cards: Dictionary = fixture_load(FIXTURES).cards
	if not (cards.has("sages") and cards.has("drought")):
		check(false, "Sages and Drought should load")
		return
	eq(cards.sages.rules_text(cards), "Draw up to 1 more card each turn", "Sages")
	eq(cards.drought.rules_text(cards).split("\n")[0], "Draw up to 1 fewer card each turn", "Drought")
