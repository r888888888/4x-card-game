class_name UIKit
extends RefCounted
## Shared building blocks for the board's components: layout constants, labels, buttons, overlays, and the small
## effects (pulses, error pop-ups) several components use. Colours come from Palette and the looks
## (Heading, Title, Stat, DarkPanel) from GameTheme (106).

const SECTION_GAP := Tokens.SPACE_5  # between the Realm and hand sections
const HEADING_GAP := Tokens.SPACE_2  # from a heading to its content
const CARD_GAP := Tokens.SPACE_3  # between cards in a row
const PAINTED := &"painted"  # the group of nodes with colours set in code, repainted when Day mode changes (183)

static var COST_COLOR: Color:  # tags for resources paid (181), and error text
	get:
		return Palette.COST
static var GAIN_COLOR: Color:  # tags for resources and VP gained (181)
	get:
		return Palette.GAIN


## Sets node's colours with apply now, and again whenever the palette switches (183): apply reads Palette when it
## runs. For colours set in code at build time; the theme (GameTheme) and anything a refresh sets follow by themselves.
static func painted(node: Node, apply: Callable) -> void:
	apply.call()
	node.add_to_group(PAINTED)
	if not node.has_meta("paint"):
		node.set_meta("paint", [])
	(node.get_meta("paint") as Array).append(apply)


## Reruns every painted node's colours in tree (after Palette.use).
static func repaint(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(PAINTED):
		for apply: Callable in node.get_meta("paint", []):
			apply.call()


## Reduce motion is on: no pulses, drifts or rolling figures.
static func calm() -> bool:
	return Settings.reduce_motion


## The outline of an empty card slot, at tableau-card size: the Realm's ghost, a territory's free slots (105).
static func slot_outline() -> Panel:
	var style := StyleBoxFlat.new()
	style.set_border_width_all(2)
	style.set_corner_radius_all(Tokens.RADIUS_0)  # cards are cut square
	var outline := Panel.new()
	painted(outline, func(): style.bg_color = Palette.GHOST_BG; style.border_color = Palette.GHOST_EDGE)
	outline.add_theme_stylebox_override("panel", style)
	outline.custom_minimum_size = CardView.TABLEAU_SIZE
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return outline


## A flat panel: bg with a border (1 wide when see-through, else 2), square corners (178) and padding all round (a Tokens.SPACE_* step, 193).
static func panel_style(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a < 1.0 else 2)
	style.set_corner_radius_all(0)  # paper is cut square (178, guide §6.3)
	style.set_content_margin_all(padding)
	return style


## Full-screen dimmer with a centred, opaque panel, added to parent; border_role names the Palette colour of its frame
## (EDGE, or a colour saying what it's about). The panel is stored as meta "panel" and its VBox as meta "box".
static func overlay(parent: Control, border_role := &"EDGE") -> Control:
	var dimmer := ColorRect.new()
	painted(dimmer, func(): dimmer.color = Palette.DIMMER)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	dimmer.z_index = 10  # above lifted and flying cards
	parent.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	if border_role != &"EDGE":  # a coloured border says what the overlay is about
		painted(panel, func(): panel.add_theme_stylebox_override("panel", GameTheme.dark_panel(Palette.color(border_role))))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", Tokens.SPACE_3)
	panel.add_child(box)
	dimmer.set_meta("panel", panel)
	dimmer.set_meta("box", box)
	return dimmer


## An overlay on parent (hidden) with a red border, a heading and lines of text, e.g. data load errors.
static func message_overlay(parent: Control, text: String, lines: Array[String]) -> Control:
	var dimmer := overlay(parent, &"WARN")
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


## An overlay's or a modal's title: the display face at type.title, in its own case (194).
static func title(text: String) -> Label:
	var label := Label.new()
	label.text = text
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


## A stat label in role's colour: a Palette role name, never a Color, so it follows a Day mode switch (183, 192).
static func stat(parent: Control, role: StringName = &"TEXT") -> Label:
	var label := Label.new()
	label.theme_type_variation = &"Stat"
	painted(label, func(): label.add_theme_color_override("font_color", Palette.color(role)))
	parent.add_child(label)
	return label


## word with "a" or "an" before it, by its first letter ("an Insight", "a Research").
static func with_article(word: String) -> String:
	return ("an " if "AEIOUaeiou".contains(word.left(1)) else "a ") + word


## A section's label: small capitals, tracked (194, guide type.heading); its text stays as written.
static func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.uppercase = true
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
	column.add_theme_constant_override("separation", Tokens.SPACE_3)
	for c in controls:
		c.size_flags_horizontal = Control.SIZE_FILL
		column.add_child(c)
	parent.add_child(column)
	return column


## The Reduce motion key (182): a LegendKey that latches while the setting is on. Toggling it sets and saves the
## setting; show_setting matches it to the setting. Put it on screen with setting_row.
static func motion_toggle() -> LegendKey:
	var key := LegendKey.new()
	key.tooltip_text = "No bouncing, shaking or tilting; cards jump to their place and fade in. Saved."
	key.toggled.connect(Settings.set_reduce_motion)
	return key


## The Day mode key (183): a LegendKey that latches while the Paper palette is on; toggling it sets and saves it.
static func day_toggle() -> LegendKey:
	var key := LegendKey.new()
	key.tooltip_text = "The drafting desk by day: warm paper and charcoal ink. Switches at once. Saved."
	key.toggled.connect(Settings.set_day_mode)
	return key


## The Interface sounds key (185): a LegendKey that latches while interface sounds are on; toggling it sets and saves it.
static func sound_toggle() -> LegendKey:
	var key := LegendKey.new()
	key.tooltip_text = "Clicks, panels and confirmations; event sounds stay on. Saved."
	key.toggled.connect(Settings.set_interface_sounds)
	return key


## A bus's volume row (185): its name, a slider from 0 to 100 in steps of 10 that sets and saves the bus's volume,
## and the figure ("70%"). The row's metas "slider" and "figure" hold them; show_volume matches them to the setting.
static func volume_row(text: String, bus: StringName, tooltip: String) -> HBoxContainer:
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.custom_minimum_size.x = 160
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.tooltip_text = tooltip
	var figure := Label.new()
	figure.custom_minimum_size.x = 56
	figure.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	figure.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider.value_changed.connect(func(value: float):
		figure.text = "%d%%" % roundi(value)
		Settings.set_volume(bus, roundi(value)))
	var row := setting_row(text, slider)
	row.add_child(figure)
	row.set_meta("slider", slider)
	row.set_meta("figure", figure)
	show_volume(row, Settings.volume(bus))
	return row


## Sets a volume_row's slider and figure to percent without telling Settings.
static func show_volume(row: HBoxContainer, percent: int) -> void:
	(row.get_meta("slider") as HSlider).set_value_no_signal(percent)
	(row.get_meta("figure") as Label).text = "%d%%" % percent


## Latches key to on (the Reduce motion or Day mode key) without telling Settings.
static func show_setting(key: LegendKey, on: bool) -> void:
	key.set_pressed_no_signal(on)


## A setting's row (182): its name on the left and key on the right, filling the width it is given (a button column's).
static func setting_row(text: String, key: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_4)
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(key)
	return row


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
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## A short message on a dark backing over the card, drifting up and fading out, on layer. width is the
## screen width it stays inside.
static func show_error(layer: Control, view: CardView, text: String, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.HINT_BG
	style.border_color = COST_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(Tokens.RADIUS_0)
	style.set_content_margin_all(Tokens.SPACE_3)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 3  # above flying cards
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(fx_label(text, Tokens.TYPE_BODY, COST_COLOR))
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
