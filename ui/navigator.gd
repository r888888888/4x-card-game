class_name Navigator
extends RefCounted
## A stack of screens (backlog 103), the master–detail pattern: push opens a screen and hides the one below, back (or
## Esc) closes it, shows the one below and gives the keyboard focus back to what had it. Each screen has a title, so a
## ScreenHeader can name where you are and where Back goes (104). An animated navigator also transitions (104): a
## screen fades in and out, or slides (below); with Reduce motion everything only fades. A leaving screen no longer counts as shown and takes no clicks while it goes. It knows
## nothing about the game; a screen is any Control, shown and hidden as it comes and goes. A screen is a sheet run along
## a rail (189): push runs it in, back runs it out; set_root and clear are silent. A screen pushed to slide (208) runs in
## from the right edge (SLIDE_IN) while the screen below moves SHIFT px left, and back runs it out to the right
## (SLIDE_OUT) as the one below returns; with Reduce motion it fades (SLIDE_FADE). A slide runs the screen its own width,
## from its container's edge, and a stand-in holds the slot of the screen it lifts out of the layout, so the sections
## around it stay still (224).

## After each push, back, set_root and clear.
signal changed

const LEAVING := &"navigator_leaving"  # meta on a screen still drawn while it transitions out
const OFFSET := &"navigator_offset"  # meta: a sliding screen's or the one below's offset from its place (208)
const STAND_IN := &"navigator_stand_in"  # meta: the empty Control holding a lifted screen's slot in its container (224)
const SLIDE_IN := 0.32  # Anim.MACHINED
const SLIDE_OUT := 0.26  # Anim.RELEASE
const SLIDE_FADE := 0.12
const SHIFT := -24.0  # px the screen below moves while one slides over it

var animated := false  # transitions on push and back (off: screens switch at once)

var _screens: Array[Control] = []
var _titles: Array[String] = []
var _slides: Array[bool] = []  # per screen: it slid in (208)
var _return_focus: Array[Control] = []  # per screen: the Control that had the focus when it was pushed
var _tween: Tween  # the running transition


## Whether screen is showing and not on its way out.
static func is_shown(screen: Control) -> bool:
	return screen.visible and not screen.get_meta(LEAVING, false)


## Opens screen (titled title) over the current top, giving focus (a Control on screen) the keyboard focus. It fades
## in, or with slide runs in from the right instead (208).
func push(screen: Control, focus: Control = null, title := "", slide := false) -> void:
	_finish()
	_return_focus.append(screen.get_viewport().gui_get_focus_owner() if screen.is_inside_tree() else null)
	var below: Control = null if _screens.is_empty() else _screens.back()
	if below != null and not (slide and animated and not UIKit.calm()):
		below.hide()
	_add(screen, title)
	_slides.append(slide)
	if slide:
		_slide_in(screen, below)
	else:
		_enter(screen)
	_sound(screen, Sfx.NAV_FORWARD)
	if focus != null:
		FocusRing.focus(focus)
	changed.emit()


## Closes the top screen and shows the one below. Returns false (and does nothing) at the root or when empty.
func back() -> bool:
	if _screens.size() < 2:
		return false
	_finish()
	var screen: Control = _screens.pop_back()
	var slid: bool = _slides.pop_back()
	_titles.pop_back()
	var focus: Control = _return_focus.pop_back()
	_screens.back().show()
	if slid:
		_slide_out(screen, _screens.back())
	else:
		_leave(screen)
	_sound(screen, Sfx.NAV_BACK)
	if is_instance_valid(focus) and focus.is_visible_in_tree():
		FocusRing.focus(focus)
	elif screen.is_inside_tree():
		screen.get_viewport().gui_release_focus()
	changed.emit()
	return true


## Hides every screen and makes screen (titled title) the only one, shown.
func set_root(screen: Control, focus: Control = null, title := "") -> void:
	_finish()
	_hide_all()
	_return_focus.append(null)
	_add(screen, title)
	_slides.append(false)
	if focus != null:
		FocusRing.focus(focus)
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


## Renames screen's title on the stack (a renamed territory, 248); nothing if screen isn't on it or keeps its title.
func retitle(screen: Control, title: String) -> void:
	var i := _screens.find(screen)
	if i != -1 and _titles[i] != title:
		_titles[i] = title
		changed.emit()


static func _sound(screen: Control, token: StringName) -> void:
	var sfx := Sfx.find(screen)
	if sfx != null:
		sfx.play(token, 0.0, sfx.player_acted())


## Esc goes back when there is a screen to go back from. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		return false
	return back()


func _add(screen: Control, title: String) -> void:
	_screens.append(screen)
	_titles.append(title)
	screen.show()


func _hide_all() -> void:
	for screen in _screens:
		if is_instance_valid(screen):
			screen.hide()
	_screens.clear()
	_titles.clear()
	_slides.clear()
	_return_focus.clear()


# --- Transitions (104) ---

func _enter(screen: Control) -> void:
	if not animated:
		return
	_tween = screen.create_tween()
	screen.modulate.a = 0.0
	_tween.tween_property(screen, "modulate:a", 1.0, Anim.SCREEN_TIME)


## Plays screen's way out, then hides it and puts it back to rest. It is out of its container's layout meanwhile,
## so the screen below takes its place at once.
func _leave(screen: Control) -> void:
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
	var width := place.size.x
	_lift(screen, place)
	_offset(Vector2(width, 0), screen, place.position)  # at its container's right edge at once, not on the tween's first step
	_tween.set_parallel()
	_tween.tween_method(_offset.bind(screen, place.position), Vector2(width, 0), Vector2.ZERO, SLIDE_IN) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	if below != null:
		var at := below.get_global_rect()
		_hold(below)
		_lift(below, at)
		_offset(Vector2.ZERO, below, at.position)
		_tween.tween_method(_offset.bind(below, at.position), Vector2.ZERO, Vector2(SHIFT, 0), SLIDE_IN) \
			.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func():
		_land(screen)
		if below != null:
			_land(below)
			_release(below)
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
	var width := place.size.x
	_hold(screen)
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


## Puts an empty stand-in of screen's size and size flags in screen's slot in its container, so lifting screen out of
## the layout moves nothing around it.
static func _hold(screen: Control) -> void:
	var parent := screen.get_parent()
	if not parent is Container:
		return
	var stand_in := Control.new()
	stand_in.custom_minimum_size = screen.size
	stand_in.size_flags_horizontal = screen.size_flags_horizontal
	stand_in.size_flags_vertical = screen.size_flags_vertical
	stand_in.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(stand_in)
	parent.move_child(stand_in, screen.get_index())
	screen.set_meta(STAND_IN, stand_in)


## Removes screen's stand-in, if it has one.
static func _release(screen: Control) -> void:
	if not screen.has_meta(STAND_IN):
		return
	var stand_in: Control = screen.get_meta(STAND_IN)
	stand_in.get_parent().remove_child(stand_in)
	stand_in.queue_free()
	screen.remove_meta(STAND_IN)


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


## A screen that finished leaving: hidden, and back opaque, clickable and in its container.
static func _rest(screen: Control) -> void:
	screen.hide()
	screen.modulate.a = 1.0
	screen.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	screen.top_level = false
	screen.remove_meta(LEAVING)
	screen.remove_meta(OFFSET)
	_release(screen)


## Completes a running transition at once (a new push or back came first).
func _finish() -> void:
	if _tween != null and _tween.is_valid() and _tween.is_running():
		_tween.custom_step(Anim.SCREEN_TIME * 10.0)
	_tween = null
