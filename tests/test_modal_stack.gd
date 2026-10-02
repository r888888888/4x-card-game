extends "res://tests/lib/test_case.gd"
## The modal stack in the real main scene (backlog 153): every modal opens on main.modals, the top one alone takes keys
## and clicks, Esc / its close keys / Close / a click outside close only the top one, closing a lower one closes those
## above, and each level's panel is cascaded from the one below. "Tree + details": the tech tree open with a tech's
## details over it. Hooks: main.modals (depth(), top()) and a modal's panel.

const CASCADE := Vector2(36, 28)

var _old_window_size := Vector2i.ZERO


## Opens main at 1920×1080 on a real game (seed 1), opens the tech tree and the first tech's details over it, calls
## body(main), then closes main.
func with_tree_and_details(body: Callable) -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)  # headless starts at another size; the whole tree fits at this one
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.tech_tree.open()
	main.details.open_def(first_tech_id())
	await wait_frames()
	check(not main.tech_tree.shown().is_empty() and not main.details.shown().is_empty(), "tree + details open")
	await body.call(main)
	close_main(main)
	window.size = _old_window_size


func first_tech_id() -> String:
	return Game.engine.tech_eras()[0].techs[0].id


## main.modals.depth(), or -1 while main has no modal stack.
func depth(main: Node) -> int:
	var modals: Object = main.get("modals")
	return -1 if modals == null else modals.depth()


## main.modals.top(), or null.
func top(main: Node) -> Object:
	var modals: Object = main.get("modals")
	return null if modals == null else modals.top()


## The global rect of modal's panel, or an empty rect while modals have no panel hook.
func panel_rect(modal: Object) -> Rect2:
	var panel: Object = modal.get("panel")
	return Rect2() if panel == null else (panel as Control).get_global_rect()


## A left click at global position at on main's viewport.
func click_at(main: Node, at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event, true)


func screen_center(main: Node) -> Vector2:
	return main.get_viewport().get_visible_rect().get_center()


# --- AC1: Esc closes the top one only ---

func test_esc_closes_the_details_over_the_tree_then_the_tree() -> void:
	await with_tree_and_details(func(main: Node):
		eq(depth(main), 2, "two modals open")
		press_key(main, KEY_ESCAPE)
		eq(main.details.shown(), {}, "Esc closes the details")
		check(not main.tech_tree.shown().is_empty(), "the tree stays open")
		eq(depth(main), 1, "one modal left")
		press_key(main, KEY_ESCAPE)
		eq(main.tech_tree.shown(), [] as Array[String], "a second Esc closes the tree")
		eq(depth(main), 0, "none left"))


# --- AC2: a click outside closes the top one only ---

func test_a_click_outside_both_panels_closes_only_the_details() -> void:
	await with_tree_and_details(func(main: Node):
		click_at(main, main.get_viewport().get_visible_rect().end - Vector2(5, 5))
		await wait_frames()
		eq(main.details.shown(), {}, "the details close")
		check(not main.tech_tree.shown().is_empty(), "the tree stays open")
		eq(depth(main), 1, "one modal left"))


func test_a_click_on_the_tree_beside_the_details_closes_only_the_details() -> void:
	await with_tree_and_details(func(main: Node):
		var tree := panel_rect(main.tech_tree)
		var at := tree.position + Vector2(6, 6)  # the tree panel's corner, inside its padding
		check(tree.has_area() and tree.has_point(at), "the point is on the tree's panel: %s" % [tree])
		check(not panel_rect(main.details).has_point(at), "and not on the details' panel")
		var researched: int = Game.engine.zone("researched").size()
		click_at(main, at)
		await wait_frames()
		eq(main.details.shown(), {}, "the details close")
		check(not main.tech_tree.shown().is_empty(), "the tree stays open")
		eq(depth(main), 1, "one modal left: no tech's details opened")
		eq(Game.engine.zone("researched").size(), researched, "no tech learned"))


# --- AC3: keys go to the top modal only ---

func test_keys_go_to_the_top_modal_only() -> void:
	await with_tree_and_details(func(main: Node):
		var turn := Game.engine.turn
		press_key(main, KEY_T)
		eq(depth(main), 2, "T (the tree's key) leaves both open")
		check(not main.tech_tree.shown().is_empty() and not main.details.shown().is_empty(), "both still shown")
		press_key(main, KEY_E)
		eq(Game.engine.turn, turn, "E doesn't end the turn")
		press_key(main, KEY_I)
		eq(main.details.shown(), {}, "I (the details' key) closes the details")
		check(not main.tech_tree.shown().is_empty(), "the tree stays open")
		eq(depth(main), 1, "one modal left"))


# --- AC4: closing a lower modal closes those above; reopening brings it to the top ---

func test_closing_the_tree_closes_the_details_over_it() -> void:
	await with_tree_and_details(func(main: Node):
		main.tech_tree.close()
		eq(main.details.shown(), {}, "the details close with the tree")
		eq(main.tech_tree.shown(), [] as Array[String], "the tree is closed")
		eq(depth(main), 0, "none left"))


func test_reopening_the_tree_brings_it_to_the_top() -> void:
	await with_tree_and_details(func(main: Node):
		main.tech_tree.open()
		eq(main.details.shown(), {}, "the details above it close")
		check(not main.tech_tree.shown().is_empty(), "the tree is open")
		eq(depth(main), 1, "one modal")
		check(top(main) == main.tech_tree, "the tree on top"))


# --- AC5: the cascade ---

func test_a_modal_alone_is_centred() -> void:
	var main := open_main()
	main.start_game(1)
	main.details.open_def(first_tech_id())
	await wait_frames()
	var rect := panel_rect(main.details)
	check(rect.has_area(), "the details have a panel")
	check(rect.get_center().distance_to(screen_center(main)) <= 1.0, "centred: %s, screen centre %s" % [
		rect.get_center(), screen_center(main)])
	close_main(main)


func test_a_modal_over_another_is_one_cascade_step_from_centre() -> void:
	await with_tree_and_details(func(main: Node):
		var tree := panel_rect(main.tech_tree)
		var details := panel_rect(main.details)
		check(tree.has_area() and details.has_area(), "both have panels")
		check(tree.get_center().distance_to(screen_center(main)) <= 1.0, "the tree, below, is centred: %s" % [
			tree.get_center()])
		var expected := screen_center(main) + CASCADE
		check(details.get_center().distance_to(expected) <= 1.0, "the details sit 36 px right, 28 down: %s, want %s" % [
			details.get_center(), expected]))


# --- AC6: every modal opens on main.modals ---

func test_details_open_on_the_stack_and_close_with_close() -> void:
	var main := open_main()
	main.start_game(1)
	main.details.open_def(first_tech_id())
	eq(depth(main), 1, "one modal")
	check(top(main) == main.details, "the details on top")
	for b in UIKit.buttons_in(main.details):
		if b.text.begins_with("Close"):
			b.pressed.emit()
	eq(depth(main), 0, "Close closes it")
	close_main(main)


func test_the_tree_opens_on_the_stack_and_close_closes_it() -> void:
	var main := open_main()
	main.start_game(1)
	main.tech_tree.open()
	eq(depth(main), 1, "one modal")
	check(top(main) == main.tech_tree, "the tree on top")
	for b in UIKit.buttons_in(main.tech_tree):
		if b.text.begins_with("Close"):
			b.pressed.emit()
	eq(depth(main), 0, "Close closes it")
	close_main(main)


func test_the_identity_modal_opens_on_the_stack_and_hides_the_toasts() -> void:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.identity_button().pressed.emit()
	eq(depth(main), 1, "one modal")
	check(top(main) == main.identity_modal, "the identity modal on top")
	Game.engine.emit_signal("noticed", "Famine ends.", GameEngine.NOTICE_INFO)
	await wait_frames()
	check(not (main.toasts as Control).is_visible_in_tree(), "toasts hidden under it")
	main.identity_modal.close_button.pressed.emit()
	eq(depth(main), 0, "Close closes it")
	close_main(main)


func test_the_event_modal_opens_on_the_stack_and_ok_closes_it() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		arrange(Game.engine.zone("event_deck"), ["windfall"])
		Game.engine.end_turn()
		eq(main.event_modal().get("id", ""), "windfall", "the drawn event is shown")
		eq(depth(main), 1, "one modal")
		check(top(main) != null and top(main).shown() == main.event_modal(), "the event modal on top")
		main.event_modal_ok_button().pressed.emit()
		eq(depth(main), 0, "OK closes it")
		close_main(main), {"windfall": 1, "omen": 1})


# --- AC7: a new game or leaving the game closes them all ---

func test_a_new_game_closes_every_modal() -> void:
	await with_tree_and_details(func(main: Node):
		main.start_game(2)
		eq(depth(main), 0, "none open")
		eq(main.tech_tree.shown(), [] as Array[String], "the tree closed")
		eq(main.details.shown(), {}, "the details closed"))


func test_leaving_for_the_title_screen_closes_every_modal() -> void:
	await with_tree_and_details(func(main: Node):
		main.show_title_screen()
		eq(depth(main), 0, "none open")
		eq(main.tech_tree.shown(), [] as Array[String], "the tree closed")
		eq(main.details.shown(), {}, "the details closed"))
