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
	{"id": "citadel", "name": "Citadel", "type": "city", "vp": 2, "tags": ["city"], "slots": 4},
	{"id": "village", "name": "Village", "type": "city", "vp": 1, "tags": ["city"]},
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
	{"id": "homeland", "name": "Homeland", "type": "territory", "slots": 5},
	{"id": "grassland", "name": "Grassland", "type": "territory", "slots": 2},
	{"id": "hills", "name": "Hills", "type": "territory", "slots": 3, "keywords": ["mountain"]},
	{"id": "jungle", "name": "Jungle", "type": "territory", "slots": 1},
	{"id": "river", "name": "River", "type": "territory", "slots": 2, "keywords": ["fresh_water", "flood_plain"]},
	{"id": "well", "name": "Well", "type": "building", "cost": {"food": 1}, "requires": ["fresh_water"]},
	{"id": "paddy", "name": "Paddy", "type": "building", "cost": {"food": 2}, "effects": [
		{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"},
		{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "flood_plain"}]},
	{"id": "lookout", "name": "Lookout", "type": "building",
	 "effects": [{"op": "score", "amount": 1, "keyword": "mountain"}]},
	{"id": "granary", "name": "Granary", "type": "building", "cost": {"food": 1},
	 "effects": [{"op": "grow", "amount": 1, "where": "here", "trigger": "upkeep"}]},
	{"id": "festival", "name": "Festival", "type": "action",
	 "effects": [{"op": "grow", "amount": 1, "where": "each"}]},
	{"id": "rally", "name": "Rally", "type": "action", "effects": [{"op": "grow", "amount": 1}]},
	{"id": "explorer", "name": "Explorer", "type": "action", "effects": [{"op": "explore"}]},
	{"id": "pioneer", "name": "Pioneer", "type": "action", "cost": {"food": 3},
	 "effects": [{"op": "settle", "card": "city"}]},
	{"id": "guildhall", "name": "Guildhall", "type": "building", "cost": {"food": 2, "wealth": 2}},
	{"id": "stall", "name": "Stall", "type": "building",
	 "effects": [{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}]},
	{"id": "bazaar", "name": "Bazaar", "type": "action",
	 "effects": [{"op": "gain_per_tag", "resource": "wealth", "amount": 2, "tag": "city"}]},
	{"id": "study", "name": "Research", "type": "action", "effects": [{"op": "research"}]},
	{"id": "trader", "name": "Trader", "type": "action", "cost": {"food": 1}, "effects": [
		{"op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2}]},
]}

## Fixture events (backlog 039), loaded with TEST_CARDS by event_db. Not in TEST_CARDS itself, so make_engine games
## have no event deck.
const TEST_EVENTS := [
	{"id": "windfall", "name": "Windfall", "type": "event", "discard": {"turns": 1},
	 "effects": [{"op": "gain", "resource": "food", "amount": 2}]},
	{"id": "trade_winds", "name": "Trade Winds", "type": "event", "discard": {"turns": 2},
	 "effects": [{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}]},
	{"id": "omen", "name": "Omen", "type": "event"},
	{"id": "harvest", "name": "Harvest", "type": "event", "discard": {"turns": 2},
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
]

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


## Table-driven loader validation (046). Each row is [label, input, fragment, kind]: load_input.call(input) returns the
## loader errors (Array[String]) or {errors, warnings}; fragment (a String, or an Array of Strings that must all
## appear) must be in the messages of kind: "errors" (the default), "one_error" (the only error), "warnings", or
## "warning_only" (in the warnings, and no errors at all). A failing row is reported with its label.
func check_cases(cases: Array, load_input: Callable) -> void:
	for row in cases:
		var label: String = row[0]
		var kind: String = row[3] if row.size() > 3 else "errors"
		var result: Variant = load_input.call(row[1])
		var errors: Array[String] = []
		var warnings: Array[String] = []
		if result is Dictionary:
			errors.assign(result.errors)
			warnings.assign(result.warnings)
		else:
			errors.assign(result)
		var messages := errors if kind in ["errors", "one_error"] else warnings
		var fragments: Array = row[2] if row[2] is Array else [row[2]]
		for fragment in fragments:
			check(has_message(messages, fragment), "%s: no %s containing '%s' in %s" % [label, kind, fragment, messages])
		if kind == "one_error":
			eq(errors.size(), 1, "%s: one error in %s" % [label, errors])
		if kind == "warning_only":
			eq(errors, [] as Array[String], "%s: errors" % label)


# --- Helpers ---

func has_message(messages: Array[String], fragment: String) -> bool:
	for m in messages:
		if fragment in m:
			return true
	return false


func resources() -> Array[String]:
	var r: Array[String] = ["food", "wealth"]
	return r


## Keyword ids for tests; TEST_CARDS territories only use these.
func keywords() -> Array[String]:
	var k: Array[String] = ["mountain", "fresh_water", "flood_plain"]
	return k


func raw_config(deck: Dictionary, overrides := {}) -> Dictionary:
	var c := {
		"resources": ["food", "wealth"], "turn_limit": 20, "hand_size": 5, "deck_model": "fixed",
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"},
		"deck": deck,
	}
	c.merge(overrides, true)
	return c


## A new game using TEST_CARDS. deck is {card_id: count}; overrides replace config keys.
func make_engine(deck: Dictionary, overrides := {}, seed_value := 1) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
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


## The uid of the starting territory (homeland) on the tableau, or -1.
func home_uid(engine: GameEngine) -> int:
	for c in engine.zone("tableau").cards:
		if c.def.id == "homeland":
			return c.uid
	return -1


func first_in_hand(engine: GameEngine) -> int:
	return engine.zone("hand").cards[0].uid


## The uid of the first card with this id in zone, or -1.
func uid_of(zone: Zone, id: String) -> int:
	for c in zone.cards:
		if c.def.id == id:
			return c.uid
	return -1


## A sorted copy of a (for comparing uid or id lists whose order doesn't matter).
func sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


## Puts the cards with these ids on top of zone z, top first, keeping the rest below them.
func arrange(z: Zone, ids_top_first: Array) -> void:
	var top: Array[CardInstance] = []
	for id in ids_top_first:
		for c in z.cards:
			if c.def.id == id and not top.has(c):
				top.append(c)
				break
	var rest: Array[CardInstance] = []
	for c in z.cards:
		if not top.has(c):
			rest.append(c)
	top.reverse()  # the top is the last element
	z.cards.assign(rest + top)
	var got := card_ids(z)
	got.reverse()
	eq(got.slice(0, ids_top_first.size()), ids_top_first, "zone arranged")


## Moves one territory_deck copy of each id (in order) straight to the tableau, as if settled
## without a city.
func settle(engine: Object, ids: Array) -> void:
	_move_territories(engine, ids, "tableau")


## Moves one territory_deck copy of each id (in order) to the frontier.
func to_frontier(engine: Object, ids: Array) -> void:
	_move_territories(engine, ids, "frontier")


func _move_territories(engine: Object, ids: Array, to_zone: String) -> void:
	var deck: Zone = engine.zone("territory_deck")
	for id in ids:
		var uid := uid_of(deck, id)
		check(uid != -1, "territory_deck has no %s" % id)
		if uid != -1:
			var card := deck.find(uid)
			deck.remove(card)
			engine.zone(to_zone).add(card)


## Puts a new copy of card id in the hand and returns its uid.
func put_in_hand(engine: Object, id: String) -> int:
	var card: CardInstance = engine.create_card(id, "hand", null)
	return card.uid


## Puts a new Research card (study) in the hand and plays it, which reveals techs. Returns
## play_card's result.
func play_research(engine: Object) -> bool:
	return engine.play_card(put_in_hand(engine, "study"))


## TEST_CARDS plus TEST_EVENTS, parsed.
func event_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_EVENTS}, resources(), "cards.json", errors, warnings, keywords())


# --- UI helpers (backlog 045) ---

## Adds a fresh main scene to the running tree. Typed Node so calls to its test hooks parse before they exist.
func open_main() -> Node:
	var main: Node = load("res://ui/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	return main


func close_main(main: Node) -> void:
	main.get_parent().remove_child(main)
	main.free()


## Plays seed 1 to the end with the bot, calling after_turn(main) each time the turn number changes.
func play_seed_1(main: Node, after_turn: Callable) -> void:
	main.start_game(1)
	var e := Game.engine
	var state := {"turn": e.turn}
	var on_changed := func():
		if e.turn != state.turn or e.is_over:
			state.turn = e.turn
			after_turn.call(main)
	e.changed.connect(on_changed)
	ScriptedBot.play(e)
	e.changed.disconnect(on_changed)
