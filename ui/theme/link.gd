extends RefCounted
## "Link": a flat Button that reads as a title you can click: dim, accent on hover.
## "TitleLink": the same in ink.


static func apply(t: Theme) -> void:
	t.set_type_variation("Link", "Button")
	t.set_font_size("font_size", "Link", Tokens.TYPE_TITLE)
	t.set_font("font", "Link", GameTheme.display())
	t.set_color("font_color", "Link", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "Link", Palette.ACCENT)
	t.set_color("font_pressed_color", "Link", Palette.ACCENT)
	t.set_color("font_focus_color", "Link", Palette.ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:  # no box or padding: it reads as text
		t.set_stylebox(state, "Link", StyleBoxEmpty.new())
	t.set_type_variation("TitleLink", "Link")  # a name you can click, in ink (the sidebar's civilization, 202)
	t.set_color("font_color", "TitleLink", Palette.TEXT)
	t.set_type_variation("CapsLink", "Link")  # a small caps link, ink on hover (the sidebar's government, 221)
	t.set_font_size("font_size", "CapsLink", Tokens.TYPE_HEADING)
	t.set_font("font", "CapsLink", GameTheme.heading_font())
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "CapsLink", Palette.TEXT)
