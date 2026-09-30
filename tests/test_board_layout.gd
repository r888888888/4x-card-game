extends "res://tests/lib/test_case.gd"
## The board without a sidebar (backlog 115), in the real main scene on the real data at 1920×1080: the play area
## spans the window, the top bar carries the civilization and government, Buy Cards and Knowledge, and End turn sits
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


## Whether any node under root runs a script whose class_name is class_name_.
func has_script_class(root: Node, class_name_: String) -> bool:
	for node in root.find_children("*", "", true, false):
		var script: Script = node.get_script()
		if script != null and script.get_global_name() == class_name_:
			return true
	return false


# --- AC1: no sidebar ---

func test_no_side_panel_and_the_board_spans_the_window() -> void:
	var main: Node = await open_game_at_1080()
	var width: float = main.get_viewport_rect().size.x
	check(not has_script_class(main, "SidePanel"), "no SidePanel")
	var realm_end: float = main.tableau.row.get_global_rect().end.x
	check(realm_end >= width - EDGE, "the Realm row reaches the right edge: ends at %d of %d" % [realm_end, width])
	var end_turn := shown_button(main, "End turn")
	var hand_end: float = end_turn.get_global_rect().end.x if end_turn != null else 0.0
	check(hand_end >= width - EDGE, "the hand section (hand, then End turn) reaches the right edge: ends at %d of %d" % [
		hand_end, width])
	close_at_1080(main)


# --- AC2: the top bar ---

func test_the_top_bar_holds_identity_supply_and_knowledge_before_menu() -> void:
	var main: Node = await open_game_at_1080()
	var menu := shown_button(main, "Menu")
	var bar: Control = menu.get_parent()
	var identity: Array = main.identity_buttons()
	var supply := shown_button(main, "Buy Cards")
	var knowledge := shown_button(main, "Knowledge")
	eq(identity.size(), 2, "civilization and government buttons")
	check(supply != null and knowledge != null, "Buy Cards and Knowledge shown")
	if identity.size() != 2 or supply == null or knowledge == null:
		close_at_1080(main)
		return
	var civ_name: String = Game.engine.card_db[Game.engine.zone("civilization").cards[0].def.id].name
	eq(identity.map(func(b: Button): return b.text), [civ_name, "Chiefdom"], "the buttons name the cards")
	var order: Array = [identity[0], identity[1], supply, knowledge, menu]
	for b: Button in order:
		eq(b.get_parent(), bar, "'%s' is in the top bar" % b.text)
	var indices := order.map(func(b: Button): return b.get_index())
	eq(indices, sorted(indices), "civilization, government, Buy Cards, Knowledge, then Menu")
	var score: Label = null
	for c in bar.get_children():
		if c is Label and (c as Label).text.begins_with("Score"):
			score = c
	check(score != null and score.get_index() < identity[0].get_index(), "after the stats")
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


# --- AC3: End turn beside the hand ---

func test_end_turn_sits_right_of_the_hand_on_screen() -> void:
	var main: Node = await open_game_at_1080()
	var viewport: Vector2 = main.get_viewport_rect().size
	var end_turn := shown_button(main, "End turn")
	check(end_turn != null, "an End turn button")
	if end_turn != null:
		var r := end_turn.get_global_rect()
		var hand: Rect2 = main.hand_scroll.get_global_rect()
		check(Rect2(Vector2.ZERO, viewport).encloses(r), "on screen: %s" % r)
		check(r.position.x >= hand.end.x, "right of the hand: starts at %d, the hand ends at %d" % [r.position.x, hand.end.x])
		check(r.position.y >= hand.position.y - TOLERANCE and r.end.y <= hand.end.y + TOLERANCE,
			"within the hand's height: %s vs %s" % [r, hand])
		eq(end_turn.theme_type_variation, &"AccentButton", "the accent look")
		check_fits_or_wider(end_turn)
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
