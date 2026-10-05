extends "res://tests/lib/tech_case.gd"
## Actions per turn (backlog 127): playing a card from hand uses 1 action; the ruling government's `actions` sets how
## many a turn has (-1, unlimited, when it sets none). Fixtures in TEST_GOVS: Band (2 actions), Court (3), Council and
## Kingdom (none). Shrine (free, +1 VP) fills the hand.

const NO_ACTIONS := "No actions left this turn."
const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}


## Puts n Shrines in e's hand and returns their uids.
func shrines(e: GameEngine, n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(put_in_hand(e, "shrine"))
	return out


## Plays each uid, checking that it played.
func play_all(e: GameEngine, uids: Array[int]) -> void:
	for uid in uids:
		check(e.play_card(uid), "play: %s" % e.play_error(uid))


## A Band game with both actions used.
func spent_band(overrides := {}) -> GameEngine:
	var e: GameEngine = gov_engine("band", {"farm": 10}, overrides)
	play_all(e, shrines(e, 2))
	return e


# --- AC1: the government field and its text ---

func test_government_actions_load() -> void:
	var r := fixture_load([], [TEST_GOVS])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	eq(gov_db().band.actions, 2, "Band's actions")
	eq(gov_db().council.actions, 0, "Council sets none")


func test_bad_government_actions_are_load_errors() -> void:
	check_cases([
		["below 1", [{"id": "x", "name": "X", "type": "government", "actions": 0}], ["'x'", "actions"]],
		["not an int", [{"id": "x", "name": "X", "type": "government", "actions": "two"}], ["'x'", "actions"]],
		["on an action", [{"id": "x", "name": "X", "type": "action", "actions": 2}], "'actions' only applies to governments", "warning_only"],
	], func(extra): return fixture_load(extra, [TEST_GOVS]))


func test_government_actions_text() -> void:
	var db := gov_db()
	eq(db.band.rules_text(db), "2 actions each turn.", "face")
	eq(db.band.rules_tooltip(db), "2 actions each turn.", "tooltip")


# --- AC2: the queries ---

func test_actions_per_turn_come_from_the_government() -> void:
	var e: GameEngine = gov_engine("band")
	eq(e.actions_per_turn(), 2, "actions_per_turn")
	eq(e.actions_left(), 2, "actions_left")
	eq(e.fork().actions_left(), 2, "fork's actions_left")
	var used: GameEngine = gov_engine("band")
	play_all(used, shrines(used, 1))
	eq(used.fork().actions_left(), 1, "a fork copies the actions used")


func test_actions_are_unlimited_without_a_government_that_sets_them() -> void:
	for gov in ["council", ""]:
		var e: GameEngine = gov_engine(gov)
		eq(e.actions_per_turn(), -1, "%s: actions_per_turn" % gov)
		eq(e.actions_left(), -1, "%s: actions_left" % gov)


# --- AC3: each play from hand uses one ---

func test_each_play_uses_an_action_until_none_are_left() -> void:
	var e: GameEngine = gov_engine("band")
	var uids := shrines(e, 3)
	e.play_card(uids[0])
	eq(e.actions_left(), 1, "after one play")
	e.play_card(uids[1])
	eq(e.actions_left(), 0, "after two plays")
	eq(e.play_error(uids[2]), NO_ACTIONS, "play_error")
	eq(e.playable_error(uids[2]), NO_ACTIONS, "playable_error")
	check(not e.play_card(uids[2]), "play_card refuses")
	check(e.zone("hand").find(uids[2]) != null, "the third Shrine stays in hand")
	eq(e.actions_left(), 0, "a refused play uses nothing")


func test_no_actions_comes_after_game_over_and_a_pending_choice() -> void:
	var over: GameEngine = spent_band()
	var shrine: int = shrines(over, 1)[0]
	over.is_over = true
	eq(over.play_error(shrine), "The game is over.", "game over wins")
	var e: GameEngine = gov_engine("band", {"farm": 10}, {"territory_deck": {"grassland": 1, "hills": 1}})
	play_all(e, shrines(e, 1))
	play_all(e, [put_in_hand(e, "explorer")] as Array[int])
	eq(e.play_error(shrines(e, 1)[0]), "Choose a territory first.", "the pending choice wins")


# --- AC4: nothing else uses an action ---

func test_other_actions_dont_use_or_need_actions() -> void:
	var e: GameEngine = spent_band(POP.merged({"supply": {"shrine": {"price": 1, "count": 2}}}))
	e.resources[GameEngine.FOOD] = 10
	e.resources[GameEngine.WEALTH] = 10
	for err in [e.buy_error("shrine"), e.discard_error(first_in_hand(e)),
			e.relieve_famine_error(), e.end_turn_error()]:
		check(not "action" in err, "'%s' shouldn't be about actions" % err)
	check(e.buy("shrine"), "buy: %s" % e.buy_error("shrine"))
	check(e.discard_card(first_in_hand(e)), "discard")
	eq(e.actions_left(), 0, "still 0 left")


func test_learning_a_tech_after_the_last_action_is_free() -> void:
	var starting := {"resources": {"food": 2, "wealth": 20, "insight": 20}, "tableau": ["capital"], "territory": "homeland",
		"government": "band"}
	var e: GameEngine = tech_engine(["pottery", "writing"], {"farm": 10}, {"starting": starting}, TEST_GOVS)
	play_all(e, shrines(e, 2))
	eq(e.actions_left(), 0, "no actions left")
	var pottery := uid_of(e.zone("research_deck"), "pottery")
	check(e.buy_tech(pottery), "buy_tech: %s" % e.buy_tech_error(pottery))
	eq(e.actions_left(), 0, "still none used by learning")


func test_choosing_an_explored_territory_after_the_last_action_is_free() -> void:
	var e: GameEngine = gov_engine("band", {"farm": 10}, {"territory_deck": {"grassland": 1, "hills": 1}})
	play_all(e, shrines(e, 1))
	play_all(e, [put_in_hand(e, "explorer")] as Array[int])
	eq(e.actions_left(), 0, "no actions left")
	var option: int = e.pending().options[0]
	check(e.choose(option), "choose: %s" % e.choose_error(option))


# --- AC5: a new turn, new actions ---

func test_actions_reset_each_turn_and_dont_carry_over() -> void:
	var e: GameEngine = spent_band()
	e.end_turn()
	eq(e.actions_left(), 2, "after using both")
	var one: GameEngine = gov_engine("band")
	play_all(one, shrines(one, 1))
	one.end_turn()
	eq(one.actions_left(), 2, "an unused action doesn't carry over")


func test_any_number_of_plays_without_actions() -> void:
	var e: GameEngine = gov_engine("council")
	play_all(e, shrines(e, 6))
	eq(e.actions_left(), -1, "still unlimited")


# --- AC7: the top bar's counter and the dimmed hand ---

## The visible labels under root whose text starts with prefix.
func labels_starting(root: Node, prefix: String) -> Array[Label]:
	var found: Array[Label] = []
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with(prefix) and label.is_visible_in_tree():
			found.append(label)
	return found


func label_text(root: Node, prefix: String) -> String:
	var found := labels_starting(root, prefix)
	eq(found.size(), 1, "labels starting '%s'" % prefix)
	return found[0].text if found.size() == 1 else ""


func test_top_bar_counts_actions_and_spent_hands_dim() -> void:
	var real := Game.engine
	Game.engine = gov_engine("band")
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var e: GameEngine = Game.engine
	eq(main.actions_label.text, "2 / 2", "at the start (204: on the heading's line)")
	var uids := shrines(e, 3)
	e.play_card(uids[0])
	await wait_frames()
	eq(main.actions_label.text, "1 / 2", "after a play")
	e.play_card(uids[1])
	await wait_frames()
	var view: CardView = main.views.get(uids[2])
	check(view != null and NO_ACTIONS in view.tooltip_text, "the last Shrine says why it can't be played")
	close_main(main)
	Game.engine = gov_engine("council")
	main = open_main()
	main.start_game(1)
	await wait_frames()
	check(not main.actions_label.is_visible_in_tree(), "no counter with unlimited actions")
	close_main(main)
	Game.engine = real


# --- 204: "In Hand" with the count on its line ---

const HOW_TO := "Drag a card into the realm, double-click it, or ←/→ then Enter. Right-click or D discards."


func test_the_hand_is_headed_in_hand_with_the_how_to_as_its_tooltip() -> void:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var hand: Array = main.section_headings().filter(func(h): return h.text == "In Hand")
	eq(hand.size(), 1, "an In Hand heading: %s" % [main.section_headings()])
	if hand.size() == 1:
		eq(hand[0].tooltip, HOW_TO, "the how-to is its tooltip")
	close_main(main)


func test_the_actions_count_sits_right_on_the_headings_line() -> void:
	var real := Game.engine
	Game.engine = gov_engine("band")
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var count: Label = main.actions_label
	eq(count.text, "2 / 2", "actions left / per turn")
	eq(count.tooltip_text, "Actions left this turn", "its tooltip")
	var headings: Array = main.find_children("*", "Label", true, false).filter(func(l): return l.text == "In Hand")
	check(headings.size() == 1, "one In Hand heading")
	var heading: Label = headings[0] if headings.size() == 1 else null
	var hand: Rect2 = main.hand_scroll.get_global_rect()
	var r := count.get_global_rect()
	check(absf(r.end.x - hand.end.x) <= 1.0, "right-aligned to the hand: ends %d, hand ends %d" % [r.end.x, hand.end.x])
	if heading != null:
		var h := heading.get_global_rect()
		check(absf(r.get_center().y - h.get_center().y) <= 4.0, "on the heading's line: %d vs %d" % [r.get_center().y, h.get_center().y])
	eq(labels_starting(main, "Actions:").size(), 0, "no 'Actions: N / M' label")
	close_main(main)
	Game.engine = real
