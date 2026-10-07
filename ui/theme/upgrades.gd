extends RefCounted
## Upgrades (302): Ribbon an upgrade along its base's foot (a hairline over it), RibbonName its name in semibold,
## UpgradeChip the "+ Upgrade" key (a free slot's ghost outline at chip size, in caption capitals) and TierStamp the tier
## an upgrade's face needs (Caption in the territory colour, in a 2 px rule).


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
	t.set_type_variation("UpgradeChip", "Button")
	t.set_font("font", "UpgradeChip", GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	t.set_font_size("font_size", "UpgradeChip", Tokens.TYPE_CAPTION)
	t.set_color("font_color", "UpgradeChip", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "UpgradeChip", Palette.TEXT)
	var chip := UIKit.panel_style(Palette.GHOST_BG, Palette.GHOST_EDGE, Tokens.SPACE_1)
	chip.set_border_width_all(1)
	chip.content_margin_left = Tokens.SPACE_2
	chip.content_margin_right = Tokens.SPACE_2
	var chip_hover := chip.duplicate() as StyleBoxFlat
	chip_hover.border_color = Palette.TEXT
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "UpgradeChip", chip)
	t.set_stylebox("hover", "UpgradeChip", chip_hover)
	t.set_stylebox("focus", "UpgradeChip", GameTheme.focus_ring())
	GameTheme.label(t, "TierStamp", Tokens.TYPE_CAPTION, Palette.TERRITORY, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	var stamp := UIKit.panel_style(Color.TRANSPARENT, Palette.TERRITORY, Tokens.SPACE_1)
	stamp.set_border_width_all(2)
	t.set_stylebox("normal", "TierStamp", stamp)
