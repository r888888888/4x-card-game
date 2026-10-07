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
	{"id": "pathfinder", "name": "Pathfinder", "type": "action",
	 "effects": [{"op": "explore"}, {"op": "gain", "resource": "food", "amount": 1}]},
	{"id": "forager", "name": "Forager", "type": "action", "effects": [{"op": "gain", "resource": "food", "amount": 1}]},
	{"id": "pioneer", "name": "Pioneer", "type": "action", "cost": {"food": 3},
	 "effects": [{"op": "settle", "card": "city"}]},
	{"id": "guildhall", "name": "Guildhall", "type": "building", "cost": {"food": 2, "wealth": 2}},
	{"id": "stall", "name": "Stall", "type": "building",
	 "effects": [{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}]},
	{"id": "bazaar", "name": "Bazaar", "type": "action",
	 "effects": [{"op": "gain_per_tag", "resource": "wealth", "amount": 2, "tag": "city"}]},
	{"id": "study", "name": "Research", "type": "action", "effects": [{"op": "gain", "resource": "insight", "amount": 3}]},
	{"id": "trader", "name": "Trader", "type": "action", "cost": {"food": 1}, "effects": [
		{"op": "trade", "resource": "wealth", "per_root_city": 2, "pop_per": 5, "min_cities": 2}]},
	{"id": "famine", "name": "Famine", "type": "event",
	 "effects": [{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]},
]}

## An action that gives back its action and takes a card from the discard into the hand (370). Not in TEST_CARDS: pass
## it as an extra card.
const RECALL_CARD := {"id": "recall", "name": "Recall", "type": "action",
	"effects": [{"op": "gain_actions", "amount": 1}, {"op": "recall"}]}

## How many turns play_seed_1 plays of the real game (066).
const SEED_1_TURNS := 20
## The real engine's turn_limit while play_seed_1 has shortened it (0 otherwise); close_main puts it back.
var _real_turn_limit := 0
var _window_size_before := Vector2i.ZERO  # open_game(big): the window size close_game restores
## The famine block raw_config adds to a population block that has none (backlog 083: required with population on).
const FAMINE := {"card": "famine", "max_counters": 3}

## Fixture events (backlog 039), loaded with TEST_CARDS by event_db. Not in TEST_CARDS itself, so make_engine games
## have no event deck.
const TEST_EVENTS := [
	{"id": "windfall", "name": "Windfall", "type": "event", "discard": {"turns": 1},
	 "flavor": "A great flood covered the plain.", "effects": [{"op": "gain", "resource": "food", "amount": 2}]},
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
var noticed_priorities := {}  # record_messages: each notice's message -> its priority (190)
var expected_errors: Array[String] = []  # expect_error's fragments; the runner checks them against the logged errors


## Expects an error containing fragment to be logged (push_error) during this test: it doesn't fail the test, and the
## test fails if no such error is logged. Counts as an assertion.
func expect_error(fragment: String) -> void:
	assertions += 1
	expected_errors.append(fragment)


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


## Table-driven loads (340), check_cases for accepted input. Each row is [label, input, expected]:
## load_input.call(input) returns {cards, config?, errors, warnings}, and expected maps a dotted path ("cards.x.era",
## "config.supply", "cards.x.is_permanent()") to the value it must equal. A row passes when it loads with no errors and
## no warnings and every path's value equals the expected one; a failure names the row's label.
func check_loads(rows: Array, load_input: Callable) -> void:
	for row in rows:
		var label: String = row[0]
		var r: Dictionary = load_input.call(row[1])
		for kind in ["errors", "warnings"]:
			check(r[kind].is_empty(), "%s: %s: %s" % [label, kind, "; ".join(r[kind])])
		var expected: Dictionary = row[2]
		for path: String in expected:
			var found := value_at(r, path)
			if found.is_empty():
				check(false, "%s: no '%s'" % [label, path])
			else:
				eq(found[0], expected[path], "%s: %s" % [label, path])


## [the value at the dotted path in root], or [] when a segment is missing. A segment ending in "()" calls that method
## with no arguments, a number indexes an array (or is an int key), and anything else is a key or property.
func value_at(root: Variant, path: String) -> Array:
	var value: Variant = root
	for segment in path.split("."):
		if segment.ends_with("()"):
			var call := Expression.new()  # calls methods of built-in types too, without logging an error when missing
			if call.parse("v." + segment, ["v"]) != OK:
				return []
			value = call.execute([value], null, false)
			if call.has_execute_failed():
				return []
		elif value is Dictionary:
			if value.has(segment):
				value = value[segment]
			elif segment.is_valid_int() and value.has(segment.to_int()):
				value = value[segment.to_int()]
			else:
				return []
		elif value is Array:
			if not segment.is_valid_int() or segment.to_int() >= value.size():
				return []
			value = value[segment.to_int()]
		elif value is Object and segment in value:
			value = value.get(segment)
		else:
			return []
	return [value]


# --- Helpers ---

func has_message(messages: Array[String], fragment: String) -> bool:
	for m in messages:
		if fragment in m:
			return true
	return false


func resources() -> Array[String]:
	var r: Array[String] = ["food", "wealth", "insight"]
	return r


## Keyword ids for tests; TEST_CARDS territories only use these.
func keywords() -> Array[String]:
	var k: Array[String] = ["mountain", "fresh_water", "flood_plain"]
	return k


## A population block without "famine" gets FAMINE (083), so fixtures that turn population on stay short.
func raw_config(deck: Dictionary, overrides := {}) -> Dictionary:
	var c := {
		"resources": ["food", "wealth", "insight"], "turn_limit": 20, "hand_size": 5, "deck_model": "fixed",
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"},
		"deck": deck,
	}
	c.merge(overrides, true)
	if c.get("population") is Dictionary and not c.population.has("famine"):
		c.population = c.population.duplicate()
		c.population["famine"] = FAMINE
	return c


## A new game using TEST_CARDS. deck is {card_id: count}; overrides replace config keys.
func make_engine(deck: Dictionary, overrides := {}, seed_value := 1, extra_cards := []) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + extra_cards}, resources(), "test", errors, warnings,
		keywords())
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


## A make_engine game with Explorers in the deck and Hills, Grassland, Jungle in the territory deck (top first), an
## Explorer played: the explore choice is open, Hills and Grassland revealed.
func explore_engine() -> GameEngine:
	var e := make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}})
	arrange(e.zone("territory_deck"), ["hills", "grassland", "jungle"])
	check(e.play_card(first_in_hand(e)), "play Explorer")
	return e


## A finished make_engine game (turn_limit 1, ended).
func over_engine() -> GameEngine:
	var e := make_engine({"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "the game is over")
	return e


## A card "x" of type with one effect.
func card_with(type: String, effect: Dictionary) -> Dictionary:
	return {"id": "x", "name": "X", "type": type, "effects": [effect]}


## Sets the pop on e's home territory (home_uid) to n.
func set_home_pop(e: GameEngine, n: int) -> void:
	e.zone("tableau").find(home_uid(e)).pop = n


## The territory the Capital stands on, or null.
func capital_land(e: GameEngine) -> CardInstance:
	for c in e.zone("tableau").cards:
		if c.def.id == "capital":
			return e.zone("tableau").find(c.territory_uid)
	return null


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
func build_on(engine: GameEngine, territory_uid: int, card_ids: Array) -> void:
	for id in card_ids:
		var card: CardInstance = engine.create_card(id, "tableau", null)
		card.territory_uid = territory_uid


## Moves one territory_deck copy of each id (in order) straight to the tableau, as if settled
## without a city.
func settle(engine: GameEngine, ids: Array) -> void:
	_move_territories(engine, ids, "tableau")


## Moves one territory_deck copy of each id (in order) to the frontier.
func to_frontier(engine: GameEngine, ids: Array) -> void:
	_move_territories(engine, ids, "frontier")


func _move_territories(engine: GameEngine, ids: Array, to_zone: String) -> void:
	var deck: Zone = engine.zone("territory_deck")
	for id in ids:
		var uid := uid_of(deck, id)
		check(uid != -1, "territory_deck has no %s" % id)
		if uid != -1:
			var card := deck.find(uid)
			deck.remove(card)
			engine.zone(to_zone).add(card)


## How many times longer slow takes than fast (backlog 150): the fastest of runs timings of each, calling it calls
## times. Compare as a ratio, never against a fixed time: the machine's speed cancels out. The two sides alternate run
## by run (236), so a busy spell on a loaded machine lands on both, and best-of-runs drops it.
func time_ratio(slow: Callable, fast: Callable, calls := 20, runs := 9) -> float:
	var sides := [slow, fast]
	var best := [-1, -1]
	for r in runs:
		for k in 2:
			var i := (r + k) % 2  # who goes first alternates too
			var start := Time.get_ticks_usec()
			for c in calls:
				sides[i].call()
			var took := Time.get_ticks_usec() - start
			best[i] = took if best[i] == -1 or took < best[i] else best[i]
	return float(maxi(best[0], 1)) / maxi(best[1], 1)


## Puts a new copy of card id in the hand and returns its uid.
func put_in_hand(engine: GameEngine, id: String) -> int:
	return put_in(engine, id, "hand")


## Puts a new copy of card id in zone_name and returns its uid. A government is placed there directly, where
## create_card would send it to the government deck (154): tests of rules for governments in the hand or discard.
func put_in(engine: GameEngine, id: String, zone_name: String) -> int:
	if engine.card_db[id].type != CardDef.GOVERNMENT:
		var card: CardInstance = engine.create_card(id, zone_name, null)
		return card.uid
	var gov := CardInstance.new(engine.state.next_uid, engine.card_db[id])
	engine.state.next_uid += 1
	engine.zone(zone_name).add(gov)
	return gov.uid


## r's cards (r from fixture_load), after appending its errors and warnings to errors and warnings.
func cards_of(r: Dictionary, errors: Array[String], warnings: Array[String]) -> Dictionary:
	errors.append_array(r.errors)
	warnings.append_array(r.warnings)
	return r.cards


## TEST_CARDS plus TEST_CIVS, parsed.
func civ_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return cards_of(fixture_load([], [TEST_CIVS]), errors, warnings)


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
	return cards_of(fixture_load([], [TEST_GOVS]), errors, warnings)


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
	return cards_of(fixture_load([], [TEST_EVENTS]), errors, warnings)


## TEST_CARDS, then each fixture set in sets (TEST_GOVS, TEST_CIVS, TECHS, …), then extra, parsed as cards.json:
## {cards, errors, warnings}. resource_list is the resources listed (resources() when empty); resource_keywords the
## config's rolled resource keywords. For loader tests; fixture_db when the cards must load.
func fixture_load(extra := [], sets := [], resource_list: Array[String] = [], resource_keywords: Array[String] = []) -> Dictionary:
	var raw: Array = TEST_CARDS.cards.duplicate()
	for fixture_set in sets:
		raw.append_array(fixture_set)
	raw.append_array(extra)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var listed := resources() if resource_list.is_empty() else resource_list
	var cards := DataLoader.parse_cards({"cards": raw}, listed, "cards.json", errors, warnings, keywords(),
		resource_keywords)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## fixture_load([card], sets): TEST_CARDS, the sets and one more card.
func card_load(card: Dictionary, sets := []) -> Dictionary:
	return fixture_load([card], sets)


## fixture_load's cards, failing the test on a load error.
func fixture_db(extra := [], sets := [], resource_list: Array[String] = []) -> Dictionary:
	var r := fixture_load(extra, sets, resource_list)
	check(r.errors.is_empty(), "test cards should load: %s" % [r.errors])
	return r.cards


## The errors from parsing a config against the parsed card db cards. overrides replace config keys after
## raw_config's defaults, so a population block is used as given (no FAMINE added).
func config_errors_for(cards: Dictionary, overrides: Dictionary, deck := {"farm": 1}) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config(deck)
	raw.merge(overrides, true)
	DataLoader.parse_config(raw, resources(), cards, "config.json", errors, warnings)
	return errors


## fixture_load([], sets) and a config parsed with overrides (see config_errors_for) against its cards: {cards, config,
## errors, warnings}, the messages of both. For check_loads rows of config.
func config_load(overrides: Dictionary, sets := []) -> Dictionary:
	return config_load_on(fixture_load([], sets), overrides)


## cards_load (a fixture_load result) plus a config parsed with overrides against its cards: {cards, config, errors,
## warnings}, the messages of both.
func config_load_on(cards_load: Dictionary, overrides: Dictionary) -> Dictionary:
	var errors: Array[String] = cards_load.errors.duplicate()
	var warnings: Array[String] = cards_load.warnings.duplicate()
	var raw := raw_config({"farm": 1})
	raw.merge(overrides, true)
	var config := DataLoader.parse_config(raw, resources(), cards_load.cards, "config.json", errors, warnings)
	return {"cards": cards_load.cards, "config": config, "errors": errors, "warnings": warnings}


## The errors from parsing a config with overrides (see config_errors_for) against fixture_db([], sets).
func config_errors(overrides: Dictionary, sets := [], deck := {"farm": 1}) -> Array[String]:
	return config_errors_for(fixture_db([], sets), overrides, deck)


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


## The territory deck board_engine games use (137): two Grassland and two Hills.
const BOARD_TERRITORIES := {"territory_deck": {"grassland": 2, "hills": 2}}
## A population block where Homeland's pop eats more than the Capital makes, for a Famine at the first upkeep.
const HUNGRY_POP := {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}


## A game on TEST_CARDS + TEST_EVENTS with BOARD_TERRITORIES and overrides, not started (with_main starts it).
func board_engine(overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := event_db(errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 10}, BOARD_TERRITORIES.merged(overrides, true)),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return GameEngine.new(cards, config)


## Runs body(main) on the real main scene with Game.engine swapped for engine, started on seed 1 (which re-deals the
## same config) and laid out; then puts the real engine back. Use with await.
func with_main(engine: GameEngine, body: Callable) -> void:
	var real := Game.engine
	Game.engine = engine
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


## Runs body(main) on a real main scene started on seed 1 and laid out, with Reduce motion set to calm. Use with await.
func with_game(calm: bool, body: Callable) -> void:
	await with_reduce_motion(calm, func():
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		await body.call(main)
		close_main(main))


## with_main on a make_engine game with deck, Grassland and Hills in the territory deck, and overrides. Use with await.
func with_territories_main(body: Callable, deck := {"farm": 10}, overrides := {}) -> void:
	await with_main(make_engine(deck, {"territory_deck": {"grassland": 1, "hills": 1}}.merged(overrides)), body)


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


## Removes dir and everything in it; nothing when it doesn't exist (temp trees the sim tests make, 291, 292).
func remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub in DirAccess.get_directories_at(dir):
		remove_tree(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## The state a toggle key shows, ON or OFF: the text of its state label beside it (219), or "" if it has none.
func shown_state(key: Object) -> String:
	var word: Variant = key.get("state_label") if key != null else null
	return (word as Label).text if word is Label else ""


## Runs body with the Settings autoload saving to a temp file at path (Day mode and Reduce motion off), then puts the
## player's store and palette back. Use with await.
func with_temp_settings(body: Callable, path := "user://test_temp_settings.cfg") -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var original: SettingsStore = Settings.store
	Settings.store = SettingsStore.new(path)
	await body.call()
	Settings.store = original
	Settings.changed.emit()  # back to the player's palette
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Opens main on a seed-1 game played to turn 3, laid out.
func mid_game() -> Node:
	var main := open_main()
	main.start_game(1)
	for i in 2:
		Game.engine.end_turn()
		close_event(main)
	await wait_frames()
	return main


## Closes the drawn-event modal if one is up, whichever event the seed drew: a choice event's first open option,
## else OK.
func close_event(main: Node) -> void:
	if main.event_modal().is_empty():
		return
	var open_options: Array[Button] = main.event_option_buttons().filter(func(b: Button): return not b.disabled)
	(open_options[0] if not open_options.is_empty() else main.event_modal_ok_button()).pressed.emit()


## Calls visit(main, name) on each screen to check: the board mid-game, then each modal and screen open over it, the
## start screens, a drawn event and game over. Use with await.
func each_screen(visit: Callable) -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		visit.call(main, "board")
		var openers := {
			"supply": func(): main.open_supply(),
			"knowledge": func(): main.knowledge.open(),
			"card details": func(): main.details.open(main.views[first_in_hand(Game.engine)]),
			"identity": func(): main.identity_modal.open(),
			"log": func(): main.log_drawer.open(),
			"game menu": func(): main.open_menu(),
		}
		for screen: String in openers:
			openers[screen].call()
			await wait_screen_transition()
			visit.call(main, screen)
			main.modals.close_all()
			if main.log_drawer.is_open():
				main.log_drawer.close()
			if main.knowledge.is_open():  # a screen since 208
				main.knowledge.close()
				await wait_screen_transition()
		close_main(main)

		main = open_main()
		await wait_screen_transition()
		visit.call(main, "start")
		main.start_screen.settings_button.pressed.emit()
		await wait_screen_transition()
		visit.call(main, "settings")
		close_main(main)
		main = open_main()
		main.show_new_game_screen()
		await wait_screen_transition()
		visit.call(main, "new game")
		close_main(main)

		main = open_main()
		main.start_game(1)
		var shown := false
		for i in 10:
			Game.engine.end_turn()
			if not main.event_modal().is_empty():
				shown = true
				break
		check(shown, "precondition: an event is drawn within 10 turns of seed 1")
		await wait_screen_transition()
		if shown:
			visit.call(main, "event")
		close_main(main)

		main = open_main()
		play_seed_1(main, func(_m): pass)
		await wait_frames()
		check(Game.engine.is_over, "precondition: game over")
		visit.call(main, "game over")
		close_main(main))


## The visible controls under root.
func visible_controls(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for c in root.find_children("*", "Control", true, false):
		if (c as Control).is_visible_in_tree():
			found.append(c)
	return found


## Waits until a navigated screen's transition (a fade, Anim.SCREEN_TIME, 104; or a slide, 208) is over. Use with await.
func wait_screen_transition() -> void:
	var longest := maxf(Anim.SCREEN_TIME, maxf(Navigator.SLIDE_IN, Navigator.SLIDE_OUT))
	await (Engine.get_main_loop() as SceneTree).create_timer(longest + 0.15).timeout


## Runs body with the window at size, then puts it back (362: a scroll area with more content than fits). Use with
## await.
func with_window_size(size: Vector2i, body: Callable) -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	window.size = size
	await body.call()
	window.size = before


## Waits until cards have popped in and flown to their slots (so their rects are laid out).
func settle_motion() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout


## Waits n frames, so containers lay out (sizes and positions) before a UI test measures them. Use with await.
func wait_frames(n := 2) -> void:
	for i in n:
		await (Engine.get_main_loop() as SceneTree).process_frame


## counter's tag (181; gone since 218, so tests assert there is none): a visible Label inside it reading "+N" or "−N"
## (a real minus), or null.
func counter_tag(counter: Control) -> Label:
	if counter == null:
		return null
	var tag := RegEx.create_from_string("^[+−][0-9]+$")
	for node in counter.find_children("*", "Label", true, false):
		var l := node as Label
		if l.name == "Forecast":  # next upkeep's change sits beside the figure too (201), not a tag
			continue
		if is_instance_valid(l) and l.is_visible_in_tree() and l.modulate.a > 0.0 and tag.search(l.text) != null:
			return l
	return null


## Adds a fresh main scene to the running tree. Typed Node so calls to its test hooks parse before they exist.
func open_main() -> Node:
	var main: Node = load("res://ui/main.tscn").instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(main)
	return main


## Main with seed 1 started (334). big: the window at 1920 × 1080 until close_game puts it back; freeze_sfx: the sound
## clock frozen at 0 (236). Pair with close_game. Use with await.
func open_game(big := false, freeze_sfx := false) -> Node:
	if big:
		var window := (Engine.get_main_loop() as SceneTree).root
		_window_size_before = window.size
		window.size = Vector2i(1920, 1080)
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	if freeze_sfx:
		main.sfx.set_clock(0.0)
	return main


## Frees an open_game main, and puts the window back to its size before a big open_game.
func close_game(main: Node) -> void:
	close_main(main)
	if _window_size_before != Vector2i.ZERO:
		(Engine.get_main_loop() as SceneTree).root.size = _window_size_before
		_window_size_before = Vector2i.ZERO


## The first visible button under root whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


## Waits s seconds of game time.
func wait_seconds(s: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(s).timeout


## A real mouse move to point at on main's viewport, with the left button held or not.
func move_mouse(main: Node, at: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	main.get_viewport().push_input(event, true)


## Moves the mouse well away from everything.
func away(main: Node) -> void:
	move_mouse(main, Vector2(2, 2))


## Control c's centre, in global coordinates.
func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## How many hover ticks (Sfx.HOVER, 245) main's sfx has played.
func hovers(main: Node) -> int:
	return main.sfx.played().filter(func(r): return r.token == Sfx.HOVER).size()


## A real click: presses and releases mouse button at point at on main's viewport.
func click_point(main: Node, at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event, true)


## A real click at the centre of control (click_point).
func click_control(main: Node, control: Control, button := MOUSE_BUTTON_LEFT) -> void:
	click_point(main, control.get_global_rect().get_center(), button)


## Opens uid's card details as one click on its view does, once the double-click window passes: no click, its
## details_requested signal.
func open_details(main: Node, uid: int) -> void:
	var view: CardView = main.views[uid]
	view.details_requested.emit(view)


## The art plate on view's face (381), or null: a hand-size face has one, named Art.
func art_plate(view: CardView) -> Control:
	return view.find_child("Art", true, false) as Control


## The first CardView under node (a modal's card), or null.
func card_under(node: Node) -> CardView:
	var found := node.find_children("*", "CardView", true, false)
	return found[0] as CardView if not found.is_empty() else null


## The uid of Hills in e's tableau, or -1.
func hills_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "hills")


## Opens the menu on main's game and presses its Settings (206): the Settings modal on top. Use with await.
func open_settings_modal(main: Node) -> void:
	main.open_menu()
	for b in main.menu_buttons():
		if b.text == "Settings":
			b.pressed.emit()
	await wait_frames()


## The texts of the visible buttons in modal's footer that wear the primary look (AccentButton, 251), left to right.
func accent_footer(modal: Object) -> Array[String]:
	var out: Array[String] = []
	for b in (modal.footer as Control).get_children():
		if b is Button and (b as Button).visible and (b as Button).theme_type_variation == &"AccentButton":
			out.append((b as Button).text)
	return out


## Presses and releases keycode on main's viewport.
func press_key(main: Node, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		main.get_viewport().push_input(event)


## One wheel notch (down, or up) at point on main's viewport (the centre of scroll when omitted), as the mouse sends
## it: pressed, then released (356).
func wheel_notch(main: Node, scroll: ScrollContainer, down := true, point := Vector2.INF) -> void:
	wheel_turn(main, scroll, MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP, point)


## One notch of wheel button (MOUSE_BUTTON_WHEEL_*, the sideways ones too, 363) at point, as wheel_notch.
func wheel_turn(main: Node, scroll: ScrollContainer, button: MouseButton, point := Vector2.INF) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.factor = 1.0
		event.position = scroll.get_global_rect().get_center() if point == Vector2.INF else point
		event.global_position = event.position
		main.get_viewport().push_input(event, true)


## The furthest scroll's scroll_vertical can go.
func scroll_bottom(scroll: ScrollContainer) -> int:
	var bar := scroll.get_v_scroll_bar()
	return int(bar.max_value - bar.page)


## The nearest ScrollContainer holding control, or null.
func scroll_around(control: Node) -> ScrollContainer:
	var node := control.get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	return node as ScrollContainer


## Checks that scroll (what) is a SmoothScroll with room to scroll, and that one wheel notch down at point (its centre
## when omitted), from the top, moves it Anim.SCROLL_STEP px (± 2): at once with Reduce motion, else gliding there
## from rest (356, 362). Use with await, inside with_reduce_motion.
func check_wheel_step(main: Node, scroll: ScrollContainer, what: String, point := Vector2.INF) -> void:
	check(scroll is SmoothScroll, "%s: a SmoothScroll, not a %s" % [what, scroll.get_class()])
	check(scroll_bottom(scroll) > Anim.SCROLL_STEP, "%s: room to scroll a step: %d" % [what, scroll_bottom(scroll)])
	scroll.scroll_vertical = 0
	await wait_frames()
	wheel_notch(main, scroll, true, point)
	var step := int(Anim.SCROLL_STEP)
	if UIKit.calm():
		eq(scroll.scroll_vertical, step, "%s: a step down at once" % what)
		return
	eq(scroll.scroll_vertical, 0, "%s: nothing moves in the notch's own frame" % what)
	await wait_frames(240)
	check(absi(scroll.scroll_vertical - step) <= 2, "%s: at rest one step down: %d" % [what, scroll.scroll_vertical])


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
	play_first_legal(e)
	e.changed.disconnect(on_changed)


## Plays e to its end by always doing the first of its legal_actions (312; a renewal with its first options), but
## revolts, abandons, disbands and discards unless a discard is owed (end_turn is listed last, so each turn plays, builds and buys first): a fast game
## for UI tests (314: the sim's GenericBot takes ~30× longer), not a good one.
func play_first_legal(e: GameEngine) -> void:
	var skip := ["revolt", "abandon", "disband", "discard_card"]
	for step in 20000:
		if e.is_over:
			return
		var owed_discard: bool = e.pending().get("kind", "") == GameEngine.PENDING_DISCARD
		var actions := e.legal_actions().filter(func(a): return not skip.has(a[0]) or (owed_discard and a[0] == "discard_card"))
		if actions.is_empty():
			return
		var action: Array = actions[0]
		if action[0] == "renew":  # a choice of count among options (312): renew with the first count, as its error query
			e.renew(action[1].slice(0, action[2]))
		else:
			e.callv(action[0], action.slice(1))


## Records engine e's logged and noticed messages in order, as "log: …" and "notice: …" (116), and each notice's
## priority in noticed_priorities (190).
func record_messages(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	e.connect("logged", func(m: String): out.append("log: " + m))
	e.connect("noticed", func(m: String, priority := &""):
		out.append("notice: " + m)
		noticed_priorities[m] = priority)
	return out


## The notices in recorded (from record_messages), without the prefix.
func notices_in(recorded: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for line in recorded:
		if line.begins_with("notice: "):
			out.append(line.trim_prefix("notice: "))
	return out


## Asserts recorded has a notice containing fragment, right after the log line with the same text (116), and, given a
## priority, that it was noticed with it (190).
func check_noticed(recorded: Array[String], fragment: String, priority := &"") -> void:
	for i in recorded.size():
		if recorded[i].begins_with("notice: ") and recorded[i].contains(fragment):
			var text := recorded[i].trim_prefix("notice: ")
			check(i > 0 and recorded[i - 1] == "log: " + text, "the notice '%s' follows its log line: %s" % [text, recorded])
			if priority != &"":
				eq(noticed_priorities.get(text), priority, "the priority of '%s'" % text)
			return
	check(false, "a notice containing '%s': %s" % [fragment, recorded])


# --- State guards (backlog 171) ---

## v as text, deeply: script objects by their script variables, a CardDef by its id (defs are shared and never
## change), a RandomNumberGenerator by its seed and state. Two values are equal state when their dumps are equal.
func state_dump(v: Variant) -> String:
	match typeof(v):
		TYPE_ARRAY:
			return "[%s]" % ", ".join(v.map(func(x): return state_dump(x)))
		TYPE_DICTIONARY:
			var parts: Array[String] = []
			for k in v:
				parts.append("%s: %s" % [state_dump(k), state_dump(v[k])])
			return "{%s}" % ", ".join(parts)
		TYPE_OBJECT:
			if v == null:
				return "null"
			if v is CardDef:
				return "CardDef(%s)" % v.id
			if v is RandomNumberGenerator:
				return "Rng(%d, %d)" % [v.seed, v.state]
			var parts: Array[String] = []
			for name in script_vars(v):
				parts.append("%s: %s" % [name, state_dump(v.get(name))])
			return "%s(%s)" % [v.get_script().get_global_name(), ", ".join(parts)]
	return var_to_str(v)


## Whether a and b hold the same state (state_dump).
func state_equal(a: Variant, b: Variant) -> bool:
	return state_dump(a) == state_dump(b)


## The script variables of a and b (two objects of one class) whose state differs, joined: "" when none does.
func state_diff(a: Object, b: Object) -> String:
	var names: Array[String] = []
	for name in script_vars(a):
		if state_dump(a.get(name)) != state_dump(b.get(name)):
			names.append(name)
	return ", ".join(names)


## The names of o's script variables (its own and its script parents'), in declaration order.
func script_vars(o: Object) -> Array[String]:
	var out: Array[String] = []
	if o.get_script() == null:
		return out
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append(p.name)
	return out


## The paths at which a and b (a value and its copy) share an array, a dictionary or an object other than a CardDef,
## so a change through one would show in the other.
func shared_refs(a: Variant, b: Variant, path := "") -> Array[String]:
	var out: Array[String] = []
	if typeof(a) != typeof(b):
		return out
	match typeof(a):
		TYPE_ARRAY:
			if is_same(a, b):
				out.append(path)
			for i in mini(a.size(), b.size()):
				out.append_array(shared_refs(a[i], b[i], "%s[%d]" % [path, i]))
		TYPE_DICTIONARY:
			if is_same(a, b):
				out.append(path)
			for k in a:
				if b.has(k):
					out.append_array(shared_refs(a[k], b[k], "%s[%s]" % [path, k]))
		TYPE_OBJECT:
			if a == null or b == null or a is CardDef:
				return out
			if is_same(a, b):
				out.append(path)
				return out
			for name in script_vars(a):
				out.append_array(shared_refs(a.get(name), b.get(name), "%s.%s" % [path, name]))
	return out


## Changes everything reachable from v in place: ints and strings on objects, every array (cleared, or given an
## element when empty) and dictionary (a new key), an RNG advanced. CardDefs are left alone.
func scribble(v: Variant) -> void:
	match typeof(v):
		TYPE_ARRAY:
			for x in v:
				scribble(x)
			if not v.is_empty():
				v.clear()
			elif v.get_typed_builtin() == TYPE_INT:
				v.append(99)
			elif v.get_typed_builtin() == TYPE_STRING:
				v.append("scribbled")
			elif not v.is_typed():
				v.append(99)
		TYPE_DICTIONARY:
			for k in v:
				scribble(v[k])
			v["scribbled"] = 99
		TYPE_OBJECT:
			if v == null or v is CardDef:
				return
			if v is RandomNumberGenerator:
				v.randi()
				return
			for name in script_vars(v):
				var x: Variant = v.get(name)
				match typeof(x):
					TYPE_INT:
						v.set(name, x + 1)
					TYPE_BOOL:
						v.set(name, not x)
					TYPE_STRING:
						v.set(name, x + "z")
					_:
						scribble(x)
