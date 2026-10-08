extends RefCounted
## A navigated screen's title bar (241): BarTitle and BarHeading, the title and its context printed on the bar's
## colour; DividerTab, the way back at its left end, the index tab of the sheet underneath: the board's colour, its
## right edge slanted (a skewed box whose left edge runs off the bar, which clips it), the sheet colour on hover.


static func apply(t: Theme) -> void:
	GameTheme.label(t, "BarTitle", Tokens.TYPE_TITLE, Palette.TEXT_ON_PLANE, GameTheme.display())
	GameTheme.label(t, "BarHeading", Tokens.TYPE_HEADING, Palette.TEXT_ON_PLANE, GameTheme.heading_font())
	t.set_type_variation("DividerTab", "Button")
	t.set_font("font", "DividerTab", GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	t.set_font_size("font_size", "DividerTab", Tokens.TYPE_LABEL)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "DividerTab", Palette.TEXT)
	var tab := UIKit.panel_style(Palette.BACKGROUND, Palette.BACKGROUND, Tokens.SPACE_3)
	tab.set_border_width_all(0)
	tab.skew = Vector2(-0.3, 0)
	tab.expand_margin_left = Tokens.SPACE_5
	tab.content_margin_left = Tokens.SPACE_4
	tab.content_margin_right = Tokens.SPACE_6
	var hover := tab.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.RAISED
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "DividerTab", tab)
	t.set_stylebox("hover", "DividerTab", hover)
	t.set_stylebox("focus", "DividerTab", GameTheme.focus_ring())
