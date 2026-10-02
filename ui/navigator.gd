class_name Navigator
extends RefCounted
## A stack of screens (backlog 103), the master–detail pattern: push opens a screen and hides the one below, back (or
## Esc) closes it, shows the one below and gives the keyboard focus back to what had it. Each screen has a title, so a
## ScreenHeader can name where you are and where Back goes (104). An animated navigator also transitions (104): a
## screen pushed from a rect (the card it opens) grows out of it and shrinks back into it; others fade; with Reduce
## motion everything only fades. A leaving screen no longer counts as shown and takes no clicks while it goes. It knows
## nothing about the game; a screen is any Control, shown and hidden as it comes and goes. A screen is a sheet run along
## a rail (189): push runs it in, back runs it out; set_root and clear are silent.

## After each push, back, set_root and clear.
signal changed

const LEAVING := &"navigator_leaving"  # meta on a screen still drawn while it transitions out

var animated := false  # transitions on push and back (off: screens switch at once)

var _screens: Array[Control] = []
var _titles: Array[String] = []
var _from: Array[Rect2] = []  # per screen: the rect it grew out of (no area: it faded in)
var _return_focus: Array[Control] = []  # per screen: the Control that had the focus when it was pushed
var _tween: Tween  # the running transition


## Whether screen is showing and not on its way out.
static func is_shown(screen: Control) -> bool:
	return screen.visible and not screen.get_meta(LEAVING, false)


## Opens screen (titled title) over the current top, giving focus (a Control on screen) the keyboard focus. from: the
## global rect it grows out of (a card), or none to fade in.
func push(screen: Control, focus: Control = null, title := "", from := Rect2()) -> void:
	_finish()
	_return_focus.append(screen.get_viewport().gui_get_focus_owner() if screen.is_inside_tree() else null)
	if not _screens.is_empty():
		_screens.back().hide()
	_add(screen, title, from)
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
	_titles.pop_back()
	var focus: Control = _return_focus.pop_back()
	_screens.back().show()
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


## Completes a running transition at once (a new push or back came first).
func _finish() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.custom_step(Anim.SCREEN_TIME * 10.0)
	_tween = null
