class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). Buttons, the accent button and text fields, plus type variations for the looks the UI repeats:
## Display, Title, Heading, Body, BodySmall, Caption, Stat and BarStat labels, RichBody text, DarkPanel (an overlay's or a modal's panel) and the pop meter's PipFilled, PipEmpty
## and GrowPip (124), and the selectable list's ListWell and ListRow (217). A control takes one with
## theme_type_variation instead of its own overrides.

const DEFAULT_FONT_SIZE := Tokens.TYPE_BODY  # everything without a size of its own (log, buttons, inputs)
const PIP_SIZE := 22  # a pop meter pip's width and height (124)
# The style guide's typefaces (178, §5): each is used through tabular(), so figures never shift width as they change.
const BODY_FONT := preload("res://assets/fonts/Barlow-Regular.ttf")
const ITALIC_FONT := preload("res://assets/fonts/Barlow-Italic.ttf")  # RichBody's [i], e.g. flavor (216)
const LABEL_FONT := preload("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
const LABEL_SEMIBOLD := preload("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Jost-Variable.ttf")
const PLINTH := Vector2(2, 2)  # a control's hard shadow (guide shadow.plinth)
const PRESS := 2  # px a pressed control travels into its shadow (guide travel.press)
const SHEET_SHADOW := Vector2(8, 8)  # a modal sheet's hard shadow (207, guide §15.11)
const SELECTED_SHADOW := Vector2(4, 4)  # a selected row's hard shadow (217, guide §4.4 "Selected")
const PULL := Tokens.SPACE_2  # px a selected row is pulled out of its list (217, guide §10.5)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = tabular(BODY_FONT)
	t.default_font_size = DEFAULT_FONT_SIZE
	_controls(t)
	_label(t, "Display", Tokens.TYPE_DISPLAY, Palette.TEXT, display())
	_label(t, "DisplayXL", Tokens.TYPE_DISPLAY_XL, Palette.TEXT, display())  # the era ceremony's name (211)
	_label(t, "Title", Tokens.TYPE_TITLE, Palette.TEXT, display())
	_label(t, "Heading", Tokens.TYPE_HEADING, Palette.TEXT_DIM, heading_font())  # UIKit.heading sets the capitals
	_label(t, "Body", Tokens.TYPE_BODY, Palette.TEXT)
	_label(t, "BodySmall", Tokens.TYPE_BODY_S, Palette.TEXT)
	_label(t, "Caption", Tokens.TYPE_CAPTION, Palette.TEXT_DIM)
	_label(t, "Stat", Tokens.TYPE_NUMERAL, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # each stat also sets its own colour: what it counts
	_label(t, "CardTitle", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a card's name, bold beside its rules (198)
	_label(t, "BigLabel", Tokens.TYPE_TITLE, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a BigButton's caps label (213)
	_label(t, "Forecast", Tokens.TYPE_NUMERAL_S, Palette.TEXT_DIM, tabular(LABEL_SEMIBOLD))  # a counter's next change (201)
	_label(t, "BarStat", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # body size like the bar's buttons, so it fits 1920 px (144)
	t.set_type_variation("RichBody", "RichTextLabel")  # modal text and the log (194)
	for size in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		t.set_font_size(size, "RichBody", Tokens.TYPE_BODY)
	t.set_font("italics_font", "RichBody", tabular(ITALIC_FONT))
	_link(t)
	_big_buttons(t)
	_end_turn_key(t)
	_select_list(t)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark_panel())
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet())
	_board_frame(t)
	_pips(t)
	_tech_tiles(t)
	return t


## The Knowledge screen's tech tiles (222, guide §11.3), index cards cut square: TechTile (available, or a later
## era's under its vellum) the sheet with an ink border, lifted onto its plinth on hover; TechTileResearched the teal
## plane; TechTileLocked the well with a rule border. TechTileText* is the text on each, and EraVellum the sheet at
## 88% laid over an era not reached.
static func _tech_tiles(t: Theme) -> void:
	var looks := {
		"TechTile": [Palette.TILE, Palette.TEXT, Palette.TEXT],
		"TechTileResearched": [Palette.RESEARCHED_FILL, Palette.TEXT, Palette.TEXT_ON_PLANE],
		"TechTileLocked": [Palette.FIELD, Palette.CONTROL_BORDER, Palette.TEXT_DISABLED],
	}
	for type: String in looks:
		var look: Array = looks[type]
		t.set_type_variation(type, "Button")
		var box := UIKit.panel_style(look[0], look[1], Tokens.SPACE_2)
		box.set_border_width_all(2)
		t.set_stylebox("normal", type, box)
		var lifted := box.duplicate() as StyleBoxFlat
		lifted.shadow_color = Palette.SHADOW
		lifted.shadow_offset = PLINTH
		lifted.shadow_size = 1  # solid, unblurred
		lifted.anti_aliasing = false
		t.set_stylebox("hover", type, lifted)
		t.set_stylebox("pressed", type, box)
		t.set_stylebox("disabled", type, box)
		t.set_stylebox("focus", type, focus_ring())
		_label(t, type.replace("TechTile", "TechTileText"), Tokens.TYPE_LABEL, look[2], tabular(LABEL_SEMIBOLD))
	t.set_type_variation("EraVellum", "PanelContainer")
	var vellum := UIKit.panel_style(Color(Palette.RAISED, 0.88), Color.TRANSPARENT, 0)
	vellum.set_border_width_all(0)  # no clear edge for the tiles to show through
	t.set_stylebox("panel", "EraVellum", vellum)


## The territory view's pop meter (124): a pip per housing, PipFilled for each pop and PipEmpty for the room left
## (Panels), and GrowPip, the button on the first empty pip: a pip-coloured border round its cost and food icon.
static func _pips(t: Theme) -> void:
	for variation: String in ["PipFilled", "PipEmpty"]:
		var filled := variation == "PipFilled"
		var pip := UIKit.panel_style(Palette.POP if filled else Color.TRANSPARENT, Palette.POP.darkened(0.0 if filled else 0.45), 0)
		pip.set_border_width_all(2)
		pip.set_corner_radius_all(Tokens.RADIUS_FULL)
		t.set_type_variation(variation, "Panel")
		t.set_stylebox("panel", variation, pip)
	t.set_type_variation("GrowPip", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := _box(Palette.CONTROL, Palette.POP)
		box.set_corner_radius_all(Tokens.RADIUS_FULL)
		box.content_margin_left = Tokens.SPACE_3
		box.content_margin_right = Tokens.SPACE_3
		box.content_margin_top = Tokens.SPACE_1
		box.content_margin_bottom = Tokens.SPACE_1
		if state == "hover":
			box.bg_color = Palette.CONTROL.lightened(0.08)
			box.border_color = Palette.TEXT
		elif state == "disabled":
			box.bg_color = Palette.CONTROL_DISABLED
			box.border_color = Palette.CONTROL_DISABLED_BORDER
		t.set_stylebox(state, "GrowPip", box)
	t.set_constant("icon_max_width", "GrowPip", 20)


## "Link": a flat Button that reads as a title you can click (a header's way back, 118): dim, accent on hover.
## "TitleLink": the same in ink.
static func _link(t: Theme) -> void:
	t.set_type_variation("Link", "Button")
	t.set_font_size("font_size", "Link", Tokens.TYPE_TITLE)
	t.set_font("font", "Link", display())
	t.set_color("font_color", "Link", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "Link", Palette.ACCENT)
	t.set_color("font_pressed_color", "Link", Palette.ACCENT)
	t.set_color("font_focus_color", "Link", Palette.ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:  # no box or padding: it sits in the breadcrumb's text
		t.set_stylebox(state, "Link", StyleBoxEmpty.new())
	t.set_type_variation("TitleLink", "Link")  # a name you can click, in ink (the sidebar's civilization, 202)
	t.set_color("font_color", "TitleLink", Palette.TEXT)
	t.set_type_variation("CapsLink", "Link")  # a small caps link, ink on hover (the sidebar's government, 221)
	t.set_font_size("font_size", "CapsLink", Tokens.TYPE_HEADING)
	t.set_font("font", "CapsLink", heading_font())
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "CapsLink", Palette.TEXT)


## The selectable list (217, guide §7): ListWell, the list's recessed well, with room on its trailing side for the
## pulled-out row; ListRow, a row printed on it with no box, and when selected (pressed) a sheet strip pulled PULL px
## out onto a hard shadow; ListRowQuiet, a ListRow with no focus ring. SelectList draws the selected row's index tab.
static func _select_list(t: Theme) -> void:
	t.set_type_variation("ListWell", "PanelContainer")
	var well := UIKit.panel_style(Palette.FIELD, Palette.FIELD, 0)
	well.set_border_width_all(0)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_top = Tokens.SPACE_2
	well.content_margin_bottom = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_4  # the pull and its shadow
	t.set_stylebox("panel", "ListWell", well)
	t.set_type_variation("ListRow", "Button")
	var flat := UIKit.panel_style(Palette.RAISED, Palette.RAISED, 0)
	flat.set_border_width_all(0)
	flat.content_margin_left = Tokens.SPACE_4
	flat.content_margin_right = Tokens.SPACE_4
	flat.content_margin_top = Tokens.SPACE_2
	flat.content_margin_bottom = Tokens.SPACE_2
	var printed := flat.duplicate() as StyleBoxFlat
	printed.draw_center = false
	t.set_stylebox("normal", "ListRow", printed)
	t.set_stylebox("hover", "ListRow", printed)
	var pulled := flat.duplicate() as StyleBoxFlat
	pulled.shadow_color = Palette.SHADOW
	pulled.shadow_offset = SELECTED_SHADOW
	pulled.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	pulled.anti_aliasing = false
	pulled.expand_margin_left = -PULL
	pulled.expand_margin_right = PULL
	pulled.content_margin_left += PULL
	pulled.content_margin_right -= PULL
	t.set_stylebox("pressed", "ListRow", pulled)
	t.set_stylebox("hover_pressed", "ListRow", pulled)
	t.set_font("font", "ListRow", tabular(LABEL_FONT))
	t.set_color("font_color", "ListRow", Palette.TEXT_DIM)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "ListRow", Palette.TEXT)
	t.set_type_variation("ListRowQuiet", "ListRow")  # a row the keyboard didn't focus: no ring (220)
	t.set_stylebox("focus", "ListRowQuiet", StyleBoxEmpty.new())


## The board's frame (221, the transitions mock's desk): Strip, the top bar's band, RAISED with a 3 px ink rule under
## it; Rail, the sidebar open on the board with a hairline on its left.
static func _board_frame(t: Theme) -> void:
	var strip := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_2)
	strip.set_border_width_all(0)
	strip.border_width_bottom = 3
	strip.content_margin_left = Tokens.SPACE_4
	strip.content_margin_right = Tokens.SPACE_4
	t.set_type_variation("Strip", "PanelContainer")
	t.set_stylebox("panel", "Strip", strip)
	var rail := UIKit.panel_style(Color.TRANSPARENT, Palette.HAIRLINE, Tokens.SPACE_4)
	rail.draw_center = false
	rail.set_border_width_all(0)
	rail.border_width_left = 1
	t.set_type_variation("Rail", "PanelContainer")
	t.set_stylebox("panel", "Rail", rail)


## An overlay's or a modal's panel; border defaults to DarkPanel's own.
static func dark_panel(border := Palette.EDGE) -> StyleBoxFlat:
	return UIKit.panel_style(Palette.RAISED, border, Tokens.SPACE_5)


## The keyboard focus ring drawn over a focused button or field; same colour as a focused card's.
## BigButton and BigButtonPrimary (213, guide §15.12): an index card on a hard plinth; RAISED at rest, CONTROL under
## the pointer or the focus, pressed TRAVEL px into the plinth. The label children draw the text, so the Button's own is
## clear.
static func _big_buttons(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["BigButton", "BigButtonPrimary"]:
		t.set_type_variation(type, "Button")
		t.set_stylebox("normal", type, _card(Palette.RAISED))
		t.set_stylebox("hover", type, _card(Palette.CONTROL))
		t.set_stylebox("focus", type, _card(Palette.CONTROL))
		var pressed := _card(Palette.CONTROL)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, _card(Palette.CONTROL_DISABLED))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)


## End turn's key (203, guide §15.12): EndTurnKey an ACCENT key in a 3 px ink border on a 4,4 plinth, pressed into it,
## disabled flat; EndTurnKeyBusy the same in CONTROL while the turn resolves. KeyLabel is its caps label; Plate the turn
## on a FIELD well, in tabular numerals (also the strip's turn, 201).
static func _end_turn_key(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["EndTurnKey", "EndTurnKeyBusy"]:
		var fill := Palette.ACCENT if type == "EndTurnKey" else Palette.CONTROL
		t.set_type_variation(type, "Button")
		for state in ["normal", "hover", "focus"]:
			var box := _card(fill.lightened(0.08) if state == "hover" else fill)
			box.set_corner_radius_all(Tokens.RADIUS_1)
			t.set_stylebox(state, type, box)
		var pressed := _card(fill.darkened(0.1))
		pressed.set_corner_radius_all(Tokens.RADIUS_1)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		var flat := _card(Palette.CONTROL_DISABLED)
		flat.set_corner_radius_all(Tokens.RADIUS_1)
		flat.border_color = Palette.CONTROL_DISABLED_BORDER
		flat.shadow_size = 0
		t.set_stylebox("disabled", type, flat)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)
	_label(t, "KeyLabel", Tokens.TYPE_BODY, Palette.TEXT_ON_ACCENT, heading_font())  # TYPE_BODY since 221
	_label(t, "Plate", Tokens.TYPE_NUMERAL_S, Palette.TEXT, tabular(LABEL_SEMIBOLD))
	_label(t, "StateWord", Tokens.TYPE_LABEL_CAPS, Palette.TEXT_DIM, heading_font())  # ON/OFF beside a toggle key (219)
	var well := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, Tokens.SPACE_1)
	well.set_border_width_all(1)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_2
	t.set_stylebox("normal", "Plate", well)


## A BigButton's card in fill: a 3 px ink border, square, on a 4,4 shadow.
static func _card(fill: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(fill, Palette.TEXT, Tokens.SPACE_0)
	style.set_border_width_all(3)
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = Vector2(BigButton.TRAVEL, BigButton.TRAVEL)
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## A modal's sheet (207, guide §15.11): RAISED in a 2 px ink rule, cut square, on a hard SHEET_SHADOW shadow.
static func sheet() -> StyleBoxFlat:
	var style := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_5)
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = SHEET_SHADOW
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


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
	_slider(t)


## A volume slider (185): a field-coloured slot with the travelled part filled like a lit lamp.
static func _slider(t: Theme) -> void:
	var slot := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, 0)
	slot.set_corner_radius_all(Tokens.RADIUS_1)
	slot.content_margin_top = Tokens.SPACE_1
	slot.content_margin_bottom = Tokens.SPACE_1
	t.set_stylebox("slider", "HSlider", slot)
	var filled := slot.duplicate() as StyleBoxFlat
	filled.bg_color = Palette.GAIN
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_stylebox("focus", "HSlider", focus_ring())


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


## The heading face (§5.2 type.heading): Barlow SemiCondensed SemiBold, tracked +10% for its capitals (194).
static func heading_font() -> FontVariation:
	var f := tabular(LABEL_SEMIBOLD)
	f.spacing_glyph = roundi(Tokens.TYPE_HEADING * 0.1)
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
	style.set_corner_radius_all(Tokens.RADIUS_1)
	style.content_margin_left = Tokens.SPACE_4
	style.content_margin_right = Tokens.SPACE_4
	style.content_margin_top = Tokens.SPACE_2
	style.content_margin_bottom = Tokens.SPACE_2
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
