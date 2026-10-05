class_name Icons
extends RefCounted
## Swaps the text glyphs the game uses (the engine's "⟳", the UI's type marks and so on) for icon
## images, in card labels and in the log. Icons are white SVGs in assets/icons/, tinted here.

const FOOD := preload("res://assets/icons/food.svg")  # the sprout: food everywhere (180)
## The resource glyphs (180), by counter key: the top bar's counters and a hand card's cost.
const RESOURCES := {
	GameEngine.FOOD: FOOD,
	GameEngine.WEALTH: preload("res://assets/icons/wealth.svg"),  # a cash coin
	GameEngine.INSIGHT: preload("res://assets/icons/insight.svg"),  # an open book
	GameEngine.UNREST: preload("res://assets/icons/unrest.svg"),  # a solid bolt
	TopBar.SCORE: preload("res://assets/icons/score.svg"),  # a starburst
	TopBar.POP: preload("res://assets/icons/pop.svg"),  # a figure
}


## The hue a resource's glyph is tinted (180): food GAIN, wealth WEALTH, insight INSIGHT, unrest UNREST, pop POP;
## TEXT for anything else (score).
static func hue(key: String) -> Color:
	return {GameEngine.FOOD: Palette.GAIN, GameEngine.WEALTH: Palette.WEALTH, GameEngine.INSIGHT: Palette.INSIGHT,
		GameEngine.UNREST: Palette.UNREST, TopBar.POP: Palette.POP}.get(key, Palette.TEXT)


## A glyph for key (a RESOURCES key) at size px, tinted its hue, taking no mouse input.
static func glyph(key: String, size: float) -> TextureRect:
	var g := TextureRect.new()
	g.texture = RESOURCES[key]
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.custom_minimum_size = Vector2(size, size)
	g.self_modulate = hue(key)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

## Glyph -> [texture, tint, scale], as the palette reads now (183: the tint can't be a constant). A null tint means
## the icon takes the colour of the text around it. scale is the icon's height as a fraction of the font size (the
## type marks sit small, like the glyphs they replace, so the type line still fits beside the cost).
static var GLYPHS: Dictionary:
	get:
		return {
			"⟳": [preload("res://assets/icons/upkeep.svg"), Palette.GAIN, 1.0],
			"▢": [preload("res://assets/icons/slot.svg"), null, 1.0],
			"⌂": [preload("res://assets/icons/housing.svg"), null, 1.0],
			"⚒": [preload("res://assets/icons/worker.svg"), null, 1.0],  # a free worker (123)
			"⛨": [preload("res://assets/icons/shield.svg"), null, 1.0],  # a territory's defence (161)
			"◆": [preload("res://assets/icons/action.svg"), null, 0.6],
			"■": [preload("res://assets/icons/building.svg"), null, 0.6],
			"●": [preload("res://assets/icons/city.svg"), null, 0.6],
			"▲": [preload("res://assets/icons/territory.svg"), null, 0.6],
			"✦": [preload("res://assets/icons/tech.svg"), null, 0.6],
			"❖": [preload("res://assets/icons/event.svg"), null, 0.6],
			"⊘": [preload("res://assets/icons/blocked.svg"), null, 1.0],
		}


## Replaces label's content with text, drawing each known glyph as an icon sized to font_size.
## Uses add_text, never BBCode, so card names can't be read as markup.
static func fill(label: RichTextLabel, text: String, font_size: int, color: Color) -> void:
	label.clear()
	var run := ""
	var glyphs := GLYPHS
	for ch in text:
		if glyphs.has(ch):
			label.add_text(run)
			run = ""
			var tint: Variant = glyphs[ch][1]
			var height := roundi(font_size * glyphs[ch][2])
			label.add_image(glyphs[ch][0], 0, height, color if tint == null else tint, INLINE_ALIGNMENT_CENTER)
		else:
			run += ch
	label.add_text(run)


## text with each known glyph turned into an [img] tag, for BBCode output such as the log.
static func bbcode(text: String, font_size: int) -> String:
	var glyphs := GLYPHS
	for ch in glyphs:
		if ch in text:
			var tint: Variant = glyphs[ch][1]
			var color := "" if tint == null else " color=#%s" % (tint as Color).to_html(false)
			var height := roundi(font_size * glyphs[ch][2])
			text = text.replace(ch, "[img height=%d valign=center%s]%s[/img]" % [height, color, glyphs[ch][0].resource_path])
	return text
