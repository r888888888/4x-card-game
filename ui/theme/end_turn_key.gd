extends RefCounted
## End turn's key (203, guide §15.12): EndTurnKey an ACCENT key in a 3 px ink border on a 4,4 plinth, pressed into it,
## disabled flat; EndTurnKeyBusy the same in CONTROL while the turn resolves. KeyLabel is its caps label; Plate the turn
## on a FIELD well, in tabular numerals (also the strip's turn, 201).


static func apply(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["EndTurnKey", "EndTurnKeyBusy"]:
		var fill := Palette.ACCENT if type == "EndTurnKey" else Palette.CONTROL
		t.set_type_variation(type, "Button")
		for state in ["normal", "hover", "focus"]:
			var box := GameTheme.card(fill.lightened(0.08) if state == "hover" else fill)
			box.set_corner_radius_all(Tokens.RADIUS_1)
			t.set_stylebox(state, type, box)
		var pressed := GameTheme.card(fill.darkened(0.1))
		pressed.set_corner_radius_all(Tokens.RADIUS_1)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		var flat := GameTheme.card(Palette.CONTROL_DISABLED)
		flat.set_corner_radius_all(Tokens.RADIUS_1)
		flat.border_color = Palette.CONTROL_DISABLED_BORDER
		flat.shadow_size = 0
		t.set_stylebox("disabled", type, flat)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)
	GameTheme.label(t, "KeyLabel", Tokens.TYPE_BODY, Palette.TEXT_ON_ACCENT, GameTheme.heading_font())  # TYPE_BODY since 221
	GameTheme.label(t, "Plate", Tokens.TYPE_NUMERAL_S, Palette.TEXT, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD))
	GameTheme.label(t, "StateWord", Tokens.TYPE_LABEL_CAPS, Palette.TEXT_DIM, GameTheme.heading_font())  # ON/OFF beside a toggle key (219)
	var well := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, Tokens.SPACE_1)
	well.set_border_width_all(1)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_2
	t.set_stylebox("normal", "Plate", well)
