extends "res://tests/lib/test_case.gd"
## The UI theme (backlog 106). AC1 records how things look today, resolved through the real main scene's theme, and
## must pass unchanged before and after the cleanup. The rest check the palette (ui/palette.gd) and the theme built
## in code (ui/game_theme.gd, GameTheme.build()), loaded by path (held as Object) so this file parses before they
## exist.

const PALETTE_PATH := "res://ui/palette.gd"
const GAME_THEME_PATH := "res://ui/game_theme.gd"
const TEXT := Color("e6ebf0")
const BUTTON_FILL := Color("2f353d")
const ACCENT := Color("e8c547")
const OVERLAY_PANEL := Color("262b31")


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


# --- AC1: nothing looks different (a guard: passes before and after) ---

func test_labels_look_as_before() -> void:
	var main := open_main()
	var heading: Label = in_main(main, UIKit.heading("h"))
	eq(heading.get_theme_font_size("font_size"), 19, "heading size")
	eq(heading.get_theme_color("font_color").to_html(), Color("b4bcc6").to_html(), "heading colour")
	var title: Label = in_main(main, UIKit.title("t"))
	eq(title.get_theme_font_size("font_size"), 26, "title size")
	eq(title.get_theme_color("font_color").to_html(), Color.WHITE.to_html(), "title colour")
	var stat := UIKit.stat(main, Color("9fd89f"))
	eq(stat.get_theme_font_size("font_size"), 26, "stat size")
	eq(stat.get_theme_color("font_color").to_html(), Color("9fd89f").to_html(), "stat colour: its own")
	close_main(main)


func test_panels_look_as_before() -> void:
	var main := open_main()
	var overlay := UIKit.overlay(main)
	var panel: PanelContainer = overlay.get_meta("panel")
	check_box(stylebox(panel, "panel"), OVERLAY_PANEL, Color(1, 1, 1, 0.25), 1, 10, Vector2(24, 24), "overlay panel")
	main.start_game(1)
	var log := log_panel(main)
	check(log != null, "the log's panel")
	if log != null:
		check_box(stylebox(log, "panel"), Color("171a1e"), Color(1, 1, 1, 0.08), 1, 10, Vector2(12, 12), "log panel")
	close_main(main)


func test_buttons_look_as_before() -> void:
	var main := open_main()
	var plain := button(main)
	var m := Vector2(14, 6)
	check_box(stylebox(plain, "normal"), BUTTON_FILL, Color("78828e"), 2, 6, m, "Button normal")
	check_box(stylebox(plain, "hover"), BUTTON_FILL.lightened(0.15), Color.WHITE, 2, 6, m, "Button hover")
	check_box(stylebox(plain, "pressed"), BUTTON_FILL.darkened(0.2), Color.WHITE, 2, 6, m, "Button pressed")
	check_box(stylebox(plain, "disabled"), Color("24282d"), Color("4a5058"), 2, 6, m, "Button disabled")
	eq(plain.get_theme_color("font_color").to_html(), TEXT.to_html(), "Button text")
	eq(plain.get_theme_color("font_disabled_color").to_html(), Color("8d96a0").to_html(), "Button disabled text")
	var accent := button(main, "AccentButton")
	check_box(stylebox(accent, "normal"), ACCENT, ACCENT, 2, 6, m, "AccentButton normal")
	check_box(stylebox(accent, "hover"), ACCENT.lightened(0.15), Color.WHITE, 2, 6, m, "AccentButton hover")
	check_box(stylebox(accent, "pressed"), ACCENT.darkened(0.2), Color.WHITE, 2, 6, m, "AccentButton pressed")
	check_box(stylebox(accent, "disabled"), Color("24282d"), Color("4a5058"), 2, 6, m, "AccentButton disabled")
	eq(accent.get_theme_color("font_color").to_html(), Color("1d2126").to_html(), "AccentButton text")
	var ring := stylebox(plain, "focus")
	check(ring != null and not ring.draw_center, "the focus ring draws no fill")
	if ring != null:
		eq(ring.border_color.to_html(), Color("5ec8ff").to_html(), "focus ring colour")
		eq(ring.border_width_left, 3, "focus ring width")
	close_main(main)


func test_fields_and_card_colours_look_as_before() -> void:
	var main := open_main()
	var field: LineEdit = in_main(main, LineEdit.new())
	check_box(stylebox(field, "normal"), Color("14171a"), Color("78828e"), 2, 6, Vector2(14, 6), "LineEdit")
	eq(field.get_theme_color("font_color").to_html(), TEXT.to_html(), "LineEdit text")
	var expected := {
		CardDef.ACTION: "4a7fb5", CardDef.BUILDING: "5f9a45", CardDef.CITY: "c08a3e",
		CardDef.TERRITORY: "8a6fb5", CardDef.TECH: "3fa7a0", CardDef.EVENT: "b5566f",
	}
	for type in expected:
		eq(CardView.TYPE_COLORS[type].to_html(false), expected[type], "%s colour" % type)
	close_main(main)


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


func test_no_colour_literals_outside_the_palette() -> void:
	var found := literal_colours()
	eq(found, [] as Array[String], "colour literals outside ui/palette.gd")


func test_the_palette_names_the_ui_colours() -> void:
	check(FileAccess.file_exists(PALETTE_PATH), "%s exists" % PALETTE_PATH)
	if not FileAccess.file_exists(PALETTE_PATH):
		return
	var names: Dictionary = load(PALETTE_PATH).get_script_constant_map()
	for name in ["TEXT", "TEXT_DIM", "PANEL", "ACCENT", "COST", "GAIN"]:
		check(names.has(name) and names[name] is Color, "Palette.%s is a colour" % name)


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
	var stat := UIKit.stat(parent, Color.WHITE)
	eq(stat.theme_type_variation, &"Stat", "stat")
	for label in [heading, title, stat]:
		check(not label.has_theme_font_size_override("font_size"), "%s: no font size override" % label.theme_type_variation)
	for label in [heading, title]:
		check(not label.has_theme_color_override("font_color"), "%s: no colour override" % label.theme_type_variation)
	heading.free()
	title.free()
	parent.free()


func test_overlay_panels_use_dark_panel() -> void:
	var main := open_main()
	var panels: Array = [UIKit.overlay(main).get_meta("panel")]
	for modal in [main.details, main.tech_tree]:
		panels.append(modal.find_children("*", "PanelContainer", true, false)[0])
	for panel in panels:
		eq(panel.theme_type_variation, &"DarkPanel", "%s uses DarkPanel" % panel.get_path())
		check(not panel.has_theme_stylebox_override("panel"), "%s: no stylebox of its own" % panel.get_path())
	var event_panel: PanelContainer = null
	for c in main.get_children():
		if c is EventModal:
			event_panel = c.find_children("*", "PanelContainer", true, false)[0]
	check(event_panel != null, "the event modal's panel")
	if event_panel != null:
		eq(event_panel.theme_type_variation, &"DarkPanel", "the event modal uses DarkPanel")
		var box := stylebox(event_panel, "panel")
		eq(box.bg_color.to_html(), OVERLAY_PANEL.to_html(), "event panel background: DarkPanel's")
		eq(box.border_color.to_html(), CardView.TYPE_COLORS[CardDef.EVENT].to_html(), "its border: the event colour")
	close_main(main)


# --- AC5: UIKit keeps layout only ---

func test_ui_kit_no_longer_builds_the_theme() -> void:
	var src := FileAccess.get_file_as_string("res://ui/ui_kit.gd")
	check(not src.contains("func style_controls"), "style_controls moved to GameTheme")
	var main_src := FileAccess.get_file_as_string("res://ui/main.gd")
	check(main_src.contains("GameTheme.build()"), "main builds its theme with GameTheme")
