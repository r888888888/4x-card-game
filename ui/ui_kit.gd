class_name UIKit
extends RefCounted
## Shared building blocks for the board's components: layout constants, the theme, labels, buttons, overlays,
## and the small effects (pulses, flying tokens, error pop-ups) several components use.

const SECTION_GAP := 22  # between the frontier, tableau and hand sections
const HEADING_GAP := 6  # from a heading to its content
const CARD_GAP := 10  # between cards in a row
const PANEL_COLOR := Color("171a1e")  # log panel background
const ACCENT := Color("e8c547")  # the main action's button (End turn)
const COST_COLOR := Color("ff8a80")  # tokens for resources paid, and error text
const GAIN_COLOR := Color("ffd966")  # tokens for resources and VP gained


## Reduce motion is on: no pulses, drifts or flying tokens.
static func calm() -> bool:
	return Settings.reduce_motion


## Button and text field looks: a visible fill and border, a hover state, and a disabled state that
## still reads. "AccentButton" (End turn) is the one main action.
static func style_controls(t: Theme) -> void:
	var box := func(bg: Color, border: Color) -> StyleBoxFlat:
		var style := panel_style(bg, border, 0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		return style
	for type: String in ["Button", "AccentButton"]:
		var accent := type == "AccentButton"
		if accent:
			t.set_type_variation(type, "Button")
		var fill := ACCENT if accent else Color("2f353d")
		var text := Color("1d2126") if accent else Color("e6ebf0")
		t.set_stylebox("normal", type, box.call(fill, ACCENT if accent else Color("78828e")))
		t.set_stylebox("hover", type, box.call(fill.lightened(0.15), Color.WHITE))
		t.set_stylebox("pressed", type, box.call(fill.darkened(0.2), Color.WHITE))
		t.set_stylebox("disabled", type, box.call(Color("24282d"), Color("4a5058")))
		t.set_stylebox("focus", type, focus_ring())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, text)
		t.set_color("font_disabled_color", type, Color("8d96a0"))
	t.set_stylebox("normal", "LineEdit", box.call(Color("14171a"), Color("78828e")))
	t.set_stylebox("focus", "LineEdit", focus_ring())
	t.set_color("font_color", "LineEdit", Color("e6ebf0"))


## The keyboard focus ring drawn over a focused button or field; same colour as a focused card's.
static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = CardView.FOCUS_COLOR
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(8)
	ring.set_expand_margin_all(3)
	return ring


static func panel_style(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a < 1.0 else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(padding)
	return style


## Full-screen dimmer with a centred, opaque panel, added to parent. The panel is stored as meta "panel" and
## its VBox as meta "box".
static func overlay(parent: Control, border := Color(1, 1, 1, 0.25)) -> Control:
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	dimmer.z_index = 10  # above lifted and flying cards
	parent.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(Color("262b31"), border, 24))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	dimmer.set_meta("panel", panel)
	dimmer.set_meta("box", box)
	return dimmer


## An overlay on parent (hidden) with a red border, a heading and lines of text, e.g. data load errors.
static func message_overlay(parent: Control, text: String, lines: Array[String]) -> Control:
	var dimmer := overlay(parent, CardView.WARN_COLOR)
	var box := dimmer.get_meta("box") as VBoxContainer
	box.add_child(heading(text))
	var body := RichTextLabel.new()
	body.custom_minimum_size = Vector2(800, 400)
	body.text = "\n".join(PackedStringArray(lines))
	box.add_child(body)
	return dimmer


## The buttons under node, in tree order.
static func buttons_in(node: Node) -> Array[Button]:
	return Array(node.find_children("*", "Button", true, false), TYPE_OBJECT, "Button", null)


## An overlay's title: bigger and white.
static func title(text: String) -> Label:
	var label := heading(text)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label


## A section of the board: a heading with its content close under it. Returns the VBox to add
## the content to.
static func section(parent: Control, text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", HEADING_GAP)
	box.add_child(heading(text))
	parent.add_child(box)
	return box


## A hidden section holding one scrolling row of cards, with tooltip (if any) on its heading. The row is stored
## as meta "row".
static func card_row_section(parent: Control, text: String, tooltip := "") -> VBoxContainer:
	var box := section(parent, text)
	box.hide()
	if tooltip != "":
		var label: Label = box.get_child(0)
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_STOP  # so the tooltip shows
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	scroll.add_child(row)
	box.set_meta("row", row)
	return box


static func stat(parent: Control, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("b4bcc6"))
	return label


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	# Tab reaches every button (with a focus ring); a mouse click doesn't leave it focused, so a
	# later Enter or arrow key goes to the cards, not to the last button clicked.
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed:
			b.release_focus.call_deferred())
	return b


static func fx_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3  # above flying cards
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label


## Sets a stat label, pulsing it when the value changes.
static func set_stat(label: Label, text: String) -> void:
	if label.text != "" and label.text != text:
		pulse(label)
	label.text = text


static func pulse(node: Control) -> void:
	if calm():
		return
	node.pivot_offset = node.size / 2
	node.scale = Vector2.ONE * Anim.PULSE_SCALE
	node.create_tween().tween_property(node, "scale", Vector2.ONE, Anim.PULSE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A resource token flying from from to to on layer, pulsing pulse_on_arrival (if any) when it lands.
static func fly_token(layer: Control, text: String, from: Vector2, to: Vector2, color: Color, pulse_on_arrival: Control, delay: float) -> void:
	var token := fx_label(text, 26, color)
	token.modulate.a = 0.0
	layer.add_child(token)
	token.reset_size()
	token.global_position = from - token.size / 2
	var t := token.create_tween()
	t.tween_interval(delay)
	if calm():  # appear at the counter, hold, fade
		token.global_position = to - token.size / 2
		t.tween_property(token, "modulate:a", 1.0, Anim.CALM_FADE_TIME)
		t.tween_interval(Anim.TOKEN_FLY_TIME)
		t.tween_property(token, "modulate:a", 0.0, Anim.CALM_FADE_TIME)
		t.tween_callback(token.queue_free)
		return
	t.tween_property(token, "modulate:a", 1.0, 0.1)
	t.tween_property(token, "global_position", to - token.size / 2, Anim.TOKEN_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if pulse_on_arrival != null:
		t.tween_callback(pulse.bind(pulse_on_arrival))
	t.tween_property(token, "modulate:a", 0.0, 0.12)
	t.tween_callback(token.queue_free)


## A short message on a dark backing over the card, drifting up and fading out, on layer. width is the
## screen width it stays inside.
static func show_error(layer: Control, view: CardView, text: String, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.border_color = COST_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 3  # above flying cards
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(fx_label(text, 20, COST_COLOR))
	layer.add_child(panel)
	panel.reset_size()
	var home := view.slot.get_global_rect() if is_instance_valid(view.slot) else view.get_global_rect()
	var x := clampf(home.get_center().x - panel.size.x / 2, 8.0, width - panel.size.x - 8.0)
	panel.global_position = Vector2(x, home.position.y + home.size.y * 0.35)
	var t := panel.create_tween()
	var drift := 0.0 if calm() else 30.0
	t.tween_property(panel, "global_position:y", panel.global_position.y - drift, Anim.ERROR_SHOW_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(panel, "modulate:a", 0.0, Anim.ERROR_SHOW_TIME) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(panel.queue_free)
