extends RefCounted
## The foot of a hand-size face whose rules don't all fit (383, guide §6.7): OverCount its "+N more" and "details" in
## the label face at caption size, dim; OverKey the I beside them, a small keycap.


static func apply(t: Theme) -> void:
	GameTheme.label(t, "OverCount", Tokens.TYPE_CAPTION, Palette.TEXT_DIM, GameTheme.tabular(GameTheme.LABEL_FONT))
	GameTheme.label(t, "OverKey", Tokens.TYPE_CAPTION, Palette.TEXT, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	var cap := UIKit.panel_style(Palette.RAISED, Palette.TEXT_DIM, Tokens.SPACE_1)
	cap.set_border_width_all(1)
	cap.set_corner_radius_all(Tokens.RADIUS_2)  # a keycap
	cap.content_margin_top = Tokens.SPACE_0
	cap.content_margin_bottom = Tokens.SPACE_0
	t.set_stylebox("normal", "OverKey", cap)
