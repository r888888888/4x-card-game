extends "res://tests/lib/test_case.gd"
## Flavor for civilizations (backlog 107): an optional `flavor` paragraph and `quote` {text, by} on a civilization card,
## validated by the loader, returned by def_details / card_details, and shown in the details modal.

const SAGES := {"id": "sages", "name": "Sages", "type": "civilization",
	"flavor": "They counted the stars.", "quote": {"text": "Know thyself.", "by": "Temple of Delphi"},
	"effects": [{"op": "score", "amount": 1, "trigger": "upkeep"}]}


## SAGES with key set to value (or removed when value is null).
func sages_with(key: String, value: Variant) -> Dictionary:
	var card := SAGES.duplicate(true)
	if value == null:
		card.erase(key)
	else:
		card[key] = value
	return card


## A new game as Sages (loaded next to civ_db's cards).
func sages_engine() -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_CIVS + [SAGES]}, resources(), "cards.json",
		errors, warnings, keywords())
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "civilization": "sages"}
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"starting": starting}), resources(), cards,
		"config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e: GameEngine = GameEngine.new(cards, config)
	e.new_game(1)
	return e


# --- AC5: loader ---

func test_civilization_flavor_and_quote_load_and_are_optional() -> void:
	check_loads([
		["flavor and quote", SAGES, {}],
		["no quote", sages_with("quote", null), {}],
		["no flavor", sages_with("flavor", null), {}],
	], card_load.bind([TEST_CIVS]))


func test_flavor_and_quote_validation() -> void:
	var quote_error := "cards.json: card 'sages': 'quote' must be {\"text\": …, \"by\": …} with non-empty strings"
	check_cases([
		["flavor not a string", sages_with("flavor", 3),
			"cards.json: card 'sages': 'flavor' must be a non-empty string", "one_error"],
		["flavor empty", sages_with("flavor", ""),
			"cards.json: card 'sages': 'flavor' must be a non-empty string", "one_error"],
		["quote not an object", sages_with("quote", "Know thyself."), quote_error, "one_error"],
		["quote without by", sages_with("quote", {"text": "Know thyself."}), quote_error, "one_error"],
		["quote with an empty text", sages_with("quote", {"text": "", "by": "Delphi"}), quote_error, "one_error"],
		["flavor on a territory", {"id": "dell", "name": "Dell", "type": "territory", "slots": 2, "flavor": "Green."},
			"card 'dell': 'flavor' only applies to civilizations", "warning_only"],
		["quote on an action", {"id": "run", "name": "Run", "type": "action", "quote": {"text": "Go.", "by": "Me"}},
			"card 'run': 'quote' only applies to civilizations", "warning_only"],
	], card_load.bind([TEST_CIVS]))


# --- AC6: details ---

func test_civilization_details_carry_flavor_and_quote() -> void:
	var e := sages_engine()
	var d: Dictionary = e.def_details("sages")
	eq(d.get("flavor"), "They counted the stars.", "flavor in def_details")
	eq(d.get("quote"), {"text": "Know thyself.", "by": "Temple of Delphi"}, "quote in def_details")
	var live: Dictionary = e.card_details(e.civilization())
	eq(live.get("flavor"), "They counted the stars.", "flavor in card_details")


func test_cards_without_flavor_have_empty_flavor_and_quote() -> void:
	var e := sages_engine()
	var d: Dictionary = e.def_details("tribe")
	eq(d.get("flavor"), "", "no flavor")
	eq(d.get("quote"), {}, "no quote")
	eq(e.def_details("farm").get("flavor"), "", "a farm has no flavor")


# --- 205: a government may have flavor too ---

const ELDERS := {"id": "elders", "name": "Elders", "type": "government", "actions": 2,
	"flavor": "The old decided.", "quote": {"text": "Listen.", "by": "A grandmother"}}


func test_a_government_may_have_flavor_and_a_quote() -> void:
	var m := card_load(ELDERS, [TEST_CIVS])
	eq(m.errors, [] as Array[String], "errors")
	eq(m.warnings, [] as Array[String], "no 'only applies to civilizations' warning")
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_CIVS + [ELDERS]}, resources(), "cards.json",
		errors, warnings, keywords())
	var def: CardDef = cards["elders"]
	eq(def.flavor, "The old decided.", "its flavor")
	eq([def.quote_text, def.quote_by], ["Listen.", "A grandmother"], "its quote")
