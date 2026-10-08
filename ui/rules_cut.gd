class_name RulesCut
extends Control
## The rules on a hand-size face (383): one label per rule, top down, showing only the whole rules that fit the room
## fit() is given; the rest are hidden and counted (hidden). A card whose rules are one paragraph is cut after its last
## whole sentence that fits, each hidden sentence counted, or hidden whole when even its first sentence doesn't fit. It
## asks for no room of its own (the card keeps its size) and clips, so a sheet sliding to a new cut never shows a part.

const SENTENCE := "[^.;]+[.;]"  # a sentence ends at a full stop or a semicolon

var left_out := 0  # rules (or sentences) the last fit() left out
var _lines: PackedStringArray
var _sentences: PackedStringArray  # a one-paragraph card's sentences; empty otherwise


func _init(lines: PackedStringArray) -> void:
	name = "Rules"
	_lines = lines
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	for line in lines:
		add_child(CardFace.rich_label(line, Tokens.TYPE_BODY))
	if lines.size() == 1:
		var text := lines[0]
		var end := 0
		for found in RegEx.create_from_string(SENTENCE).search_all(text):
			_sentences.append(found.get_string())
			end = found.get_end()
		if end < text.length() and not _sentences.is_empty():  # words after the last stop: a sentence of their own
			_sentences.append(text.substr(end))


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO


## The height every rule needs, whole, at the box's width.
func needed() -> float:
	var total := 0.0
	for i in get_child_count():
		total += _height(_set_text(i, _lines[i]))
	return total


## Shows the whole rules (or sentences) that fit room px, top down, and hides the rest. Returns hidden.
func fit(room: float) -> int:
	left_out = 0
	if _sentences.size() > 1:
		var n := _sentences.size()
		var label := _set_text(0, "".join(_sentences))
		while n > 0 and _height(label) > room + 0.5:
			n -= 1
			_set_text(0, "".join(_sentences.slice(0, n)))
		label.visible = n > 0
		if n > 0:
			_place(label, 0.0)
		left_out = _sentences.size() - n
		return left_out
	var y := 0.0
	for i in get_child_count():
		var label := _set_text(i, _lines[i])
		var h := _height(label)
		label.visible = left_out == 0 and y + h <= room + 0.5
		if label.visible:
			_place(label, y)
			y += h
		else:
			left_out += 1
	return left_out


## Rule i's label showing text (refilled only when it changes).
func _set_text(i: int, text: String) -> RichTextLabel:
	var label := get_child(i) as RichTextLabel
	if label.get_meta("source", "") != text:
		label.set_meta("source", text)
		Icons.fill(label, text, Tokens.TYPE_BODY, Palette.TEXT)
	return label


## label's height at the box's width.
func _height(label: RichTextLabel) -> float:
	label.size = Vector2(size.x, label.size.y)
	return label.get_content_height()


func _place(label: RichTextLabel, y: float) -> void:
	label.position = Vector2(0, y)
	label.size = Vector2(size.x, _height(label))
