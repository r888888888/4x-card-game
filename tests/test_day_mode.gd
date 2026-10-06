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
		main.identity_modal.open()  # a modal (the tech tree is a screen since 208)
		await wait_frames()
		var depth: int = main.modals.depth()
		var panel: PanelContainer = main.identity_modal.panel
		set_day(true)
		await wait_frames()
		eq(main.modals.depth(), depth, "the civilization modal stays open")
		eq((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, palette("RAISED"), "its panel is paper")
		main.open_menu()
		await wait_frames()
		set_day(false)
		await wait_frames()
		check(main.menu_buttons()[0].is_visible_in_tree(), "the menu stays open")
		var menu_button: Button = main.menu_buttons()[0]
		eq((menu_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, palette("CONTROL"), "its buttons are night again")
		close_main(main))


func test_the_settings_modal_switches_and_stays_open() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()  # the Settings modal since 206
		await wait_frames()
		set_day(true)
		await wait_frames()
		check(main.settings_modal.is_open(), "still open")
		eq((main.settings_modal.panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, palette("RAISED"),
			"its sheet reads the day paper")
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


func test_the_settings_modal_shows_a_day_mode_key_under_reduce_motion() -> void:
	await with_temp_settings(func():
		set_day(true)
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		var key: Control = main.settings_modal.day_toggle  # one set of keys since 206: the Settings modal's
		check(key != null and key.get_script() != null and key.get_script().resource_path == KEY_PATH, "a LegendKey")
		eq(row_text(key), "Day mode", "labelled Day mode")
		eq(shown_state(key), "ON", "shows the setting (219: beside the key)")
		var motion_row: Control = main.settings_modal.motion_toggle.get_parent()
		check(key.get_parent().get_index() == motion_row.get_index() + 1 and key.get_parent().get_parent() == motion_row.get_parent(),
			"right under Reduce motion")
		close_main(main))


func test_the_day_key_is_in_the_focus_loop() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_game(1)
		main.open_menu()
		await wait_frames()
		for b in main.menu_buttons():
			if b.text == "Settings":
				b.pressed.emit()
		await wait_frames()
		(main.settings_modal.motion_toggle as Control).grab_focus()
		press_key(main, KEY_TAB)
		eq(main.get_viewport().gui_get_focus_owner(), main.settings_modal.day_toggle, "Tab from Reduce motion to Day mode")
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


# --- 197: card type lines and keyword lines read on paper ---

## The colour a face line is drawn in: a Label's font colour, a RichTextLabel's default colour.
func line_color(line: Control) -> Color:
	return line.get_theme_color("font_color") if line is Label else line.get_theme_color("default_color")


## view's type line and keyword lines (TypeRow's text, PrintedInfo, Keywords), each as [what, Control].
func secondary_lines(view: CardView) -> Array:
	var found := []
	var type_row := view.find_child("TypeRow", true, false)
	if type_row != null:
		for line in type_row.get_children():
			found.append(["%s's type line" % view.card_id, line])
	for line_name in ["PrintedInfo", "Keywords"]:
		var line := view.find_child(line_name, true, false) as Control
		if line != null and line.visible:
			found.append(["%s's %s" % [view.card_id, line_name], line])
	return found


## Checks every hand card's type line, a frontier territory's keyword line (the home territory has none since 199) and every supply
## card's type line contrast at least 4.5:1 with RAISED in the current mode (seed 5, Sumer).
func check_secondary_lines(main: Node, mode: String) -> void:
	var e := Game.engine
	var views: Array[CardView] = []
	for c in e.zone("hand").cards:
		views.append(main.views[c.uid])
	views.append(main.views[home_uid(e)])
	var frontier: CardView = main.views[e.zone("frontier").cards[0].uid]
	views.append(frontier)
	check(frontier.find_child("Keywords", true, false) != null, "%s: the frontier card's keyword line is its Keywords" % mode)
	main.open_supply()
	await wait_frames()
	views.append_array(main.supply.views())
	var lines := []
	for view in views:
		lines.append_array(secondary_lines(view))
	# every card but the settled home territory, which shows no keywords since 199
	check(lines.size() >= views.size() - 1, "%s: precondition: a type or keyword line on every card (%d lines)" % [mode, lines.size()])
	for pair in lines:
		var r := contrast(line_color(pair[1]), palette("RAISED"))
		check(r >= 4.5, "%s: %s is %.2f:1 on RAISED, needs 4.5" % [mode, pair[0], r])
	main.supply.close()
	await wait_frames()


## A seed-5 Sumer game with the territory deck's first card on the frontier, laid out.
func sumer_with_frontier() -> Node:
	var main := open_main()
	main.start_game(5, "sumer")
	var e := Game.engine
	var deck: Zone = e.zone("territory_deck")
	var card: CardInstance = deck.cards[0]
	deck.remove(card)
	e.zone("frontier").add(card)
	e.changed.emit()
	await wait_frames()
	return main


func test_bug_197_type_and_keyword_lines_read_on_paper_in_day_mode() -> void:
	await with_temp_settings(func():
		set_day(true)
		var main: Node = await sumer_with_frontier()
		await check_secondary_lines(main, "day")
		close_main(main))


func test_bug_197_type_and_keyword_lines_read_on_night_sheets() -> void:
	await with_temp_settings(func():
		var main: Node = await sumer_with_frontier()
		await check_secondary_lines(main, "night")
		close_main(main))


func test_bug_197_type_and_keyword_lines_switch_with_day_mode_mid_game() -> void:
	await with_temp_settings(func():
		var main: Node = await sumer_with_frontier()
		set_day(true)
		await wait_frames()
		await check_secondary_lines(main, "switched to day")
		set_day(false)
		await wait_frames()
		await check_secondary_lines(main, "switched back to night")
		close_main(main))


# --- 323: rich text on paper ---

## main's RichBody texts that set no colour of their own (the log sets LOG_TEXT).
func rich_bodies(main: Node) -> Array:
	return main.find_children("*", "RichTextLabel", true, false).filter(func(label: RichTextLabel):
		return label.theme_type_variation == &"RichBody" and not label.has_theme_color_override("default_color"))


func test_bug_323_rich_body_text_follows_day_mode() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		check(rich_bodies(main).size() >= 4, "the event, details, revolt and abandon modals' texts are found")
		for day in [true, false]:
			set_day(day)
			await wait_frames()
			for label: RichTextLabel in rich_bodies(main):
				eq(label.get_theme_color("default_color"), palette("TEXT"),
					"%s: %s reads TEXT" % ["day" if day else "night", label.get_path()])
		close_main(main))
