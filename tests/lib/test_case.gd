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
	{"id": "silo", "name": "Silo", "type": "building", "cost": {"food": 1}, "housing": 1, "famine_guard": 1},
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
	{"id": "famine", "name": "Famine", "type": "event",
	 "effects": [{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]},
]}

## How many turns play_seed_1 plays of the real game (066).
const SEED_1_TURNS := 20
## The real engine's turn_limit while play_seed_1 has shortened it (0 otherwise); close_main puts it back.
var _real_turn_limit := 0
## The famine block raw_config adds to a population block that has none (backlog 083: required with population on).
const FAMINE := {"card": "famine", "max_counters": 3}

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

## Fixture civilizations (backlog 062), loaded with TEST_CARDS by civ_db. Not in TEST_CARDS itself, like TEST_EVENTS.
const TEST_CIVS := [
	{"id": "tribe", "name": "Tribe", "type": "civilization", "effects": [
		{"op": "gain", "resource": "food", "amount": 3, "trigger": "start"},
		{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}]},
	{"id": "nomads", "name": "Nomads", "type": "civilization", "vp": 1,
	 "effects": [{"op": "score", "amount": 1, "trigger": "upkeep"}]},
]

## Fixture governments (backlog 065; Band and Court set actions, 127), loaded with TEST_CARDS by gov_db. Not in TEST_CARDS itself, like TEST_CIVS.
const TEST_GOVS := [
	{"id": "council", "name": "Council", "type": "government"},
	{"id": "kingdom", "name": "Kingdom", "type": "government", "cost": {"food": 2}, "vp": 1, "effects": [
		{"op": "gain", "resource": "wealth", "amount": 1},
		{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "band", "name": "Band", "type": "government", "actions": 2},  # 127
	{"id": "court", "name": "Court", "type": "government", "actions": 3},
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


## A population block without "famine" gets FAMINE (083), so fixtures that turn population on stay short.
func raw_config(deck: Dictionary, overrides := {}) -> Dictionary:
	var c := {
		"resources": ["food", "wealth"], "turn_limit": 20, "hand_size": 5, "deck_model": "fixed",
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"},
		"deck": deck,
	}
	c.merge(overrides, true)
	if c.get("population") is Dictionary and not c.population.has("famine"):
		c.population = c.population.duplicate()
		c.population["famine"] = FAMINE
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


## The uid of the starting territory on the tableau (config starting.territory, homeland in TEST_CARDS, or the
## civilization's home, 111), or -1. It is the first territory on the tableau: settled ones come after it.
func home_uid(engine: GameEngine) -> int:
	for c in engine.zone("tableau").cards:
		if c.def.type == CardDef.TERRITORY:
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


## Puts new copies of the buildings card_ids straight on territory territory_uid, in order (the last ones go idle
## first), without paying or checking slots.
func build_on(engine: Object, territory_uid: int, card_ids: Array) -> void:
	for id in card_ids:
		var card: CardInstance = engine.create_card(id, "tableau", null)
		card.territory_uid = territory_uid


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


## TEST_CARDS plus TEST_CIVS, parsed.
func civ_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_CIVS}, resources(), "cards.json", errors, warnings, keywords())


## A new game on civ_db() with starting.civilization civ ("" for none); overrides replace config keys.
func civ_engine(civ: String, deck := {"farm": 10}, overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := civ_db(errors, warnings)
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var o := {"starting": starting}
	o.merge(overrides, true)
	var config := DataLoader.parse_config(raw_config(deck, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var engine := GameEngine.new(cards, config)
	engine.new_game(1)
	return engine


## TEST_CARDS plus TEST_GOVS, parsed.
func gov_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS}, resources(), "cards.json", errors, warnings, keywords())


## A new game on gov_db() with starting.government gov ("" for none); overrides replace config keys.
func gov_engine(gov: String, deck := {"farm": 10}, overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := gov_db(errors, warnings)
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"starting": starting}
	o.merge(overrides, true)
	var config := DataLoader.parse_config(raw_config(deck, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var engine := GameEngine.new(cards, config)
	engine.new_game(1)
	return engine


## TEST_CARDS plus TEST_EVENTS, parsed.
func event_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_EVENTS}, resources(), "cards.json", errors, warnings, keywords())


## TEST_CARDS plus extra cards, parsed: {cards, errors, warnings}.
func load_with(extra: Array, resource_keywords: Array[String] = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + extra}, resources(), "cards.json", errors, warnings,
		keywords(), resource_keywords)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## The errors from parsing a config against the parsed card db cards. overrides replace config keys after
## raw_config's defaults, so a population block is used as given (no FAMINE added).
func config_errors_for(cards: Dictionary, overrides: Dictionary, deck := {"farm": 1}) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config(deck)
	raw.merge(overrides, true)
	DataLoader.parse_config(raw, resources(), cards, "config.json", errors, warnings)
	return errors


# --- UI helpers (backlog 045) ---

## Runs body with Game.engine swapped for a game on TEST_CARDS + TEST_EVENTS with main deck {farm: 5, caravan: 5} and
## event_deck (by default Windfall, Trade Winds, Omen), then puts the real engine back. overrides replace config keys.
func with_event_engine(body: Callable, event_deck := {"windfall": 1, "trade_winds": 1, "omen": 1}, overrides := {}) -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := event_db(errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 5, "caravan": 5},
		{"event_deck": event_deck}.merged(overrides, true)), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	body.call()
	Game.engine = real


## Runs body with Reduce motion set to calm in a temp settings store, then puts the player's settings back (104: a
## transition test must know whether screens grow or only fade). Use with await.
func with_reduce_motion(calm: bool, body: Callable) -> void:
	var path := "user://test_reduce_motion_settings.cfg"
	var original: SettingsStore = Settings.store
	Settings.store = SettingsStore.new(path)
	Settings.store.reduce_motion = calm
	await body.call()
	Settings.store = original
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Waits until a navigated screen's transition (Anim.SCREEN_TIME, 104) is over. Use with await.
func wait_screen_transition() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(Anim.SCREEN_TIME + 0.15).timeout


## Waits n frames, so containers lay out (sizes and positions) before a UI test measures them. Use with await.
func wait_frames(n := 2) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


## Adds a fresh main scene to the running tree. Typed Node so calls to its test hooks parse before they exist.
func open_main() -> Node:
	var main: Node = load("res://ui/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	return main


## Presses and releases keycode on main's viewport.
func press_key(main: Node, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		main.get_viewport().push_input(event)


func close_main(main: Node) -> void:
	main.get_parent().remove_child(main)
	main.free()
	if _real_turn_limit > 0:  # play_seed_1 shortened the real game
		Game.engine.config.turn_limit = _real_turn_limit
		_real_turn_limit = 0


## Plays seed 1 with the bot for SEED_1_TURNS turns (the real turn_limit is lowered for this game, 066: a whole
## 100-turn game through the UI is too slow for the suite; close_main restores it), calling after_turn(main) each
## time the turn number changes. test_content's sweep plays full-length games.
func play_seed_1(main: Node, after_turn: Callable) -> void:
	var e := Game.engine
	if _real_turn_limit == 0:
		_real_turn_limit = e.config.turn_limit
	e.config.turn_limit = mini(SEED_1_TURNS, _real_turn_limit)
	main.start_game(1)
	var state := {"turn": e.turn}
	var on_changed := func():
		if e.turn != state.turn or e.is_over:
			state.turn = e.turn
			after_turn.call(main)
	e.changed.connect(on_changed)
	ScriptedBot.play(e)
	e.changed.disconnect(on_changed)


## Records engine e's logged and noticed messages in order, as "log: …" and "notice: …" (116). e is an Object so
## the connection fails at run time, not parse time, before the signal exists.
func record_messages(e: Object) -> Array[String]:
	var out: Array[String] = []
	e.connect("logged", func(m: String): out.append("log: " + m))
	e.connect("noticed", func(m: String): out.append("notice: " + m))
	return out


## The notices in recorded (from record_messages), without the prefix.
func notices_in(recorded: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for line in recorded:
		if line.begins_with("notice: "):
			out.append(line.trim_prefix("notice: "))
	return out


## Asserts recorded has a notice containing fragment, right after the log line with the same text (116).
func check_noticed(recorded: Array[String], fragment: String) -> void:
	for i in recorded.size():
		if recorded[i].begins_with("notice: ") and recorded[i].contains(fragment):
			var text := recorded[i].trim_prefix("notice: ")
			check(i > 0 and recorded[i - 1] == "log: " + text, "the notice '%s' follows its log line: %s" % [text, recorded])
			return
	check(false, "a notice containing '%s': %s" % [fragment, recorded])
