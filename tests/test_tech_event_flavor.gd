extends "res://tests/lib/test_case.gd"
## Flavor for techs and events (backlog 215): a tech may carry a `flavor` line and a `quote` {text, by}, an event a
## `flavor` line, as civilizations do (107); since 253 an event may carry a quote too (test_anarchy_event.gd). The details window shows them; card faces never do.

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


## Loads TEST_CARDS plus card; returns {errors, warnings}.
func card_messages(card: Dictionary) -> Dictionary:
	var r := fixture_load([card])
	return {"errors": r.errors, "warnings": r.warnings}


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
	var m := card_messages(FIRE)
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "warnings")
	var d: Dictionary = flavor_engine().def_details("fire")
	eq(d.get("flavor"), "Fire, tamed.", "flavor in def_details")
	eq(d.get("quote"), {"text": "Knowledge is power.", "by": "Francis Bacon"}, "quote in def_details")


# --- AC2: an event's flavor ---

func test_an_event_may_have_flavor() -> void:
	var m := card_messages(COMET)
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
	], card_messages)


# --- AC5: still not on buildings ---

func test_flavor_on_a_building_is_still_ignored_with_a_warning() -> void:
	var m := card_messages({"id": "hut", "name": "Hut", "type": "building", "flavor": "Cosy."})
	eq(m.errors, [] as Array[String], "errors")
	has_msg(m.warnings, "card 'hut': 'flavor' only applies to civilizations (ignored)")


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
