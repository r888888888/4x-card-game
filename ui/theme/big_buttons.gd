extends RefCounted
## BigButton and BigButtonPrimary (213, guide §15.12): an index card on a hard plinth; RAISED at rest, CONTROL under
## the pointer or the focus, pressed TRAVEL px into the plinth. The label children draw the text, so the Button's own is
## clear.


static func apply(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["BigButton", "BigButtonPrimary"]:
		t.set_type_variation(type, "Button")
		t.set_stylebox("normal", type, GameTheme.card(Palette.RAISED))
		t.set_stylebox("hover", type, GameTheme.card(Palette.CONTROL))
		t.set_stylebox("focus", type, GameTheme.card(Palette.CONTROL))
		var pressed := GameTheme.card(Palette.CONTROL)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, GameTheme.card(Palette.CONTROL_DISABLED))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)
