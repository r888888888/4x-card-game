extends "res://tests/lib/tech_case.gd"
## Standing modifiers (backlog 129): a permanent card's `modifiers` object ({key: non-zero int}), summed by
## modifier(key) over the working tableau cards, ALWAYS_ON_ZONES and the active events. The first key is "actions",
## added to the government's actions (127). Fixtures are local so other tests load while the field is missing: Palace
## (free building, +1 action), Calendar (tech, +1), Sages (civilization, +1), Unrest (1-turn event, −1) and Riot
## (1-turn event, −3). Engines are held as Object so the file parses before the API.

const PALACE := {"id": "palace", "name": "Palace", "type": "building", "modifiers": {"actions": 1}}
const CALENDAR := {"id": "calendar", "name": "Calendar", "type": "tech", "cost": {"insight": 2}, "modifiers": {"actions": 1}}
const SAGES := {"id": "sages", "name": "Sages", "type": "civilization", "modifiers": {"actions": 1}}
const UNREST := {"id": "unrest", "name": "Unrest", "type": "event", "discard": {"turns": 1}, "modifiers": {"actions": -1}}
const RIOT := {"id": "riot", "name": "Riot", "type": "event", "discard": {"turns": 1}, "modifiers": {"actions": -3}}
const FIXTURES := [PALACE, CALENDAR, SAGES, UNREST, RIOT]
const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}


## Loader result {errors, warnings, cards} for TEST_CARDS, TEST_GOVS and extra.
func load_cards(extra: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_GOVS + extra}, resources(), "cards.json",
		errors, warnings, keywords())
	return {"errors": errors, "warnings": warnings, "cards": cards}


## A card "x" of type with modifiers value.
func with_modifiers(type: String, value: Variant) -> Dictionary:
	var card := {"id": "x", "name": "X", "type": type, "modifiers": value}
	if type == CardDef.TECH:
		card["cost"] = {"insight": 1}
	return card


## A Band game (2 actions) on TEST_CARDS and the fixtures, population on (home pop 2), 10 food and 10 wealth.
func band_game() -> Object:
	var r := load_cards(FIXTURES)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var o := {"starting": {"resources": {"food": 10, "wealth": 10}, "tableau": ["capital"], "territory": "homeland",
		"government": "band"}}
	o.merge(POP)
	var config := DataLoader.parse_config(raw_config({"farm": 10}, o), resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## Makes event id active in e for turns upkeeps.
func activate(e: Object, id: String, turns := 1) -> void:
	var card: CardInstance = e.create_card(id, "active_events", null)
	card.turns_left = turns


# --- AC1: loading ---

func test_modifiers_load_on_permanent_cards() -> void:
	var r := load_cards(FIXTURES)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if r.cards.has("palace"):
		eq(r.cards.palace.modifiers, {"actions": 1}, "Palace's modifiers")
		eq(r.cards.unrest.modifiers, {"actions": -1}, "a negative value")


func test_modifiers_validation() -> void:
	check_cases([
		["unknown key", [with_modifiers("building", {"food": 1})], ["card 'x'", "modifiers.food"]],
		["not an int", [with_modifiers("building", {"actions": "one"})], ["card 'x'", "modifiers.actions"]],
		["zero", [with_modifiers("building", {"actions": 0})], ["card 'x'", "modifiers.actions"]],
		["not an object", [with_modifiers("building", 1)], ["card 'x'", "modifiers"]],
		["on an action", [with_modifiers("action", {"actions": 1})], "'modifiers' only applies to", "warning_only"],
		["on a territory", [{"id": "x", "name": "X", "type": "territory", "slots": 1, "modifiers": {"actions": 1}}],
			"'modifiers' only applies to", "warning_only"],
	], load_cards)
	for type in ["building", "city", "tech", "civilization", "government", "event"]:
		var r := load_cards([with_modifiers(type, {"actions": 1})])
		eq(r.errors, [] as Array[String], "%s: errors" % type)
		eq(r.warnings, [] as Array[String], "%s: warnings" % type)


# --- AC2: the lookup ---

func test_modifier_sums_working_cards_always_on_zones_and_active_events() -> void:
	var e: Object = band_game()
	eq(e.modifier("actions"), 0, "none yet")
	build_on(e, home_uid(e), ["palace"])
	eq(e.modifier("actions"), 1, "a working building")
	e.create_card("calendar", "researched", null)
	eq(e.modifier("actions"), 2, "a researched tech")
	e.create_card("sages", "civilization", null)
	eq(e.modifier("actions"), 3, "the civilization")
	activate(e, "unrest")
	eq(e.modifier("actions"), 2, "an active event takes 1")
	eq(e.modifier("housing"), 0, "a key no card has")


func test_an_idle_building_stops_counting() -> void:
	var e: Object = band_game()
	var home := home_uid(e)
	build_on(e, home, ["lookout", "lookout", "palace"])
	var palace := uid_of(e.zone("tableau"), "palace")
	check(e.is_idle(palace), "Palace is the third building on 2 pop")
	eq(e.modifier("actions"), 0, "idle: no modifier")
	check(e.grow(home), "grow: %s" % e.grow_error(home))
	check(not e.is_idle(palace), "staffed again")
	eq(e.modifier("actions"), 1, "working: counts again")


# --- AC3: actions per turn ---

func test_actions_per_turn_adds_the_actions_modifier() -> void:
	var e: Object = band_game()
	e.create_card("calendar", "researched", null)
	eq(e.actions_per_turn(), 3, "Band 2 + Calendar 1")
	e.create_card("sages", "civilization", null)
	eq(e.actions_per_turn(), 4, "and Sages 1")
	var u: Object = band_game()
	activate(u, "unrest")
	eq(u.actions_per_turn(), 1, "Band 2 − Unrest 1")
	u.end_turn()
	check(card_ids(u.zone("event_discard")).has("unrest"), "Unrest has ended")
	eq(u.actions_per_turn(), 2, "back to 2")


func test_actions_per_turn_never_drops_below_1() -> void:
	var e: Object = band_game()
	activate(e, "riot")
	eq(e.actions_per_turn(), 1, "Band 2 − Riot 3 stops at 1")
	eq(e.actions_left(), 1, "one action left")


# --- AC4: mid-turn ---

func test_a_modifier_played_mid_turn_counts_at_once() -> void:
	var e: Object = band_game()
	var palace := put_in_hand(e, "palace")
	check(e.play_card(palace, home_uid(e)), "play Palace: %s" % e.play_error(palace, home_uid(e)))
	eq(e.actions_left(), 2, "3 − 1 used")


func test_a_tech_bought_mid_turn_counts_at_once() -> void:
	var starting := {"resources": {"food": 2, "wealth": 20, "insight": 20}, "tableau": ["capital"], "territory": "homeland",
		"government": "band"}
	var e: Object = tech_engine(["calendar", "pottery"], {"farm": 10}, {"starting": starting}, TEST_GOVS + [CALENDAR])
	eq(e.actions_left(), 2, "Band: 2")
	var calendar := uid_of(e.zone("research_deck"), "calendar")
	check(e.buy_tech(calendar), "learn Calendar: %s" % e.buy_tech_error(calendar))
	eq(e.actions_left(), 3, "2 + 1 from Calendar")


# --- AC5: unlimited stays unlimited ---

func test_modifiers_dont_limit_unlimited_actions() -> void:
	var e: Object = gov_engine("council")
	var cards: Dictionary = load_cards(FIXTURES).cards
	if not cards.has("unrest"):
		check(false, "Unrest should load")
		return
	e.card_db = cards
	activate(e, "unrest")
	eq(e.actions_per_turn(), -1, "still unlimited")


# --- AC6: text ---

func test_modifier_text() -> void:
	var cards: Dictionary = load_cards(FIXTURES).cards
	if not (cards.has("palace") and cards.has("unrest")):
		check(false, "Palace and Unrest should load")
		return
	eq(cards.palace.rules_text(cards), "+1 action each turn", "Palace's face")
	eq(cards.palace.rules_tooltip(cards), "+1 action each turn", "Palace's tooltip")
	eq(cards.unrest.rules_text(cards).split("\n")[0], "−1 action each turn", "Unrest's face")
	check(cards.unrest.rules_tooltip(cards).begins_with("−1 action each turn while active"), "Unrest's tooltip: %s" %
		cards.unrest.rules_tooltip(cards))
	eq(cards.riot.rules_text(cards).split("\n")[0], "−3 actions each turn", "plural")
