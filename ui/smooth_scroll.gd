class_name SmoothScroll
extends ScrollContainer
## A scroll area that glides (backlog 356, guide §7.17): it takes the mouse wheel itself, so a notch pushes the content
## and the push decays (Anim.SCROLL_FRICTION), easing it Anim.SCROLL_STEP px and coasting to rest; notches add up, and
## the glide stops dead at either end. follow(control) eases a control into view. Reduce motion: both jump. Anything
## else that moves it (its scrollbar, a direct scroll_vertical) stops the glide.

var _velocity := 0.0  # px per second, down positive
var _pos := 0.0  # where the glide is, unrounded
var _follow: Tween


func _init() -> void:
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed or not wheel.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		return
	accept_event()
	var push := Anim.SCROLL_STEP * (wheel.factor if wheel.factor > 0.0 else 1.0)
	push *= 1.0 if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
	_stop_follow()
	if UIKit.calm():
		scroll_vertical += roundi(push)
		return
	if not is_processing():
		_pos = scroll_vertical
	_velocity += push * Anim.SCROLL_FRICTION
	set_process(true)


## Eases the content so control (inside it) lies wholly in view; nothing when it already does.
func follow(control: Control) -> void:
	var top := scroll_vertical + control.get_global_rect().position.y - get_global_rect().position.y
	var to := scroll_vertical
	if top < scroll_vertical:
		to = int(top)
	elif top + control.size.y > scroll_vertical + size.y:
		to = int(ceilf(top + control.size.y - size.y))
	to = clampi(to, 0, _bottom())
	if to == scroll_vertical:
		return
	_halt()
	_stop_follow()
	if UIKit.calm():
		scroll_vertical = to
		return
	_follow = create_tween()
	_follow.tween_method(func(y: float): scroll_vertical = roundi(y), float(scroll_vertical), float(to),
		Anim.SCROLL_FOLLOW_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Moves the glide one frame: the exact distance its decaying speed covers in delta, so a notch travels SCROLL_STEP.
func _process(delta: float) -> void:
	if scroll_vertical != roundi(_pos):  # the scrollbar or a direct set moved it
		_halt()
		return
	var decay := exp(-Anim.SCROLL_FRICTION * delta)
	var left := _velocity / Anim.SCROLL_FRICTION  # the travel still to come
	_pos += left * (1.0 - decay)
	_velocity *= decay
	if absf(left * decay) < Anim.SCROLL_REST:
		_pos += left * decay
		_velocity = 0.0
	if _pos <= 0.0 or _pos >= _bottom():
		_pos = clampf(_pos, 0.0, _bottom())
		_velocity = 0.0
	scroll_vertical = roundi(_pos)
	if _velocity == 0.0:
		set_process(false)


## The furthest the content can go.
func _bottom() -> int:
	var bar := get_v_scroll_bar()
	return maxi(0, int(bar.max_value - bar.page))


func _halt() -> void:
	_velocity = 0.0
	set_process(false)


func _stop_follow() -> void:
	if _follow != null:
		_follow.kill()
		_follow = null
