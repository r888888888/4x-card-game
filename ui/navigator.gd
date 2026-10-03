class_name Navigator
extends RefCounted
## A stack of screens (backlog 103), the master–detail pattern: push opens a screen and hides the one below, back (or
## Esc) closes it, shows the one below and gives the keyboard focus back to what had it. Each screen has a title, so a
## ScreenHeader can name where you are and where Back goes (104). An animated navigator also transitions (104): a
## screen pushed from a rect (the card it opens) grows out of it and shrinks back into it; others fade; with Reduce
## motion everything only fades. A leaving screen no longer counts as shown and takes no clicks while it goes. It knows
## nothing about the game; a screen is any Control, shown and hidden as it comes and goes. A screen is a sheet run along
## a rail (189): push runs it in, back runs it out; set_root and clear are silent. A screen pushed to slide (208) runs in
## from the right edge (SLIDE_IN) while the screen below moves SHIFT px left, and back runs it out to the right
## (SLIDE_OUT) as the one below returns; with Reduce motion it fades (SLIDE_FADE).

## After each push, back, set_root and clear.
signal changed

const LEAVING := &"navigator_leaving"  # meta on a screen still drawn while it transitions out
const OFFSET := &"navigator_offset"  # meta: a sliding screen's or the one below's offset from its place (208)
const SLIDE_IN := 0.32  # Anim.MACHINED
const SLIDE_OUT := 0.26  # Anim.RELEASE
const SLIDE_FADE := 0.12
const SHIFT := -24.0  # px the screen below moves while one slides over it

var animated := false  # transitions on push and back (off: screens switch at once)

var _screens: Array[Control] = []
var _titles: Array[String] = []
var _from: Array[Rect2] = []  # per screen: the rect it grew out of (no area: it faded in)
var _slides: Array[bool] = []  # per screen: it slid in (208)
var _return_focus: Array[Control] = []  # per screen: the Control that had the focus when it was pushed
var _tween: Tween  # the running transition


## Whether screen is showing and not on its way out.
static func is_shown(screen: Control) -> bool:
	return screen.visible and not screen.get_meta(LEAVING, false)


## Opens screen (titled title) over the current top, giving focus (a Control on screen) the keyboard focus. from: the
## global rect it grows out of (a card), or none to fade in; slide: it runs in from the right instead (208).
func push(screen: Control, focus: Control = null, title := "", from := Rect2(), slide := false) -> void:
	_finish()
	_return_focus.append(screen.get_viewport().gui_get_focus_owner() if screen.is_inside_tree() else null)
	var below: Control = null if _screens.is_empty() else _screens.back()
	if below != null and not (slide and animated and not UIKit.calm()):
		below.hide()
	_add(screen, title, from)
	_slides.append(slide)
	if slide:
		_slide_in(screen, below)
	else:
		_enter(screen, from)
	_sound(screen, Sfx.NAV_FORWARD)
	if focus != null:
		focus.grab_focus()
	changed.emit()


## Closes the top screen and shows the one below. Returns false (and does nothing) at the root or when empty.
func back() -> bool:
	if _screens.size() < 2:
		return false
	_finish()
	var screen: Control = _screens.pop_back()
	var from: Rect2 = _from.pop_back()
	var slid: bool = _slides.pop_back()
	_titles.pop_back()
	var focus: Control = _return_focus.pop_back()
	_screens.back().show()
	if slid:
		_slide_out(screen, _screens.back())
	else:
		_leave(screen, from)
	_sound(screen, Sfx.NAV_BACK)
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus()
	elif screen.is_inside_tree():
		screen.get_viewport().gui_release_focus()
	changed.emit()
	return true


## Hides every screen and makes screen (titled title) the only one, shown.
func set_root(screen: Control, focus: Control = null, title := "") -> void:
	_finish()
	_hide_all()
	_return_focus.append(null)
	_add(screen, title, Rect2())
	_slides.append(false)
	if focus != null:
		focus.grab_focus()
	changed.emit()


## Hides every screen and empties the stack.
func clear() -> void:
	_finish()
	_hide_all()
	changed.emit()


## The screen on top, or null when the stack is empty.
func top() -> Control:
	return null if _screens.is_empty() else _screens.back()


func depth() -> int:
	return _screens.size()


## The screen under screen on the stack, or null (screen at the root, or not on the stack).
func below(screen: Control) -> Control:
	var at := _screens.find(screen)
	return _screens[at - 1] if at > 0 else null


## The screens' titles, bottom first.
func titles() -> Array[String]:
	return _titles.duplicate()


static func _sound(screen: Control, token: StringName) -> void:
	var sfx := Sfx.find(screen)
	if sfx != null:
		sfx.play(token, 0.0, sfx.player_acted())


## Esc goes back when there is a screen to go back from. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return false
	return back()


func _add(screen: Control, title: String, from: Rect2) -> void:
	_screens.append(screen)
	_titles.append(title)
	_from.append(from)
	screen.show()


func _hide_all() -> void:
	for screen in _screens:
		if is_instance_valid(screen):
			screen.hide()
	_screens.clear()
	_titles.clear()
	_from.clear()
	_slides.clear()
	_return_focus.clear()


# --- Transitions (104) ---

func _enter(screen: Control, from: Rect2) -> void:
	if not animated:
		return
	_tween = screen.create_tween()
	if from.has_area() and not UIKit.calm():
		screen.scale = _scale_onto(screen, from)
		_tween.tween_property(screen, "scale", Vector2.ONE, Anim.SCREEN_TIME).set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	else:
		screen.modulate.a = 0.0
		_tween.tween_property(screen, "modulate:a", 1.0, Anim.SCREEN_TIME)


## Plays screen's way out, then hides it and puts it back to rest. It is out of its container's layout meanwhile,
## so the screen below takes its place at once.
func _leave(screen: Control, from: Rect2) -> void:
	if not animated:
		screen.hide()
		return
	screen.set_meta(LEAVING, true)
	screen.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	if screen.get_parent() is Container:
		var rect := screen.get_global_rect()
		screen.top_level = true
		screen.global_position = rect.position
		screen.size = rect.size
	_tween = screen.create_tween()
	if from.has_area() and not UIKit.calm():
		_tween.tween_property(screen, "scale", _scale_onto(screen, from), Anim.SCREEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	else:
		_tween.tween_property(screen, "modulate:a", 0.0, Anim.SCREEN_TIME)
	_tween.tween_callback(_rest.bind(screen))


## How far screen sits from its place while it slides, or the screen below has moved aside (208); zero at rest.
static func offset_of(screen: Control) -> Vector2:
	return screen.get_meta(OFFSET, Vector2.ZERO)


## Runs screen in from the right edge over below (which moves SHIFT px left, then hides), or fades it with Reduce
## motion. Both are out of their container's layout meanwhile.
func _slide_in(screen: Control, below: Control) -> void:
	if not animated:
		return
	_tween = screen.create_tween()
	if UIKit.calm():
		screen.modulate.a = 0.0
		_tween.tween_property(screen, "modulate:a", 1.0, SLIDE_FADE)
		return
	var place := screen.get_global_rect()
	var width := screen.get_viewport_rect().size.x - place.position.x
	_lift(screen, place)
	_offset(Vector2(width, 0), screen, place.position)  # off the right edge at once, not on the tween's first step
	_tween.set_parallel()
	_tween.tween_method(_offset.bind(screen, place.position), Vector2(width, 0), Vector2.ZERO, SLIDE_IN) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if below != null:
		var at := below.get_global_rect()
		_lift(below, at)
		_offset(Vector2.ZERO, below, at.position)
		_tween.tween_method(_offset.bind(below, at.position), Vector2.ZERO, Vector2(SHIFT, 0), SLIDE_IN) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func():
		_land(screen)
		if below != null:
			_land(below)
			below.hide()
			below.set_meta(OFFSET, Vector2(SHIFT, 0)))  # it stays aside under the screen


## Runs screen out to the right as below comes back from SHIFT px left, or fades it with Reduce motion.
func _slide_out(screen: Control, below: Control) -> void:
	if not animated:
		screen.hide()
		below.remove_meta(OFFSET)
		return
	screen.set_meta(LEAVING, true)
	screen.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	var place := screen.get_global_rect()
	_lift(screen, place)
	_tween = screen.create_tween()
	if UIKit.calm():
		below.remove_meta(OFFSET)
		_tween.tween_property(screen, "modulate:a", 0.0, SLIDE_FADE)
		_tween.tween_callback(_rest.bind(screen))
		return
	var width := screen.get_viewport_rect().size.x - place.position.x
	_tween.set_parallel()
	_tween.tween_method(_offset.bind(screen, place.position), Vector2.ZERO, Vector2(width, 0), SLIDE_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var at := place  # the screen below comes back to where the leaving one was
	_lift(below, at)
	_tween.tween_method(_offset.bind(below, at.position), Vector2(SHIFT, 0), Vector2.ZERO, SLIDE_OUT) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		_land(below)
		_rest(screen))


## Takes screen out of its container's layout, held at global rect at.
static func _lift(screen: Control, at: Rect2) -> void:
	if screen.get_parent() is Container:
		screen.top_level = true
	screen.global_position = at.position
	screen.size = at.size


## Puts a slid screen back in its container's layout, at rest.
static func _land(screen: Control) -> void:
	screen.top_level = false
	screen.remove_meta(OFFSET)


static func _offset(by: Vector2, screen: Control, place: Vector2) -> void:
	screen.set_meta(OFFSET, by)
	screen.global_position = place + by


## Sets screen's pivot so that scaling it by the returned factor lays it exactly over from (both global rects).
static func _scale_onto(screen: Control, from: Rect2) -> Vector2:
	var at := screen.get_global_rect()  # at full size
	var s := Vector2(from.size.x / maxf(at.size.x, 1.0), from.size.y / maxf(at.size.y, 1.0))
	var pivot := Vector2.ZERO
	for axis in 2:
		if absf(1.0 - s[axis]) > 0.001:
			pivot[axis] = (from.position[axis] - at.position[axis]) / (1.0 - s[axis])
	screen.pivot_offset = pivot
	return s


## A screen that finished leaving: hidden, and back at full size, opaque, clickable and in its container.
static func _rest(screen: Control) -> void:
	screen.hide()
	screen.scale = Vector2.ONE
	screen.modulate.a = 1.0
	screen.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	screen.top_level = false
	screen.remove_meta(LEAVING)
	screen.remove_meta(OFFSET)


## Completes a running transition at once (a new push or back came first).
func _finish() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.custom_step(Anim.SCREEN_TIME * 10.0)
	_tween = null
