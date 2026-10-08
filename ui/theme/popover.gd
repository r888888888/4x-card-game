extends RefCounted
## A popover (379): the tooltip's printed tab (guide §11.11), ink with sheet text in Night and Day alike, cut square,
## anchored under what opened it. PopoverHeading in label caps, then a two-column ledger of PopoverText and
## PopoverFigure, PopoverRule a hairline above each total.


static func apply(t: Theme) -> void:
	var tab := UIKit.panel_style(Palette.TEXT, Palette.TEXT, Tokens.SPACE_4)
	tab.content_margin_top = Tokens.SPACE_3
	tab.content_margin_bottom = Tokens.SPACE_3
	t.set_type_variation("Popover", "PanelContainer")
	t.set_stylebox("panel", "Popover", tab)
	GameTheme.label(t, "PopoverHeading", Tokens.TYPE_LABEL_CAPS, Palette.RAISED, GameTheme.heading_font())
	GameTheme.label(t, "PopoverText", Tokens.TYPE_BODY_S, Palette.RAISED)
	GameTheme.label(t, "PopoverFigure", Tokens.TYPE_NUMERAL_S, Palette.RAISED, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	var rule := StyleBoxLine.new()
	rule.color = Palette.RAISED
	rule.thickness = 1
	t.set_type_variation("PopoverRule", "HSeparator")
	t.set_stylebox("separator", "PopoverRule", rule)
	t.set_constant("separation", "PopoverRule", Tokens.SPACE_2)
