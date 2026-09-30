class_name UIKit
extends RefCounted
## Shared building blocks for the board's components: layout constants, labels, buttons, overlays, and the small
## effects (pulses, flying tokens, error pop-ups) several components use. Colours come from Palette and the looks
## (Heading, Title, Stat, DarkPanel) from GameTheme (106).

const SECTION_GAP := 22  # between the frontier, tableau and hand sections
const HEADING_GAP := 6  # from a heading to its content
const CARD_GAP := 10  # between cards in a row
const COST_COLOR := Palette.COST  # tokens for resources paid, and error text
const GAIN_COLOR := Palette.GAIN  # tokens for resources and VP gained


## Reduce motion is on: no pulses, drifts or flying tokens.
static func calm() -> bool:
	return Settings.reduce_motion


## A flat panel: bg with a border (1 wide when see-through, else 2), round corners and padding all round.
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
static func overlay(parent: Control, border := Palette.EDGE) -> Control:
	var dimmer := ColorRect.new()
	dimmer.color = Palette.DIMMER
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	dimmer.z_index = 10  # above lifted and flying cards
	parent.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	if border != Palette.EDGE:  # a coloured border says what the overlay is about
		panel.add_theme_stylebox_override("panel", GameTheme.dark_panel(border))
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
	label.theme_type_variation = &"Title"
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
	label.theme_type_variation = &"Stat"
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


## word with "a" or "an" before it, by its first letter ("an Insight", "a Research").
static func with_article(word: String) -> String:
	return ("an " if "AEIOUaeiou".contains(word.left(1)) else "a ") + word


static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Heading"
	return label


static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # buttons fit their text (100); rows and tiles set SIZE_FILL
	b.pressed.connect(on_pressed)
	# Tab reaches every button (with a focus ring); a mouse click doesn't leave it focused, so a
	# later Enter or arrow key goes to the cards, not to the last button clicked.
	b.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and not event.pressed:
			b.release_focus.call_deferred())
	return b


## A stacked column of buttons for a menu or a screen (100), added to parent: controls share the widest one's width,
## and the column is centred in parent.
static func button_column(parent: Control, controls: Array[Control]) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	for c in controls:
		c.size_flags_horizontal = Control.SIZE_FILL
		column.add_child(c)
	parent.add_child(column)
	return column


## The Reduce motion toggle: a button that says its state in words (a checkbox's box is hard to read on this
## background). Toggling it sets and saves the setting; show_motion matches it to the setting.
static func motion_toggle() -> Button:
	var toggle := button("", func(): pass)
	toggle.toggle_mode = true
	toggle.tooltip_text = "No bouncing, shaking or tilting; cards jump to their place and fade in. Saved."
	toggle.toggled.connect(Settings.set_reduce_motion)
	return toggle


static func show_motion(toggle: Button, calm: bool) -> void:
	toggle.set_pressed_no_signal(calm)
	toggle.text = "Reduce motion: %s" % ("on" if calm else "off")


## Keeps keyboard focus inside controls: Tab/Shift+Tab and Up/Down wrap around them; Left/Right stay put.
static func focus_loop(controls: Array[Control]) -> void:
	for i in controls.size():
		var here := controls[i]
		var next := controls[(i + 1) % controls.size()]
		var prev := controls[i - 1]
		here.focus_next = here.get_path_to(next)
		here.focus_previous = here.get_path_to(prev)
		here.focus_neighbor_bottom = here.focus_next
		here.focus_neighbor_top = here.focus_previous
		here.focus_neighbor_left = NodePath(".")
		here.focus_neighbor_right = NodePath(".")


static func fx_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3  # above flying cards
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.OUTLINE)
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
	style.bg_color = Palette.HINT_BG
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
