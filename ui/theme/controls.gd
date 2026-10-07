extends RefCounted


static func apply(t: Theme) -> void:
	for type: String in ["Button", "AccentButton"]:
		var accent := type == "AccentButton"
		if accent:
			t.set_type_variation(type, "Button")
		var fill := Palette.ACCENT if accent else Palette.CONTROL
		var text := Palette.TEXT_ON_ACCENT if accent else Palette.TEXT
		var rim := 3 if accent else 2  # the guide's primary button has a 3 px ink border (§7.1, 251)
		t.set_stylebox("normal", type, _rim(_box(fill, Palette.TEXT if accent else Palette.CONTROL_BORDER), rim))
		t.set_stylebox("hover", type, _rim(_box(fill.lightened(0.08), Palette.TEXT), rim))
		t.set_stylebox("pressed", type, _pressed(_rim(_box(fill.darkened(0.1), Palette.TEXT), rim)))
		# a latched toggle
		t.set_stylebox("hover_pressed", type, _pressed(_rim(_box(fill.darkened(0.04), Palette.TEXT), rim)))
		t.set_stylebox("disabled", type, _flat(_box(Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER)))
		t.set_font("font", type, GameTheme.tabular(GameTheme.LABEL_SEMIBOLD if accent else GameTheme.LABEL_FONT))
		t.set_stylebox("focus", type, GameTheme.focus_ring())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, text)
		t.set_color("font_disabled_color", type, Palette.TEXT_DISABLED)
	t.set_stylebox("normal", "LineEdit", _box(Palette.FIELD, Palette.CONTROL_BORDER))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())  # its caret shows the focus; Godot draws this box even when
	# FocusRing hides the focus (251)
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_DIM)
	t.set_color("font_color", "Label", Palette.TEXT)  # a plain label; Godot's default is white, unreadable on Day's paper (355)
	_slider(t)


## A volume slider (185): a field-coloured slot with the travelled part filled like a lit lamp.
static func _slider(t: Theme) -> void:
	var slot := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, 0)
	slot.set_corner_radius_all(Tokens.RADIUS_1)
	slot.content_margin_top = Tokens.SPACE_1
	slot.content_margin_bottom = Tokens.SPACE_1
	t.set_stylebox("slider", "HSlider", slot)
	var filled := slot.duplicate() as StyleBoxFlat
	filled.bg_color = Palette.GAIN
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_stylebox("focus", "HSlider", GameTheme.focus_ring())


## A button's or field's box: the border 2 wide, a machined 2 px corner, room around the text, standing on a hard
## shadow (178, guide §6.5, §15.1).
static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(bg, border, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(Tokens.RADIUS_1)
	style.content_margin_left = Tokens.SPACE_4
	style.content_margin_right = Tokens.SPACE_4
	style.content_margin_top = Tokens.SPACE_2
	style.content_margin_bottom = Tokens.SPACE_2
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = GameTheme.PLINTH
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## style with its border width px on every side.
static func _rim(style: StyleBoxFlat, width: int) -> StyleBoxFlat:
	style.set_border_width_all(width)
	return style


## style pressed into its shadow (178): a stylebox can't translate, so the drawn box moves GameTheme.PRESS px down and right
## through negative expand margins on the top and left and positive ones on the bottom and right, the content margins
## move its text with it, and the shadow is gone.
static func _pressed(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	style.expand_margin_left = -GameTheme.PRESS
	style.expand_margin_top = -GameTheme.PRESS
	style.expand_margin_right = GameTheme.PRESS
	style.expand_margin_bottom = GameTheme.PRESS
	style.content_margin_left += GameTheme.PRESS
	style.content_margin_right -= GameTheme.PRESS
	style.content_margin_top += GameTheme.PRESS
	style.content_margin_bottom -= GameTheme.PRESS
	return style


## style lying flat: no shadow (disabled controls).
static func _flat(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	return style
