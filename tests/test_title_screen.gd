extends "res://tests/lib/test_case.gd"
## The title screen as a ledger (backlog 213) in the real main scene at 1920×1080: two halves (the ledger left, an
## empty Art control right behind a 1 px rule), a caps kicker, the title on two lines, a caps subtitle and three
## BigButtons flush left in one width; the BigButton look (lamp edge, caps label, caption, ›, plinth) from the theme.
## Hooks: main.start_screen (art, kicker, title, subtitle, new_game_button, settings_button, exit_button); a
## BigButton's label, caption, chevron and lamp.

const TOLERANCE := 1.0
const CAPTIONS := {"New game": "Choose a civilization and a seed", "Settings": "Motion, day mode, sound",
	"Exit game": "Close the game"}

var _old_window_size := Vector2i.ZERO


func open_title() -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)
	var main := open_main()
	await wait_screen_transition()
	return main


func close_title(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


## Whether b runs BigButton (read by name, so this file parses before the class exists).
func is_big(b: Object) -> bool:
	return b != null and b.get_script() != null and (b.get_script() as Script).get_global_name() == &"BigButton"


func keys(main: Node) -> Array[Button]:
	var s: Object = main.start_screen
	return [s.new_game_button, s.settings_button, s.exit_button]


# --- AC1: two halves ---

func test_the_title_screen_is_a_ledger_left_and_an_empty_art_half_right() -> void:
	var main: Node = await open_title()
	var s: Object = main.start_screen
	var width: float = main.get_viewport_rect().size.x
	var art := s.art as Control
	check(art != null and art.is_visible_in_tree(), "an Art control")
	if art == null:
		close_title(main)
		return
	eq(art.name, &"Art", "named Art")
	eq(art.get_children().filter(func(c): return c.name != "Rule").map(func(c): return c.get_script().get_global_name() if c.get_script() else ""),
		[&"SunriseArt"], "only its art (214) and the rule")
	var r := art.get_global_rect()
	check(absf(r.position.x - width / 2) <= TOLERANCE and absf(r.end.x - width) <= TOLERANCE, "the right half: %s" % r)
	var rule := art.find_child("Rule", true, false) as ColorRect
	check(rule != null, "a rule on its left edge")
	if rule != null:
		eq(rule.color, Palette.CONTROL_DISABLED_BORDER, "the rule's colour")
		eq(rule.size.x, 1.0, "1 px")
		check(absf(rule.get_global_rect().position.x - r.position.x) <= TOLERANCE, "at the art's left edge")
	eq(s.kicker.text, "Est. Turn 001", "the kicker")
	check(s.kicker.uppercase, "in caps")
	var title := s.title as Label
	eq(title.text.replace("\n", " "), ProjectSettings.get_setting("application/config/name"), "the game's name")
	eq(title.theme_type_variation, &"Display", "Display")
	eq(title.get_line_count(), 2, "on two lines")
	eq(s.subtitle.text, "Civilizations in cards", "the subtitle")
	check(s.subtitle.uppercase, "in caps")
	var left: float = title.get_global_rect().position.x
	for c in [s.kicker, s.subtitle] + keys(main):
		check(absf((c as Control).get_global_rect().position.x - left) <= TOLERANCE, "%s flush left with the title" % c.name)
		check((c as Control).get_global_rect().end.x <= r.position.x, "%s in the left half" % c.name)
	var widths := keys(main).map(func(b): return b.size.x)
	check(widths.all(func(w): return absf(w - widths[0]) <= TOLERANCE), "one width: %s" % [widths])
	close_title(main)


# --- AC2: the keys ---

func test_each_key_is_a_big_button_with_caps_label_caption_chevron_and_lamp() -> void:
	var main: Node = await open_title()
	for b in keys(main):
		var name: String = b.text
		check(is_big(b), "%s is a BigButton" % name)
		if not is_big(b):
			continue
		var big: Object = b
		eq(big.label.text, name, "%s: its label" % name)
		check(big.label.uppercase, "%s: in caps" % name)
		eq(big.label.theme_type_variation, &"BigLabel", "%s: BigLabel" % name)
		eq(big.caption.text, CAPTIONS[name], "%s: its caption" % name)
		eq(big.caption.theme_type_variation, &"Caption", "%s: Caption" % name)
		eq(big.chevron.text, "›", "%s: a › at its right" % name)
		check((big.chevron as Control).get_global_rect().position.x > (big.caption as Control).get_global_rect().end.x, "%s: › right of the text" % name)
		eq(big.lamp.size.x, float(Tokens.SPACE_2), "%s: a lamp edge SPACE_2 wide" % name)
		check(absf((big.lamp as Control).get_global_rect().position.x - b.get_global_rect().position.x) <= 4.0, "%s: along its left" % name)
		eq(big.lamp.color, Palette.ACCENT if name == "New game" else Palette.FIELD, "%s: its lamp" % name)
	var t := GameTheme.build()
	eq(t.get_type_variation_base("BigLabel"), &"Label", "BigLabel varies Label")
	eq(t.get_font_size("font_size", "BigLabel"), Tokens.TYPE_TITLE, "BigLabel at title size")
	var font := t.get_font("font", "BigLabel")
	while font is FontVariation:
		font = (font as FontVariation).base_font
	eq(font, GameTheme.LABEL_SEMIBOLD, "BigLabel in the semibold label face")
	close_title(main)


# --- AC3: the box and its press ---

func test_the_big_button_is_an_index_card_on_a_plinth_that_sinks_when_pressed() -> void:
	var t := GameTheme.build()
	for variation in ["BigButton", "BigButtonPrimary"]:
		eq(t.get_type_variation_base(variation), &"Button", "%s varies Button" % variation)
		var normal := t.get_stylebox("normal", variation) as StyleBoxFlat
		eq(normal.bg_color, Palette.RAISED, "%s: RAISED" % variation)
		eq(normal.border_color, Palette.TEXT, "%s: TEXT border" % variation)
		eq(normal.border_width_left, 3, "%s: 3 px" % variation)
		eq(normal.corner_radius_top_left, Tokens.RADIUS_0, "%s: square" % variation)
		eq(normal.shadow_color, Palette.SHADOW, "%s: SHADOW plinth" % variation)
		eq(normal.shadow_offset, Vector2(4, 4), "%s: offset 4,4" % variation)
		for state in ["hover", "focus"]:
			var box := t.get_stylebox(state, variation) as StyleBoxFlat
			check(box != null and box.bg_color == Palette.CONTROL, "%s: CONTROL on %s" % [variation, state])
		var pressed := t.get_stylebox("pressed", variation) as StyleBoxFlat
		eq(pressed.shadow_size, 0, "%s: pressed loses the plinth" % variation)
		eq([pressed.expand_margin_left, pressed.expand_margin_top], [-4.0, -4.0], "%s: pressed moves +4,+4" % variation)


func test_a_big_buttons_press_plays_the_key_sounds() -> void:
	var main: Node = await open_title()
	var b: Button = main.start_screen.settings_button
	var from: int = main.sfx.played().size()
	b.button_down.emit()
	b.button_up.emit()
	var tokens: Array = main.sfx.played().slice(from).map(func(r): return r.token)
	eq(tokens, [Sfx.BUTTON_PRESS, Sfx.BUTTON_RELEASE], "press down, release up (187)")
	close_title(main)


# --- AC5: Day mode ---

func test_day_mode_switches_the_keys_at_once() -> void:
	await with_temp_settings(func():
		var main: Node = await open_title()
		Settings.call("set_day_mode", true)
		await wait_frames()
		var new_game: Button = main.start_screen.new_game_button
		var box := new_game.get_theme_stylebox("normal") as StyleBoxFlat
		eq(box.bg_color, Palette.DAY["RAISED"], "the fill in Paper")
		eq(box.border_color, Palette.DAY["TEXT"], "the border in Paper")
		if is_big(new_game):
			var big: Object = new_game
			var exit: Object = main.start_screen.exit_button
			eq(big.lamp.color, Palette.DAY["ACCENT"], "the primary lamp in Paper")
			eq(exit.lamp.color, Palette.DAY["FIELD"], "a plain lamp in Paper")
			eq(big.caption.get_theme_color("font_color"), Palette.DAY["TEXT_DIM"], "the caption in Paper")
		else:
			check(false, "New game is a BigButton")
		check(main.start_screen.is_open(), "the screen stays open")
		close_title(main))
