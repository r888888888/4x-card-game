class_name CabinetDoors
extends Control
## Two steel doors over the whole window (backlog 209, transitions.html transition 5): they slide in from the edges and
## meet at the centre (CLOSE_TIME), hold, then part back to the edges (PART_TIME). What changes behind them changes
## while they are shut (swap). While they move they take every click; main holds back the keys (moving()).

const CLOSE_TIME := 0.20  # Anim.MACHINED
const HOLD_TIME := 0.06
const PART_TIME := 0.26  # Anim.LATCH, without its anticipation (no tween overshoots)
const SEAM := 3  # px of ink on each door's meeting edge

var left: PanelContainer
var right: PanelContainer

var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 12  # above the choice overlays and the board's flying cards, below the modals
	visible = false
	left = _door("CHOOSE A", true)
	right = _door("GOVERNMENT", false)


## Whether the doors are running (they take the input meanwhile).
func moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Closes the doors, calls swap while they are shut, then parts them and hides.
func close_over(swap: Callable) -> void:
	stop()
	show()
	_place(0.0)
	_sound(Sfx.CABINET_CLOSE, CLOSE_TIME)  # scheduled now, so each sounds on its moment whatever the frame rate
	_sound(Sfx.CABINET_PART, CLOSE_TIME + HOLD_TIME)
	_tween = create_tween()
	_tween.tween_method(_place, 0.0, 1.0, CLOSE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_callback(swap)
	_tween.tween_method(_place, 1.0, 0.0, PART_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(hide)


## Stops the doors where they are and hides them (a new game).
func stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	hide()


## Lays the doors out shut by closed (0: at the edges, 1: met at the centre).
func _place(closed: float) -> void:
	var half := get_viewport_rect().size.x / 2 if is_inside_tree() else size.x / 2
	var height := get_viewport_rect().size.y if is_inside_tree() else size.y
	left.size = Vector2(half, height)
	right.size = Vector2(half, height)
	left.position = Vector2(-half + half * closed, 0)
	right.position = Vector2(half * 2 - half * closed, 0)


## A door labelled text, its seam on its right (is_left) or left edge.
func _door(text: String, is_left: bool) -> PanelContainer:
	var door := PanelContainer.new()
	door.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(Tokens.RADIUS_0)
	if is_left:
		style.border_width_right = SEAM
	else:
		style.border_width_left = SEAM
	UIKit.painted(door, func():
		style.bg_color = Palette.CONTROL
		style.border_color = Palette.TEXT)
	door.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Heading"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_left else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", Tokens.SPACE_5)
	pad.add_theme_constant_override("margin_right", Tokens.SPACE_5)
	pad.add_child(label)
	door.add_child(pad)
	add_child(door)
	return door


func _sound(token: StringName, delay: float) -> void:
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.play(token, delay)
