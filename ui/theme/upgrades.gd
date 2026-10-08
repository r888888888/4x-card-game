extends RefCounted
## Upgrades (302): Ribbon an upgrade along its base's foot (a hairline over it), RibbonName its name in semibold,
## UpgradeBadge the ▲ on a building with an upgrade not yet built (410; a caption in the territory colour) and TierStamp
## the tier an upgrade's face needs (Caption in the territory colour, in a 2 px rule).


static func apply(t: Theme) -> void:
	t.set_type_variation("Ribbon", "PanelContainer")
	var ribbon := StyleBoxFlat.new()
	ribbon.draw_center = false
	ribbon.border_color = Palette.HAIRLINE
	ribbon.border_width_top = 1
	ribbon.content_margin_left = Tokens.SPACE_1
	ribbon.content_margin_right = Tokens.SPACE_1
	ribbon.content_margin_top = Tokens.SPACE_1
	ribbon.content_margin_bottom = Tokens.SPACE_1
	t.set_stylebox("panel", "Ribbon", ribbon)
	GameTheme.label(t, "RibbonName", Tokens.TYPE_BODY_S, Palette.TEXT, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	GameTheme.label(t, "UpgradeBadge", Tokens.TYPE_CAPTION, Palette.TERRITORY, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	GameTheme.label(t, "TierStamp", Tokens.TYPE_CAPTION, Palette.TERRITORY, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	var stamp := UIKit.panel_style(Color.TRANSPARENT, Palette.TERRITORY, Tokens.SPACE_1)
	stamp.set_border_width_all(2)
	t.set_stylebox("normal", "TierStamp", stamp)
