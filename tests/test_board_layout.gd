extends "res://tests/lib/test_case.gd"
## The board without a sidebar (backlog 115), in the real main scene on the real data at 1920×1080: the play area
## reaches the sidebar (202), the top bar carries Buy Cards and Knowledge, and End turn sits
## right of the hand.

const EDGE := 40.0  # px from the window's right edge that counts as reaching it
const TOLERANCE := 1.0

var _old_window_size := Vector2i.ZERO


## Opens main at the base resolution with a seed 1 game, laid out. Pair with close_at_1080.
func open_game_at_1080() -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)  # headless starts at another size
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	return main


func close_at_1080(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


## The first button under root that is visible on screen and whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


## The first label under root that is visible on screen and whose text starts with prefix, or null.
func shown_label(root: Node, prefix: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with(prefix):
			return label
	return null


## Whether any node under root runs a script whose class_name is class_name_.
func has_script_class(root: Node, class_name_: String) -> bool:
	for node in root.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and script.get_global_name() == class_name_:
			return true
	return false


# --- AC1: no sidebar ---

func test_no_side_panel_and_the_board_reaches_the_sidebar() -> void:
	var main: Node = await open_game_at_1080()
	var width: float = main.get_viewport_rect().size.x
	check(not has_script_class(main, "SidePanel"), "no SidePanel")
	var rail: float = (main.sidebar as Control).get_global_rect().position.x  # the Realm and hand stop at the sidebar (202)
	var realm_end: float = main.tableau.row.get_global_rect().end.x
	check(realm_end >= rail - EDGE, "the Realm row reaches the sidebar: ends at %d, sidebar at %d of %d" % [realm_end, rail, width])
	check(not has_script_class(main, "TurnBox"), "no TurnBox beside the hand (121)")
	check(shown_label(main, "Deck ") == null, "no Deck/Discard counts on the board: they are in the log drawer (121)")
	var hand_end: float = main.hand_scroll.get_global_rect().end.x
	check(hand_end >= rail - EDGE, "the hand reaches the sidebar: ends at %d, sidebar at %d" % [hand_end, rail])
	close_at_1080(main)


# --- AC2: the top bar ---

func test_the_top_bar_holds_supply_and_knowledge_before_menu() -> void:
	var main: Node = await open_game_at_1080()
	var menu := shown_button(main, "Menu")
	var bar: Control = menu.get_parent()
	var supply := shown_button(main, "Buy Cards")
	var knowledge := shown_button(main, "Knowledge")
	check(supply != null and knowledge != null, "Buy Cards and Knowledge shown")
	if supply == null or knowledge == null:
		close_at_1080(main)
		return
	var order: Array = [supply, knowledge, menu]  # the civilization moved to the sidebar (202)
	for b: Button in order:
		eq(b.get_parent(), bar, "'%s' is in the top bar" % b.text)
	var indices := order.map(func(b: Button): return b.get_index())
	eq(indices, sorted(indices), "Buy Cards, Knowledge, then Menu")
	var score: Control = main.counter(TopBar.SCORE)
	check(score.get_parent() == bar and score.get_index() < supply.get_index(), "after the stats")
	close_at_1080(main)


func test_top_bar_controls_are_on_screen_and_buttons_fit_their_text() -> void:
	var main: Node = await open_game_at_1080()
	var viewport: Vector2 = main.get_viewport_rect().size
	var bar: Control = shown_button(main, "Menu").get_parent()
	for c in bar.get_children():
		if not (c is Control and c.visible):
			continue
		var r: Rect2 = c.get_global_rect()
		check(r.position.x >= -TOLERANCE and r.end.x <= viewport.x + TOLERANCE, "'%s' on screen: %s" % [c.name, r])
		if c is Button:
			var minimum: float = c.get_combined_minimum_size().x
			check(absf(c.size.x - minimum) <= TOLERANCE, "'%s' fits its text: width %d, minimum %d" % [
				c.text, c.size.x, minimum])
	close_at_1080(main)


# --- 120: End turn in the top bar ---

## Every button under root whose text starts with prefix, shown or not.
func buttons_starting(root: Node, prefix: String) -> Array[Button]:
	var out: Array[Button] = []
	for b in UIKit.buttons_in(root):
		if b.text.begins_with(prefix):
			out.append(b)
	return out


func test_end_turn_is_in_the_top_bar_between_log_and_menu() -> void:
	var main: Node = await open_game_at_1080()
	var viewport: Vector2 = main.get_viewport_rect().size
	var menu := shown_button(main, "Menu")
	var log_button := shown_button(main, "Log")
	var end_turns := buttons_starting(main, "End turn")
	eq(end_turns.size(), 1, "one End turn button (none beside the hand)")
	if end_turns.size() == 1 and menu != null and log_button != null:
		var end_turn := end_turns[0]
		eq(end_turn.get_parent(), menu.get_parent(), "in the top bar")
		check(log_button.get_index() < end_turn.get_index() and end_turn.get_index() < menu.get_index(),
			"right of Log, left of Menu: %d, %d, %d" % [log_button.get_index(), end_turn.get_index(), menu.get_index()])
		check(Rect2(Vector2.ZERO, viewport).encloses(end_turn.get_global_rect()), "on screen: %s" % end_turn.get_global_rect())
		eq(end_turn.theme_type_variation, &"AccentButton", "the accent look")
		check_fits_or_wider(end_turn)
	close_at_1080(main)


func test_end_turn_is_disabled_with_the_reason_while_the_turn_cant_end() -> void:
	var main: Node = await open_game_at_1080()
	var e := Game.engine
	check(e.play_card(put_in_hand(e, "scout")), "play Scout: an explore choice is pending")
	await wait_frames()
	var error := e.end_turn_error()
	check(error != "", "the turn can't end")
	var end_turn := shown_button(main, "End turn")
	check(end_turn != null, "End turn shown")
	if end_turn != null:
		check(end_turn.disabled, "disabled")
		eq(end_turn.tooltip_text, error, "the reason as its tooltip")
	close_at_1080(main)


func test_top_bar_buttons_put_their_key_in_the_tooltip_not_the_text() -> void:
	var main: Node = await open_game_at_1080()
	var keys := {"Buy Cards": "S", "Knowledge": "T", "Log": "L", "End turn": "E", "Menu": "Esc"}
	for prefix in keys:
		var b := shown_button(main, prefix)
		check(b != null, "a %s button" % prefix)
		if b != null:
			check(not b.text.contains("("), "'%s' names no key" % b.text)
			check(b.tooltip_text.begins_with("Shortcut: %s." % keys[prefix]), "'%s' tooltip starts with its key: %s" % [
				b.text, b.tooltip_text])
	close_at_1080(main)


## Starts seed 1 again as the civilization with the longest name and puts the hand 3 over its limit at the end of
## the turn, so End turn reads "Discard 3 (hand limit M)", with unrest at 10 (144): the top bar's texts at their longest.
func longest_top_bar(main: Node) -> void:
	var e := Game.engine
	var longest := ""
	for id in e.card_db:
		var def: CardDef = e.card_db[id]
		if def.type == CardDef.CIVILIZATION and (longest == "" or def.name.length() > e.card_db[longest].name.length()):
			longest = id
	main.start_game(1, longest)
	for i in e.config.hand_limit + 3 - e.zone("hand").size():
		put_in_hand(e, e.zone("hand").cards[0].def.id)
	e.end_turn()
	if not main.event_modal().is_empty():
		main.event_modal_ok_button().pressed.emit()
	e.resources["unrest"] = 10  # two digits (144): "Unrest: 10 / N (+n)"
	e.changed.emit()
	await wait_frames()


func test_the_top_bar_fits_with_its_longest_texts() -> void:
	var main: Node = await open_game_at_1080()
	await longest_top_bar(main)
	var viewport: Vector2 = main.get_viewport_rect().size
	check(shown_button(main, "Discard 3 (hand limit") != null, "End turn asks for 3 discards")
	check(main.counter(GameEngine.INSIGHT).is_visible_in_tree(), "the Insight counter is in the bar (139)")
	check(main.counter(GameEngine.UNREST).is_visible_in_tree(), "the Unrest counter is in the bar (144)")
	var bar: Control = shown_button(main, "Menu").get_parent()
	for c in bar.get_children():
		if not (c is Control and c.visible):
			continue
		var r: Rect2 = c.get_global_rect()
		check(r.position.x >= -TOLERANCE and r.end.x <= viewport.x + TOLERANCE, "'%s' on screen: %s" % [c.get("text"), r])
		if c is Button:
			check(c.size.x >= c.get_combined_minimum_size().x - TOLERANCE, "'%s' shows its whole text" % c.text)
	close_at_1080(main)


## End turn is a primary action: at least as wide as its text.
func check_fits_or_wider(b: Button) -> void:
	check(b.size.x >= b.get_combined_minimum_size().x - TOLERANCE, "'%s' shows its whole text" % b.text)


func test_end_turn_still_ends_the_turn_and_shows_a_pending_discard() -> void:
	var main: Node = await open_game_at_1080()
	var e := Game.engine
	press_key(main, KEY_E)
	eq(e.turn, 2, "E ends the turn")
	for i in e.config.hand_limit + 2 - e.zone("hand").size():
		put_in_hand(e, e.zone("hand").cards[0].def.id)
	e.end_turn()
	await wait_frames()
	var pending := e.pending()
	if pending.get("kind", "") == GameEngine.PENDING_DISCARD:
		check(shown_button(main, "Discard %d (hand limit" % pending.count) != null, "End turn asks for the discard")
	else:
		check(false, "a discard is pending with the hand over its limit: %s" % [pending])
	close_at_1080(main)


# --- AC4: the event piles on the Events heading: see test_event_panel ---
