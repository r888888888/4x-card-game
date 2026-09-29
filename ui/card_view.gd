class_name CardView
extends PanelContainer
## Visual for one card. It rests inside a slot Control that a zone's container lays out, and
## animates itself: it lifts on hover, slides when its slot moves, flies between slots on the
## shared effects layer, and follows the cursor while dragged. Hand cards emit drag_requested and
## double_clicked and discard_requested (right-click); pickable cards (a pending choice) emit picked. main.gd decides what those mean.

signal drag_requested(view: CardView, grab_offset: Vector2)
signal double_clicked(view: CardView)
signal discard_requested(view: CardView)
signal picked(view: CardView)

enum State { REST, FLYING, DRAGGING, LEAVING }

const TYPE_COLORS := {
	"action": Color("4a7fb5"),
	"building": Color("5f9a45"),
	"city": Color("c08a3e"),
	"territory": Color("8a6fb5"),
	"tech": Color("3fa7a0"),
}
const HAND_SIZE := Vector2(264, 320)
const TABLEAU_SIZE := Vector2(245, 175)
const COMPACT_SIZE := Vector2(245, 95)  # a frontier territory: name and info only
# A shape per type, so types can be told apart without colour. Drawn as icons (see Icons).
const TYPE_MARKS := {
	"action": "◆",
	"building": "■",
	"city": "●",
	"territory": "▲",
	"tech": "✦",
}
const WARN_COLOR := Color("ff6b6b")
const HIGHLIGHT_COLOR := Color("ffd966")
# A dimmed card (unplayable, or an idle building) greys its background and border, never its text.
const DIM_BG := Color("202328")
const DIM_BORDER := Color("50565e")
const STRIP_BG := Color("4a1f22")  # the reason strip at the bottom of a dimmed card
const STRIP_TEXT := Color("ffd6d1")
const FOCUS_COLOR := Color("5ec8ff")  # keyboard focus ring; distinct from gold (target) and red (warning)
const FOCUS_RING_GAP := 6.0  # px between the card's edge and its focus ring (outside or inside)

var uid := -1
var in_hand := false
var pickable := false  # an option of a pending choice or a target: a click picks it
var lift_on_hover := false  # lift and grow under the mouse like a hand card (supply cards, which have room)
var state := State.REST
var slot: Control  # where the card rests; laid out by the hand or tableau container
var fx_scale := Vector2.ONE  # tweened for squash, pop and shrink; multiplies the chased scale

var _style: StyleBoxFlat
var _color: Color
var _box: VBoxContainer
var _rules_tip := ""  # the full card text; the start of every tooltip
var _warning := false
var _highlight := false
var _dimmed := false
var _focused := false
var _hover := false
var _pressed := false
var _press_pos := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _last_mouse_x := 0.0
var _lift := 0.0
var _base_scale := 1.0
var _rest_offset := Vector2.ZERO  # eases back to zero after the slot moves
var _last_slot_pos := Vector2.ZERO
var _target_size := Vector2.ZERO
var _delay := 0.0  # seconds to wait before a dealt card starts flying
var _shake_x := 0.0
var _shake_on_land := false
var _layer: Control
var _fx_tween: Tween


## Builds (or rebuilds) the card's content. play_error: "" if playable, otherwise the reason
## (shown on the card and as tooltip). Ignored for tableau cards. compact leaves out the type line and
## rules (for frontier territories, to save height).
func setup(card: CardInstance, card_db: Dictionary, p_in_hand: bool, play_error := "", compact := false) -> void:
	uid = card.uid
	in_hand = p_in_hand
	pickable = false
	var def := card.def
	_color = TYPE_COLORS.get(def.type, Color.GRAY)
	_target_size = HAND_SIZE if in_hand else (COMPACT_SIZE if compact else TABLEAU_SIZE)
	custom_minimum_size = _target_size

	if _style == null:
		_style = StyleBoxFlat.new()
		_style.set_border_width_all(2)
		_style.set_corner_radius_all(8)
		_style.set_content_margin_all(12)
		_style.shadow_color = Color(0, 0, 0, 0.45)
		add_theme_stylebox_override("panel", _style)
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		size = _target_size
	_dimmed = false

	if _box != null:
		remove_child(_box)
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)

	_box.add_child(_label(def.name, 22))  # the title gets the full width

	# Type line, with the cost at its right on a hand card.
	var type_row := HBoxContainer.new()
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var subtitle: String = TYPE_MARKS.get(def.type, "") + " " + def.type.capitalize()
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	var subtitle_label := _rich_label(subtitle, 18, _color.lightened(0.5))
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(subtitle_label)
	if in_hand:
		var cost := _label(_cost_text(def.cost), 19, HIGHLIGHT_COLOR)
		cost.name = "Cost"
		cost.autowrap_mode = TextServer.AUTOWRAP_OFF  # the type line wraps around it instead
		type_row.add_child(cost)
	if not compact:
		_box.add_child(type_row)
	else:
		type_row.free()

	_rules_tip = def.rules_tooltip(card_db)
	var rules_text := "" if compact else def.rules_text(card_db)
	if rules_text != "":  # territories have none; an empty label would still take a line
		var rules := _rich_label(rules_text, 19)
		rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_box.add_child(rules)

	if def.type == "territory":
		var info := "▢%d ⌂%d" % [def.slots, def.housing]  # explained in the tooltip
		var names := def.keywords.map(func(k): return k.capitalize())
		if not names.is_empty():
			info += " · " + ", ".join(PackedStringArray(names))
		var info_label := _rich_label(info, 18, _color.lightened(0.5))
		info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_box.add_child(info_label)

	if def.vp > 0:
		_box.add_child(_label("%d VP" % def.vp, 20, Color("ffd966")))

	if in_hand:
		set_play_error(play_error)
	else:
		modulate = Color.WHITE
		_set_tip("")
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	_update_border()


## Updates the playable look of a hand card: tooltip, cursor, dimming, and a strip at the bottom
## saying why it can't be played.
func set_play_error(play_error: String) -> void:
	var playable := play_error == ""
	_set_tip("Drag into the tableau (or double-click) to play. Right-click to discard." if playable else play_error)
	mouse_default_cursor_shape = Control.CURSOR_DRAG if playable else Control.CURSOR_FORBIDDEN
	_set_dimmed(not playable, "" if playable else "⊘ " + play_error)


## Shows a revealed tech's price and passes: "Cost 4 wealth (was 5)", pass markers (●○○), and
## "last chance" on its final appearance. The numbers come from the engine.
func set_tech_info(cost: int, printed: int, passes: int, max_passes: int) -> void:
	var old := _box.get_node_or_null("TechInfo")
	if old != null:
		_box.remove_child(old)
		old.queue_free()
	var markers := "●".repeat(passes) + "○".repeat(max_passes - passes)
	var text := "Cost %d wealth" % cost
	if cost != printed:
		text += " (was %d)" % printed
	text += "\nPassed %s" % markers
	if passes == max_passes - 1:
		text += " · last chance"
	var info := _label(text, 19, HIGHLIGHT_COLOR)
	info.name = "TechInfo"
	_box.add_child(info)


## Shows a supply pile's price and copies left ("2 wealth · 1 left"). error: "" if it can be bought,
## otherwise the reason, which dims the card and leads its tooltip.
func set_buy_info(price: int, left: int, error: String) -> void:
	var info := _box.get_node_or_null("BuyInfo") as Label
	if info == null:
		info = _label("", 19, HIGHLIGHT_COLOR)
		info.name = "BuyInfo"
		_box.add_child(info)
	info.text = "%d wealth · %d left" % [price, left]
	_set_dimmed(error != "", "" if error == "" else "⊘ " + error)
	if error == "":
		_set_tip("Click to buy a copy into your discard.")
	else:
		tooltip_text = error + "\n\n" + _rules_tip
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if error == "" else Control.CURSOR_FORBIDDEN


## Dims a tableau building with no worker and marks it "Idle" (or clears that).
func set_idle(idle: bool) -> void:
	_set_dimmed(idle, "⊘ Idle: no worker" if idle else "")
	_set_tip("Idle: this territory has more buildings than pop, so this one skips upkeep." if idle else "")


## Makes a non-hand card clickable as a choice option or target (or not). tooltip says what a click does.
func set_pickable(on: bool, tooltip := "") -> void:
	pickable = on
	if in_hand:
		return
	_set_tip(tooltip if on else "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	if not on:
		_set_hover(false)


## Shows or hides the keyboard focus ring. A focused hand card also lifts like a hovered one.
func set_focused(on: bool) -> void:
	_focused = on
	if state == State.REST:
		z_index = 1 if (_hover or _focused) else 0
	queue_redraw()


## Tints the card red while it is held over the play area but can't be played there.
func set_warning(on: bool) -> void:
	_warning = on
	_update_border()


## Outlines the card in gold as a valid target for the card being played.
func set_highlight(on: bool) -> void:
	_highlight = on
	_update_border()


## Sets the tooltip: the full card text, a blank line, then hint (either part may be empty).
func _set_tip(hint: String) -> void:
	if _rules_tip == "" or hint == "":
		tooltip_text = _rules_tip + hint
	else:
		tooltip_text = _rules_tip + "\n\n" + hint


## Greys the card's background and border (not its text) and shows reason in a strip at the
## bottom, or undoes both.
func _set_dimmed(on: bool, reason: String) -> void:
	_dimmed = on
	var strip := _box.get_node_or_null("Reason") as PanelContainer
	if reason == "":
		if strip != null:
			_box.remove_child(strip)
			strip.queue_free()
	else:
		if strip == null:
			strip = PanelContainer.new()
			strip.name = "Reason"
			strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = STRIP_BG
			style.set_corner_radius_all(4)
			style.set_content_margin_all(6)
			strip.add_theme_stylebox_override("panel", style)
			strip.add_child(_rich_label("", 18, STRIP_TEXT))
			_box.add_child(strip)
		Icons.fill(strip.get_child(0) as RichTextLabel, reason, 18, STRIP_TEXT)
	_update_border()


# --- Movement ---

## Places the card at rest in slot immediately.
func attach(p_slot: Control) -> void:
	_set_slot(p_slot)
	if get_parent() == null:
		slot.add_child(self)
	else:
		reparent(slot)
	_come_to_rest()


## Starts at rest in slot, growing in from nothing (a card created on the tableau) after delay.
func pop_in(p_slot: Control, delay := 0.0) -> void:
	attach(p_slot)
	if _calm():
		_fade_in()
		return
	fx_scale = Vector2.ZERO
	var t := _play_fx()
	t.tween_interval(delay)
	t.tween_property(self, "fx_scale", Vector2.ONE, Anim.POP_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A quick squash and bounce back, the same as landing in a slot (nothing with reduce motion).
func squash() -> void:
	if _calm():
		return
	fx_scale = Anim.LAND_SQUASH
	_play_fx().tween_property(self, "fx_scale", Vector2.ONE, Anim.LAND_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Appears at from_point (the deck) on layer, fading in, and after delay flies to slot.
func deal(p_slot: Control, layer: Control, from_point: Vector2, delay: float) -> void:
	layer.add_child(self)
	global_position = from_point - size / 2
	fx_scale = Vector2.ONE if _calm() else Vector2(0.5, 0.5)
	modulate.a = 0.0
	fly_to_slot(p_slot, layer)
	_delay = delay
	var t := _play_fx()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(self, "fx_scale", Vector2.ONE, 0.25)


## Moves onto layer and flies to p_slot, easing its size to the slot's card size.
func fly_to_slot(p_slot: Control, layer: Control) -> void:
	_set_slot(p_slot)
	_to_layer(layer)
	state = State.FLYING
	_update_border()


## Flies back to its own slot (after a cancelled or refused drag).
func return_home() -> void:
	if state == State.DRAGGING or state == State.FLYING:
		fly_to_slot(slot, _layer)


## Shakes to say "no": now if resting, otherwise when it lands back in its slot.
func reject() -> void:
	if state == State.REST:
		_shake()
	else:
		_shake_on_land = true
		return_home()


func begin_drag(layer: Control, grab_offset: Vector2) -> void:
	_hover = false
	_to_layer(layer)
	_grab_offset = grab_offset
	_last_mouse_x = get_global_mouse_position().x
	state = State.DRAGGING
	_update_border()


## Leaves the board: optionally pops (first flying to via, e.g. the card it was played on), then
## shrinks and fades towards point, then frees itself.
func leave(layer: Control, point: Vector2, pop: bool, via: Variant = null) -> void:
	_to_layer(layer)
	state = State.LEAVING
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _play_fx()
	if _calm():  # fade out where it is
		t.tween_property(self, "modulate:a", 0.0, Anim.CALM_FADE_TIME)
		t.tween_callback(queue_free)
		return
	if via is Vector2:
		t.tween_property(self, "global_position", via - size / 2, Anim.TARGET_FLY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if pop:
		t.tween_property(self, "fx_scale", Vector2(1.15, 1.15), Anim.DISCARD_POP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "global_position", point - size / 2, Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "fx_scale", Vector2(0.3, 0.3), Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	pivot_offset = size / 2
	match state:
		State.REST:
			var w := 1.0 if _calm() else _weight(Anim.REST_SHARPNESS, delta)
			_rest_offset = _rest_offset.lerp(Vector2.ZERO, w)
			# Only hand and supply cards lift and grow: their rows have room for it; the scrolling frontier
			# and tableau would clip a lifted target, so those show hover by border and shadow alone.
			var lifted := (_hover or _focused) and (in_hand or lift_on_hover) and not _calm()
			_lift = lerpf(_lift, -Anim.HOVER_LIFT if lifted else 0.0, w)
			_base_scale = lerpf(_base_scale, Anim.HOVER_SCALE if lifted else 1.0, w)
			rotation = lerp_angle(rotation, 0.0, w)
			position = _rest_pos() + _rest_offset + Vector2(_shake_x, _lift)
			_fit_to_slot()
		State.FLYING:
			if _delay > 0.0:
				_delay -= delta
			elif not is_instance_valid(slot):
				state = State.REST
			else:
				var w := 1.0 if _calm() else _weight(Anim.FLY_SHARPNESS, delta)
				var target := slot.global_position + _rest_pos()
				var target_size := _fit_size()
				global_position = global_position.lerp(target, w)
				size = size.lerp(target_size, w)
				_base_scale = lerpf(_base_scale, 1.0, w)
				rotation = lerp_angle(rotation, 0.0, w)
				if global_position.distance_to(target) < Anim.ARRIVE_DISTANCE \
						and size.distance_to(target_size) < 1.0:
					_land()
		State.DRAGGING:
			var mouse := get_global_mouse_position()
			var calm := _calm()
			var w := 1.0 if calm else _weight(Anim.FOLLOW_SHARPNESS, delta)
			global_position = global_position.lerp(mouse - _grab_offset, w)
			var speed := (mouse.x - _last_mouse_x) / maxf(delta, 0.001)
			_last_mouse_x = mouse.x
			var tilt := 0.0 if calm else clampf(speed * Anim.TILT_PER_SPEED, -Anim.MAX_TILT, Anim.MAX_TILT)
			rotation = lerp_angle(rotation, tilt, w if calm else _weight(Anim.REST_SHARPNESS, delta))
			_base_scale = lerpf(_base_scale, 1.0 if calm else Anim.DRAG_SCALE, w)
	scale = _base_scale * fx_scale


func _land() -> void:
	reparent(slot)
	_come_to_rest()
	if _calm():
		_shake_on_land = false
		if modulate.a >= 1.0:  # not mid deal, which fades itself in
			_fade_in()
		return
	squash()
	if _shake_on_land:
		_shake_on_land = false
		_shake()


func _come_to_rest() -> void:
	state = State.REST
	z_index = 1 if _focused else 0
	_rest_offset = Vector2.ZERO
	_lift = 0.0
	rotation = 0.0
	position = _rest_pos()
	_fit_to_slot()
	_update_border()


func _shake() -> void:
	if _calm():
		return
	# Its own tween, so it can run on top of the landing squash.
	create_tween().tween_method(func(t: float):
		_shake_x = sin(t * PI * 6.0) * Anim.SHAKE_PX * (1.0 - t), 0.0, 1.0, Anim.SHAKE_TIME)


func _set_slot(p_slot: Control) -> void:
	if slot == p_slot:
		return
	if is_instance_valid(slot) and slot.item_rect_changed.is_connected(_on_slot_moved):
		slot.item_rect_changed.disconnect(_on_slot_moved)
	slot = p_slot
	_last_slot_pos = slot.position
	slot.item_rect_changed.connect(_on_slot_moved)


## The container moved our slot (a card left or joined the row). Keep the card where it was on
## screen and let _process slide it into the new place.
func _on_slot_moved() -> void:
	if state == State.REST:
		_rest_offset -= slot.position - _last_slot_pos
	_last_slot_pos = slot.position


func _to_layer(layer: Control) -> void:
	_layer = layer
	if get_parent() != layer:
		reparent(layer)
	z_index = 2  # above hovered hand cards


## The card's size: its nominal size, taller if its text needs more room.
func _fit_size() -> Vector2:
	return Vector2(_target_size.x, maxf(_target_size.y, get_combined_minimum_size().y))


## Keeps the card at its fitted size and the slot tall enough to hold it.
func _fit_to_slot() -> void:
	var fit := _fit_size()
	if size != fit:
		size = fit
	var need := fit.y + _rest_pos().y
	if slot.custom_minimum_size.y != need:
		slot.custom_minimum_size.y = need


func _rest_pos() -> Vector2:
	return Vector2(0, Anim.LIFT_ROOM) if in_hand else Vector2.ZERO


func _play_fx() -> Tween:
	if _fx_tween != null:
		_fx_tween.kill()
	_fx_tween = create_tween()
	return _fx_tween


func _draw() -> void:
	if _focused:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = FOCUS_COLOR
		ring.set_border_width_all(3)
		ring.set_corner_radius_all(12)
		# Outside a hand card; inside any other, where the frontier and tableau scroll boxes would
		# clip a ring drawn outside it.
		var gap := FOCUS_RING_GAP if in_hand else -FOCUS_RING_GAP
		draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(gap))


## Reduce motion is on: no lift, tilt, squash or shake, and cards jump to their place and fade in.
func _calm() -> bool:
	return Settings.reduce_motion


func _fade_in() -> void:
	modulate.a = 0.3
	_play_fx().tween_property(self, "modulate:a", 1.0, Anim.CALM_FADE_TIME)


static func _weight(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)


# --- Input and hover ---

func _gui_input(event: InputEvent) -> void:
	if pickable and state == State.REST and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		picked.emit(self)
		return
	if not in_hand or _delay > 0.0 or state == State.DRAGGING or state == State.LEAVING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		discard_requested.emit(self)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if not event.pressed:
			_pressed = false
		elif event.double_click:
			_pressed = false
			double_clicked.emit(self)
		else:
			_pressed = true
			_press_pos = event.position
	elif event is InputEventMouseMotion and _pressed:
		if event.position.distance_to(_press_pos) >= Anim.DRAG_START_DISTANCE:
			_pressed = false
			drag_requested.emit(self, _press_pos)


func _set_hover(on: bool) -> void:
	_hover = on and (in_hand or pickable) and state == State.REST
	if state == State.REST:
		z_index = 1 if (_hover or _focused) else 0  # draw over the neighbours while lifted
	_update_border()


func _update_border() -> void:
	_style.bg_color = DIM_BG if _dimmed else _color.darkened(0.65)
	if _warning:
		_style.border_color = WARN_COLOR
	elif _hover or state == State.DRAGGING:
		_style.border_color = Color.WHITE
	elif _highlight:
		_style.border_color = HIGHLIGHT_COLOR
	else:
		_style.border_color = DIM_BORDER if _dimmed else _color
	_style.shadow_size = 14 if (_hover or state == State.DRAGGING) else 0
	_style.set_border_width_all(4 if _highlight else 2)
	_style.shadow_offset = Vector2(0, 8)


static func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		if cost[r] > 0:
			parts.append("%d %s" % [cost[r], r])
	return "Free" if parts.is_empty() else ", ".join(parts)


## A card label. It wraps, so long text makes the card taller rather than wider than its slot.
static func _label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A card label for text that can hold glyphs (see Icons), which it draws as icons. Like _label it
## wraps and never takes mouse input. One line is exactly as tall as a Label's; wrapped lines sit 3px
## closer (a RichTextLabel adds its line_separation after the last line too, so it can't match both).
static func _rich_label(text: String, font_size: int, color := Color.WHITE) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Icons.fill(label, text, font_size, color)
	return label
