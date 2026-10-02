class_name BigButton
extends Button
## A large-format key for the few places that deserve a big press (backlog 213; the title screen for now): an index card
## (the BigButton / BigButtonPrimary variations: RAISED, a 3 px ink border, cut square, on a 4,4 plinth) with a lamp edge
## along its left (ACCENT on the primary key, FIELD otherwise), its label in caps (BigLabel) over a one-line caption,
## and a › at its right. Pressed, the card and what is on it travel +TRAVEL px into the plinth. Its text stays the
## Button's (for focus, tests and screen readers) but the label draws it.

const TRAVEL := 4.0  # px a press moves the card (its plinth's offset)
const PRESS_TIME := 0.07  # Anim.KEY_PRESS_TIME: a snap down
const RELEASE_TIME := 0.12  # Anim.KEY_RELEASE_TIME

var label: Label
var caption: Label
var chevron: Label
var lamp: ColorRect

var _face: MarginContainer  # everything drawn on the card, moved with the press
var _tween: Tween


func _init(text_: String, caption_text: String, primary := false) -> void:
	text = text_
	theme_type_variation = &"BigButtonPrimary" if primary else &"BigButton"
	custom_minimum_size = Vector2(Tokens.SPACE_9 * 4 + Tokens.SPACE_6, Tokens.SPACE_8 + Tokens.SPACE_4)
	_face = MarginContainer.new()
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "bottom"]:
		_face.add_theme_constant_override("margin_" + side, Tokens.SPACE_1)  # inside the 3 px border
	_face.add_theme_constant_override("margin_right", Tokens.SPACE_5)
	add_child(_face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(row)
	lamp = ColorRect.new()
	lamp.custom_minimum_size.x = Tokens.SPACE_2
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.painted(lamp, func(): lamp.color = Palette.ACCENT if primary else Palette.FIELD)
	row.add_child(lamp)
	var words := VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", Tokens.SPACE_0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(words)
	label = Label.new()
	label.text = text_
	label.uppercase = true
	label.theme_type_variation = &"BigLabel"
	words.add_child(label)
	caption = Label.new()
	caption.text = caption_text
	caption.theme_type_variation = &"Caption"
	words.add_child(caption)
	chevron = Label.new()
	chevron.text = "›"
	chevron.theme_type_variation = &"BigLabel"
	chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chevron.size_flags_vertical = Control.SIZE_FILL
	row.add_child(chevron)
	for c in [label, caption, chevron]:
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_down.connect(func(): _travel(Vector2(TRAVEL, TRAVEL), PRESS_TIME))
	button_up.connect(func(): _travel(Vector2.ZERO, RELEASE_TIME))


## Moves what is on the card with it, as the pressed style moves the card.
func _travel(to: Vector2, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if UIKit.calm():
		_face.position = to
		return
	_tween = create_tween()
	_tween.tween_property(_face, "position", to, time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
