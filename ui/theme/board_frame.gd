extends RefCounted
## The board's frame (221, the transitions mock's desk): Strip, the top bar's band, walnut grain under RAISED with a
## 3 px ink rule under it (341); Rail, the sidebar open on the board with a hairline on its left, on the board's grain
## so a screen sliding in passes under it (224). The Sidebar lines its grain up with the board's (rail()).


static func apply(t: Theme) -> void:
	var strip := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_2)
	strip.set_border_width_all(0)
	strip.border_width_bottom = 3
	strip.content_margin_left = Tokens.SPACE_4
	strip.content_margin_right = Tokens.SPACE_4
	t.set_type_variation("Strip", "PanelContainer")
	t.set_stylebox("panel", "Strip", Surfaces.box(Surfaces.STRIP, strip))
	t.set_type_variation("Rail", "PanelContainer")
	t.set_stylebox("panel", "Rail", GameTheme.rail())
