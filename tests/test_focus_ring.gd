extends "res://tests/lib/test_case.gd"
## The focus ring waits for Tab (backlog 230): the game starts in pointer mode, where a control the code focuses (a
## modal's action button, a screen's first control) has the focus but draws no ring; Tab or Shift+Tab switches to
## keyboard mode, where it draws; a mouse click switches back. "Draws the ring" is Godot's shown focus state:
## has_focus(true), which is false while the focus is hidden.


## Opens main on seed 1 with the menu open (Restart focused by the menu). Use with await.
func open_menu_main() -> Node:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.open_menu()
	await wait_frames()
	return main


func focus_owner(main: Node) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Whether control has the focus and draws it (the ring).
func rings(control: Control) -> bool:
	return control != null and control.has_focus(true)


## Shift+Tab, pressed and released.
func press_shift_tab(main: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = pressed
		main.get_viewport().push_input(event)


## A left click (press and release) near the bottom-right corner of main's viewport, outside any modal's panel.
func click_corner(main: Node) -> void:
	var at := main.get_viewport().get_visible_rect().end - Vector2(5, 5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = pressed
		main.get_viewport().push_input(event, true)


# --- AC1: pointer mode: a modal's action button has the focus, with no ring ---

func test_a_modals_action_button_is_focused_with_no_ring_until_tab() -> void:
	var main: Node = await open_menu_main()
	var restart: Button = main.menu_buttons()[0]
	eq(restart.text, "Restart", "the menu's first button")
	eq(focus_owner(main), restart, "Restart has the focus")
	check(not rings(restart), "Restart draws no ring before Tab")
	var presses := [0]
	restart.pressed.connect(func(): presses[0] += 1)
	press_key(main, KEY_ENTER)
	await wait_frames()
	eq(presses[0], 1, "Enter still presses Restart")
	close_main(main)


func test_the_settings_modal_focuses_its_first_control_with_no_ring() -> void:
	var main := open_main()
	main.start_game(1)
	await open_settings_modal(main)
	var owner := focus_owner(main)
	check(owner != null, "the settings modal focuses a control")
	check(not rings(owner), "it draws no ring before Tab")
	close_main(main)


# --- AC2: a Navigator screen's focus control, with no ring ---

func test_a_pushed_screens_focus_control_draws_no_ring() -> void:
	var main := open_main()
	await wait_frames()
	var screen := Control.new()
	var button := UIKit.button("Go", func(): pass)
	screen.add_child(button)
	main.add_child(screen)
	main.nav.push(screen, button, "Probe")
	await wait_frames()
	eq(focus_owner(main), button, "the screen's control has the focus")
	check(not rings(button), "it draws no ring before Tab")
	close_main(main)


# --- AC3: Tab and Shift+Tab move the focus and show the ring ---

func test_tab_and_shift_tab_in_a_modal_show_the_ring() -> void:
	var main: Node = await open_menu_main()
	var buttons: Array[Button] = main.menu_buttons()
	press_key(main, KEY_TAB)
	await wait_frames()
	eq(focus_owner(main), buttons[1], "Tab moves the focus to New game")
	check(rings(buttons[1]), "New game draws the ring")
	press_shift_tab(main)
	await wait_frames()
	eq(focus_owner(main), buttons[0], "Shift+Tab moves it back to Restart")
	check(rings(buttons[0]), "Restart draws the ring")
	close_main(main)


# --- AC4: keyboard mode: the next modal's action button draws the ring ---

func test_after_tab_the_next_modal_focuses_with_the_ring() -> void:
	var main: Node = await open_menu_main()
	press_key(main, KEY_TAB)
	press_key(main, KEY_ESCAPE)  # closes the menu
	await wait_frames()
	main.open_menu()
	await wait_frames()
	var restart: Button = main.menu_buttons()[0]
	eq(focus_owner(main), restart, "Restart has the focus again")
	check(rings(restart), "in keyboard mode it draws the ring")
	close_main(main)


# --- AC5: a mouse click goes back to pointer mode ---

func test_a_click_hides_the_ring_again() -> void:
	var main: Node = await open_menu_main()
	press_key(main, KEY_TAB)
	await wait_frames()
	click_corner(main)  # outside the menu's panel: closes it
	await wait_frames()
	check(not main.modals.is_open(), "the click closed the menu")
	main.open_menu()
	await wait_frames()
	var restart: Button = main.menu_buttons()[0]
	eq(focus_owner(main), restart, "Restart has the focus")
	check(not rings(restart), "after a click it draws no ring")
	close_main(main)


func test_a_fresh_main_starts_in_pointer_mode() -> void:
	var first: Node = await open_menu_main()
	press_key(first, KEY_TAB)  # keyboard mode in one main...
	close_main(first)
	var main: Node = await open_menu_main()  # ...isn't carried into the next
	check(not rings(main.menu_buttons()[0]), "a new main's menu draws no ring on Restart")
	close_main(main)


# --- AC6: the arrows in a select list still show the ring ---

func test_down_in_the_civilization_list_shows_the_ring() -> void:
	var main := open_main()
	await wait_frames()
	var list := UIKit.select_list()
	var screen := Control.new()
	screen.add_child(list)
	main.add_child(screen)
	for id in ["a", "b"]:
		list.add_row(id, id.to_upper())
	await wait_frames()
	main.nav.push(screen, list.row("a"), "Probe")  # a screen focusing its first row, in pointer mode
	press_key(main, KEY_DOWN)
	await wait_frames()
	eq(focus_owner(main), list.row("b"), "Down focuses b")
	check(rings(list.row("b")), "b draws the ring")
	close_main(main)


# --- Every code focus goes through the one helper ---

func test_no_ui_script_but_the_helper_calls_grab_focus() -> void:
	var helper := "res://ui/focus_ring.gd"
	check(FileAccess.file_exists(helper), "%s holds the focus mode" % helper)
	for file in DirAccess.get_files_at("res://ui"):
		var path := "res://ui/" + file
		if file.ends_with(".gd") and path != helper:
			check(not FileAccess.get_file_as_string(path).contains("grab_focus("),
				"%s focuses through FocusRing, not grab_focus" % path)
