class_name RulesPopover
extends PanelContainer
## A card's full rules in a small printed tab beside it (383), in 379's Popover looks: ink, inverse text, cut square,
## a label-caps heading over its lines, and a notch toward what it is beside. Not a modal: no scrim and nothing blocked;
## the pointer may rest on it. Esc or a press anywhere closes it (closed, then it frees itself); its owner closes it
## otherwise.

signal closed

const WIDTH := 320.0
const GAP := Tokens.SPACE_3  # between it and what it is beside
const NOTCH := 6.0  # px the notch points out
const NOTCH_Y := Tokens.SPACE_4  # the notch's middle, down from the top
const SLIDE := 4.0  # px it slides in from, away from what it is beside

var _left := false  # opened left of what it is beside: the notch on its right


func _init(heading: String, lines: PackedStringArray) -> void:
	theme_type_variation = &"Popover"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = WIDTH
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", Tokens.SPACE_1)
	add_child(box)
	var title := Label.new()
	title.text = heading
	title.uppercase = true
	title.theme_type_variation = &"PopoverHeading"
	box.add_child(title)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.theme_type_variation = &"PopoverText"
		box.add_child(label)


## Opens on layer beside anchor (a global rect): right of it, or left when the screen's right edge has no room; it
## slides in, or with calm (Reduce motion) appears in place.
func open_beside(layer: Control, anchor: Rect2, calm: bool) -> void:
	layer.add_child(self)
	_fit_height()
	var edge := layer.get_viewport_rect().size.x - Tokens.SPACE_2
	_left = anchor.end.x + GAP + WIDTH > edge
	var x := anchor.position.x - GAP - WIDTH if _left else anchor.end.x + GAP
	var at := Vector2(x, anchor.position.y) - layer.global_position
	position = at
	if not calm:
		position.x += -SLIDE if _left else SLIDE
		create_tween().tween_property(self, "position", at, Anim.OVERFLOW_SLIDE) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Lays the lines out at WIDTH, then takes the height they wrap to (a wrapping label measures at its width).
func _fit_height() -> void:
	size = Vector2(WIDTH, 0)
	var parts: Array = [self] + find_children("*", "Control", true, false)
	for i in 2:  # widths first, then the heights at those widths
		for control: Control in parts:
			if control is Container:
				control.notification(Container.NOTIFICATION_SORT_CHILDREN)
		parts.reverse()
		for control: Control in parts:
			control.update_minimum_size()
		parts.reverse()
	size = Vector2(WIDTH, get_combined_minimum_size().y)


## The heading and lines, one per line (tests).
func text() -> String:
	var lines: PackedStringArray = []
	for label in find_children("*", "Label", true, false):
		lines.append((label as Label).text)
	return "\n".join(lines)


## Closes it: closed, then it frees itself.
func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventMouseButton and event.pressed:  # the press goes on to whatever it was on
		close()


func _draw() -> void:
	var tip := Vector2(size.x + NOTCH if _left else -NOTCH, NOTCH_Y)
	var base := size.x if _left else 0.0
	draw_colored_polygon(PackedVector2Array([Vector2(base, NOTCH_Y - NOTCH), tip, Vector2(base, NOTCH_Y + NOTCH)]),
		Palette.TEXT)
