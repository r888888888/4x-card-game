extends RefCounted
## The Knowledge screen's tech tiles (222, guide §11.3), index cards cut square: TechTile (available, or a later
## era's under its vellum) the sheet with an ink border; TechTileShort the same with muted text, for an available tech
## the insight doesn't cover yet (325); TechTileResearched the teal plane; TechTileLocked the well
## with a rule border. On hover each takes the index cards' ink rule on a 4 px shadow and the buttons' lighter fill
## (280). Each has a <name>Linked twin, the same with a TECH_LINK border at rest, for the tiles linked to the hovered
## tech (278). TechTileText* is the text on each, and EraVellum the sheet at 88% laid over an era not reached.


static func apply(t: Theme) -> void:
	var looks := {
		"TechTile": [Palette.TILE, Palette.TEXT, Palette.TEXT],
		"TechTileShort": [Palette.TILE, Palette.TEXT, Palette.TEXT_DISABLED],
		"TechTileResearched": [Palette.RESEARCHED_FILL, Palette.TEXT, Palette.TEXT_ON_PLANE],
		"TechTileLocked": [Palette.FIELD, Palette.CONTROL_BORDER, Palette.TEXT_DISABLED],
	}
	for type: String in looks:
		var look: Array = looks[type]
		t.set_type_variation(type, "Button")
		var box := UIKit.panel_style(look[0], look[1], Tokens.SPACE_2)
		box.set_border_width_all(2)
		t.set_stylebox("normal", type, box)
		var lifted := box.duplicate() as StyleBoxFlat
		lifted.border_color = Palette.TEXT  # the index cards' hover (179, 231): an ink rule on a 4 px shadow
		lifted.bg_color = look[0].lightened(0.08)  # and the buttons' lighter fill, which shows in Night too
		lifted.shadow_color = Palette.SHADOW
		lifted.shadow_offset = GameTheme.SELECTED_SHADOW
		lifted.shadow_size = 1  # solid, unblurred
		lifted.anti_aliasing = false
		t.set_stylebox("hover", type, lifted)
		t.set_stylebox("pressed", type, box)
		t.set_stylebox("disabled", type, box)
		t.set_stylebox("focus", type, GameTheme.focus_ring())
		GameTheme.label(t, type.replace("TechTile", "TechTileText"), Tokens.TYPE_LABEL, look[2], GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
		t.set_type_variation(type + "Linked", type)
		var link := box.duplicate() as StyleBoxFlat
		link.border_color = Palette.TECH_LINK
		t.set_stylebox("normal", type + "Linked", link)
		t.set_stylebox("hover", type + "Linked", lifted)  # the hovered tile wins over its link mark
		t.set_stylebox("pressed", type + "Linked", link)
		t.set_stylebox("disabled", type + "Linked", link)
	t.set_type_variation("EraVellum", "PanelContainer")
	var vellum := UIKit.panel_style(Color(Palette.RAISED, 0.88), Color.TRANSPARENT, 0)
	vellum.set_border_width_all(0)  # no clear edge for the tiles to show through
	t.set_stylebox("panel", "EraVellum", vellum)
