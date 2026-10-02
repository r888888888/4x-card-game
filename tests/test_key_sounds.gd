extends "res://tests/lib/test_case.gd"
## Key sounds (187) in the real main.tscn: every button clicks at its contact on the way down and up (mouse or keys),
## hover and focus are silent, a press dragged off sounds and does nothing, a disabled key gives a dead tap and shows
## its reason at once, End turn has its own key and relay, the legend key latches with its own sounds, turning
## interface sounds off is still heard, and Reduce motion plays them at the press. main.sfx's clock is frozen at 0.

var _old_window_size := Vector2i.ZERO


## Main at 1920×1080 with seed 1 started and its sound clock frozen at 0. Pair with close_game.
func open_game() -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.sfx.set_clock(0.0)
	return main


func close_game(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


## The first visible button under root whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


func mouse(main: Node, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	main.get_viewport().push_input(event, true)


func move_mouse(main: Node, at: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	main.get_viewport().push_input(event, true)


func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## [token, at] of every sound played, at rounded to the ms.
func heard(main: Node) -> Array:
	return main.sfx.played().map(func(r): return [r.token, snappedf(r.at, 0.001)])


func tokens(main: Node) -> Array:
	return main.sfx.played().map(func(r): return r.token)


# --- AC1: a click down, a tick up, hover silent ---

func test_a_button_clicks_at_contact_going_down_and_coming_up() -> void:
	await with_reduce_motion(false, func():
		var main: Node = await open_game()
		var log_button := shown_button(main, "Log")
		mouse(main, centre(log_button), true)
		eq(heard(main), [[Sfx.BUTTON_PRESS, 0.024]], "the press at its contact")
		mouse(main, centre(log_button), false)
		eq(heard(main), [[Sfx.BUTTON_PRESS, 0.024], [Sfx.BUTTON_RELEASE, 0.047]], "the release at its contact")
		check(main.sfx.played().all(func(r): return r.get("input") == true), "both are the player's input")
		close_game(main))


func test_space_and_enter_on_a_button_click_too() -> void:
	await with_reduce_motion(false, func():
		var main: Node = await open_game()
		shown_button(main, "Log").grab_focus()
		press_key(main, KEY_SPACE)
		eq(tokens(main), [Sfx.BUTTON_PRESS, Sfx.BUTTON_RELEASE], "Space")
		main.sfx.set_clock(1.0)
		press_key(main, KEY_ENTER)
		eq(tokens(main).size(), 4, "Enter: two more")
		close_game(main))


func test_hover_focus_and_tab_are_silent() -> void:
	var main: Node = await open_game()
	var log_button := shown_button(main, "Log")
	move_mouse(main, centre(log_button))
	log_button.grab_focus()
	press_key(main, KEY_TAB)
	await wait_frames()
	eq(main.sfx.played(), [], "nothing")
	close_game(main)


func test_a_modals_buttons_click_too() -> void:
	var main: Node = await open_game()
	main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
	await wait_frames()
	var before: int = main.sfx.played().size()  # the sheet it laid down (189)
	var close := shown_button(main.details, "Close")
	check(close != null, "the details' Close")
	if close != null:
		mouse(main, centre(close), true)
		eq(tokens(main).slice(before), [Sfx.BUTTON_PRESS], "it clicks")
		mouse(main, centre(close), false)
	close_game(main)


# --- AC2: dragged off; disabled ---

func test_a_press_dragged_off_sounds_both_and_does_nothing() -> void:
	var main: Node = await open_game()
	var log_button := shown_button(main, "Log")
	var away := centre(log_button) + Vector2(0, 400)
	mouse(main, centre(log_button), true)
	move_mouse(main, away, true)
	mouse(main, away, false)
	await wait_frames()
	eq(tokens(main), [Sfx.BUTTON_PRESS, Sfx.BUTTON_RELEASE], "both sounds")
	check(not main.log_drawer.is_open(), "the Log didn't open")
	close_game(main)


func test_a_disabled_button_gives_a_dead_tap_and_shows_its_reason_at_once() -> void:
	var main: Node = await open_game()
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var locked := Button.new()
	locked.text = "Locked"
	locked.disabled = true
	locked.tooltip_text = "Not while the moon is up."
	locked.position = Vector2(800, 500)
	layer.add_child(locked)
	await wait_frames()
	mouse(main, centre(locked), true)
	mouse(main, centre(locked), false)
	eq(heard(main), [[Sfx.REJECT_LOCKED, 0.0]], "one dead tap at once, nothing else")
	var tip: Control = main.call("locked_tip") if main.has_method("locked_tip") else null
	check(tip != null and tip.is_visible_in_tree(), "the reason shows at once")
	if tip != null:
		var labels := tip.find_children("*", "Label", true, false)
		eq(labels.map(func(l): return l.text), ["Not while the moon is up."], "the tooltip's text")
	close_game(main)


# --- AC3: End turn ---

func test_end_turn_presses_heavy_and_closes_a_relay_when_the_turn_ends() -> void:
	await with_reduce_motion(false, func():
		var main: Node = await open_game()
		var end_turn := shown_button(main, "End turn")
		mouse(main, centre(end_turn), true)
		eq(heard(main), [[Sfx.ENDTURN_PRESS, 0.024]], "the big key's press")
		mouse(main, centre(end_turn), false)
		eq(Game.engine.turn, 2, "the turn ended")
		var sounds := heard(main)
		check(sounds.has([Sfx.ENDTURN_COMMIT, 0.065]), "the relay 0.065 s after the release: %s" % [sounds])
		check(sounds.has([Sfx.ENDTURN_TURN, 0.185]), "the drum 0.12 s after that: %s" % [sounds])
		check(not tokens(main).has(Sfx.BUTTON_PRESS) and not tokens(main).has(Sfx.BUTTON_RELEASE), "no plain key sounds")
		close_game(main))


func test_end_turn_that_owes_a_discard_comes_up_like_any_key() -> void:
	await with_reduce_motion(false, func():
		var main: Node = await open_game()
		var e := Game.engine
		for i in e.config.hand_limit + 2 - e.zone("hand").size():
			put_in_hand(e, e.zone("hand").cards[0].def.id)
		e.changed.emit()
		await wait_frames()
		var end_turn := shown_button(main, "End turn")
		mouse(main, centre(end_turn), true)
		mouse(main, centre(end_turn), false)
		eq(e.turn, 1, "the turn didn't end: a discard is owed")
		var keys := heard(main).filter(func(h): return h[0] != Sfx.SHEET_OPEN)  # the turn's event modal lays its sheet (189)
		eq(keys, [[Sfx.ENDTURN_PRESS, 0.024], [Sfx.BUTTON_RELEASE, 0.047]], "press, then a plain release")
		close_game(main))


func test_a_disabled_end_turn_gives_a_dead_tap() -> void:
	await with_reduce_motion(true, func():  # the cards put in hand jump in, not fly over the top bar
		var main: Node = await open_game()
		var e := Game.engine
		for i in e.config.hand_limit + 2 - e.zone("hand").size():
			put_in_hand(e, e.zone("hand").cards[0].def.id)
		e.end_turn()  # a discard is owed: End turn waits, disabled
		if not main.event_modal().is_empty():  # the turn's event, drawn before the discard
			main.event_modal_ok_button().pressed.emit()
		await wait_frames()
		main.sfx.set_clock(5.0)
		var played_before: int = main.sfx.played().size()
		var end_turn: Button = main.sidebar.get("end_turn")  # the sidebar's key since 203
		check(end_turn != null and end_turn.disabled, "End turn, disabled")
		if end_turn != null:
			mouse(main, centre(end_turn), true)
			mouse(main, centre(end_turn), false)
			eq(tokens(main).slice(played_before), [Sfx.REJECT_LOCKED], "a dead tap")
		close_game(main))


# --- AC4: the legend key ---

func test_the_legend_key_latches_on_and_lets_go_with_its_own_sounds() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game()
		main.open_menu()
		await wait_frames()
		var from: int = main.sfx.played().size()  # after the menu's sheet laid down (207): this test hears its key
		var key: Button = main.menu_day_toggle()
		mouse(main, centre(key), true)
		mouse(main, centre(key), false)
		await wait_frames()
		check(key.button_pressed, "latched ON")
		eq(heard(main).slice(from), [[Sfx.BUTTON_PRESS, 0.024], [Sfx.TOGGLE_ON, 0.038]], "press, then the latch catching")
		main.sfx.set_clock(1.0)
		mouse(main, centre(key), true)
		mouse(main, centre(key), false)
		await wait_frames()
		eq(heard(main).slice(from + 2), [[Sfx.BUTTON_PRESS, 1.024], [Sfx.TOGGLE_OFF, 1.047]], "press, then the latch letting go")
		close_game(main))


# --- AC5: interface sounds off is still heard ---

func test_turning_interface_sounds_off_is_heard_before_the_bus_mutes() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game()
		main.open_menu()
		await wait_frames()
		var from: int = main.sfx.played().size()  # after the menu's sheet laid down (207): this test hears its key
		var key: Button = main.call("menu_sound_toggle")
		mouse(main, centre(key), true)
		mouse(main, centre(key), false)
		eq(Settings.interface_sounds, false, "turned off")
		eq(tokens(main).slice(from), [Sfx.BUTTON_PRESS, Sfx.TOGGLE_OFF], "its press and its OFF")
		var bus := AudioServer.get_bus_index(Settings.INTERFACE)
		eq(AudioServer.is_bus_mute(bus), false, "the Interface bus waits for the OFF")
		await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout
		eq(AudioServer.is_bus_mute(bus), true, "then mutes: the next press is silent")
		close_game(main))


func test_settings_can_mute_interface_sounds_after_a_grace() -> void:
	await with_temp_settings(func():
		var bus := AudioServer.get_bus_index(Settings.INTERFACE)
		Settings.call("set_interface_sounds", false, 0.2)
		eq(Settings.interface_sounds, false, "off at once")
		eq(AudioServer.is_bus_mute(bus), false, "still sounding")
		await (Engine.get_main_loop() as SceneTree).create_timer(0.3).timeout
		eq(AudioServer.is_bus_mute(bus), true, "muted after the grace"))


# --- AC6: Reduce motion ---

func test_with_reduce_motion_keys_sound_at_the_press_and_release() -> void:
	await with_reduce_motion(true, func():
		var main: Node = await open_game()
		var log_button := shown_button(main, "Log")
		mouse(main, centre(log_button), true)
		mouse(main, centre(log_button), false)
		var end_turn := shown_button(main, "End turn")
		end_turn.grab_focus()  # by key: the open log covers it
		press_key(main, KEY_SPACE)
		var sounds := heard(main)
		for s in [[Sfx.BUTTON_PRESS, 0.0], [Sfx.BUTTON_RELEASE, 0.0], [Sfx.ENDTURN_PRESS, 0.0], [Sfx.ENDTURN_COMMIT, 0.0],
				[Sfx.ENDTURN_TURN, 0.12]]:
			check(sounds.has(s), "%s: %s" % [s, sounds])
		close_game(main))
