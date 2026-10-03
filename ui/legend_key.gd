class_name LegendKey
extends Button
## The toggle key (182; the window bar since 219, guide §7.5, §15.4): a square push key that latches. A toggle Button on
## the theme's button boxes, so latched is the pressed box sunk 2 px into its shadow (178); a lamp window in the middle
## of its face lights when latched, and its state_label, which its row shows beside it, prints the state, ON or OFF. It
## makes its own key sounds (187): the switch's press going down, then the latch catching (ON) or letting go (OFF) as
## it comes back up.

const LAMP_SIZE := Vector2(14, 6)
const MIN_SIZE := Vector2(32, 32)

## ON or OFF, kept in step with the key; UIKit.setting_row puts it right after the key.
var state_label := Label.new()
var _was_on := false  # latched when the press went down


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = MIN_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER  # stays square in a taller row
	state_label.theme_type_variation = "StateWord"
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.ready.connect(_fit_state_label)
	toggled.connect(func(_on: bool): _show_state())
	add_to_group(KeySounds.OWN_SOUNDS)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	_show_state()


func _on_down() -> void:
	_was_on = button_pressed
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.at_contact(Sfx.BUTTON_PRESS, Anim.KEY_PRESS_TIME, Anim.SNAP, true)


func _on_up() -> void:
	var sfx := Sfx.find(self)
	if sfx == null:
		return
	if button_pressed == _was_on:  # dragged off: the switch only came back up
		sfx.at_contact(Sfx.BUTTON_RELEASE, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true)
	elif button_pressed:
		sfx.at_contact(Sfx.TOGGLE_ON, Anim.KEY_PRESS_TIME, Anim.SNAP, true)
	else:
		sfx.at_contact(Sfx.TOGGLE_OFF, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true)


## The theme's boxes are only reachable once the key is in the tree: copy them, and again when Day mode rebuilds the
## theme (183).
func _ready() -> void:
	UIKit.painted(self, _copy_boxes)


func _copy_boxes() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		remove_theme_stylebox_override(state)
		var box := get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if box == null:
			continue
		add_theme_stylebox_override(state, box)


## A key that never went into a row frees its state label with it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(state_label) and state_label.get_parent() == null:
		state_label.free()


## The state label is as wide as its wider word, so the key doesn't move when the word changes.
func _fit_state_label() -> void:
	var font := state_label.get_theme_font("font")
	var font_size := state_label.get_theme_font_size("font_size")
	var widest := maxf(font.get_string_size("ON", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
		font.get_string_size("OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	state_label.custom_minimum_size.x = ceilf(widest)


## set_pressed_no_signal emits nothing, so the state label also follows the state here.
func _process(_delta: float) -> void:
	if state_label.text != state_text():
		_show_state()


## The lamp's colour: lit (GAIN) while latched, dark (FIELD) while up.
func lamp_color() -> Color:
	return Palette.GAIN if button_pressed else Palette.FIELD


## The state the key is in: ON while latched, OFF while up.
func state_text() -> String:
	return "ON" if button_pressed else "OFF"


func _show_state() -> void:
	state_label.text = state_text()
	queue_redraw()


func _draw() -> void:
	var travel := GameTheme.PRESS if button_pressed else 0  # the window sinks with the latched box
	var window := Rect2((size - LAMP_SIZE) / 2 + Vector2(travel, travel), LAMP_SIZE)
	draw_rect(window, lamp_color())
	draw_rect(window, Palette.CONTROL_BORDER, false, 1.0)
