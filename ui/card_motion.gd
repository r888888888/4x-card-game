class_name CardMotion
extends RefCounted
## How one CardView moves (backlog 086): at rest in its slot (lifting on hover, sliding when the slot moves), flying
## between slots on the shared effects layer, following the cursor while dragged, and leaving the board. The view's
## movement methods and _process hand off to this; it reads the view's hover, focus and size, and sets its state. It
## makes the card's sounds where its motion happens (188): a flick as a drag lifts it, a pat as a played card lands
## (place_on_land), a double tap as a refused card starts its shake.

var view: CardView
var delay := 0.0  # seconds to wait before a dealt card starts flying
var place_on_land := false  # a played card on its way: it pats down as it lands (188)
var _lift := 0.0
var _rest_offset := Vector2.ZERO  # eases back to zero after the slot moves
var _last_slot_pos := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _last_mouse_x := 0.0
var _shake_x := 0.0
var _shake_on_land := false
var _layer: Control
var _fx_tween: Tween


func _init(p_view: CardView) -> void:
	view = p_view


## Places the card at rest in slot immediately.
func attach(slot: Control) -> void:
	_set_slot(slot)
	if view.get_parent() == null:
		slot.add_child(view)
	else:
		view.reparent(slot)
	_come_to_rest()


## Starts at rest in slot, growing in from nothing (a card created on the tableau) after p_delay.
func pop_in(slot: Control, p_delay: float) -> void:
	attach(slot)
	if _calm():
		_fade_in()
		return
	view.fx_scale = Vector2.ZERO
	var t := _play_fx()
	t.tween_interval(p_delay)
	t.tween_property(view, "fx_scale", Vector2.ONE, Anim.POP_IN_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Appears at from_point (the deck) on layer, fading in, and after p_delay flies to slot.
func deal(slot: Control, layer: Control, from_point: Vector2, p_delay: float) -> void:
	layer.add_child(view)
	view.global_position = from_point - view.size / 2
	view.fx_scale = Vector2.ONE if _calm() else Vector2(0.5, 0.5)
	view.modulate.a = 0.0
	fly_to_slot(slot, layer)
	delay = p_delay
	var t := _play_fx()
	t.tween_interval(p_delay)
	t.tween_property(view, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(view, "fx_scale", Vector2.ONE, 0.25)


## Moves onto layer and flies to slot, easing its size to the slot's card size.
func fly_to_slot(slot: Control, layer: Control) -> void:
	_set_slot(slot)
	_to_layer(layer)
	view.state = CardView.State.FLYING
	view._update_border()


## Flies back to its own slot (after a cancelled or refused drag).
func return_home() -> void:
	if view.state == CardView.State.DRAGGING or view.state == CardView.State.FLYING:
		fly_to_slot(view.slot, _layer)


## Shakes to say "no": now if resting, otherwise when it lands back in its slot.
func reject() -> void:
	if view.state == CardView.State.REST:
		_refused()
	else:
		_shake_on_land = true
		return_home()


func begin_drag(layer: Control, grab_offset: Vector2) -> void:
	view._hover = false
	_to_layer(layer)
	_grab_offset = grab_offset
	_last_mouse_x = view.get_global_mouse_position().x
	view.state = CardView.State.DRAGGING
	view._update_border()
	var sfx := Sfx.find(view)
	if sfx != null:
		sfx.at_contact(Sfx.CARD_LIFT, Anim.LIFT_TIME, Anim.SNAP, true)


## Leaves the board: optionally pops (first flying to via, e.g. the card it was played on), then
## shrinks and fades towards point, calls on_arrival (if valid; not with Reduce motion), then frees the view.
func leave(layer: Control, point: Vector2, pop: bool, via: Variant, on_arrival := Callable()) -> void:
	_to_layer(layer)
	view.state = CardView.State.LEAVING
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _play_fx()
	if _calm():  # fade out where it is
		t.tween_property(view, "modulate:a", 0.0, Anim.CALM_FADE_TIME)
		t.tween_callback(view.queue_free)
		return
	if via is Vector2:
		t.tween_property(view, "global_position", via - view.size / 2, Anim.TARGET_FLY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if pop:
		t.tween_property(view, "fx_scale", Vector2(1.15, 1.15), Anim.DISCARD_POP_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(view, "global_position", point - view.size / 2, Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(view, "fx_scale", Vector2(0.3, 0.3), Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(view, "modulate:a", 0.0, Anim.DISCARD_FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if on_arrival.is_valid():
		t.tween_callback(on_arrival)
	t.tween_callback(view.queue_free)


## One frame: chase the rest place, the slot or the cursor, depending on the view's state.
func process(delta: float) -> void:
	view.pivot_offset = view.size / 2
	match view.state:
		CardView.State.REST:
			var w := 1.0 if _calm() else _weight(Anim.REST_SHARPNESS, delta)
			_rest_offset = _rest_offset.lerp(Vector2.ZERO, w)
			# Only hand and supply cards lift: their rows have room for it; the scrolling frontier and tableau
			# would clip a lifted target, so those show hover by border and shadow alone. Nothing grows (179).
			var lifted := (view._hover or view._focused) and (view.in_hand or view.lift_on_hover) and not _calm()
			_lift = lerpf(_lift, -Anim.HOVER_LIFT if lifted else 0.0, w)
			view.rotation = lerp_angle(view.rotation, 0.0, w)
			view.position = _rest_pos() + _rest_offset + Vector2(_shake_x, _lift)
			_fit_to_slot()
		CardView.State.FLYING:
			if delay > 0.0:
				delay -= delta
			elif not is_instance_valid(view.slot):
				view.state = CardView.State.REST
			else:
				var w := 1.0 if _calm() else _weight(Anim.FLY_SHARPNESS, delta)
				var target := view.slot.global_position + _rest_pos()
				var target_size := _fit_size()
				view.global_position = view.global_position.lerp(target, w)
				view.size = view.size.lerp(target_size, w)
				view.rotation = lerp_angle(view.rotation, 0.0, w)
				if view.global_position.distance_to(target) < Anim.ARRIVE_DISTANCE \
						and view.size.distance_to(target_size) < 1.0:
					_land()
		CardView.State.DRAGGING:
			var mouse := view.get_global_mouse_position()
			var calm := _calm()
			var w := 1.0 if calm else _weight(Anim.FOLLOW_SHARPNESS, delta)
			view.global_position = view.global_position.lerp(mouse - _grab_offset, w)
			var speed := (mouse.x - _last_mouse_x) / maxf(delta, 0.001)
			_last_mouse_x = mouse.x
			var tilt := 0.0 if calm else clampf(speed * Anim.TILT_PER_SPEED, -Anim.MAX_TILT, Anim.MAX_TILT)
			view.rotation = lerp_angle(view.rotation, tilt, w if calm else _weight(Anim.REST_SHARPNESS, delta))
	view.scale = view.fx_scale


## The size of the slot the card rests in: its nominal size, plus the lift room above a hand card. A card whose
## text needs more room grows its slot once it is at rest.
func slot_size() -> Vector2:
	return view._target_size + _rest_pos()


func _land() -> void:
	view.reparent(view.slot)
	_come_to_rest()  # with a firm stop: no squash (179)
	if place_on_land:
		place_on_land = false
		_play(Sfx.CARD_PLACE)
	if _shake_on_land:
		_shake_on_land = false
		_refused()
	if _calm() and view.modulate.a >= 1.0:  # not mid deal, which fades itself in
		_fade_in()


## Refused: the double tap as the shake starts (with Reduce motion, the tap alone).
func _refused() -> void:
	_play(Sfx.REJECT, true)
	_shake()


func _play(token: StringName, input := false) -> void:
	var sfx := Sfx.find(view)
	if sfx != null:
		sfx.play(token, 0.0, input)


func _come_to_rest() -> void:
	view.state = CardView.State.REST
	view.z_index = 1 if view._focused else 0
	_rest_offset = Vector2.ZERO
	_lift = 0.0
	view.rotation = 0.0
	view.position = _rest_pos()
	_fit_to_slot()
	view._update_border()


func _shake() -> void:
	if _calm():
		return
	# Its own tween, so it can run on top of a fade.
	view.create_tween().tween_method(func(t: float):
		_shake_x = sin(t * PI * 6.0) * Anim.SHAKE_PX * (1.0 - t), 0.0, 1.0, Anim.SHAKE_TIME)


func _set_slot(slot: Control) -> void:
	if view.slot == slot:
		return
	if is_instance_valid(view.slot) and view.slot.item_rect_changed.is_connected(_on_slot_moved):
		view.slot.item_rect_changed.disconnect(_on_slot_moved)
	view.slot = slot
	_last_slot_pos = slot.position
	slot.item_rect_changed.connect(_on_slot_moved)


## The container moved our slot (a card left or joined the row). Keep the card where it was on
## screen and let process slide it into the new place.
func _on_slot_moved() -> void:
	if view.state == CardView.State.REST:
		_rest_offset -= view.slot.position - _last_slot_pos
	_last_slot_pos = view.slot.position


func _to_layer(layer: Control) -> void:
	_layer = layer
	if view.get_parent() != layer:
		view.reparent(layer)
	view.z_index = 2  # above hovered hand cards


## The card's size: its nominal size, taller if its text needs more room.
func _fit_size() -> Vector2:
	return Vector2(view._target_size.x, maxf(view._target_size.y, view.get_combined_minimum_size().y))


## Keeps the card at its fitted size and the slot tall enough to hold it.
func _fit_to_slot() -> void:
	var fit := _fit_size()
	if view.size != fit:
		view.size = fit
	var need := fit.y + _rest_pos().y
	if view.slot.custom_minimum_size.y != need:
		view.slot.custom_minimum_size.y = need


func _rest_pos() -> Vector2:
	return Vector2(0, Anim.LIFT_ROOM) if view.in_hand else Vector2.ZERO


func _play_fx() -> Tween:
	if _fx_tween != null:
		_fx_tween.kill()
	_fx_tween = view.create_tween()
	return _fx_tween


## Reduce motion is on: no lift, tilt or shake, and cards jump to their place and fade in.
func _calm() -> bool:
	return Settings.reduce_motion


func _fade_in() -> void:
	view.modulate.a = 0.3
	_play_fx().tween_property(view, "modulate:a", 1.0, Anim.CALM_FADE_TIME)


static func _weight(sharpness: float, delta: float) -> float:
	return 1.0 - exp(-sharpness * delta)
