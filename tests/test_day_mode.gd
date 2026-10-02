extends "res://tests/lib/test_case.gd"
## Day mode (183): the Paper palette, switched at once on every open screen, from a Day mode legend key under Reduce
## motion. Palette colours are read by name (Script.get) so this file parses while they are still constants; the
## switch goes through Settings.set_day_mode on a temp settings file, and every test ends back on the player's palette.

const PALETTE_PATH := "res://ui/palette.gd"
const KEY_PATH := "res://ui/legend_key.gd"
## AC2's Day values.
const DAY := {"BACKGROUND": "efe8da", "RAISED": "f8f4ec", "CONTROL": "dcd3c2", "TEXT": "22211f", "ACCENT": "a8401b"}
## 178's Night values for the same names.
const NIGHT := {"BACKGROUND": "1f1e1c", "RAISED": "2a2825", "CONTROL": "3a3733", "TEXT": "ede6d6", "ACCENT": "e0703f"}


## Palette's colour called name, as it reads now.
func palette(name: String) -> Color:
	return load(PALETTE_PATH).get(name)


func set_day(on: bool) -> void:
	Settings.call("set_day_mode", on)


## WCAG relative luminance of c.
func luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


## WCAG contrast ratio of a on b.
func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


# --- AC2: two values per colour ---

func test_the_palette_reads_day_values_in_day_mode_and_night_values_otherwise() -> void:
	await with_temp_settings(func():
		set_day(true)
		for name: String in DAY:
			eq(palette(name).to_html(false), DAY[name], "day %s" % name)
		set_day(false)
		for name: String in NIGHT:
			eq(palette(name).to_html(false), NIGHT[name], "night %s" % name))


func test_both_modes_keep_the_guides_contrast() -> void:
	await with_temp_settings(func():
		for day in [false, true]:
			set_day(day)
			var mode := "day" if day else "night"
			for text in ["TEXT", "TEXT_DIM"]:
				for ground in ["RAISED", "BACKGROUND"]:
					var r := contrast(palette(text), palette(ground))
					check(r >= 4.5, "%s: %s on %s is %.2f:1, needs 4.5" % [mode, text, ground, r])
			var on_accent := contrast(palette("TEXT_ON_ACCENT"), palette("ACCENT"))
			check(on_accent >= 4.5, "%s: TEXT_ON_ACCENT on ACCENT is %.2f:1, needs 4.5" % [mode, on_accent])
			for hue in ["CONTROL_BORDER", "GAIN", "WEALTH", "INSIGHT", "UNREST", "POP"]:
				var r := contrast(palette(hue), palette("RAISED"))
				check(r >= 3.0, "%s: %s on RAISED is %.2f:1, needs 3" % [mode, hue, r])
		set_day(false))


# --- AC3: switched mid-game ---

## Opens main on a seed-1 game played to turn 3, laid out.
func mid_game() -> Node:
	var main := open_main()
	main.start_game(1)
	for i in 2:
		Game.engine.end_turn()
		if not main.event_modal().is_empty():
			main.event_modal_ok_button().pressed.emit()
	await wait_frames()
	return main


## What switching mustn't change: the turn, the hand, the resources and the log's text.
func game_now(main: Node) -> Array:
	var e := Game.engine
	return [e.turn, card_ids(e.zone("hand")), e.resources.duplicate(), main.log_drawer.text()]


## Checks main's look reads palette's current values: the theme's button, the background, every card view's panel and
## band, the top bar's glyphs and figures and the log.
func check_look(main: Node, mode: String) -> void:
	var button := Button.new()
	main.add_child(button)
	eq((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, palette("CONTROL"), "%s: a Button's fill" % mode)
	button.free()
	eq(main.background_color(), palette("BACKGROUND"), "%s: the board's background" % mode)
	for uid in main.views:
		var view: CardView = main.views[uid]
		if view.board_kind == CardView.BOARD_FRONTIER:
			continue
		var box := view.get_theme_stylebox("panel") as StyleBoxFlat
		check(box.bg_color in [palette("RAISED"), palette("DIM_BG")], "%s: %s's panel %s" % [mode, view.card_id, box.bg_color.to_html()])
		var band := view.find_child("Band", true, false) as ColorRect
		if band != null:
			var type: String = Game.engine.card_db[view.card_id].type
			check(band.color in [palette(type.to_upper()), palette("DIM_BORDER")], "%s: %s's band" % [mode, view.card_id])
	for key in [GameEngine.FOOD, GameEngine.WEALTH]:
		var counter: Control = main.counter(key)
		var glyph := counter.find_children("*", "TextureRect", true, false)[0] as TextureRect
		eq(glyph.self_modulate, Icons.hue(key), "%s: the %s glyph" % [mode, key])
		eq(figure_color(counter), palette("TEXT"), "%s: the %s figure" % [mode, key])
	var log_text := main.log_drawer.find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	eq(log_text.get_theme_color("default_color"), palette("LOG_TEXT"), "%s: the log's text" % mode)


## The colour counter's figure is drawn in (an odometer's since 181, else the label's).
func figure_color(counter: Control) -> Color:
	return counter.figure().color if counter.has_method("figure") else counter.get_theme_color("font_color")


func test_day_mode_switches_a_game_in_progress_and_back() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		eq(Game.engine.turn, 3, "turn 3")
		var before := game_now(main)
		set_day(true)
		await wait_frames()
		eq(palette("CONTROL").to_html(false), "dcd3c2", "precondition: day values")
		check_look(main, "day")
		eq(game_now(main), before, "the game is untouched")
		set_day(false)
		await wait_frames()
		check_look(main, "night")
		eq(game_now(main), before, "the game is still untouched")
		close_main(main))


# --- AC4: open screens and modals take it too ---

func test_open_modals_and_screens_switch_and_stay_open() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		main.tech_tree.open()
		await wait_frames()
		var depth: int = main.modals.depth()
		var panel := main.tech_tree.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
		set_day(true)
		await wait_frames()
		eq(main.modals.depth(), depth, "the tech tree stays open")
		eq((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, palette("RAISED"), "its panel is paper")
		main.open_menu()
		await wait_frames()
		set_day(false)
		await wait_frames()
		check(main.menu_buttons()[0].is_visible_in_tree(), "the menu stays open")
		var menu_button: Button = main.menu_buttons()[0]
		eq((menu_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, palette("CONTROL"), "its buttons are night again")
		close_main(main))


func test_the_settings_screen_switches_and_stays_open() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		set_day(true)
		await wait_frames()
		check(main.settings_screen.is_open(), "still open")
		var back: Button = main.settings_screen.back_button
		eq(back.get_theme_color("font_color"), palette("TEXT_DIM"), "its link back reads the day ink")
		close_main(main))


# --- AC5: the Day mode row ---

## The label beside key in its row ("" if none).
func row_text(key: Control) -> String:
	if key == null or key.get_parent() == null:
		return ""
	for c in key.get_parent().get_children():
		if c is Label:
			return c.text
	return ""


func test_both_screens_show_a_day_mode_key_under_reduce_motion() -> void:
	await with_temp_settings(func():
		set_day(true)
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var pairs := [[main.settings_screen.day_toggle, main.settings_screen.motion_toggle],
			[main.menu_day_toggle(), main.menu_motion_toggle()]]
		for pair in pairs:
			var key: Control = pair[0]
			check(key != null and key.get_script() != null and key.get_script().resource_path == KEY_PATH, "a LegendKey")
			eq(row_text(key), "Day mode", "labelled Day mode")
			eq(key.text, "ON", "shows the setting")
			var motion_row: Control = pair[1].get_parent()
			check(key.get_parent().get_index() == motion_row.get_index() + 1 and key.get_parent().get_parent() == motion_row.get_parent(),
				"right under Reduce motion")
		close_main(main))


func test_toggling_either_day_key_sets_it_and_shows_on_the_other() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var screen_key: Button = main.settings_screen.day_toggle
		var menu_key: Button = main.menu_day_toggle()
		screen_key.button_pressed = true
		await wait_frames()
		check(Settings.store.get("day_mode"), "the settings screen's key turns day mode on")
		eq(menu_key.text, "ON", "the menu's key follows")
		menu_key.button_pressed = false
		await wait_frames()
		check(not Settings.store.get("day_mode"), "the menu's key turns it off")
		eq(screen_key.text, "OFF", "the settings screen's key follows")
		close_main(main))


func test_the_day_keys_are_in_the_focus_loops() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_game(1)
		main.open_menu()
		await wait_frames()
		(main.menu_motion_toggle() as Control).grab_focus()
		press_key(main, KEY_TAB)
		eq(main.get_viewport().gui_get_focus_owner(), main.menu_day_toggle(), "menu: Tab from Reduce motion to Day mode")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		main.show_title_screen()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		(main.settings_screen.motion_toggle as Control).grab_focus()
		press_key(main, KEY_TAB)
		eq(main.get_viewport().gui_get_focus_owner(), main.settings_screen.day_toggle,
			"settings: Tab from Reduce motion to Day mode")
		close_main(main))


# --- Bug 195: Day mode saved before any game ---

func test_bug_195_opening_main_in_day_mode_before_a_game_raises_no_error() -> void:
	await with_temp_settings(func():
		set_day(true)
		var real := Game.engine
		Game.engine = board_engine()  # no game started: its zones don't exist yet
		var main := open_main()
		await wait_frames()
		check(main.start_screen.is_open(), "the title screen is open")
		check(not main.board_shown(), "the board isn't shown")
		var button := Button.new()
		main.add_child(button)
		eq((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.to_html(false), Palette.DAY["CONTROL"].to_html(false),
			"the theme was built in Paper")
		button.free()
		close_main(main)
		Game.engine = real)


func test_bug_195_a_game_started_in_day_mode_shows_the_board_in_paper() -> void:
	await with_temp_settings(func():
		set_day(true)
		var real := Game.engine
		Game.engine = board_engine()
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		eq(main.background_color().to_html(false), Palette.DAY["BACKGROUND"].to_html(false), "the board's background")
		var view: CardView = main.views[first_in_hand(Game.engine)]
		var fill := (view.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.to_html(false)
		check(fill in [Palette.DAY["RAISED"].to_html(false), Palette.DAY["DIM_BG"].to_html(false)], "a hand card's panel is paper: %s" % fill)
		close_main(main)
		Game.engine = real)
