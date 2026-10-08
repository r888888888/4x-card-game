extends "res://tests/lib/test_case.gd"
## Flavor for techs, events, actions and buildings (backlog 215, 351, 352, 396): a tech or building may carry a `flavor`
## line and a `quote` {text, by} (a building's since 396, for the wonders), an event or action a `flavor` line, as
## civilizations do (107); since 253 an event may carry a quote too (test_anarchy_event.gd). The details window shows
## them; card faces never do.

const FIRE := {"id": "fire", "name": "Fire", "type": "tech", "cost": {"insight": 1},
	"flavor": "Fire, tamed.", "quote": {"text": "Knowledge is power.", "by": "Francis Bacon"}}
const COMET := {"id": "comet", "name": "Comet", "type": "event", "discard": {"turns": 2},
	"flavor": "The sky burned.", "effects": [{"op": "gain", "resource": "food", "amount": 1}]}


## card with key set to value (or removed when value is null).
func with_field(card: Dictionary, key: String, value: Variant) -> Dictionary:
	var c := card.duplicate(true)
	if value == null:
		c.erase(key)
	else:
		c[key] = value
	return c


## A new game on TEST_CARDS plus FIRE and COMET, whose event deck is one Comet.
func flavor_engine() -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(fixture_load([FIRE, COMET]), errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"event_deck": {"comet": 1}}), resources(), cards,
		"config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	return e


# --- AC1: a tech's flavor and quote ---

func test_a_tech_may_have_flavor_and_a_quote() -> void:
	var m := card_load(FIRE)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	var d: Dictionary = flavor_engine().def_details("fire")
	eq(d.get("flavor"), "Fire, tamed.", "flavor in def_details")
	eq(d.get("quote"), {"text": "Knowledge is power.", "by": "Francis Bacon"}, "quote in def_details")


# --- AC2: an event's flavor ---

func test_an_event_may_have_flavor() -> void:
	var m := card_load(COMET)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	var e := flavor_engine()
	eq(e.def_details("comet").get("flavor"), "The sky burned.", "flavor in def_details")
	e.end_turn()
	var active := e.zone("active_events")
	eq(active.size(), 1, "the Comet was drawn")
	if active.size() == 1:
		eq(e.card_details(active.cards[0].uid).get("flavor"), "The sky burned.", "flavor in the drawn event's card_details")


# --- AC4: the same validation as a civilization's ---

func test_tech_and_event_flavor_validation() -> void:
	var quote_error := "cards.json: card 'fire': 'quote' must be {\"text\": …, \"by\": …} with non-empty strings"
	check_cases([
		["tech flavor not a string", with_field(FIRE, "flavor", 3),
			"cards.json: card 'fire': 'flavor' must be a non-empty string", "one_error"],
		["tech flavor empty", with_field(FIRE, "flavor", ""),
			"cards.json: card 'fire': 'flavor' must be a non-empty string", "one_error"],
		["tech quote without by", with_field(FIRE, "quote", {"text": "Knowledge is power."}), quote_error, "one_error"],
		["event flavor not a string", with_field(COMET, "flavor", 3),
			"cards.json: card 'comet': 'flavor' must be a non-empty string", "one_error"],
		["event flavor empty", with_field(COMET, "flavor", ""),
			"cards.json: card 'comet': 'flavor' must be a non-empty string", "one_error"],
	], card_load)


# --- AC5: still not on territories (352: buildings may have flavor) ---

func test_flavor_on_a_territory_is_still_ignored_with_a_warning() -> void:
	var m := card_load({"id": "dell", "name": "Dell", "type": "territory", "slots": 2, "flavor": "Green."})
	eq(m.errors, [] as Array[String], "errors")
	has_msg(m.warnings, "card 'dell': 'flavor' only applies to civilizations (ignored)")


# --- AC7: no flavor on a card face ---

## The face text of card id from cards, built by CardView.setup with kind ("" for a hand-style face).
func face_of(cards: Dictionary, id: String, kind := "") -> String:
	var view := CardView.new()
	view.setup(CardInstance.new(900, cards[id]), cards, false, "", kind)
	var text := view.face_text()
	view.free()
	return text


func test_a_tech_face_shows_no_flavor_or_quote() -> void:
	var flavored := fixture_db([FIRE])
	var plain := fixture_db([with_field(with_field(FIRE, "flavor", null), "quote", null)])
	check((flavored["fire"] as CardDef).flavor != "", "the tech has flavor")
	var face := face_of(flavored, "fire")
	eq(face, face_of(plain, "fire"), "the face is the same as without flavor")
	check(not face.contains("Fire, tamed.") and not face.contains("Bacon"), "no flavor or quote: %s" % face)


func test_an_event_face_shows_no_flavor() -> void:
	var flavored := fixture_db([COMET])
	var plain := fixture_db([with_field(COMET, "flavor", null)])
	check((flavored["comet"] as CardDef).flavor != "", "the event has flavor")
	for kind in ["", CardView.BOARD_EVENT]:
		var face := face_of(flavored, "comet", kind)
		eq(face, face_of(plain, "comet", kind), "the %s face is the same as without flavor" % (kind if kind != "" else "card"))
		check(not face.contains("The sky burned."), "no flavor: %s" % face)


# --- 351: an action's flavor ---

const TREK := {"id": "trek", "name": "Trek", "type": "action", "flavor": "They went over the hill.",
	"effects": [{"op": "gain", "resource": "food", "amount": 1}]}


func test_an_action_may_have_flavor() -> void:
	var m := card_load(TREK)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	var e := make_engine({"farm": 10}, {}, 1, [TREK])
	eq(e.def_details("trek").get("flavor"), "They went over the hill.", "flavor in def_details")
	var uid := put_in_hand(e, "trek")
	eq(e.card_details(uid).get("flavor"), "They went over the hill.", "flavor in the card in hand's card_details")


func test_action_flavor_validation() -> void:
	check_cases([
		["action flavor not a string", with_field(TREK, "flavor", 3),
			"cards.json: card 'trek': 'flavor' must be a non-empty string", "one_error"],
		["action flavor empty", with_field(TREK, "flavor", ""),
			"cards.json: card 'trek': 'flavor' must be a non-empty string", "one_error"],
	], card_load)


func test_a_quote_on_an_action_is_ignored_with_a_warning() -> void:
	var quoted := with_field(TREK, "quote", {"text": "Onward.", "by": "A guide"})
	var m := card_load(quoted)
	eq(m.errors, [] as Array[String], "errors")
	has_msg(m.warnings, "card 'trek': 'quote' only applies to civilizations (ignored)")
	var e := make_engine({"farm": 10}, {}, 1, [quoted])
	eq(e.def_details("trek").get("quote"), {}, "no quote in def_details")


func test_an_action_face_shows_no_flavor() -> void:
	var flavored := fixture_db([TREK])
	var plain := fixture_db([with_field(TREK, "flavor", null)])
	check((flavored["trek"] as CardDef).flavor != "", "the action has flavor")
	var face := face_of(flavored, "trek")
	eq(face, face_of(plain, "trek"), "the face is the same as without flavor")
	check(not face.contains("over the hill"), "no flavor: %s" % face)


# --- 352: a building's flavor ---

const KILN := {"id": "kiln", "name": "Kiln", "type": "building", "cost": {"food": 1}, "flavor": "Mud brick, baked hard."}


func test_a_building_may_have_flavor() -> void:
	var m := card_load(KILN)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	var e := make_engine({"farm": 10}, {}, 1, [KILN])
	eq(e.def_details("kiln").get("flavor"), "Mud brick, baked hard.", "flavor in def_details")
	build_on(e, home_uid(e), ["kiln"])
	var uid := uid_of(e.zone("tableau"), "kiln")
	eq(e.card_details(uid).get("flavor"), "Mud brick, baked hard.", "flavor in the built building's card_details")


func test_building_flavor_validation() -> void:
	check_cases([
		["building flavor not a string", with_field(KILN, "flavor", 3),
			"cards.json: card 'kiln': 'flavor' must be a non-empty string", "one_error"],
		["building flavor empty", with_field(KILN, "flavor", ""),
			"cards.json: card 'kiln': 'flavor' must be a non-empty string", "one_error"],
	], card_load)


func test_a_building_face_shows_no_flavor() -> void:
	var flavored := fixture_db([KILN])
	var plain := fixture_db([with_field(KILN, "flavor", null)])
	check((flavored["kiln"] as CardDef).flavor != "", "the building has flavor")
	for in_hand in [true, false]:
		var faces: Array[String] = []
		for cards: Dictionary in [flavored, plain]:
			var view := CardView.new()
			view.setup(CardInstance.new(900, cards["kiln"]), cards, in_hand)
			faces.append(view.face_text())
			view.free()
		eq(faces[0], faces[1], "the %s face is the same as without flavor" % ("hand" if in_hand else "supply"))
		check(not faces[0].contains("baked hard"), "no flavor: %s" % faces[0])


# --- 396: a building's quote (for the wonders) ---

const SPHINX := {"id": "sphinx", "name": "Sphinx", "type": "building", "cost": {"food": 1}, "flavor": "A lion with a face.",
	"quote": {"text": "Look on my works.", "by": "Shelley"}}


func test_a_building_may_have_a_quote() -> void:
	var m := card_load(SPHINX)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	if m.cards.has("sphinx"):
		var def: CardDef = m.cards.sphinx
		eq([def.quote_text, def.quote_by], ["Look on my works.", "Shelley"], "the quote is read")
	var e := make_engine({"farm": 10}, {}, 1, [SPHINX])
	var quote := {"text": "Look on my works.", "by": "Shelley"}
	eq(e.def_details("sphinx").get("quote"), quote, "quote in def_details")
	build_on(e, home_uid(e), ["sphinx"])
	var uid := uid_of(e.zone("tableau"), "sphinx")
	eq(e.card_details(uid).get("quote"), quote, "quote in the built building's card_details")


func test_building_quote_validation() -> void:
	var quote_error := "cards.json: card 'sphinx': 'quote' must be {\"text\": …, \"by\": …} with non-empty strings"
	check_cases([
		["building quote not an object", with_field(SPHINX, "quote", "Look on my works."), quote_error, "one_error"],
		["building quote without by", with_field(SPHINX, "quote", {"text": "Look on my works."}), quote_error, "one_error"],
		["building quote with an empty text", with_field(SPHINX, "quote", {"text": "", "by": "Shelley"}), quote_error,
			"one_error"],
	], card_load)


func test_a_building_without_a_quote_has_none() -> void:
	var e := make_engine({"farm": 10}, {}, 1, [KILN])
	eq(e.def_details("kiln").get("quote"), {}, "no quote in def_details")


func test_a_quote_on_a_territory_city_or_unit_is_still_ignored_with_a_warning() -> void:
	for card: Dictionary in [
		{"id": "dell", "name": "Dell", "type": "territory", "slots": 2},
		{"id": "hamlet", "name": "Hamlet", "type": "city", "vp": 1, "tags": ["city"]},
		{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2},
	]:
		var quoted := with_field(card, "quote", {"text": "Onward.", "by": "A guide"})
		var m := card_load(quoted)
		eq(m.errors, [] as Array[String], "%s: errors" % card.type)
		has_msg(m.warnings, "card '%s': 'quote' only applies to civilizations (ignored)" % card.id)
		if m.cards.has(card.id):
			eq((m.cards[card.id] as CardDef).quote_text, "", "%s: no quote read" % card.type)


func test_a_building_face_shows_no_quote() -> void:
	var quoted := fixture_db([SPHINX])
	var plain := fixture_db([with_field(SPHINX, "quote", null)])
	check((quoted["sphinx"] as CardDef).quote_text != "", "the building has a quote")
	for in_hand in [true, false]:
		var faces: Array[String] = []
		for cards: Dictionary in [quoted, plain]:
			var view := CardView.new()
			view.setup(CardInstance.new(900, cards["sphinx"]), cards, in_hand)
			faces.append(view.face_text())
			view.free()
		eq(faces[0], faces[1], "the %s face is the same as without a quote" % ("hand" if in_hand else "supply"))
		check(not faces[0].contains("my works") and not faces[0].contains("Shelley"), "no quote: %s" % faces[0])
