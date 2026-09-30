class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). Buttons, the accent button and text fields, plus type variations for the looks the UI repeats:
## Heading, Title and Stat labels, and DarkPanel (an overlay's or a modal's panel). A control takes one with
## theme_type_variation instead of its own overrides.

const DEFAULT_FONT_SIZE := 20  # everything without a size of its own (log, buttons, inputs)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = DEFAULT_FONT_SIZE
	_controls(t)
	_label(t, "Heading", 19, Palette.TEXT_DIM)
	_label(t, "Title", 26, Color.WHITE)
	_label(t, "Stat", 26, Color.WHITE)  # each stat also sets its own colour: what it counts
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark_panel())
	return t


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
