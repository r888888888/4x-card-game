extends RefCounted
## A supply pile's price tag (232): a WEALTH plane hanging below the card, PriceTagText on it.


static func apply(t: Theme) -> void:
	var style := UIKit.panel_style(Palette.WEALTH, Palette.WEALTH, Tokens.SPACE_1)
	style.content_margin_left = Tokens.SPACE_3
	style.content_margin_right = Tokens.SPACE_3
	t.set_type_variation("PriceTag", "PanelContainer")
	t.set_stylebox("panel", "PriceTag", style)
	GameTheme.label(t, "PriceTagText", Tokens.TYPE_BODY, Palette.TEXT_ON_ACCENT, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
