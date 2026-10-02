extends "res://tests/lib/test_case.gd"
## The gain_actions op (backlog 128): "+N actions" this turn when played, on top of the government's actions (127).
## Fixtures Drill (free, +1 action) and Muster (free, +2 actions) are local, not in TEST_CARDS, so other tests load
## while the op is missing. Governments from TEST_GOVS: Band (2 actions), Council (none: unlimited).

const DRILL := {"id": "drill", "name": "Drill", "type": "action", "effects": [{"op": "gain_actions", "amount": 1}]}
const MUSTER := {"id": "muster", "name": "Muster", "type": "action", "effects": [{"op": "gain_actions", "amount": 2}]}
const NO_ACTIONS := "No actions left this turn."


## A new game (TEST_CARDS, Drill, Muster) ruled by gov.
func game_ruled_by(gov: String) -> GameEngine:
	var r := fixture_load([DRILL, MUSTER], [TEST_GOVS, TEST_CIVS])
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": gov}
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"starting": starting}), resources(), r.cards,
		"config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## Plays a new copy of id from the hand, checking that it played.
func play_new(e: GameEngine, id: String) -> void:
	var uid := put_in_hand(e, id)
	check(e.play_card(uid), "play %s: %s" % [id, e.play_error(uid)])


# --- AC1: loading ---

func test_gain_actions_loads() -> void:
	var r := fixture_load([DRILL, MUSTER], [TEST_GOVS, TEST_CIVS])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_gain_actions_validation() -> void:
	var load_one := func(card: Dictionary) -> Dictionary: return fixture_load([card], [TEST_GOVS, TEST_CIVS])
	check_cases([
		["amount 0", card_with("action", {"op": "gain_actions", "amount": 0}), ["card 'x'", "'amount' must be an integer >= 1"]],
		["amount not an int", card_with("action", {"op": "gain_actions", "amount": "one"}), ["card 'x'", "'amount'"]],
		["on upkeep", card_with("building", {"op": "gain_actions", "amount": 1, "trigger": "upkeep"}),
			"'gain_actions' only works on play (got trigger 'upkeep')"],
		["on start", card_with("civilization", {"op": "gain_actions", "amount": 1, "trigger": "start"}),
			["card 'x'", "'gain_actions' can't trigger on start"]],
		["on an event", card_with("event", {"op": "gain_actions", "amount": 1}),
			["card 'x'", "an event effect can't use 'gain_actions'"]],
	], load_one)


func test_gain_actions_amount_defaults_to_1() -> void:
	var r := fixture_load([card_with("action", {"op": "gain_actions"})], [TEST_GOVS, TEST_CIVS])
	eq(r.errors, [] as Array[String], "errors")
	if r.cards.has("x"):
		eq(r.cards.x.rules_text(r.cards), "+1 action", "the default amount is 1")


# --- AC2: the actions it gives ---

func test_a_plus_one_card_pays_back_its_action() -> void:
	var e: GameEngine = game_ruled_by("band")
	play_new(e, "drill")
	eq(e.actions_left(), 2, "one used, one gained")
	eq(e.actions_per_turn(), 2, "actions_per_turn is unchanged")


func test_a_plus_two_card_leaves_one_more() -> void:
	var e: GameEngine = game_ruled_by("band")
	play_new(e, "muster")
	eq(e.actions_left(), 3, "one used, two gained")


# --- AC3: it still needs an action to be played ---

func test_a_plus_one_card_cant_be_played_with_no_actions_left() -> void:
	var e: GameEngine = game_ruled_by("band")
	play_new(e, "shrine")
	play_new(e, "shrine")
	var drill := put_in_hand(e, "drill")
	eq(e.play_error(drill), NO_ACTIONS, "play_error")
	check(not e.play_card(drill), "play_card refuses")


# --- AC4: gained actions last the turn ---

func test_gained_actions_dont_carry_over() -> void:
	var e: GameEngine = game_ruled_by("band")
	play_new(e, "muster")
	e.end_turn()
	eq(e.actions_left(), 2, "back to the government's 2")


# --- AC5: unlimited actions ---

func test_gain_actions_does_nothing_with_unlimited_actions() -> void:
	var e: GameEngine = game_ruled_by("council")
	play_new(e, "drill")
	eq(e.actions_left(), -1, "still unlimited")


# --- AC6: text ---

func test_gain_actions_text() -> void:
	var cards: Dictionary = fixture_load([DRILL, MUSTER], [TEST_GOVS, TEST_CIVS]).cards
	if not (cards.has("drill") and cards.has("muster")):
		check(false, "Drill and Muster should load")
		return
	eq(cards.drill.rules_text(cards), "+1 action", "Drill's face")
	eq(cards.drill.rules_tooltip(cards), "+1 action this turn", "Drill's tooltip")
	eq(cards.muster.rules_text(cards), "+2 actions", "Muster's face")
	eq(cards.muster.rules_tooltip(cards), "+2 actions this turn", "Muster's tooltip")
