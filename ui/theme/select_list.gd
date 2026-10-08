extends RefCounted
## The selectable list (217, guide §7.16): ListWell, the list's recessed well; ListRow, a row printed on it with no box,
## and when selected (pressed) a sheet strip in place, with no depth (356); ListRowQuiet, a ListRow with no focus ring.
## SelectList lights the selected row's lamp. And the scroll areas' VScrollBar (356, §7.17) and HScrollBar (363): a thin
## steel grabber on the well, ink-2 under the pointer and while dragged.


static func apply(t: Theme) -> void:
	t.set_type_variation("ListWell", "PanelContainer")
	var well := UIKit.panel_style(Palette.FIELD, Palette.FIELD, 0)
	well.set_border_width_all(0)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_top = Tokens.SPACE_2
	well.content_margin_bottom = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_2
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
	t.set_stylebox("pressed", "ListRow", flat)
	t.set_stylebox("hover_pressed", "ListRow", flat)
	t.set_font("font", "ListRow", GameTheme.tabular(GameTheme.LABEL_FONT))
	t.set_color("font_color", "ListRow", Palette.TEXT_DIM)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "ListRow", Palette.TEXT)
	t.set_type_variation("ListRowQuiet", "ListRow")  # a row the keyboard didn't focus: no ring (220)
	t.set_stylebox("focus", "ListRowQuiet", StyleBoxEmpty.new())
	_scroll_bar(t, "VScrollBar", [SIDE_LEFT, SIDE_RIGHT], [SIDE_TOP, SIDE_BOTTOM])
	_scroll_bar(t, "HScrollBar", [SIDE_TOP, SIDE_BOTTOM], [SIDE_LEFT, SIDE_RIGHT])  # sideways (363): the hand's


## A scrollbar's look on type: a FIELD track whose margins on its across sides make the bar 8 px thick, and a grabber
## whose margins on its along sides set its shortest length.
static func _scroll_bar(t: Theme, type: StringName, across: Array[Side], along: Array[Side]) -> void:
	var track := UIKit.panel_style(Palette.FIELD, Palette.FIELD, 0)
	track.set_border_width_all(0)
	for side in across:
		track.set_content_margin(side, Tokens.SPACE_1)  # the bar's 8 px thickness
	for state in ["scroll", "scroll_focus"]:
		t.set_stylebox(state, type, track)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := track.duplicate() as StyleBoxFlat
		grabber.bg_color = Palette.CONTROL if state == "grabber" else Palette.TEXT_DIM
		for side in along:
			grabber.set_content_margin(side, Tokens.SPACE_3)  # its shortest
		t.set_stylebox(state, type, grabber)
