extends "res://tests/lib/test_case.gd"
## The UI theme (backlog 106; 178: the Night shift look). AC1 records how things look, resolved through the real main scene's theme, and
## must pass unchanged before and after the cleanup. The rest check the palette (ui/palette.gd) and the theme built
## in code (ui/game_theme.gd, GameTheme.build()), loaded by path (held as Object) so this file parses before they
## exist. 393: every section file in ui/theme/ is in GameTheme.SECTIONS, and each type variation has one section.

const Looks := preload("res://tests/lib/surface_looks.gd")
const PALETTE_PATH := "res://ui/palette.gd"
const GAME_THEME_PATH := "res://ui/game_theme.gd"


## Adds c to main (so it resolves main's theme) and returns it.
func in_main(main: Node, c: Control) -> Control:
	main.add_child(c)
	return c


func button(main: Node, variation := "") -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	return in_main(main, b)


func stylebox(c: Control, name: String) -> StyleBoxFlat:
	return c.get_theme_stylebox(name) as StyleBoxFlat


## Checks a flat stylebox's colours, border width, corner radius and left/top content margins.
func check_box(box: StyleBoxFlat, bg: Color, border: Color, width: int, radius: int, margins: Vector2, what: String) -> void:
	check(box != null, "%s: a flat stylebox" % what)
	if box == null:
		return
	eq(box.bg_color.to_html(), bg.to_html(), "%s background" % what)
	eq(box.border_color.to_html(), border.to_html(), "%s border" % what)
	eq(box.border_width_left, width, "%s border width" % what)
	eq(box.corner_radius_top_left, radius, "%s corner radius" % what)
	eq(Vector2(box.content_margin_left, box.content_margin_top), margins, "%s content margins" % what)


## The log's panel: the PanelContainer holding the log's RichTextLabel (in the log drawer since 115), or null.
func log_panel(main: Node) -> PanelContainer:
	var drawer: Node = main.get("log_drawer")
	if drawer == null:
		return null
	for c in drawer.find_children("*", "RichTextLabel", true, false):
		var node: Node = c.get_parent()
		while node != null and node != drawer.get_parent():
			if node is PanelContainer:
				return node
			node = node.get_parent()
	return null


# --- 106 AC1, rewritten by 178: how things look (a guard; 178 set these values on purpose) ---

## 178 AC1: the style guide's Night shift values, by Palette name.
const NIGHT_SHIFT := {
	"BACKGROUND": "1f1e1c", "RAISED": "2a2825", "TILE": "2a2825", "FIELD": "171614", "PANEL": "171614",
	"CONTROL": "3a3733", "CONTROL_BORDER": "857d70", "CONTROL_DISABLED": "171614", "CONTROL_DISABLED_BORDER": "4a463f",
	"TEXT": "ede6d6", "TEXT_DIM": "b9b1a1", "TEXT_DISABLED": "8e877a", "ACCENT": "e0703f", "TEXT_ON_ACCENT": "1f1e1c",
	"GAIN": "93b585", "COST": "e07a63", "WARN": "e07a63", "FOCUS": "6cc3bc", "WEALTH": "d9a441", "INSIGHT": "86a9cc",
	"UNREST": "e07a63", "POP": "5fb0a9", "SHADOW": "0d0c0b", "EDGE": "ede6d6",
	"ACTION": "86a9cc", "BUILDING": "a9b26c", "CITY": "d9a441", "TERRITORY": "93b585", "TECH": "5fb0a9", "EVENT": "e07a63",
}


func test_the_palette_holds_the_night_shift_values() -> void:
	var palette: Script = load(PALETTE_PATH)  # by name: a constant or (183) a static var
	for name: String in NIGHT_SHIFT:
		var value: Variant = palette.get(name)
		check(value is Color, "Palette.%s is a colour" % name)
		if value is Color:
			eq((value as Color).to_html(), Color(NIGHT_SHIFT[name]).to_html(), "Palette.%s" % name)


func test_labels_look_as_before() -> void:
	var main := open_main()
	var heading: Label = in_main(main, UIKit.heading("h"))
	eq(heading.get_theme_font_size("font_size"), 15, "heading size (194: type.heading)")
	eq(heading.get_theme_color("font_color").to_html(), Palette.TEXT_DIM.to_html(), "heading colour")
	var title: Label = in_main(main, UIKit.title("t"))
	eq(title.get_theme_font_size("font_size"), 28, "title size (194: type.title)")
	eq(title.get_theme_color("font_color").to_html(), Palette.TEXT.to_html(), "title colour: ink, not white")
	var stat := UIKit.stat(main, &"POP")
	eq(stat.get_theme_font_size("font_size"), 26, "stat size")
	eq(stat.get_theme_color("font_color").to_html(), Palette.POP.to_html(), "stat colour: its own")
	close_main(main)


func test_panels_are_cut_square() -> void:
	var main := open_main()
	var overlay := UIKit.overlay(main)
	var panel: PanelContainer = overlay.get_meta("panel")
	var surface := panel.get_theme_stylebox("panel")
	check(Looks.texture_of(surface) != null, "overlay panel: on paper (341)")
	var frame := Looks.frame_of(surface)
	check(frame != null, "overlay panel: framed")
	if frame != null:
		eq(frame.border_color.to_html(), Palette.EDGE.to_html(), "overlay panel border")
		eq(frame.border_width_left, 2, "overlay panel border width")
		eq(frame.corner_radius_top_left, 0, "overlay panel corner radius")
	eq(Vector2(surface.content_margin_left, surface.content_margin_top), Vector2(24, 24), "overlay panel content margins")
	main.start_game(1)
	var log := log_panel(main)
	check(log != null, "the log's panel")
	if log != null:
		check_box(stylebox(log, "panel"), Palette.PANEL, Palette.FAINT_EDGE, 1, 0, Vector2(12, 12), "log panel")
	eq(UIKit.panel_style(Palette.RAISED, Palette.EDGE, 8).corner_radius_bottom_right, 0, "UIKit.panel_style: radius 0")
	close_main(main)


## Checks box stands on its hard shadow (178 AC3): SHADOW, offset (2, 2), size 1, no anti-aliasing.
func check_plinth(box: StyleBoxFlat, what: String) -> void:
	if box == null:
		return
	eq(box.shadow_color.to_html(), Palette.SHADOW.to_html(), "%s shadow colour" % what)
	eq(box.shadow_offset, Vector2(2, 2), "%s shadow offset" % what)
	eq(box.shadow_size, 1, "%s shadow size" % what)
	check(not box.anti_aliasing, "%s: no anti-aliasing" % what)


## Checks box is sunk 2 px into its shadow (178 AC4): no shadow, expand margins −2 left and top, +2 right and bottom,
## content margins 16, 8, 12, 4.
func check_sunk(box: StyleBoxFlat, what: String) -> void:
	check(box != null, "%s: a flat stylebox" % what)
	if box == null:
		return
	eq(box.shadow_size, 0, "%s: no shadow" % what)
	eq([box.expand_margin_left, box.expand_margin_top, box.expand_margin_right, box.expand_margin_bottom],
		[-2.0, -2.0, 2.0, 2.0], "%s expand margins (left, top, right, bottom)" % what)
	eq([box.content_margin_left, box.content_margin_top, box.content_margin_right, box.content_margin_bottom],
		[18.0, 10.0, 14.0, 6.0], "%s content margins (left, top, right, bottom)" % what)


func test_buttons_stand_on_a_hard_shadow() -> void:
	var main := open_main()
	var plain := button(main)
	var m := Vector2(16, 8)  # 193: space.4 across, space.2 down (guide §6.1)
	check_box(stylebox(plain, "normal"), Palette.CONTROL, Palette.CONTROL_BORDER, 2, 2, m, "Button normal")
	check_plinth(stylebox(plain, "normal"), "Button normal")
	check_box(stylebox(plain, "hover"), Palette.CONTROL.lightened(0.08), Palette.TEXT, 2, 2, m, "Button hover")
	check_plinth(stylebox(plain, "hover"), "Button hover")
	check_box(stylebox(plain, "disabled"), Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER, 2, 2, m,
		"Button disabled")
	if stylebox(plain, "disabled") != null:
		eq(stylebox(plain, "disabled").shadow_size, 0, "Button disabled lies flat")
	eq(plain.get_theme_color("font_color").to_html(), Palette.TEXT.to_html(), "Button text")
	eq(plain.get_theme_color("font_disabled_color").to_html(), Palette.TEXT_DISABLED.to_html(), "Button disabled text")
	close_main(main)


func test_a_pressed_button_sinks_into_its_shadow() -> void:
	var main := open_main()
	for variation in ["", "AccentButton"]:
		var b := button(main, variation)
		for state in ["pressed", "hover_pressed"]:
			check_sunk(stylebox(b, state), "%s %s" % [variation if variation != "" else "Button", state])
	close_main(main)


func test_the_accent_button_is_signal_orange() -> void:
	var main := open_main()
	var accent := button(main, "AccentButton")
	# 251: the guide's primary button (§7.1, the specimen's .btn.primary) has a 3 px ink border
	check_box(stylebox(accent, "normal"), Palette.ACCENT, Palette.TEXT, 3, 2, Vector2(16, 8), "AccentButton normal")
	check_plinth(stylebox(accent, "normal"), "AccentButton normal")
	eq(accent.get_theme_color("font_color").to_html(), Palette.TEXT_ON_ACCENT.to_html(), "AccentButton text")
	check_box(stylebox(accent, "disabled"), Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER, 2, 2,
		Vector2(16, 8), "AccentButton disabled: the plain Button's disabled look")
	close_main(main)


func test_only_the_accent_button_is_filled_with_the_accent() -> void:
	var t: Theme = load(GAME_THEME_PATH).build()
	var found: Array[String] = []
	for type in t.get_stylebox_type_list():
		for name in t.get_stylebox_list(type):
			var box := t.get_stylebox(name, type) as StyleBoxFlat
			if box != null and box.draw_center and box.bg_color.is_equal_approx(Palette.ACCENT):
				found.append("%s %s" % [type, name])
	check(not found.is_empty(), "AccentButton is filled with ACCENT")
	# End turn, the accent action, is its own key since 203
	eq(found.filter(func(s: String): return not s.begins_with("AccentButton ") and not s.begins_with("EndTurnKey ")), [],
		"no other variation uses ACCENT")


func test_the_focus_ring_is_square_and_outside_the_control() -> void:
	var main := open_main()
	var ring := stylebox(button(main), "focus")
	check(ring != null and not ring.draw_center, "the focus ring draws no fill")
	if ring != null:
		eq(ring.border_color.to_html(), Palette.FOCUS.to_html(), "focus ring colour")
		eq(ring.border_width_left, 2, "focus ring width")
		eq(ring.corner_radius_top_left, 0, "focus ring radius")
		eq(ring.expand_margin_left, 4.0, "focus ring 4 px outside")
	close_main(main)


func test_a_field_draws_no_focus_ring() -> void:
	var t: Theme = load(GAME_THEME_PATH).build()
	var ring := t.get_stylebox("focus", "LineEdit")
	check(ring is StyleBoxEmpty, "251: a field's focus box draws nothing (its caret shows the focus), got %s" % ring)


func test_fields_and_card_colours_look_as_before() -> void:
	var main := open_main()
	var field: LineEdit = in_main(main, LineEdit.new())
	check_box(stylebox(field, "normal"), Palette.FIELD, Palette.CONTROL_BORDER, 2, 2, Vector2(16, 8), "LineEdit")
	eq(field.get_theme_color("font_color").to_html(), Palette.TEXT.to_html(), "LineEdit text")
	var expected := {
		CardDef.ACTION: "86a9cc", CardDef.BUILDING: "a9b26c", CardDef.CITY: "d9a441",
		CardDef.TERRITORY: "93b585", CardDef.TECH: "5fb0a9", CardDef.EVENT: "e07a63",
	}
	for type in expected:
		eq(CardView.TYPE_COLORS[type].to_html(false), expected[type], "%s colour" % type)
	close_main(main)


# --- 178 AC2: the guide's typefaces, with tabular lining figures ---

## Checks font is a FontVariation of file (under assets/fonts/) with tnum and lnum on.
func check_face(font: Font, file: String, what: String) -> void:
	check(font is FontVariation, "%s: a FontVariation" % what)
	if not font is FontVariation:
		return
	var base: Font = (font as FontVariation).base_font
	eq(base.resource_path if base != null else "", "res://assets/fonts/" + file, "%s face" % what)
	var features: Dictionary = (font as FontVariation).opentype_features
	var ts := TextServerManager.get_primary_interface()
	for tag in ["tnum", "lnum"]:
		var on: int = features.get(tag, features.get(ts.name_to_tag(tag), 0))
		eq(on, 1, "%s: %s on" % [what, tag])


func test_the_theme_uses_the_guides_typefaces() -> void:
	var t: Theme = load(GAME_THEME_PATH).build()
	check_face(t.default_font, "Barlow-Regular.ttf", "the default font")
	check_face(t.get_font("font", "Button"), "BarlowSemiCondensed-Medium.ttf", "Button")
	check_face(t.get_font("font", "AccentButton"), "BarlowSemiCondensed-SemiBold.ttf", "AccentButton")
	for variation in ["Stat", "BarStat"]:
		check_face(t.get_font("font", variation), "BarlowSemiCondensed-SemiBold.ttf", variation)
	for variation in ["Title", "Link"]:
		var font := t.get_font("font", variation)
		check_face(font, "Jost-Variable.ttf", variation)
		if font is FontVariation:
			var weight: Dictionary = font.variation_opentype
			var ts := TextServerManager.get_primary_interface()
			eq(weight.get("wght", weight.get(ts.name_to_tag("wght"), 0)), 500, "%s at weight 500" % variation)


func test_the_fonts_ship_with_their_licences() -> void:
	for file in ["Barlow-Regular.ttf", "BarlowSemiCondensed-Medium.ttf", "BarlowSemiCondensed-SemiBold.ttf",
			"Jost-Variable.ttf", "OFL-Barlow.txt", "OFL-Jost.txt"]:
		check(FileAccess.file_exists("res://assets/fonts/" + file), "assets/fonts/%s" % file)


# --- AC2: one palette ---

## The ui/ scripts other than the palette whose code builds a Color from literals.
func literal_colours() -> Array[String]:
	var found: Array[String] = []
	var literal := RegEx.create_from_string("Color8?\\(\\s*(\"|[0-9.])")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd") or "res://ui/" + file == PALETTE_PATH:
			continue
		var lines := FileAccess.get_file_as_string("res://ui/" + file).split("\n")
		for i in lines.size():
			var code := lines[i].split("#")[0] if not lines[i].strip_edges().begins_with("##") else ""
			if literal.search(code) != null:
				found.append("ui/%s:%d" % [file, i + 1])
	return found


## The ui/ scripts other than the palette that write a BBCode colour as a literal: [color=#…] or [color=<name>] (395).
func bbcode_literal_colours() -> Array[String]:
	var found: Array[String] = []
	var literal := RegEx.create_from_string("\\[color=(#|[a-z])")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd") or "res://ui/" + file == PALETTE_PATH:
			continue
		var lines := FileAccess.get_file_as_string("res://ui/" + file).split("\n")
		for i in lines.size():
			if literal.search(lines[i]) != null:
				found.append("ui/%s:%d" % [file, i + 1])
	return found


func test_no_bbcode_colour_literals_outside_the_palette() -> void:
	eq(bbcode_literal_colours(), [] as Array[String], "BBCode colour literals outside ui/palette.gd")


func test_no_colour_literals_outside_the_palette() -> void:
	var found := literal_colours()
	eq(found, [] as Array[String], "colour literals outside ui/palette.gd")


func test_the_palette_names_the_ui_colours() -> void:
	check(FileAccess.file_exists(PALETTE_PATH), "%s exists" % PALETTE_PATH)
	if not FileAccess.file_exists(PALETTE_PATH):
		return
	var palette: Script = load(PALETTE_PATH)
	for name in ["TEXT", "TEXT_DIM", "PANEL", "ACCENT", "COST", "GAIN"]:
		check(palette.get(name) is Color, "Palette.%s is a colour" % name)


# --- AC3: one theme ---

func test_game_theme_builds_the_controls_and_variations() -> void:
	check(FileAccess.file_exists(GAME_THEME_PATH), "%s exists" % GAME_THEME_PATH)
	if not FileAccess.file_exists(GAME_THEME_PATH):
		return
	var t: Theme = load(GAME_THEME_PATH).build()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		check(t.has_stylebox(state, "Button"), "Button %s" % state)
		check(t.has_stylebox(state, "AccentButton"), "AccentButton %s" % state)
	eq(t.get_type_variation_base("AccentButton"), &"Button", "AccentButton varies Button")
	for label in ["Heading", "Title", "Stat"]:
		eq(t.get_type_variation_base(label), &"Label", "%s varies Label" % label)
		check(t.has_font_size("font_size", label), "%s font size" % label)
	for label in ["Heading", "Title"]:
		check(t.has_color("font_color", label), "%s colour" % label)
	eq(t.get_type_variation_base("DarkPanel"), &"PanelContainer", "DarkPanel varies PanelContainer")
	check(t.has_stylebox("panel", "DarkPanel"), "DarkPanel stylebox")


## 233 AC1, AC2: a tooltip is a printed tab (guide §11.11): ink fill, sheet text, square, with room around the text,
## in Night and Day alike.
func test_tooltips_are_ink_tabs_with_room() -> void:
	for day in [false, true]:
		Palette.use(day)
		var t: Theme = load(GAME_THEME_PATH).build()
		var what := "Day" if day else "Night"
		var box := t.get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
		check(box != null, "%s: TooltipPanel is a flat box" % what)
		if box != null:
			eq(box.bg_color.to_html(), Palette.TEXT.to_html(), "%s: tooltip fill is ink" % what)
			eq(box.corner_radius_top_left, Tokens.RADIUS_0, "%s: tooltip is square" % what)
			eq(Vector2(box.content_margin_left, box.content_margin_top), Vector2(Tokens.SPACE_4, Tokens.SPACE_3),
					"%s: tooltip padding" % what)
		eq(t.get_color("font_color", "TooltipLabel").to_html(), Palette.RAISED.to_html(), "%s: tooltip text is sheet" % what)
		eq(t.get_font_size("font_size", "TooltipLabel"), Tokens.TYPE_BODY_S, "%s: tooltip text size" % what)
	Palette.use(false)


func test_main_uses_the_game_theme() -> void:
	var main := open_main()
	check(main.theme != null and main.theme.get_type_variation_base("Heading") == &"Label", "main's theme has the variations")
	close_main(main)


# --- AC4: components use the variations ---

func test_ui_kit_labels_use_the_variations() -> void:
	var heading := UIKit.heading("h")
	eq(heading.theme_type_variation, &"Heading", "heading")
	var title := UIKit.title("t")
	eq(title.theme_type_variation, &"Title", "title")
	var parent := Control.new()
	var stat := UIKit.stat(parent, &"TEXT")
	eq(stat.theme_type_variation, &"Stat", "stat")
	for label in [heading, title, stat]:
		check(not label.has_theme_font_size_override("font_size"), "%s: no font size override" % label.theme_type_variation)
	for label in [heading, title]:
		check(not label.has_theme_color_override("font_color"), "%s: no colour override" % label.theme_type_variation)
	heading.free()
	title.free()
	parent.free()


func test_overlay_panels_use_dark_panel_and_modals_the_sheet() -> void:
	var main := open_main()
	var overlay_panel: PanelContainer = UIKit.overlay(main).get_meta("panel")
	eq(overlay_panel.theme_type_variation, &"DarkPanel", "an overlay uses DarkPanel")
	check(not overlay_panel.has_theme_stylebox_override("panel"), "an overlay: no stylebox of its own")
	for c in main.get_children():
		if c is Modal:  # 207: every modal is a sheet in an ink rule, the event modal too
			var panel: PanelContainer = (c as Modal).panel
			eq(panel.theme_type_variation, &"Sheet", "%s uses Sheet" % c.get_script().get_global_name())
			check(not panel.has_theme_stylebox_override("panel"), "%s: no stylebox of its own" % c.get_script().get_global_name())
			eq(Looks.frame_of(panel.get_theme_stylebox("panel")).border_color.to_html(), Palette.TEXT.to_html(), "%s: an ink rule" % c.get_script().get_global_name())
	close_main(main)


# --- AC5: UIKit keeps layout only ---

func test_ui_kit_no_longer_builds_the_theme() -> void:
	var src := FileAccess.get_file_as_string("res://ui/ui_kit.gd")
	check(not src.contains("func style_controls"), "style_controls moved to GameTheme")
	var main_src := FileAccess.get_file_as_string("res://ui/main.gd")
	check(main_src.contains("GameTheme.build()"), "main builds its theme with GameTheme")


# --- 393: the theme's sections, one file each ---

const SECTIONS_DIR := "res://ui/theme"


func test_every_section_file_is_listed_and_every_listed_one_exists() -> void:
	var listed: Array = GameTheme.SECTIONS.map(func(s: Script): return s.resource_path)
	check(not listed.is_empty(), "GameTheme.SECTIONS lists the sections")
	var files: Array = Array(DirAccess.get_files_at(SECTIONS_DIR)).filter(func(f: String): return f.ends_with(".gd")) \
		.map(func(f: String): return SECTIONS_DIR + "/" + f)
	eq(files.filter(func(f): return not listed.has(f)), [], "section files GameTheme.SECTIONS leaves out")
	eq(listed.filter(func(f): return not FileAccess.file_exists(f)), [], "listed sections with no file")


func test_each_look_has_one_section() -> void:
	var owner := {}
	var problems: Array[String] = []
	check(not GameTheme.SECTIONS.is_empty(), "GameTheme.SECTIONS lists the sections")
	for section: Script in GameTheme.SECTIONS:
		var t := Theme.new()
		section.call("apply", t)
		var name := section.resource_path.get_file()
		if t.get_type_list().is_empty():
			problems.append("%s defines nothing" % name)
		for type in t.get_type_list():
			if t.get_type_variation_base(type) == &"":
				continue
			if owner.has(type):
				problems.append("%s is defined by %s and %s" % [type, owner[type], name])
			owner[type] = name
	eq(problems, [] as Array[String], "each section's looks are its own")
