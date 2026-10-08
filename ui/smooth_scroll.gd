class_name SmoothScroll
extends ScrollContainer
## A scroll area that glides (backlog 356, guide §7.17): it takes the mouse wheel itself, so a notch pushes the content
## and the push decays (Anim.SCROLL_FRICTION), easing it Anim.SCROLL_STEP px and coasting to rest; notches add up, and
## the glide stops dead at either end. It glides down, or sideways when its vertical scrolling is disabled (363: the
## hand), where the sideways wheel pushes it too. follow(control) eases a control into view on both axes. Reduce
## motion: both jump. Anything else that moves it (its scrollbar, a direct scroll_vertical) stops the glide.

const _FORWARD := [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT]  # the notches that push down or right
const _SIDEWAYS := [MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]

var _velocity := 0.0  # px per second, down or right positive
var _pos := 0.0  # where the glide is, unrounded
var _follow: Tween


func _init() -> void:
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	var buttons := [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] + (_SIDEWAYS if _sideways() else [])
	if not wheel.button_index in buttons:
		return
	accept_event()
	var push := Anim.SCROLL_STEP * (wheel.factor if wheel.factor > 0.0 else 1.0)
	push *= 1.0 if wheel.button_index in _FORWARD else -1.0
	_stop_follow()
	if UIKit.calm():
		_set_scroll(_scroll() + roundi(push))
		return
	if not is_processing():
		_pos = _scroll()
	_velocity += push * Anim.SCROLL_FRICTION
	set_process(true)


## Eases the content so control (inside it) lies wholly in view; when it already does, only stops an earlier follow.
func follow(control: Control) -> void:
	var from := Vector2(scroll_horizontal, scroll_vertical)
	var content: Control = control
	while content.get_parent() != self:
		content = content.get_parent()
	# Where control sits in the content: the content's own position may lag a scroll set this frame, control's with it.
	var start := control.get_global_rect().position - content.get_global_rect().position
	var to := Vector2i(
		_into_view(scroll_horizontal, start.x, control.size.x, size.x, _end(get_h_scroll_bar())),
		_into_view(scroll_vertical, start.y, control.size.y, size.y, _end(get_v_scroll_bar())))
	_stop_follow()  # an earlier follow's target may no longer show control
	if Vector2(to) == from:
		return
	_halt()
	if UIKit.calm():
		scroll_horizontal = to.x
		scroll_vertical = to.y
		notification(NOTIFICATION_SORT_CHILDREN)  # lay the content out at once, not next frame
		return
	_follow = create_tween()
	_follow.tween_method(func(at: Vector2):
		scroll_horizontal = roundi(at.x)
		scroll_vertical = roundi(at.y), from, Vector2(to), Anim.SCROLL_FOLLOW_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Where the scroll (now at, showing span px, the furthest end) must go along one axis so a control start px into the
## content and length long lies wholly in view.
static func _into_view(at: int, start: float, length: float, span: float, end: int) -> int:
	var to := at
	if start < at:
		to = int(start)
	elif start + length > at + span:
		to = int(ceilf(start + length - span))
	return clampi(to, 0, end)


## Moves the glide one frame: the exact distance its decaying speed covers in delta, so a notch travels SCROLL_STEP.
func _process(delta: float) -> void:
	if _scroll() != roundi(_pos):  # the scrollbar or a direct set moved it
		_halt()
		return
	var decay := exp(-Anim.SCROLL_FRICTION * delta)
	var left := _velocity / Anim.SCROLL_FRICTION  # the travel still to come
	_pos += left * (1.0 - decay)
	_velocity *= decay
	if absf(left * decay) < Anim.SCROLL_REST:
		_pos += left * decay
		_velocity = 0.0
	var end := _end(_bar())
	if _pos <= 0.0 or _pos >= end:
		_pos = clampf(_pos, 0.0, end)
		_velocity = 0.0
	_set_scroll(roundi(_pos))
	if _velocity == 0.0:
		set_process(false)


## Whether it glides sideways: its vertical scrolling is disabled.
func _sideways() -> bool:
	return vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED


## The scrollbar along the axis it glides on.
func _bar() -> ScrollBar:
	return get_h_scroll_bar() if _sideways() else get_v_scroll_bar()


func _scroll() -> int:
	return scroll_horizontal if _sideways() else scroll_vertical


func _set_scroll(to: int) -> void:
	if _sideways():
		scroll_horizontal = to
	else:
		scroll_vertical = to


## The furthest bar's axis can go.
static func _end(bar: ScrollBar) -> int:
	return maxi(0, int(bar.max_value - bar.page))


func _halt() -> void:
	_velocity = 0.0
	set_process(false)


func _stop_follow() -> void:
	if _follow != null:
		_follow.kill()
		_follow = null
