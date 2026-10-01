class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). Buttons, the accent button and text fields, plus type variations for the looks the UI repeats:
## Heading, Title, Stat and BarStat labels, DarkPanel (an overlay's or a modal's panel) and the pop meter's PipFilled, PipEmpty
## and GrowPip (124). A control takes one with
## theme_type_variation instead of its own overrides.

const DEFAULT_FONT_SIZE := 20  # everything without a size of its own (log, buttons, inputs)
const PIP_SIZE := 22  # a pop meter pip's width and height (124)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = DEFAULT_FONT_SIZE
	_controls(t)
	_label(t, "Heading", 19, Palette.TEXT_DIM)
	_label(t, "Title", 26, Color.WHITE)
	_label(t, "Stat", 26, Color.WHITE)  # each stat also sets its own colour: what it counts
	_label(t, "BarStat", 20, Color.WHITE)  # the top bar's stats: 20 like its buttons, so the bar fits 1920 px (144)
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
			box.bg_color = Palette.CONTROL.lightened(0.15)
			box.border_color = Color.WHITE
		elif state == "disabled":
			box.bg_color = Palette.CONTROL_DISABLED
			box.border_color = Palette.CONTROL_DISABLED_BORDER
		t.set_stylebox(state, "GrowPip", box)
	t.set_constant("icon_max_width", "GrowPip", 20)


## "Link": a flat Button that reads as a title you can click (a header's way back, 118): dim, accent on hover.
static func _link(t: Theme) -> void:
	t.set_type_variation("Link", "Button")
	t.set_font_size("font_size", "Link", 26)
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
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(8)
	ring.set_expand_margin_all(3)
	return ring


static func _controls(t: Theme) -> void:
	for type: String in ["Button", "AccentButton"]:
		var accent := type == "AccentButton"
		if accent:
			t.set_type_variation(type, "Button")
		var fill := Palette.ACCENT if accent else Palette.CONTROL
		var text := Palette.TEXT_ON_ACCENT if accent else Palette.TEXT
		t.set_stylebox("normal", type, _box(fill, Palette.ACCENT if accent else Palette.CONTROL_BORDER))
		t.set_stylebox("hover", type, _box(fill.lightened(0.15), Color.WHITE))
		t.set_stylebox("pressed", type, _box(fill.darkened(0.2), Color.WHITE))
		t.set_stylebox("disabled", type, _box(Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER))
		t.set_stylebox("focus", type, focus_ring())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, text)
		t.set_color("font_disabled_color", type, Palette.TEXT_DISABLED)
	t.set_stylebox("normal", "LineEdit", _box(Palette.FIELD, Palette.CONTROL_BORDER))
	t.set_stylebox("focus", "LineEdit", focus_ring())
	t.set_color("font_color", "LineEdit", Palette.TEXT)


static func _label(t: Theme, variation: String, font_size: int, color: Color) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, font_size)
	t.set_color("font_color", variation, color)


## A button's or field's box: the border 2 wide, small corners, room around the text.
static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(bg, border, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
