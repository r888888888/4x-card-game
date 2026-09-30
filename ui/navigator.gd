class_name Navigator
extends RefCounted
## A stack of screens (backlog 103), the master–detail pattern: push opens a screen and hides the one below, back (or
## Esc) closes it, shows the one below and gives the keyboard focus back to what had it. It knows nothing about the
## game; a screen is any Control, shown and hidden as it comes and goes.

## After each push, back, set_root and clear.
signal changed

var _screens: Array[Control] = []
var _return_focus: Array[Control] = []  # per screen: the Control that had the focus when it was pushed


## Opens screen over the current top, giving focus (a Control on screen) the keyboard focus.
func push(screen: Control, focus: Control = null) -> void:
	_return_focus.append(screen.get_viewport().gui_get_focus_owner() if screen.is_inside_tree() else null)
	if not _screens.is_empty():
		_screens.back().hide()
	_screens.append(screen)
	screen.show()
	if focus != null:
		focus.grab_focus()
	changed.emit()


## Closes the top screen and shows the one below. Returns false (and does nothing) at the root or when empty.
func back() -> bool:
	if _screens.size() < 2:
		return false
	var screen: Control = _screens.pop_back()
	var focus: Control = _return_focus.pop_back()
	screen.hide()
	_screens.back().show()
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		focus.grab_focus()
	elif screen.is_inside_tree():
		screen.get_viewport().gui_release_focus()
	changed.emit()
	return true


## Hides every screen and makes screen the only one, shown.
func set_root(screen: Control, focus: Control = null) -> void:
	_hide_all()
	_screens.append(screen)
	_return_focus.append(null)
	screen.show()
	if focus != null:
		focus.grab_focus()
	changed.emit()


## Hides every screen and empties the stack.
func clear() -> void:
	_hide_all()
	changed.emit()


## The screen on top, or null when the stack is empty.
func top() -> Control:
	return null if _screens.is_empty() else _screens.back()


func depth() -> int:
	return _screens.size()


## Esc goes back when there is a screen to go back from. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return false
	return back()


func _hide_all() -> void:
	for screen in _screens:
		if is_instance_valid(screen):
			screen.hide()
	_screens.clear()
	_return_focus.clear()
