class_name Vellum
extends ColorRect
## Targeting under vellum (backlog 210, transitions.html transition 6): while a card waits for one of several targets, a
## sheet of translucent paper wipes in from the left over the play area and the card and its valid targets are lifted
## above it (the targets ringed in FOCUS). It takes every click: the board decides what a click at a point does (a
## target plays the card there; anything else cancels). Ending the targeting wipes it off to the right. Reduce motion:
## it fades in and out instead.

const LIFT_Z := 6  # a lifted card view's z_index is raised this much (the vellum sits at Z)
const Z := 4  # above the board and flying cards, below the choice overlays
const ALPHA := 0.72  # how much of the board shows through
const WIPE_IN := 0.26  # Anim.MACHINED
const WIPE_OUT := 0.20  # Anim.RELEASE
const FADE := 0.12

var _area: Callable  # the global Rect2 it covers (the play area and the sidebar, full width)
var _on_click: Callable  # (global point) a left click on it
var _lifted: Array[CardView] = []
var _tween: Tween


func _init(area: Callable, on_click: Callable) -> void:
	_area = area
	_on_click = on_click
	z_index = Z
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIKit.painted(self, func(): color = Color(Palette.RAISED, ALPHA))


## Lays the vellum down with views lifted above it: the first is the card waiting for a target, the rest its targets.
func lay(views: Array[CardView]) -> void:
	_stop()
	_let_down()
	for i in views.size():
		if is_instance_valid(views[i]):
			views[i].set_above_vellum(true, i > 0)
			_lifted.append(views[i])
	var area: Rect2 = _area.call()
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	global_position = area.position
	_tween = create_tween()
	if UIKit.calm():
		size = area.size
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, FADE)
		return
	modulate.a = 1.0
	size = Vector2(0, area.size.y)
	_tween.tween_property(self, "size:x", area.size.x, WIPE_IN).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Lets the cards down and wipes the vellum off to the right (or fades it with Reduce motion).
func lift() -> void:
	_let_down()
	if not visible:
		return
	_stop()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween()
	if UIKit.calm():
		_tween.tween_property(self, "modulate:a", 0.0, FADE)
	else:
		var end := position.x + size.x
		_tween.set_parallel()
		_tween.tween_property(self, "position:x", end, WIPE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "size:x", 0.0, WIPE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween = _tween.chain()
	_tween.tween_callback(hide)


## Test hooks (210): the part of the window it covers now, and the card views drawn above it.
func covered_rect() -> Rect2:
	return get_global_rect()


func lifted() -> Array[CardView]:
	return _lifted.filter(func(v): return is_instance_valid(v))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_on_click.call(event.global_position)


func _let_down() -> void:
	for view in _lifted:
		if is_instance_valid(view):
			view.set_above_vellum(false)
	_lifted.clear()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
