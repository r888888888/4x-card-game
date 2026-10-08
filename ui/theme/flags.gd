extends RefCounted
## A notification flag (250, guide §15.9): Flag, a RAISED strip in a 2 px ink rule open on its right (the rail's
## side, where its hue bar sits flush), cut square on a hard plinth; FlagText its one line at the label size; FlagClose
## its ×, flat text, ink on hover.


static func apply(t: Theme) -> void:
	var strip := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_0)  # the bar runs its full height
	strip.border_width_right = 0
	strip.content_margin_left = Tokens.SPACE_3
	strip.shadow_color = Palette.SHADOW
	strip.shadow_offset = GameTheme.PLINTH
	strip.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	strip.anti_aliasing = false
	t.set_type_variation("Flag", "PanelContainer")
	t.set_stylebox("panel", "Flag", strip)
	GameTheme.label(t, "FlagText", Tokens.TYPE_LABEL, Palette.TEXT, GameTheme.tabular(GameTheme.LABEL_FONT))
	t.set_type_variation("FlagClose", "Button")
	t.set_font_size("font_size", "FlagClose", Tokens.TYPE_TITLE)  # Barlow's × is small
	t.set_color("font_color", "FlagClose", Palette.TEXT_DIM)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "FlagClose", Palette.TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:  # no box: it reads as a printed ×
		t.set_stylebox(state, "FlagClose", StyleBoxEmpty.new())
