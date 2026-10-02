class_name Toasts
extends Control
## Short messages centred under the top bar (backlog 116): the engine's notices, each for Anim.TOAST_TIME, and the
## targeting hint, until targeting ends. At most MAX show, newest on top. They never take the mouse or the focus, and
## hide while covered (a modal, the menu or a start screen is open); they keep ageing meanwhile.

const MAX := 3
const FADE_IN := 0.15
const FADE_OUT := 0.3
const DROP_PX := 12.0  # a new toast drops this far into place (not with Reduce motion)

var _top_bar: Control
var _covered: Callable  # -> bool: whether something covers the board
var _column: VBoxContainer
var _hint: Control  # the targeting hint's toast, or null


## top_bar: the toasts sit under it. covered() -> bool says when to hide them.
func _init(top_bar: Control, covered: Callable) -> void:
	_top_bar = top_bar
	_covered = covered
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 5  # above the board and flying cards, below the log drawer
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", Tokens.SPACE_2)
	add_child(_column)


func _process(_delta: float) -> void:
	visible = not _covered.call()
	_column.reset_size()
	_column.position = Vector2((size.x - _column.size.x) / 2, _top_bar.get_global_rect().end.y - global_position.y + 8)


## Shows message for Anim.TOAST_TIME, then fades it out.
func notice(message: String) -> void:
	var toast := _add(message)
	var t := toast.create_tween()
	t.tween_interval(Anim.TOAST_TIME)
	t.tween_callback(_leave.bind(toast))


## Shows text until clear_hint (the targeting hint), replacing any hint already shown.
func hint(text: String) -> void:
	clear_hint()
	_hint = _add(text)


func clear_hint() -> void:
	if _hint != null:
		_leave(_hint)
		_hint = null


## The toasts showing (not leaving), top to bottom: each is the panel holding its text.
func shown() -> Array[Control]:
	var out: Array[Control] = []
	for slot in _column.get_children():
		if not slot.is_queued_for_deletion() and not slot.has_meta("leaving"):
			out.append(slot.get_child(0))
	return out


## The text of each toast showing, top to bottom.
func texts() -> Array[String]:
	var out: Array[String] = []
	for panel in shown():
		out.append((panel.get_child(0) as Label).text)
	return out


## A new toast on top, fading (and, without Reduce motion, dropping) in; the oldest leaves past MAX.
func _add(text: String) -> Control:
	var label := UIKit.fx_label(text.strip_edges(), Tokens.TYPE_BODY, Palette.TEXT)
	label.z_index = 0
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	var slot := Control.new()  # holds the panel's place in the column while the panel moves inside it
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # each toast centred, not just the column
	slot.add_child(panel)
	_column.add_child(slot)
	_column.move_child(slot, 0)
	panel.reset_size()
	slot.custom_minimum_size = panel.size
	panel.modulate.a = 0.0
	var t := panel.create_tween().set_parallel()
	t.tween_property(panel, "modulate:a", 1.0, FADE_IN)
	if not UIKit.calm():
		panel.position.y = -DROP_PX
		t.tween_property(panel, "position:y", 0.0, FADE_IN).set_ease(Tween.EASE_OUT)
	var showing := shown()
	if showing.size() > MAX:
		_leave(showing.back())
	return panel


## Fades panel's toast out and frees it; it stops counting as shown at once.
func _leave(panel: Control) -> void:
	var slot := panel.get_parent()
	if slot == null or slot.has_meta("leaving"):
		return
	slot.set_meta("leaving", true)
	var t := panel.create_tween()
	t.tween_property(panel, "modulate:a", 0.0, FADE_OUT)
	t.tween_callback(slot.queue_free)
