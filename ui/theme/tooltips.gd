extends RefCounted
## A tooltip, and the locked tip that uses the same types (187): a printed tab (233, guide §11.11), ink with sheet text
## in Night and Day alike, cut square, with room around the text.


static func apply(t: Theme) -> void:
	var tab := UIKit.panel_style(Palette.TEXT, Palette.TEXT, Tokens.SPACE_4)
	tab.content_margin_top = Tokens.SPACE_3
	tab.content_margin_bottom = Tokens.SPACE_3
	t.set_stylebox("panel", "TooltipPanel", tab)
	t.set_color("font_color", "TooltipLabel", Palette.RAISED)
	t.set_font_size("font_size", "TooltipLabel", Tokens.TYPE_BODY_S)
