class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). Buttons, the accent button and text fields, plus type variations for the looks the UI repeats:
## Heading, Title, Stat and BarStat labels, DarkPanel (an overlay's or a modal's panel) and the pop meter's PipFilled, PipEmpty
## and GrowPip (124). A control takes one with
## theme_type_variation instead of its own overrides.

const DEFAULT_FONT_SIZE := 20  # everything without a size of its own (log, buttons, inputs)
const PIP_SIZE := 22  # a pop meter pip's width and height (124)
# The style guide's typefaces (178, §5): each is used through tabular(), so figures never shift width as they change.
const BODY_FONT := preload("res://assets/fonts/Barlow-Regular.ttf")
const LABEL_FONT := preload("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
const LABEL_SEMIBOLD := preload("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Jost-Variable.ttf")
const PLINTH := Vector2(2, 2)  # a control's hard shadow (guide shadow.plinth)
const PRESS := 2  # px a pressed control travels into its shadow (guide travel.press)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = tabular(BODY_FONT)
	t.default_font_size = DEFAULT_FONT_SIZE
	_controls(t)
	_label(t, "Heading", 19, Palette.TEXT_DIM)
	_label(t, "Title", 26, Palette.TEXT, display())
	_label(t, "Stat", 26, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # each stat also sets its own colour: what it counts
	_label(t, "BarStat", 20, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # 20 like the bar's buttons, so it fits 1920 px (144)
	_link(t)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark_panel())
	_pips(t)
	return t


## The territory view's pop meter (124): a pip per housing, PipFilled for each pop and PipEmpty for the room left
## (Panels), and GrowPip, the button on the first empty pip: a pip-coloured border round its cost and food icon.
static func _pips(t: Theme) -> void:
	for variation: String in ["PipFilled", "PipEmpty"]:
		var filled := variation == "PipFilled"
		var pip := UIKit.panel_style(Palette.POP if filled else Color.TRANSPARENT, Palette.POP.darkened(0.0 if filled else 0.45), 0)
		pip.set_border_width_all(2)
		pip.set_corner_radius_all(PIP_SIZE / 2)
		t.set_type_variation(variation, "Panel")
		t.set_stylebox("panel", variation, pip)
	t.set_type_variation("GrowPip", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box(Palette.CONTROL, Palette.POP)
		box.set_corner_radius_all(PIP_SIZE / 2)
		box.content_margin_left = 10
		box.content_margin_right = 12
		box.content_margin_top = 2
		box.content_margin_bottom = 2
		if state == "hover":
			box.bg_color = Palette.CONTROL.lightened(0.08)
			box.border_color = Palette.TEXT
		elif state == "disabled":
			box.bg_color = Palette.CONTROL_DISABLED
			box.border_color = Palette.CONTROL_DISABLED_BORDER
		t.set_stylebox(state, "GrowPip", box)
	t.set_constant("icon_max_width", "GrowPip", 20)


## "Link": a flat Button that reads as a title you can click (a header's way back, 118): dim, accent on hover.
static func _link(t: Theme) -> void:
	t.set_type_variation("Link", "Button")
	t.set_font_size("font_size", "Link", 26)
	t.set_font("font", "Link", display())
	t.set_color("font_color", "Link", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "Link", Palette.ACCENT)
	t.set_color("font_pressed_color", "Link", Palette.ACCENT)
	t.set_color("font_focus_color", "Link", Palette.ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:  # no box or padding: it sits in the breadcrumb's text
		t.set_stylebox(state, "Link", StyleBoxEmpty.new())


## An overlay's or a modal's panel; border defaults to DarkPanel's own.
static func dark_panel(border := Palette.EDGE) -> StyleBoxFlat:
	return UIKit.panel_style(Palette.RAISED, border, 24)


## The keyboard focus ring drawn over a focused button or field; same colour as a focused card's.
static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Palette.FOCUS
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(0)
	ring.set_expand_margin_all(4)
	return ring


static func _controls(t: Theme) -> void:
	for type: String in ["Button", "AccentButton"]:
		var accent := type == "AccentButton"
		if accent:
			t.set_type_variation(type, "Button")
		var fill := Palette.ACCENT if accent else Palette.CONTROL
		var text := Palette.TEXT_ON_ACCENT if accent else Palette.TEXT
		t.set_stylebox("normal", type, _box(fill, Palette.TEXT if accent else Palette.CONTROL_BORDER))
		t.set_stylebox("hover", type, _box(fill.lightened(0.08), Palette.TEXT))
		t.set_stylebox("pressed", type, _pressed(_box(fill.darkened(0.1), Palette.TEXT)))
		t.set_stylebox("hover_pressed", type, _pressed(_box(fill.darkened(0.04), Palette.TEXT)))  # a latched toggle
		t.set_stylebox("disabled", type, _flat(_box(Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER)))
		t.set_font("font", type, tabular(LABEL_SEMIBOLD if accent else LABEL_FONT))
		t.set_stylebox("focus", type, focus_ring())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, text)
		t.set_color("font_disabled_color", type, Palette.TEXT_DISABLED)
	t.set_stylebox("normal", "LineEdit", _box(Palette.FIELD, Palette.CONTROL_BORDER))
	t.set_stylebox("focus", "LineEdit", focus_ring())
	t.set_color("font_color", "LineEdit", Palette.TEXT)


static func _label(t: Theme, variation: String, font_size: int, color: Color, font: Font = null) -> void:
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


## Jost at Medium weight (500), the guide's display face: titles and the header's link back (178).
static func display() -> FontVariation:
	var f := tabular(DISPLAY_FONT)
	f.variation_opentype = {"wght": 500}
	return f


## A button's or field's box: the border 2 wide, a machined 2 px corner, room around the text, standing on a hard
## shadow (178, guide §6.5, §15.1).
static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(bg, border, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = PLINTH
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## style pressed into its shadow (178): a stylebox can't translate, so the drawn box moves PRESS px down and right
## through negative expand margins on the top and left and positive ones on the bottom and right, the content margins
## move its text with it, and the shadow is gone.
static func _pressed(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	style.expand_margin_left = -PRESS
	style.expand_margin_top = -PRESS
	style.expand_margin_right = PRESS
	style.expand_margin_bottom = PRESS
	style.content_margin_left += PRESS
	style.content_margin_right -= PRESS
	style.content_margin_top += PRESS
	style.content_margin_bottom -= PRESS
	return style


## style lying flat: no shadow (disabled controls).
static func _flat(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	return style
