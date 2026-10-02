extends "res://tests/lib/test_case.gd"
## Text sizes (194): the guide's type scale (docs/design/mcm-style-guide.md §5.2) as Tokens.TYPE_* named after its
## tokens, the theme's variations at those sizes, every size on screen a step of the scale, and no literal size in ui/.
## Tokens and the theme are read by name (Script.get, Theme lookups) so this file parses before they exist.

const TOKENS_PATH := "res://ui/tokens.gd"
## The guide's type tokens (§5.2) by Tokens name.
const TYPE_SCALE := {
	"TYPE_DISPLAY_XL": 56, "TYPE_DISPLAY": 40, "TYPE_TITLE": 28, "TYPE_HEADING": 15, "TYPE_BODY": 20, "TYPE_BODY_S": 17,
	"TYPE_LABEL": 17, "TYPE_LABEL_CAPS": 14, "TYPE_CAPTION": 14, "TYPE_NUMERAL_XL": 44, "TYPE_NUMERAL": 26,
	"TYPE_NUMERAL_S": 17,
}
const SIZES := [14, 15, 17, 20, 26, 28, 40, 44, 56]
## Label variations and their sizes (AC1).
const LABELS := {"Display": 40, "Title": 28, "Heading": 15, "Body": 20, "BodySmall": 17, "Caption": 14, "Stat": 26}


## The base face of variation's font in theme t (through FontVariations), or null.
func base_face(t: Theme, variation: String) -> Font:
	var font := t.get_font("font", variation)
	while font is FontVariation:
		font = (font as FontVariation).base_font
	return font


## The font sizes a visible text control draws with: a RichTextLabel's three, else its font_size.
func sizes_of(c: Control) -> Array[int]:
	if c is RichTextLabel:
		return [c.get_theme_font_size("normal_font_size"), c.get_theme_font_size("bold_font_size"),
			c.get_theme_font_size("italics_font_size")]
	return [c.get_theme_font_size("font_size")]


## Whether c draws text: a Label, Button, LineEdit or RichTextLabel.
func is_text(c: Control) -> bool:
	return c is Label or c is Button or c is LineEdit or c is RichTextLabel


# --- AC1: the tokens and variations ---

func test_the_tokens_hold_the_guides_type_scale() -> void:
	var tokens: Script = load(TOKENS_PATH)
	for name: String in TYPE_SCALE:
		eq(tokens.get(name), TYPE_SCALE[name], "Tokens.%s" % name)


func test_the_theme_has_a_label_variation_per_type_role() -> void:
	var t := GameTheme.build()
	for variation: String in LABELS:
		eq(t.get_type_variation_base(variation), &"Label", "%s varies Label" % variation)
		eq(t.get_font_size("font_size", variation), LABELS[variation], "%s size" % variation)
	eq(t.get_type_variation_base("RichBody"), &"RichTextLabel", "RichBody varies RichTextLabel")
	for size in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		eq(t.get_font_size(size, "RichBody"), 20, "RichBody %s" % size)
	for variation in ["Display", "Title"]:
		eq(base_face(t, variation), GameTheme.DISPLAY_FONT, "%s uses the display face" % variation)
	eq(base_face(t, "Heading"), GameTheme.LABEL_SEMIBOLD, "Heading uses the semibold label face")


# --- AC2: headings are capitals, tracked ---

func test_a_heading_is_capitals_at_15_tracked() -> void:
	var main := open_main()
	var heading := UIKit.heading("The realm")
	main.add_child(heading)
	check(heading.uppercase, "drawn in capitals")
	eq(heading.text, "The realm", "its text unchanged")
	eq(heading.get_theme_font_size("font_size"), 15, "15 px")
	var font := heading.get_theme_font("font") as FontVariation
	check(font != null and font.spacing_glyph >= 1, "letter spacing of 1 px or more (+10%% at 15 px)")
	heading.free()
	close_main(main)


# --- AC3, AC4: on screen ---

func test_every_text_size_on_screen_is_on_the_scale() -> void:
	var off: Array[String] = []
	await each_screen(func(main: Node, screen: String):
		for c in visible_controls(main):
			if is_text(c):
				for size in sizes_of(c):
					if not SIZES.has(size):
						off.append("%s: %s %d" % [screen, main.get_path_to(c), size]))
	eq(off, [] as Array[String], "text sizes off the type scale")


func test_every_text_size_on_a_card_face_is_on_the_scale() -> void:
	await with_temp_settings(func():
		var main: Node = await mid_game()
		var off: Array[String] = []
		var faces := 0
		for uid in main.views:
			var view: CardView = main.views[uid]
			if not view.is_visible_in_tree():
				continue
			faces += 1
			for c in view.find_children("*", "Control", true, false):
				if (c as Control).is_visible_in_tree() and is_text(c):
					for size in sizes_of(c):
						if not SIZES.has(size):
							off.append("%s %s: %d" % [view.card_id, c.name, size])
		check(faces >= 5, "precondition: hand and Realm cards on the board (%d)" % faces)
		eq(off, [] as Array[String], "card face sizes off the type scale")
		close_main(main))


# --- AC5: no literal sizes ---

## The calls that take a font size, by name.
const SIZE_CALLS := "\\b(add_theme_font_size_override|set_font_size|label|rich_label|fx_label|Icons\\.fill|Icons\\.bbcode)\\("


## The ui/ lines (other than the theme's and the tokens') that pass an integer literal other than 0 to a call taking a
## font size, or write [font_size=…] BBCode.
func size_literals() -> Array[String]:
	var found: Array[String] = []
	var call := RegEx.create_from_string(SIZE_CALLS)
	var strings := RegEx.create_from_string("\"(\\\\.|[^\"\\\\])*\"")
	var integer := RegEx.create_from_string("(?<![\\w.])[1-9][0-9]*(?![\\w.])")
	for file in DirAccess.get_files_at("res://ui"):
		if not file.ends_with(".gd") or file in ["game_theme.gd", "tokens.gd"]:
			continue
		var lines := FileAccess.get_file_as_string("res://ui/" + file).split("\n")
		for i in lines.size():
			var line := lines[i]
			if line.strip_edges().begins_with("#"):
				continue
			if line.contains("[font_size="):
				found.append("ui/%s:%d [font_size=]" % [file, i + 1])
				continue
			var code := strings.sub(line.split("#")[0], "\"\"", true)
			var m := call.search(code)
			if m != null and code.substr(m.get_end()).begins_with(")") == false and not code.contains("func "):
				if integer.search(code.substr(m.get_end())) != null:
					found.append("ui/%s:%d" % [file, i + 1])
	return found


func test_no_ui_script_passes_a_literal_text_size() -> void:
	eq(size_literals(), [] as Array[String], "literal text sizes (use Tokens.TYPE_* or a variation)")


func test_a_title_keeps_its_case() -> void:
	var title := UIKit.title("Knowledge")
	check(not title.uppercase, "a title isn't drawn in capitals (type.title is Title Case)")
	eq(title.theme_type_variation, &"Title", "the Title variation")
	title.free()
