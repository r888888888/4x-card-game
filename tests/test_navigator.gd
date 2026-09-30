extends "res://tests/lib/test_case.gd"
## The navigation stack (backlog 103): Navigator on plain Controls, then the real main scene's start screens on it.
## Navigator is loaded by path (held as Object) so this file parses before ui/navigator.gd exists.

const NAVIGATOR_PATH := "res://ui/navigator.gd"

var _host: Control  # holds the test screens in the running tree, so they can take the focus


## A new Navigator, or null (with a failed check) when ui/navigator.gd doesn't exist yet.
func make_nav() -> Object:
	check(FileAccess.file_exists(NAVIGATOR_PATH), "%s exists" % NAVIGATOR_PATH)
	if not FileAccess.file_exists(NAVIGATOR_PATH):
		return null
	return load(NAVIGATOR_PATH).new()


## Screens A, B and C, each a Control holding one Button, added to the running tree and shown.
func make_screens() -> Dictionary:
	_host = Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_host)
	var out := {}
	for name in ["A", "B", "C"]:
		var screen := Control.new()
		screen.name = name
		var button := Button.new()
		button.text = name
		screen.add_child(button)
		_host.add_child(screen)
		out[name] = screen
	return out


func button_of(screen: Control) -> Button:
	return screen.get_child(0)


func free_screens() -> void:
	_host.get_parent().remove_child(_host)
	_host.free()


func focus_owner() -> Control:
	return _host.get_viewport().gui_get_focus_owner()


func esc(pressed := true, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.physical_keycode = KEY_ESCAPE
	event.pressed = pressed
	event.echo = echo
	return event


## Which of screens are visible, by name, in A, B, C order.
func visible_names(screens: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for name in ["A", "B", "C"]:
		if screens[name].visible:
			out.append(name)
	return out


# --- AC1: push ---

func test_push_shows_the_new_screen_and_hides_the_one_below() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A)
	nav.push(s.B)
	eq(visible_names(s), ["B", "C"] as Array[String], "B shown, A hidden (C was never on the stack)")
	eq(nav.top(), s.B, "top")
	eq(nav.depth(), 2, "depth")
	nav.push(s.C)
	eq(visible_names(s), ["C"] as Array[String], "C shown, B hidden")
	eq(nav.depth(), 3, "depth 3")
	free_screens()


# --- AC2: back ---

func test_back_returns_to_the_screen_below() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	s.C.hide()
	nav.set_root(s.A)
	nav.push(s.B)
	eq(nav.back(), true, "back from B")
	eq(visible_names(s), ["A"] as Array[String], "A shown again, B hidden")
	eq(nav.top(), s.A, "top A")
	eq(nav.depth(), 1, "depth 1")
	free_screens()


func test_back_at_the_root_or_empty_does_nothing() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	s.B.hide()
	s.C.hide()
	eq(nav.back(), false, "empty: false")
	eq(nav.depth(), 0, "still empty")
	nav.set_root(s.A)
	eq(nav.back(), false, "root: false")
	eq(visible_names(s), ["A"] as Array[String], "A still shown")
	eq(nav.depth(), 1, "still the root")
	free_screens()


# --- AC3: focus ---

func test_push_focuses_the_given_control_and_back_gives_the_focus_back() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A)
	button_of(s.A).grab_focus()
	nav.push(s.B, button_of(s.B))
	eq(focus_owner(), button_of(s.B), "B's button focused")
	nav.back()
	eq(focus_owner(), button_of(s.A), "A's button has the focus again")
	free_screens()


func test_back_leaves_no_focus_when_the_old_focus_is_gone() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A)
	var old := Button.new()
	_host.add_child(old)
	old.grab_focus()
	nav.push(s.B, button_of(s.B))
	old.hide()  # no longer visible: it can't take the focus back
	nav.back()
	eq(focus_owner(), null, "nothing focused")
	free_screens()


# --- AC4: Esc ---

func test_esc_goes_back_above_the_root_only() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A)
	eq(nav.handle_key(esc()), false, "Esc at the root: not used")
	eq(nav.depth(), 1, "still the root")
	nav.push(s.B)
	eq(nav.handle_key(esc(false)), false, "a release: not used")
	eq(nav.handle_key(esc(true, true)), false, "an echo: not used")
	var other := InputEventKey.new()
	other.keycode = KEY_ENTER
	other.pressed = true
	eq(nav.handle_key(other), false, "another key: not used")
	eq(nav.depth(), 2, "still on B")
	eq(nav.handle_key(esc()), true, "Esc on B: used")
	eq(nav.top(), s.A, "back on A")
	free_screens()


# --- AC5: reset and changed ---

func test_set_root_and_clear_reset_the_stack() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A)
	nav.push(s.B)
	nav.set_root(s.C)
	eq(visible_names(s), ["C"] as Array[String], "only C shown")
	eq(nav.depth(), 1, "depth 1")
	eq(nav.top(), s.C, "C is the root")
	nav.clear()
	eq(visible_names(s), [] as Array[String], "everything hidden")
	eq(nav.depth(), 0, "empty")
	eq(nav.top(), null, "no top")
	free_screens()


func test_changed_is_emitted_once_per_step() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	var count := [0]
	nav.changed.connect(func(): count[0] += 1)
	nav.set_root(s.A)
	eq(count[0], 1, "set_root")
	nav.push(s.B)
	eq(count[0], 2, "push")
	nav.back()
	eq(count[0], 3, "back")
	nav.back()  # at the root: nothing happens
	eq(count[0], 3, "a refused back")
	nav.clear()
	eq(count[0], 4, "clear")
	free_screens()


# --- AC6: the start screens use it ---

func test_the_start_screens_are_on_the_navigator() -> void:
	var main := open_main()
	var nav: Object = main.nav
	eq(nav.top(), main.start_screen.overlay, "launch: the title screen")
	main.start_screen.new_game_button.pressed.emit()
	eq(nav.top(), main.new_game_screen.overlay, "New game: the new game screen")
	eq(nav.depth(), 2, "over the title screen")
	nav.back()
	eq(nav.top(), main.start_screen.overlay, "back to the title")
	main.start_screen.settings_button.pressed.emit()
	eq(nav.top(), main.settings_screen.overlay, "Settings: the settings screen")
	main.settings_screen.back_button.pressed.emit()
	main.start_game(3)
	eq(nav.depth(), 0, "a game on the board: nothing on the stack")
	press_key(main, KEY_ESCAPE)
	main.menu_buttons().filter(func(b): return b.text == "New game")[0].pressed.emit()
	eq(nav.top(), main.new_game_screen.overlay, "menu New game: the new game screen")
	eq(nav.depth(), 2, "over the title screen")
	close_main(main)


# --- Backlog 104: titles, the header and transitions ---
# An animated navigator (nav.animated = true, as the board's are) transitions; a plain one switches at once (103).
# with_reduce_motion (test_case.gd) sets Reduce motion.

const HEADER_PATH := "res://ui/screen_header.gd"


## Screens A, B and C at 1000×800 (like full-screen overlays) in the running tree.
func sized_screens() -> Dictionary:
	var s := make_screens()
	for name in s:
		s[name].size = Vector2(1000, 800)
	return s


func animated_nav() -> Object:
	var nav := make_nav()
	if nav != null:
		nav.animated = true
	return nav


func test_titles_follow_the_stack() -> void:
	var nav := make_nav()
	if nav == null:
		return
	var s := make_screens()
	nav.set_root(s.A, null, "Realm")
	nav.push(s.B, null, "River Meadow")
	eq(nav.titles(), ["Realm", "River Meadow"] as Array[String], "bottom first")
	nav.back()
	eq(nav.titles(), ["Realm"] as Array[String], "back drops the top title")
	free_screens()


func test_the_header_names_the_screen_below_and_the_path() -> void:
	var nav := make_nav()
	if nav == null:
		return
	check(FileAccess.file_exists(HEADER_PATH), "%s exists" % HEADER_PATH)
	if not FileAccess.file_exists(HEADER_PATH):
		return
	var s := make_screens()
	var header: Control = load(HEADER_PATH).new(nav)
	_host.add_child(header)
	nav.set_root(s.A, null, "Realm")
	check(not header.back_button.visible, "at the root: no back button")
	eq(header.breadcrumb_text(), "Realm", "at the root: its title")
	nav.push(s.B, null, "River Meadow")
	check(header.back_button.visible, "a back button")
	eq(header.back_button.text, "← Realm", "naming the screen below")
	eq(header.breadcrumb_text(), "Realm › River Meadow", "the path")
	header.back_button.pressed.emit()
	eq(nav.depth(), 1, "pressing it goes back")
	eq(header.breadcrumb_text(), "Realm", "and the header follows")
	free_screens()


func test_push_from_a_rect_grows_the_screen_out_of_it() -> void:
	await with_reduce_motion(false, func():
		var nav := animated_nav()
		if nav == null:
			return
		var s := sized_screens()
		nav.set_root(s.A)
		var from := Rect2(100, 120, 200, 160)
		nav.push(s.B, null, "B", from)
		check(s.B.visible, "shown at once")
		check(s.B.scale.x < 0.5 and s.B.scale.y < 0.5, "starts small: %s" % s.B.scale)
		var top_left: Vector2 = s.B.get_global_transform() * Vector2.ZERO
		check(top_left.distance_to(from.position) < 2.0, "over the rect: %s vs %s" % [top_left, from.position])
		await wait_screen_transition()
		eq(s.B.scale, Vector2.ONE, "full size")
		eq(s.B.modulate.a, 1.0, "opaque")
		free_screens())


func test_push_without_a_rect_fades_in() -> void:
	await with_reduce_motion(false, func():
		var nav := animated_nav()
		if nav == null:
			return
		var s := sized_screens()
		nav.set_root(s.A)
		nav.push(s.B, null, "B")
		check(s.B.modulate.a < 0.5, "starts see-through")
		eq(s.B.scale, Vector2.ONE, "full size")
		await wait_screen_transition()
		eq(s.B.modulate.a, 1.0, "opaque")
		free_screens())


func test_with_reduce_motion_a_push_only_fades() -> void:
	await with_reduce_motion(true, func():
		var nav := animated_nav()
		if nav == null:
			return
		var s := sized_screens()
		nav.set_root(s.A)
		nav.push(s.B, null, "B", Rect2(100, 120, 200, 160))
		eq(s.B.scale, Vector2.ONE, "no growing")
		check(s.B.modulate.a < 0.5, "a fade")
		await wait_screen_transition()
		eq(s.B.modulate.a, 1.0, "opaque")
		free_screens())


func test_back_reverses_the_push_and_the_screen_below_takes_input_at_once() -> void:
	await with_reduce_motion(false, func():
		var nav := animated_nav()
		if nav == null:
			return
		var s := sized_screens()
		nav.set_root(s.A)
		nav.push(s.B, null, "B", Rect2(100, 120, 200, 160))
		await wait_screen_transition()
		check(nav.back(), "back")
		check(s.A.visible, "the screen below is shown at once")
		eq(nav.top(), s.A, "and is the top")
		check(s.B.visible, "the leaving screen is still drawn")
		check(not Navigator.is_shown(s.B), "but no longer counts as shown")
		eq(s.B.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED, "and takes no clicks")
		await wait_screen_transition()
		check(not s.B.visible, "then hidden")
		eq(s.B.scale, Vector2.ONE, "reset to full size for next time")
		eq(s.B.modulate.a, 1.0, "and opaque")
		eq(s.B.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_INHERITED, "and clickable")
		free_screens())


func test_a_new_step_finishes_the_running_transition_first() -> void:
	await with_reduce_motion(false, func():
		var nav := animated_nav()
		if nav == null:
			return
		var s := sized_screens()
		nav.set_root(s.A)
		nav.push(s.B, null, "B")
		nav.push(s.C, null, "C")
		check(not s.B.visible, "B's fade in was finished, then B hidden under C")
		eq(s.B.modulate.a, 1.0, "B left opaque")
		nav.back()
		nav.back()
		check(s.A.visible and Navigator.is_shown(s.A), "A shown")
		check(not s.C.visible, "C's fade out was finished when the next back came")
		await wait_screen_transition()
		check(not s.B.visible and not s.C.visible, "both gone")
		free_screens())
