extends "res://tests/lib/test_case.gd"
## The sound rows (185) in the real main.tscn: the Interface sounds key and Master, Game and Interface sliders, in the
## Settings modal since 206 (they were on the settings screen and, the key, in the menu), showing the settings, in its
## focus loop.

const KEY_PATH := "res://ui/legend_key.gd"
const SETTINGS_PATH := "user://test_sound_rows_settings.cfg"
const BUS_ROWS := [["Master", &"Master"], ["Game", &"Game"], ["Interface", &"Interface"]]


## The label beside control in its row ("" if none).
func row_text(control: Control) -> String:
	if control == null or control.get_parent() == null:
		return ""
	for c in control.get_parent().get_children():
		if c is Label and c != control:
			return c.text
	return ""


func slider(main: Node, bus: StringName) -> HSlider:
	var sliders: Dictionary = main.settings_modal.get("sliders") if main.settings_modal.get("sliders") != null else {}
	return sliders.get(bus)


func figure(main: Node, bus: StringName) -> Label:
	var figures: Dictionary = main.settings_modal.get("figures") if main.settings_modal.get("figures") != null else {}
	return figures.get(bus)


func open_settings(main: Node) -> void:
	main.start_screen.settings_button.pressed.emit()
	await wait_frames()


# --- AC1: the rows in the Settings modal ---

func test_the_settings_modal_shows_the_sound_rows_under_day_mode() -> void:
	await with_temp_settings(func():
		var main := open_main()
		await open_settings(main)
		var key: Control = main.settings_modal.get("sound_toggle")
		check(key != null and key.get_script() != null and key.get_script().resource_path == KEY_PATH,
			"an Interface sounds LegendKey")
		if key == null:
			close_main(main)
			return
		eq(row_text(key), "Interface sounds", "its label")
		var day_row: Control = main.settings_modal.day_toggle.get_parent()
		eq(key.get_parent().get_parent(), day_row.get_parent(), "in the same column as Day mode")
		eq(key.get_parent().get_index(), day_row.get_index() + 1, "right under Day mode")
		for i in BUS_ROWS.size():
			var s := slider(main, BUS_ROWS[i][1])
			check(s != null, "a %s slider" % BUS_ROWS[i][0])
			if s == null:
				continue
			eq(row_text(s), BUS_ROWS[i][0], "its label")
			eq(s.get_parent().get_index(), key.get_parent().get_index() + 1 + i, "%s in reading order" % BUS_ROWS[i][0])
			eq([s.min_value, s.max_value, s.step], [0.0, 100.0, 10.0], "%s runs 0–100 in steps of 10" % BUS_ROWS[i][0])
			var f := figure(main, BUS_ROWS[i][1])
			check(f != null and f.get_parent() == s.get_parent(), "%s's figure in its row" % BUS_ROWS[i][0])
		close_main(main), SETTINGS_PATH)


# --- AC2: the current settings ---

func test_the_settings_modal_shows_the_current_sound_settings() -> void:
	await with_temp_settings(func():
		Settings.store.set("master", 80)
		Settings.store.set("game", 50)
		Settings.store.set("interface", 70)
		Settings.store.set("interface_sounds", false)
		Settings.changed.emit()
		var main := open_main()
		await open_settings(main)
		var values := []
		var figures := []
		for row in BUS_ROWS:
			var s := slider(main, row[1])
			var f := figure(main, row[1])
			values.append(s.value if s != null else -1.0)
			figures.append(f.text if f != null else "")
		eq(values, [80.0, 50.0, 70.0], "the sliders")
		eq(figures, ["80%", "50%", "70%"], "the figures")
		var key: Button = main.settings_modal.get("sound_toggle")
		eq(key.text if key != null else "", "OFF", "the Interface sounds key")
		close_main(main), SETTINGS_PATH)


# --- AC3: moving a slider, toggling the key ---

func test_pressing_right_on_a_slider_sets_its_volume() -> void:
	await with_temp_settings(func():
		Settings.set_volume(Settings.GAME, 50)
		var main := open_main()
		await open_settings(main)
		var s := slider(main, Settings.GAME)
		check(s != null, "the Game slider")
		if s != null:
			s.grab_focus()
			press_key(main, KEY_RIGHT)
			await wait_frames()
			eq(s.value, 60.0, "the slider moved a step")
			eq(Settings.volume(Settings.GAME), 60, "Settings.set_volume(GAME, 60)")
			var saved := SettingsStore.new(SETTINGS_PATH)
			saved.load()
			eq(saved.get("game"), 60, "saved")
			eq(figure(main, Settings.GAME).text, "60%", "the figure follows at once")
		close_main(main), SETTINGS_PATH)


func test_the_interface_sounds_key_sets_the_setting() -> void:
	await with_temp_settings(func():
		var main := open_main()
		await open_settings(main)
		var key: Button = main.settings_modal.get("sound_toggle")
		check(key != null, "the key")
		if key != null:
			eq(key.text, "ON", "on by default")
			key.button_pressed = false
			await wait_frames()
			eq(Settings.interface_sounds, false, "turned off")
			key.button_pressed = true
			await wait_frames()
			eq(Settings.interface_sounds, true, "turned on")
		close_main(main), SETTINGS_PATH)


# --- AC5: focus and tooltips ---

func test_the_sound_rows_are_in_the_focus_loop_in_reading_order() -> void:
	await with_temp_settings(func():
		var main := open_main()
		await open_settings(main)
		var order: Array = [main.settings_modal.day_toggle, main.settings_modal.get("sound_toggle")]
		for row in BUS_ROWS:
			order.append(slider(main, row[1]))
		order.append(main.settings_modal.close_button)  # the modal's Close follows (206)
		check(not order.has(null), "every control: %s" % [order])
		if not order.has(null):
			(order[0] as Control).grab_focus()
			for i in range(1, order.size()):
				press_key(main, KEY_TAB)
				eq(main.get_viewport().gui_get_focus_owner(), order[i], "settings: Tab to step %d" % i)
		close_main(main), SETTINGS_PATH)


func test_each_slider_says_what_it_sets() -> void:
	await with_temp_settings(func():
		var main := open_main()
		var tips := []
		for row in BUS_ROWS:
			var s := slider(main, row[1])
			tips.append(s.tooltip_text if s != null else "")
		eq(tips, ["Everything.", "Events: techs, cities, eras.", "Clicks, panels and confirmations."], "the tooltips")
		close_main(main), SETTINGS_PATH)
