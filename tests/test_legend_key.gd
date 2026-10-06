extends "res://tests/lib/test_case.gd"
## The toggle key (182; the window bar since 219): a square push key that latches, with a lamp window in its face and
## its state, ON or OFF, in a label beside it, in a "Reduce motion" row in the Settings modal.

const KEY_PATH := "res://ui/legend_key.gd"
const SETTINGS_PATH := "user://test_reduce_motion_settings.cfg"  # with_reduce_motion's store
const TIP := "No bouncing, shaking or tilting; cards jump to their place and fade in. Saved."


## A new legend key added to main (so it resolves main's theme), laid out.
func new_key(main: Node) -> LegendKey:
	var key := LegendKey.new()
	main.add_child(key)
	await wait_frames()
	return key


## The "Reduce motion" label in key's row, or null.
func row_label(key: Control) -> Label:
	if key == null or key.get_parent() == null:
		return null
	for c in key.get_parent().get_children():
		if c is Label and (c as Label).text == "Reduce motion":
			return c
	return null


## The label that prints key's state, or null: the key's state_label, which its row shows right after it (219).
func state_label(key: Object) -> Label:
	if key == null or not "state_label" in key:
		return null
	return key.state_label


## Whether the saved settings file says Reduce motion is on.
func saved_calm() -> bool:
	var saved := SettingsStore.new(SETTINGS_PATH)
	saved.load()
	return saved.reduce_motion


# --- AC1: a square toggle with no legend of its own, its lamp lit while latched ---

func test_the_key_is_a_square_toggle_whose_lamp_lights_when_latched() -> void:
	var main := open_main()
	var key: LegendKey = await new_key(main)
	check(key is Button and key.toggle_mode, "a toggle Button")
	eq(key.text, "", "no legend on its face")
	check(key.size.x >= 32 and key.size.y >= 32, "at least 32 × 32: %s" % key.size)
	check(key.custom_minimum_size.x < 64, "no longer the 64 px legend key: %s" % key.custom_minimum_size)
	key.button_pressed = true
	await wait_frames()
	eq(key.lamp_color(), Palette.GAIN, "latched: the lamp is lit")
	eq(key.text, "", "latched: still no legend")
	key.button_pressed = false
	await wait_frames()
	eq(key.lamp_color(), Palette.FIELD, "up: the lamp is dark")
	key.set_pressed_no_signal(true)
	await wait_frames()
	eq(key.lamp_color(), Palette.GAIN, "set without a signal: lit")
	close_main(main)


# --- AC2: the theme's key boxes, with no room kept for a strip ---

func test_the_key_sits_on_the_themes_boxes_with_the_lamp_in_its_face() -> void:
	var main := open_main()
	var key: LegendKey = await new_key(main)
	var plain := Button.new()
	main.add_child(plain)
	var up := key.get_theme_stylebox("normal") as StyleBoxFlat
	var down := key.get_theme_stylebox("pressed") as StyleBoxFlat
	check(up != null and down != null, "flat normal and pressed boxes")
	if up != null and down != null:
		eq(up.shadow_size, 1, "up: on its shadow")
		eq(up.bg_color, (plain.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, "up: the theme's fill")
		eq(down.shadow_size, 0, "latched: sunk, no shadow")
		eq(down.expand_margin_top, -2.0, "latched: 2 px down")
		eq(up.content_margin_top, plain.get_theme_stylebox("normal").content_margin_top, "no room kept above for a strip")
	close_main(main)


# --- AC3: the key names its state ---

func test_the_keys_state_text_is_on_while_latched_and_off_while_up() -> void:
	var main := open_main()
	var key: LegendKey = await new_key(main)
	eq(key.state_text(), "OFF", "up: OFF")
	key.button_pressed = true
	eq(key.state_text(), "ON", "latched: ON")
	key.button_pressed = false
	eq(key.state_text(), "OFF", "up again: OFF")
	key.set_pressed_no_signal(true)
	eq(key.state_text(), "ON", "set without a signal: ON")
	close_main(main)


# --- AC4: a row in the Settings modal (206): name, key, state word ---

func test_the_settings_modal_shows_a_reduce_motion_row_with_a_key_and_its_state() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var key: Object = main.settings_modal.motion_toggle
		check(key != null and key.get_script() != null and key.get_script().resource_path == KEY_PATH, "a LegendKey: %s" % key)
		check(row_label(key) != null, "a 'Reduce motion' label in its row")
		var word := state_label(key)
		check(word != null, "a state label")
		if word != null:
			eq(word.get_parent(), key.get_parent(), "the state label in the key's row")
			eq(word.get_index(), (key as Node).get_index() + 1, "right after the key")
			eq(word.text, "ON", "shows the setting: on")
		eq(key.tooltip_text if key != null else "", TIP, "the old toggle's tooltip")
		close_main(main))


func test_every_settings_toggle_row_shows_its_state_label() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		for key: Object in [main.settings_modal.motion_toggle, main.settings_modal.day_toggle, main.settings_modal.sound_toggle]:
			var word := state_label(key)
			check(word != null and word.get_parent() == key.get_parent(), "%s: a state label in its row" % key)
			if word != null:
				eq(word.text, "ON" if (key as Button).button_pressed else "OFF", "%s: the label matches the key" % key)
		close_main(main))


func test_toggling_the_key_sets_saves_and_shows_it() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var key: Button = main.settings_modal.motion_toggle
		key.button_pressed = true
		await wait_frames()
		check(Settings.reduce_motion, "the key turns it on")
		check(saved_calm(), "saved on")
		eq(shown_state(key), "ON", "and shows it")
		key.button_pressed = false
		await wait_frames()
		check(not Settings.reduce_motion, "and off")
		check(not saved_calm(), "saved off")
		eq(shown_state(key), "OFF", "and shows it")
		key.set_pressed_no_signal(true)
		await wait_frames()
		eq(shown_state(key), "ON", "set without a signal: shows it")
		close_main(main))


# --- AC5: the row in the modal's column; the key stays put as the word changes ---

func test_the_row_spans_the_column_label_left_key_and_state_right() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var old := window.size
	window.size = Vector2i(1920, 1080)
	var main := open_main()
	main.start_game(1)
	await open_settings_modal(main)
	await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout  # the sheet's rise (207)
	var key: Button = main.settings_modal.motion_toggle
	var label := row_label(key)
	var word := state_label(key)
	check(label != null and word != null, "the row's name and state labels")
	if label != null and word != null:
		var row := key.get_parent() as Control
		var day_row := (main.settings_modal.day_toggle as Control).get_parent() as Control
		check(absf(row.size.x - day_row.size.x) <= 1.0, "the rows share the column's width: %s vs %s" % [row.size.x, day_row.size.x])
		check(label.get_global_rect().position.x < key.get_global_rect().position.x, "name left, key right")
		check(key.get_global_rect().end.x <= word.get_global_rect().position.x, "the state word right of the key")
		check(absf(word.get_global_rect().end.x - row.get_global_rect().end.x) <= 1.0, "the state word at the row's right")
		key.set_pressed_no_signal(false)
		await wait_frames(2)
		var off_x := key.get_global_rect().position.x
		var off_w := word.size.x
		key.set_pressed_no_signal(true)
		await wait_frames(2)
		eq(word.size.x, off_w, "the state label as wide for ON as for OFF")
		eq(key.get_global_rect().position.x, off_x, "the key doesn't move when toggled")
	close_main(main)
	window.size = old


# --- AC6: keys ---

func test_the_key_is_in_the_focus_loop_and_space_toggles_it() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.start_game(1)
		await open_settings_modal(main)
		var key: Control = main.settings_modal.motion_toggle
		key.grab_focus()
		press_key(main, KEY_SPACE)
		await wait_frames()
		check(Settings.reduce_motion, "Space toggles the setting")
		press_key(main, KEY_TAB)
		eq(main.get_viewport().gui_get_focus_owner(), main.settings_modal.day_toggle, "Tab from the key reaches Day mode (183)")
		press_key(main, KEY_TAB)
		eq(main.get_viewport().gui_get_focus_owner(), main.settings_modal.sound_toggle, "then Interface sounds (185)")
		close_main(main))
