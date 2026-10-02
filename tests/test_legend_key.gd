extends "res://tests/lib/test_case.gd"
## The legend key (182): Reduce motion as a push key that latches, with a lamp strip and its state printed on it,
## in a "Reduce motion" row on the settings screen and in the menu. The key is loaded by path (held as Object) so
## this file parses before ui/legend_key.gd exists.

const KEY_PATH := "res://ui/legend_key.gd"
const SETTINGS_PATH := "user://test_reduce_motion_settings.cfg"  # with_reduce_motion's store
const TIP := "No bouncing, shaking or tilting; cards jump to their place and fade in. Saved."


## A new legend key added to main (so it resolves main's theme), laid out; null if the script is missing.
func new_key(main: Node) -> Button:
	check(FileAccess.file_exists(KEY_PATH), "%s exists" % KEY_PATH)
	if not FileAccess.file_exists(KEY_PATH):
		return null
	var key: Button = load(KEY_PATH).new()
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


## Whether the saved settings file says Reduce motion is on.
func saved_calm() -> bool:
	var saved := SettingsStore.new(SETTINGS_PATH)
	saved.load()
	return saved.reduce_motion


# --- AC1: a toggle that prints its state and lights its lamp ---

func test_the_key_reads_on_with_a_lit_lamp_and_off_with_a_dark_one() -> void:
	var main := open_main()
	var key: Object = await new_key(main)
	if key != null:
		check(key is Button and key.toggle_mode, "a toggle Button")
		key.button_pressed = true
		await wait_frames()
		eq(key.text, "ON", "latched: ON")
		eq(key.lamp_color(), Palette.GAIN, "latched: the lamp is lit")
		key.button_pressed = false
		await wait_frames()
		eq(key.text, "OFF", "up: OFF")
		eq(key.lamp_color(), Palette.FIELD, "up: the lamp is dark")
		key.set_pressed_no_signal(true)
		await wait_frames()
		eq(key.text, "ON", "set without a signal: ON")
		eq(key.lamp_color(), Palette.GAIN, "set without a signal: lit")
	close_main(main)


# --- AC2: the theme's key boxes, with room for the lamp ---

func test_the_key_sits_on_the_themes_boxes_with_room_for_the_lamp() -> void:
	var main := open_main()
	var key: Button = await new_key(main)
	if key != null:
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
			check(up.content_margin_top >= plain.get_theme_stylebox("normal").content_margin_top + 6,
				"room above the legend for the 6 px lamp: %s" % up.content_margin_top)
		check(key.size.x >= 64 and key.size.y >= 44, "at least 64 × 44: %s" % key.size)
	close_main(main)


# --- AC3: a row in the Settings modal (206: it replaced the settings screen's and the menu's rows) ---

func test_the_settings_modal_shows_a_reduce_motion_row_with_a_legend_key() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var key: Object = main.settings_modal.motion_toggle
		check(key != null and key.get_script() != null and key.get_script().resource_path == KEY_PATH, "a LegendKey: %s" % key)
		check(row_label(key) != null, "a 'Reduce motion' label in its row")
		eq(key.text if key != null else "", "ON", "shows the setting: on")
		eq(key.tooltip_text if key != null else "", TIP, "the old toggle's tooltip")
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
		eq(key.text, "ON", "and shows it")
		key.button_pressed = false
		await wait_frames()
		check(not Settings.reduce_motion, "and off")
		check(not saved_calm(), "saved off")
		eq(key.text, "OFF", "and shows it")
		close_main(main))


# --- AC4: the row in the modal's column ---

func test_the_row_spans_the_column_label_left_key_right() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var old := window.size
	window.size = Vector2i(1920, 1080)
	var main := open_main()
	main.start_game(1)
	await open_settings_modal(main)
	await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout  # the sheet's rise (207)
	var key: Control = main.settings_modal.motion_toggle
	var label := row_label(key)
	check(label != null, "the row's label")
	if label != null:
		var row := key.get_parent() as Control
		var day_row := (main.settings_modal.day_toggle as Control).get_parent() as Control
		check(absf(row.size.x - day_row.size.x) <= 1.0, "the rows share the column's width: %s vs %s" % [row.size.x, day_row.size.x])
		check(label.get_global_rect().position.x < key.get_global_rect().position.x, "label left, key right")
		check(absf(key.get_global_rect().end.x - row.get_global_rect().end.x) <= 1.0, "the key at the row's right")
	close_main(main)
	window.size = old


# --- AC5: keys ---

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
