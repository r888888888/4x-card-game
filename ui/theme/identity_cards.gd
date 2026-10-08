extends RefCounted
## The civilization modal's cards (231): IdentityCard a card on the desk (the board's fill in a 2 px rule, cut square,
## lifted onto its plinth with an ink rule on hover), Flavor its italic foot, and DeckTab a small tab per card in the
## government deck (the well in a rule of the government colour, thicker along its top).


static func apply(t: Theme) -> void:
	t.set_type_variation("IdentityCard", "Button")
	var card := UIKit.panel_style(Palette.BACKGROUND, Palette.CONTROL_BORDER, Tokens.SPACE_0)
	card.anti_aliasing = false
	var lifted := card.duplicate() as StyleBoxFlat
	lifted.border_color = Palette.TEXT
	lifted.shadow_color = Palette.SHADOW
	lifted.shadow_offset = GameTheme.SELECTED_SHADOW
	lifted.shadow_size = 1  # solid, unblurred
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "IdentityCard", card)
	t.set_stylebox("hover", "IdentityCard", lifted)
	t.set_stylebox("focus", "IdentityCard", GameTheme.focus_ring())
	# GivesCard: a card a tech gives, just its face (289); SlotButton: a free slot's "+ Build" (297), just its words
	for look in ["GivesCard", "SlotButton"]:
		t.set_type_variation(look, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(state, look, StyleBoxEmpty.new())
		t.set_stylebox("focus", look, GameTheme.focus_ring())
	GameTheme.label(t, "Flavor", Tokens.TYPE_BODY_S, Palette.TEXT_DIM, GameTheme.tabular(GameTheme.ITALIC_FONT))
	t.set_type_variation("DeckTab", "Button")
	t.set_font_size("font_size", "DeckTab", Tokens.TYPE_BODY_S)
	t.set_font("font", "DeckTab", GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	var tab := UIKit.panel_style(Palette.FIELD, Palette.GOVERNMENT, Tokens.SPACE_2)
	tab.set_border_width_all(1)
	tab.border_width_top = 3
	tab.content_margin_top = Tokens.SPACE_1
	tab.content_margin_bottom = Tokens.SPACE_1
	var tab_hover := tab.duplicate() as StyleBoxFlat
	tab_hover.border_color = Palette.TEXT
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "DeckTab", tab)
	t.set_stylebox("hover", "DeckTab", tab_hover)
	t.set_stylebox("focus", "DeckTab", GameTheme.focus_ring())
