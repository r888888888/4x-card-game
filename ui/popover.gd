class_name Popover
extends PanelContainer
## A small ledger anchored under the control that opened it (379), in the tooltip's look (guide §11.11): not a Modal,
## so no scrim and nothing centred. Each section is a label-caps heading, then a two-column ledger, one row per line,
## then a hairline and its total. Its owner opens and closes it; it takes no input of its own.

var anchor: Control  # what it hangs under while open; null while closed

var _box: VBoxContainer


func _init() -> void:
	theme_type_variation = &"Popover"
	top_level = true  # placed on screen under its anchor, outside any container's layout
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", Tokens.SPACE_2)
	add_child(_box)
	hide()


## Opens under at, showing sections: [{heading, rows: [[left, right]], total: [left, right] or []}].
func open(at: Control, sections: Array) -> void:
	anchor = at
	set_sections(sections)
	show()
	_place()


## Closes it.
func close() -> void:
	anchor = null
	hide()


## Whether it is open.
func is_open() -> bool:
	return visible and anchor != null


## Replaces what it shows with sections (see open), staying where it is anchored.
func set_sections(sections: Array) -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	for section: Dictionary in sections:
		if section.get("heading", "") != "":
			var heading := Label.new()
			heading.text = section.heading
			heading.uppercase = true
			heading.theme_type_variation = &"PopoverHeading"
			_box.add_child(heading)
		var ledger := _ledger()
		for line: Array in section.rows:
			_line(ledger, line)
		if not section.get("total", []).is_empty():
			var rule := HSeparator.new()
			rule.theme_type_variation = &"PopoverRule"
			_box.add_child(rule)
			_line(_ledger(), section.total)
	if is_open():
		_place()


## Every line shown, in order: each section's rows, then its total, as [left, right] (headings left out).
func lines() -> Array:
	var out := []
	for ledger in _box.get_children():
		if ledger is GridContainer:
			var cells := ledger.get_children()
			for i in range(0, cells.size(), 2):
				out.append([(cells[i] as Label).text, (cells[i + 1] as Label).text])
	return out


func _ledger() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", Tokens.SPACE_5)
	grid.add_theme_constant_override("v_separation", Tokens.SPACE_1)
	_box.add_child(grid)
	return grid


func _line(grid: GridContainer, line: Array) -> void:
	var left := Label.new()
	left.text = line[0]
	left.theme_type_variation = &"PopoverText"
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(left)
	var right := Label.new()
	right.text = line[1]
	right.theme_type_variation = &"PopoverFigure"
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(right)


## Sits just under the anchor, its left edge on the anchor's, kept inside the window.
func _place() -> void:
	reset_size()
	var rect := anchor.get_global_rect()
	var screen := get_viewport_rect().size
	var at := Vector2(rect.position.x, rect.end.y + Tokens.SPACE_2)
	at.x = clampf(at.x, Tokens.SPACE_2, maxf(Tokens.SPACE_2, screen.x - size.x - Tokens.SPACE_2))
	global_position = at
