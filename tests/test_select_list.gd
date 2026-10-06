extends "res://tests/lib/test_case.gd"
## The selectable list (backlog 217, guide §7 "Selectable list", the index card): UIKit.select_list() builds a SelectList,
## a well of ListRow rows of which one is selected: a filled strip in place with a lit indicator lamp before its name
## (356: no pull, no shadow, no index tab). Held as Object so this file parses before SelectList exists.


## UIKit.select_list(), called through the loaded script so this file parses before it exists.
func new_list() -> Object:
	return load("res://ui/ui_kit.gd").select_list()


## A list of three rows ("a", "b", "c") in main, laid out, with chosen ids appended to picks.
func three_rows(main: Node, picks: Array) -> Object:
	var list: Object = new_list()
	main.add_child(list)
	for id in ["a", "b", "c"]:
		list.add_row(id, id.to_upper())
	list.chosen.connect(func(id: String): picks.append(id))
	await wait_frames()
	return list


## The rows of list whose lamp shows (356), by id.
func shown_lamps(list: Object) -> Array[String]:
	var out: Array[String] = []
	for id in list.ids():
		var lamp := ReadyLamp.of(list.row(id))
		if lamp != null and lamp.is_visible_in_tree():
			out.append(id)
	return out


# --- AC3: the rows ---

func test_a_list_row_draws_no_box_until_selected() -> void:
	var main := open_main()
	var row := Button.new()
	row.theme_type_variation = &"ListRow"
	main.add_child(row)
	for state in ["normal", "hover"]:
		var box := row.get_theme_stylebox(state)
		var flat := box as StyleBoxFlat
		check(box is StyleBoxEmpty or (flat != null and not flat.draw_center and flat.border_width_left == 0),
			"ListRow %s: no box or border" % state)
	eq(row.get_theme_color("font_color").to_html(), Palette.TEXT_DIM.to_html(), "ListRow text is ink-2")
	for state in ["pressed", "hover_pressed"]:
		var box := row.get_theme_stylebox(state) as StyleBoxFlat
		check(box != null and box.draw_center, "ListRow %s: a filled strip" % state)
		if box == null:
			continue
		eq(box.bg_color.to_html(), Palette.RAISED.to_html(), "ListRow %s: the sheet" % state)
		eq(box.shadow_size, 0, "ListRow %s: no shadow (356)" % state)
		eq([box.expand_margin_left, box.expand_margin_right], [0.0, 0.0], "ListRow %s: in place, not pulled (356)" % state)
		var normal := row.get_theme_stylebox("normal")
		eq([box.content_margin_left, box.content_margin_right], [normal.content_margin_left, normal.content_margin_right],
			"ListRow %s: its text doesn't move (356)" % state)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		eq(row.get_theme_color(state).to_html(), Palette.TEXT.to_html(), "ListRow %s is ink" % state)
	close_main(main)


func test_the_list_is_a_well() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	var box := (list as Control).get_theme_stylebox("panel") as StyleBoxFlat
	check(box != null and box.draw_center, "the list draws a panel")
	if box != null:
		eq(box.bg_color.to_html(), Palette.FIELD.to_html(), "the well")
	for id in list.ids():
		check((list.row(id) as Button).theme_type_variation in [&"ListRow", &"ListRowQuiet"], "row %s is a ListRow" % id)
	close_main(main)


# --- AC4: the selection lamp (356; the index tab until then) ---

func test_only_the_selected_row_shows_its_lamp_lit() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	list.select("b")
	await wait_frames()
	eq(list.selected, "b", "b selected")
	eq(shown_lamps(list), ["b"] as Array[String], "one lamp, on b")
	eq([(list.row("a") as Button).button_pressed, (list.row("b") as Button).button_pressed], [false, true], "b pressed")
	for id in list.ids():
		eq((list.row(id) as Node).find_child("IndexTab", true, false), null, "%s: no index tab" % id)
	var row := list.row("b") as Button
	var lamp := ReadyLamp.of(row)
	check(lamp != null and lamp.is_lit(), "b's lamp is lit")
	if lamp != null:
		eq(lamp.get_global_rect().position.x, row.get_global_rect().position.x + Tokens.SPACE_4,
			"before the name, at the row's text margin")
	for id in ["a", "c"]:
		check(ReadyLamp.of(list.row(id)) != null, "%s keeps its lamp's room" % id)
	list.select("c")
	await wait_frames()
	eq(shown_lamps(list), ["c"] as Array[String], "the lamp moves to c")
	close_main(main)


func test_a_click_or_up_and_down_choose_a_row() -> void:
	var main := open_main()
	var picks := []
	var list: Object = await three_rows(main, picks)
	(list.row("c") as Button).pressed.emit()
	eq(list.selected, "c", "a click selects")
	(list.row("a") as Button).grab_focus()
	list.select("a")
	press_key(main, KEY_DOWN)
	eq(list.selected, "b", "Down selects the next row")
	eq(main.get_viewport().gui_get_focus_owner(), list.row("b"), "and focuses it")
	press_key(main, KEY_UP)
	press_key(main, KEY_UP)
	eq(list.selected, "a", "Up stops at the first row")
	eq(picks, ["c", "b", "a"], "chosen fires once per change by the player, not for select()")
	await wait_frames()
	eq(shown_lamps(list), ["a"] as Array[String], "the lamp follows the arrows")
	close_main(main)


# --- AC5: focus is not selection ---

func test_a_list_rows_focus_is_the_ring_not_the_selection() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	var row := list.row("a") as Button
	list.select("a")
	row.grab_focus()
	press_key(main, KEY_TAB)
	await wait_frames()
	eq(main.get_viewport().gui_get_focus_owner(), list.row("b"), "Tab moves the focus to b")
	check(draws_the_ring(list.row("b")), "the focus is the teal ring, with no fill")
	eq(list.selected, "a", "a stays selected")
	eq(shown_lamps(list), ["a"] as Array[String], "the lamp stays on a")
	check(not (list.row("b") as Button).button_pressed, "the focused row is not pressed")
	close_main(main)


# --- 220: the ring waits for the keyboard ---

## Whether row's focus stylebox is the focus ring: no fill, a FOCUS border.
func draws_the_ring(row: Button) -> bool:
	var ring := row.get_theme_stylebox("focus") as StyleBoxFlat
	return ring != null and not ring.draw_center and ring.border_color == Palette.FOCUS and ring.border_width_left > 0


## Shift+Tab, pressed and released.
func press_shift_tab(main: Node) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.shift_pressed = true
		event.pressed = pressed
		main.get_viewport().push_input(event)


func test_a_row_focused_by_the_code_draws_no_ring() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	(list.row("a") as Button).grab_focus()
	await wait_frames()
	check((list.row("a") as Button).get_theme_stylebox("focus") is StyleBoxEmpty, "a: no ring")
	close_main(main)


func test_the_arrows_show_the_ring() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	(list.row("a") as Button).grab_focus()
	press_key(main, KEY_DOWN)
	await wait_frames()
	eq(main.get_viewport().gui_get_focus_owner(), list.row("b"), "Down focuses b")
	check(draws_the_ring(list.row("b")), "b: the ring")
	close_main(main)


func test_tab_and_shift_tab_show_the_ring() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	(list.row("a") as Button).grab_focus()
	press_key(main, KEY_TAB)
	await wait_frames()
	eq(main.get_viewport().gui_get_focus_owner(), list.row("b"), "Tab focuses b")
	check(draws_the_ring(list.row("b")), "b: the ring")
	press_shift_tab(main)
	await wait_frames()
	eq(main.get_viewport().gui_get_focus_owner(), list.row("a"), "Shift+Tab focuses a")
	check(draws_the_ring(list.row("a")), "a: the ring")
	close_main(main)


func test_the_ring_goes_when_the_focus_leaves() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	(list.row("a") as Button).grab_focus()
	press_key(main, KEY_DOWN)
	await wait_frames()
	check(draws_the_ring(list.row("b")), "b: the ring")
	(list.row("c") as Button).grab_focus()
	await wait_frames()
	check(not draws_the_ring(list.row("b")), "b, unfocused: back to no ring")
	(list.row("b") as Button).grab_focus()
	await wait_frames()
	check((list.row("b") as Button).get_theme_stylebox("focus") is StyleBoxEmpty, "b, focused by the code again: no ring")
	close_main(main)
