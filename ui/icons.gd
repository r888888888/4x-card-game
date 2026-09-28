class_name Icons
extends RefCounted
## Swaps the text glyphs the game uses (the engine's "⟳", the UI's type marks and so on) for icon
## images, in card labels and in the log. Icons are white SVGs in assets/icons/, tinted here.

## Glyph -> [texture, tint, scale]. A null tint means the icon takes the colour of the text around
## it. scale is the icon's height as a fraction of the font size (the type marks sit small, like the
## glyphs they replace, so the type line still fits beside the cost).
const GLYPHS := {
	"⟳": [preload("res://assets/icons/upkeep.svg"), Color("ffd966"), 1.0],
	"▢": [preload("res://assets/icons/slot.svg"), null, 1.0],
	"⌂": [preload("res://assets/icons/housing.svg"), null, 1.0],
	"◆": [preload("res://assets/icons/action.svg"), null, 0.6],
	"■": [preload("res://assets/icons/building.svg"), null, 0.6],
	"●": [preload("res://assets/icons/city.svg"), null, 0.6],
	"▲": [preload("res://assets/icons/territory.svg"), null, 0.6],
	"⊘": [preload("res://assets/icons/blocked.svg"), null, 1.0],
}


## Replaces label's content with text, drawing each known glyph as an icon sized to font_size.
## Uses add_text, never BBCode, so card names can't be read as markup.
static func fill(label: RichTextLabel, text: String, font_size: int, color: Color) -> void:
	label.clear()
	var run := ""
	for ch in text:
		if GLYPHS.has(ch):
			label.add_text(run)
			run = ""
			var tint: Variant = GLYPHS[ch][1]
			var height := roundi(font_size * GLYPHS[ch][2])
			label.add_image(GLYPHS[ch][0], 0, height, color if tint == null else tint, INLINE_ALIGNMENT_CENTER)
		else:
			run += ch
	label.add_text(run)


## text with each known glyph turned into an [img] tag, for BBCode output such as the log.
static func bbcode(text: String, font_size: int) -> String:
	for ch in GLYPHS:
		if ch in text:
			var tint: Variant = GLYPHS[ch][1]
			var color := "" if tint == null else " color=#%s" % (tint as Color).to_html(false)
			var height := roundi(font_size * GLYPHS[ch][2])
			text = text.replace(ch, "[img height=%d valign=center%s]%s[/img]" % [height, color, GLYPHS[ch][0].resource_path])
	return text
