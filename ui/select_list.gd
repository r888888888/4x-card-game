class_name SelectList
extends PanelContainer
## The selectable list (backlog 217, guide §7 "Selectable list", the index card): rows printed on a recessed well, of
## which one is selected. The selected row is pulled out as a sheet strip on a hard shadow (ListRow's pressed look)
## with the signal index tab on its leading edge; the keyboard focus keeps its own ring. A click, or Up and Down on a
## row, chooses: the row is selected and chosen fires. select() changes the selection without firing chosen.

## The player chose id's row.
signal chosen(id: String)

var selected := ""  # the selected row's id, "" for none

var _box := VBoxContainer.new()
var _rows := {}  # id -> its row Button, in the order added


func _init() -> void:
	theme_type_variation = &"ListWell"
	_box.add_theme_constant_override("separation", Tokens.SPACE_1)
	add_child(_box)


## Adds a row reading text for id, at the bottom, and returns it.
func add_row(id: String, text: String) -> Button:
	var row := UIKit.button(text, func(): _choose(id))
	row.theme_type_variation = &"ListRow"
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_FILL  # a list row: the column's width (100)
	var tab := ColorRect.new()
	tab.name = "IndexTab"
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.visible = false
	tab.anchor_bottom = 1.0
	tab.offset_left = GameTheme.PULL  # on the pulled-out strip's leading edge
	tab.offset_right = GameTheme.PULL + Tokens.SPACE_1
	UIKit.painted(tab, func(): tab.color = Palette.ACCENT)
	row.add_child(tab)
	row.gui_input.connect(func(event: InputEvent):
		var step := 1 if event.is_action_pressed("ui_down") else -1 if event.is_action_pressed("ui_up") else 0
		var list := ids()
		var at := list.find(id) + step
		if step != 0 and at >= 0 and at < list.size():
			row.accept_event()
			_choose(list[at])
			_rows[list[at]].grab_focus())
	_box.add_child(row)
	_rows[id] = row
	return row


## Removes every row.
func clear() -> void:
	for row in _box.get_children():
		_box.remove_child(row)
		row.queue_free()
	_rows.clear()
	selected = ""


## Selects id's row ("" or an unknown id: none) without firing chosen.
func select(id: String) -> void:
	selected = id
	for row_id in _rows:
		var row := _rows[row_id] as Button
		row.set_pressed_no_signal(row_id == id)
		row.get_node("IndexTab").visible = row_id == id


## The rows' ids, in order.
func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_rows.keys())
	return out


## id's row, or null.
func row(id: String) -> Button:
	return _rows.get(id)


func _choose(id: String) -> void:
	select(id)
	chosen.emit(id)
