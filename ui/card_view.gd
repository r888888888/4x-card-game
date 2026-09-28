class_name CardView
extends PanelContainer
## Visual for one card. It rests inside a slot Control that the hand or tableau container lays
## out, and animates itself: it lifts on hover, slides when its slot moves, flies between slots on
## the shared effects layer, and follows the cursor while dragged. Hand cards emit drag_requested
## and double_clicked; main.gd decides what those mean.

signal drag_requested(view: CardView, grab_offset: Vector2)
signal double_clicked(view: CardView)

enum State { REST, FLYING, DRAGGING, LEAVING }

const TYPE_COLORS := {
	"action": Color("4a7fb5"),
	"building": Color("5f9a45"),
	"city": Color("c08a3e"),
}
const HAND_SIZE := Vector2(215, 280)
const TABLEAU_SIZE := Vector2(215, 150)
const WARN_COLOR := Color("ff6b6b")

var uid := -1
var in_hand := false
var state := State.REST
var slot: Control  # where the card rests; laid out by the hand or tableau container
var fx_scale := Vector2.ONE  # tweened for squash, pop and shrink; multiplies the chased scale

var _style: StyleBoxFlat
var _color: Color
var _box: VBoxContainer
var _playable := true
var _warning := false
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
## (shown as tooltip). Ignored for tableau cards.
func setup(card: CardInstance, card_db: Dictionary, p_in_hand: bool, play_error := "") -> void:
	uid = card.uid
	in_hand = p_in_hand
	var def := card.def
	_color = TYPE_COLORS.get(def.type, Color.GRAY)
	_target_size = HAND_SIZE if in_hand else TABLEAU_SIZE
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
	_style.bg_color = _color.darkened(0.65)
	_style.border_color = _color

	if _box != null:
		remove_child(_box)
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(header)
	var title := _label(def.name, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if in_hand:
		var cost := _label(_cost_text(def.cost), 19)
		cost.name = "Cost"
		header.add_child(cost)

	var subtitle := def.type.capitalize()
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	_box.add_child(_label(subtitle, 16, _color.lightened(0.5)))

	var rules := _label(def.rules_text(card_db), 19)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(rules)

	if def.vp > 0:
		_box.add_child(_label("%d VP" % def.vp, 20, Color("ffd966")))

	if in_hand:
		set_play_error(play_error)
	else:
		_playable = true
		modulate = Color.WHITE
		tooltip_text = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW


## Updates the playable look of a hand card: cost colour, tooltip, cursor, greying.
func set_play_error(play_error: String) -> void:
	_playable = play_error == ""
	var cost := _box.get_node_or_null("Cost") as Label
	if cost != null:
		cost.add_theme_color_override("font_color", Color("ffd966") if _playable else Color("ff8a80"))
	tooltip_text = "Drag into the tableau (or double-click) to play." if _playable else play_error
	mouse_default_cursor_shape = Control.CURSOR_DRAG if _playable else Control.CURSOR_FORBIDDEN
	# Greyed but still readable; the red cost shows why.
	modulate = Color.WHITE if _playable else Color(0.68, 0.68, 0.68)


## Tints the card red while it is held over the play area but can't be played there.
func set_warning(on: bool) -> void:
	_warning = on
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


## Starts at rest in slot, growing in from nothing (a card created on the tableau).
func pop_in(p_slot: Control) -> void:
	attach(p_slot)
	fx_scale = Vector2.ZERO
	_play_fx().tween_property(self, "fx_scale", Vector2.ONE, Anim.POP_IN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Appears at from_point (the deck) on layer, fading in, and after delay flies to slot.
func deal(p_slot: Control, layer: Control, from_point: Vector2, delay: float) -> void:
	layer.add_child(self)
	global_position = from_point - size / 2
	fx_scale = Vector2(0.5, 0.5)
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


## Leaves the board: optionally pops, then shrinks and fades towards point, then frees itself.
func leave(layer: Control, point: Vector2, pop: bool) -> void:
	_to_layer(layer)
	state = State.LEAVING
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _play_fx()
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
			var w := _weight(Anim.REST_SHARPNESS, delta)
			_rest_offset = _rest_offset.lerp(Vector2.ZERO, w)
			_lift = lerpf(_lift, -Anim.HOVER_LIFT if _hover else 0.0, w)
			_base_scale = lerpf(_base_scale, Anim.HOVER_SCALE if _hover else 1.0, w)
			rotation = lerp_angle(rotation, 0.0, w)
			position = _rest_pos() + _rest_offset + Vector2(_shake_x, _lift)
			_fit_to_slot()
		State.FLYING:
			if _delay > 0.0:
				_delay -= delta
			elif not is_instance_valid(slot):
				state = State.REST
			else:
				var w := _weight(Anim.FLY_SHARPNESS, delta)
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
			var w := _weight(Anim.FOLLOW_SHARPNESS, delta)
			global_position = global_position.lerp(mouse - _grab_offset, w)
			var speed := (mouse.x - _last_mouse_x) / maxf(delta, 0.001)
			_last_mouse_x = mouse.x
			var tilt := clampf(speed * Anim.TILT_PER_SPEED, -Anim.MAX_TILT, Anim.MAX_TILT)
			rotation = lerp_angle(rotation, tilt, _weight(Anim.REST_SHARPNESS, delta))
			_base_scale = lerpf(_base_scale, Anim.DRAG_SCALE, w)
	scale = _base_scale * fx_scale


func _land() -> void:
	reparent(slot)
	_come_to_rest()
	fx_scale = Anim.LAND_SQUASH
	_play_fx().tween_property(self, "fx_scale", Vector2.ONE, Anim.LAND_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _shake_on_land:
		_shake_on_land = false
		_shake()


func _come_to_rest() -> void:
	state = State.REST
	z_index = 0
	_rest_offset = Vector2.ZERO
	_lift = 0.0
	rotation = 0.0
	position = _rest_pos()
	_fit_to_slot()
	_update_border()


func _shake() -> void:
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


static func _weight(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)


# --- Input and hover ---

func _gui_input(event: InputEvent) -> void:
	if not in_hand or _delay > 0.0 or state == State.DRAGGING or state == State.LEAVING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
	_hover = on and in_hand and state == State.REST
	if state == State.REST:
		z_index = 1 if _hover else 0  # draw over the neighbours while lifted
	_update_border()


func _update_border() -> void:
	if _warning:
		_style.border_color = WARN_COLOR
	elif _hover or state == State.DRAGGING:
		_style.border_color = Color.WHITE
	else:
		_style.border_color = _color
	_style.shadow_size = 14 if (_hover or state == State.DRAGGING) else 0
	_style.shadow_offset = Vector2(0, 8)


static func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		if cost[r] > 0:
			parts.append("%d %s" % [cost[r], r])
	return "Free" if parts.is_empty() else ", ".join(parts)


static func _label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
