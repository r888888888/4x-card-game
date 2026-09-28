extends RefCounted
## Base class for test files. Every tests/**/test_*.gd file extends this:
##   extends "res://tests/lib/test_case.gd"
## The runner creates a fresh instance for each test_* method, so tests never
## share state. Each test must make at least one assertion.

## Small card set used by rules tests. Add cards here when a test needs one;
## never make rules tests depend on data/cards.json (balance changes would break them).
const TEST_CARDS := {"cards": [
	{"id": "capital", "name": "Capital", "type": "city", "vp": 2, "tags": ["city"],
	 "effects": [{"op": "gain", "resource": "food", "amount": 2, "trigger": "upkeep"}]},
	{"id": "city", "name": "City", "type": "city", "vp": 2, "tags": ["city"],
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "farm", "name": "Farm", "type": "building", "cost": {"food": 2}, "tags": ["farm"],
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "scout", "name": "Scout", "type": "action",
	 "effects": [{"op": "draw", "amount": 2}]},
	{"id": "settler", "name": "Settler", "type": "action", "cost": {"food": 3},
	 "effects": [{"op": "create", "card": "city"}]},
	{"id": "caravan", "name": "Caravan", "type": "action",
	 "effects": [{"op": "gain_per_tag", "resource": "food", "amount": 2, "tag": "city"}]},
	{"id": "temple", "name": "Temple", "type": "building", "cost": {"food": 1}, "vp": 1,
	 "effects": [{"op": "score", "amount": 1, "trigger": "upkeep"}]},
	{"id": "shrine", "name": "Shrine", "type": "action",
	 "effects": [{"op": "score", "amount": 1}]},
]}

var test_name := ""  # "file::method", set by the runner
var failures: Array[String] = []  # shared with the runner
var assertions := 0


# --- Assertions ---

func check(condition: bool, message := "expected true") -> void:
	assertions += 1
	if not condition:
		failures.append("%s: %s" % [test_name, message])


func eq(actual: Variant, expected: Variant, what := "") -> void:
	assertions += 1
	if actual != expected:
		failures.append("%s: %s expected %s, got %s" % [test_name, what, expected, actual])


## Asserts that some message contains fragment (for loader errors/warnings).
func has_msg(messages: Array[String], fragment: String) -> void:
	check(has_message(messages, fragment), "no message containing '%s' in %s" % [fragment, messages])


# --- Helpers ---

func has_message(messages: Array[String], fragment: String) -> bool:
	for m in messages:
		if fragment in m:
			return true
	return false


func resources() -> Array[String]:
	var r: Array[String] = ["food"]
	return r


func raw_config(deck: Dictionary, overrides := {}) -> Dictionary:
	var c := {
		"resources": ["food"], "turn_limit": 20, "hand_size": 5, "deck_model": "fixed",
		"starting": {"resources": {"food": 2}, "tableau": ["capital"]},
		"deck": deck,
	}
	c.merge(overrides, true)
	return c


## A new game using TEST_CARDS. deck is {card_id: count}; overrides replace config keys.
func make_engine(deck: Dictionary, overrides := {}, seed_value := 1) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings)
	var config := DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var engine := GameEngine.new(cards, config)
	engine.new_game(seed_value)
	return engine


func card_ids(zone: Zone) -> Array[String]:
	var ids: Array[String] = []
	for c in zone.cards:
		ids.append(c.def.id)
	return ids


func first_in_hand(engine: GameEngine) -> int:
	return engine.zone("hand").cards[0].uid
