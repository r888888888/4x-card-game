extends RefCounted
## A popover (383; 379 reuses it): the printed tab of a tooltip (guide §11.11), ink with sheet text in Night and Day
## alike, cut square. Popover its panel, PopoverHeading its label-caps heading, PopoverBody its lines.


static func apply(t: Theme) -> void:
	var tab := UIKit.panel_style(Palette.TEXT, Palette.TEXT, Tokens.SPACE_4)
	tab.content_margin_top = Tokens.SPACE_3
	tab.content_margin_bottom = Tokens.SPACE_3
	t.set_type_variation("Popover", "PanelContainer")
	t.set_stylebox("panel", "Popover", tab)
	GameTheme.label(t, "PopoverHeading", Tokens.TYPE_LABEL_CAPS, Palette.RAISED,
		GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	GameTheme.label(t, "PopoverBody", Tokens.TYPE_BODY_S, Palette.RAISED)
