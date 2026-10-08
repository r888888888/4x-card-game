class_name SelectList
extends PanelContainer
## The selectable list (backlog 217, guide §7.16 "Selectable list"): rows printed on a recessed well, of which one is
## selected. The selected row is marked in place (356): a sheet strip (ListRow's pressed look) with a lit indicator lamp
## before its name, a ReadyLamp each row holds room for; the keyboard focus keeps its own ring, drawn only when a key (the
## arrows, Tab or Shift+Tab) moved the focus onto the row (220). A click, or Up and Down on a row, chooses: the row is selected and chosen fires. select() changes the selection without firing chosen.

## The player chose id's row.
signal chosen(id: String)

var selected := ""  # the selected row's id, "" for none

var _box := VBoxContainer.new()
var _rows := {}  # id -> its row Button, in the order added
var _keyed := false  # a focus-moving key is being handled: a row it focuses draws the ring


func _init() -> void:
	theme_type_variation = &"ListWell"
	_box.add_theme_constant_override("separation", Tokens.SPACE_1)
	add_child(_box)


## Adds a row reading text for id, at the bottom, and returns it.
func add_row(id: String, text: String) -> Button:
	var row := UIKit.button(text, func(): _choose(id))
	row.theme_type_variation = &"ListRowQuiet"
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_FILL  # a list row: the column's width (100)
	var lamp := ReadyLamp.attach(row)  # every row keeps the lamp's room; only the selected one shows it
	lamp.set_lit(true, true)  # quietly: a selection, not news
	lamp.visible = false
	row.focus_entered.connect(func(): row.theme_type_variation = &"ListRow" if _keyed else &"ListRowQuiet")
	row.focus_exited.connect(func(): row.theme_type_variation = &"ListRowQuiet")
	row.gui_input.connect(func(event: InputEvent):
		var step := 1 if event.is_action_pressed("ui_down") else -1 if event.is_action_pressed("ui_up") else 0
		var list := ids()
		var at := list.find(id) + step
		if step != 0 and at >= 0 and at < list.size():
			row.accept_event()
			_choose(list[at])
			FocusRing.focus(_rows[list[at]], true))
	_box.add_child(row)
	_rows[id] = row
	return row


## Adds a heading over the rows added after it (the Build modal's Buildings and Units, 297), SPACE_5 below any rows
## before it (356); not a row: ids() and the arrows skip it.
func add_heading(text: String) -> Label:
	if _box.get_child_count() > 0:
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.custom_minimum_size.y = Tokens.SPACE_4  # with the box's SPACE_1 on either side: SPACE_5
		_box.add_child(gap)
	var label := UIKit.heading(text)
	_box.add_child(label)
	return label


## Removes every row and heading.
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
		ReadyLamp.of(row).visible = row_id == id


## The rows' ids, in order.
func ids() -> Array[String]:
	var out: Array[String] = []
	out.assign(_rows.keys())
	return out


## id's row, or null.
func row(id: String) -> Button:
	return _rows.get(id)


func _input(event: InputEvent) -> void:
	for action in ["ui_up", "ui_down", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action_pressed(action):
			_keyed = true
			set_deferred("_keyed", false)
			return


func _choose(id: String) -> void:
	select(id)
	chosen.emit(id)
