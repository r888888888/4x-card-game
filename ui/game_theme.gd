class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). build() sets the base: the default font, the label type scale (Display, Title, Heading, Body, BodySmall,
## Caption, Stat, …), RichBody text, DarkPanel and Sheet. Every other look is a section, one file each in ui/theme/
## (393): `extends RefCounted` with `static func apply(t: Theme)`, listed in SECTIONS (the suite checks the list and
## that each type variation has one section). A new look goes in a section file, not here. A control takes a look
## with theme_type_variation instead of its own overrides. The shared builders and fonts stay here, public.

const DEFAULT_FONT_SIZE := Tokens.TYPE_BODY  # everything without a size of its own (log, buttons, inputs)
# The style guide's typefaces (178, §5): each is used through tabular(), so figures never shift width as they change.
const BODY_FONT := preload("res://assets/fonts/Barlow-Regular.ttf")
const ITALIC_FONT := preload("res://assets/fonts/Barlow-Italic.ttf")  # RichBody's [i], e.g. flavor (216)
const LABEL_FONT := preload("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
const LABEL_SEMIBOLD := preload("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Jost-Variable.ttf")
const PLINTH := Vector2(2, 2)  # a control's hard shadow (guide shadow.plinth)
const PRESS := 2  # px a pressed control travels into its shadow (guide travel.press)
const SELECTED_SHADOW := Vector2(4, 4)  # a selected row's hard shadow (217, guide §4.4 "Selected")
## The looks, one section file each in ui/theme/, applied in this order after the base types (393).
const SECTIONS: Array[Script] = [
	preload("res://ui/theme/controls.gd"),
	preload("res://ui/theme/link.gd"),
	preload("res://ui/theme/divider_tab.gd"),
	preload("res://ui/theme/big_buttons.gd"),
	preload("res://ui/theme/end_turn_key.gd"),
	preload("res://ui/theme/select_list.gd"),
	preload("res://ui/theme/price_tag.gd"),
	preload("res://ui/theme/board_frame.gd"),
	preload("res://ui/theme/icon_button.gd"),
	preload("res://ui/theme/tech_tiles.gd"),
	preload("res://ui/theme/identity_cards.gd"),
	preload("res://ui/theme/upgrades.gd"),
	preload("res://ui/theme/tooltips.gd"),
	preload("res://ui/theme/popover.gd"),
	preload("res://ui/theme/flags.gd"),
	preload("res://ui/theme/card_foot.gd"),
]


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = tabular(BODY_FONT)
	t.default_font_size = DEFAULT_FONT_SIZE
	label(t, "Display", Tokens.TYPE_DISPLAY, Palette.TEXT, display())
	label(t, "DisplayXL", Tokens.TYPE_DISPLAY_XL, Palette.TEXT, display())  # the era ceremony's name (211)
	label(t, "Title", Tokens.TYPE_TITLE, Palette.TEXT, display())
	label(t, "Heading", Tokens.TYPE_HEADING, Palette.TEXT_DIM, heading_font())  # UIKit.heading sets the capitals
	label(t, "Verdict", Tokens.TYPE_DISPLAY, Palette.TEXT, verdict_font())  # the raid modal's headline (389)
	label(t, "Body", Tokens.TYPE_BODY, Palette.TEXT)
	label(t, "BodySmall", Tokens.TYPE_BODY_S, Palette.TEXT)
	label(t, "Caption", Tokens.TYPE_CAPTION, Palette.TEXT_DIM)
	label(t, "FinePrint", Tokens.TYPE_CAPTION, Palette.TEXT_DIM, heading_font())  # a card's gates, at its foot (382)
	label(t, "LedgerLabel", Tokens.TYPE_LABEL_CAPS, Palette.TEXT_DIM, heading_font())  # a card's figure's name (382)
	label(t, "LedgerFigure", Tokens.TYPE_NUMERAL_S, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # and the figure
	label(t, "Refusal", Tokens.TYPE_BODY_S, Palette.COST)  # why an action can't be done, beside its disabled key (259)
	label(t, "Stat", Tokens.TYPE_NUMERAL, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # each stat also sets its own colour: what it counts
	label(t, "CardTitle", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a card's name, bold beside its rules (198)
	label(t, "BigLabel", Tokens.TYPE_TITLE, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a BigButton's caps label (213)
	label(t, "Forecast", Tokens.TYPE_NUMERAL_S, Palette.TEXT_DIM, tabular(LABEL_SEMIBOLD))  # a counter's next change (201)
	label(t, "BarStat", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # body size like the bar's buttons, so it fits 1920 px (144)
	t.set_type_variation("RichBody", "RichTextLabel")  # modal text and the log (194)
	for size in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		t.set_font_size(size, "RichBody", Tokens.TYPE_BODY)
	t.set_font("italics_font", "RichBody", tabular(ITALIC_FONT))
	t.set_font("bold_font", "RichBody", tabular(LABEL_SEMIBOLD))  # a real bold for [b] headers, not a synthesized one
	t.set_color("default_color", "RichBody", Palette.TEXT)  # Godot's default is white, unreadable on Day's paper (323)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark_panel())
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet())
	for section in SECTIONS:  # the looks, each in its own file (393)
		section.apply(t)
	return t


## The Rail's box with its grain lined up for a rail at origin on screen.
static func rail(origin := Vector2.ZERO) -> SurfaceBox:
	var frame := UIKit.panel_style(Palette.BACKGROUND, Palette.HAIRLINE, Tokens.SPACE_4)
	frame.set_border_width_all(0)
	frame.border_width_left = 1
	return Surfaces.board(origin, frame)


## An overlay's panel (341: a sheet of paper); border defaults to DarkPanel's own.
static func dark_panel(border := Palette.EDGE) -> SurfaceBox:
	return Surfaces.sheet(border)


## A BigButton's card in fill: a 3 px ink border, square, on a 4,4 shadow.
static func card(fill: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(fill, Palette.TEXT, Tokens.SPACE_0)
	style.set_border_width_all(3)
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = Vector2(BigButton.TRAVEL, BigButton.TRAVEL)
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## A modal's sheet (207, guide §15.11): paper in a 2 px ink rule, cut square, on a soft shadow (341).
static func sheet() -> SurfaceBox:
	return Surfaces.sheet(Palette.TEXT)


## The keyboard focus ring drawn over a focused button or field; same colour as a focused card's.
static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Palette.FOCUS
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(0)
	ring.set_expand_margin_all(4)
	return ring


static func label(t: Theme, variation: String, font_size: int, color: Color, font: Font = null) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, font_size)
	t.set_color("font_color", variation, color)
	if font != null:
		t.set_font("font", variation, font)


## base with tabular lining figures (OpenType tnum and lnum), so a changing number keeps its width (178).
static func tabular(base: Font) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.opentype_features = {"tnum": 1, "lnum": 1}
	return f


## The heading face (§5.2 type.heading): Barlow SemiCondensed SemiBold, tracked +10% for its capitals (194).
static func heading_font() -> FontVariation:
	var f := tabular(LABEL_SEMIBOLD)
	f.spacing_glyph = roundi(Tokens.TYPE_HEADING * 0.1)
	return f


## The verdict face (389): Barlow SemiCondensed SemiBold at display size, tracked +8% for its capitals, so a raid's
## outcome reads apart from the sheet's Jost title.
static func verdict_font() -> FontVariation:
	var f := tabular(LABEL_SEMIBOLD)
	f.spacing_glyph = roundi(Tokens.TYPE_DISPLAY * 0.08)
	return f


## Jost at Medium weight (500), the guide's display face: titles and the header's link back (178).
static func display() -> FontVariation:
	var f := tabular(DISPLAY_FONT)
	f.variation_opentype = {"wght": 500}
	return f
