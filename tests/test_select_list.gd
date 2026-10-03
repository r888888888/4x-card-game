extends "res://tests/lib/test_case.gd"
## The selectable list (backlog 217, guide §7 "Selectable list", the index card): UIKit.select_list() builds a SelectList,
## a well of ListRow rows of which one is selected, pulled out onto a plinth with the signal index tab on its leading
## edge. Held as Object so this file parses before SelectList exists.


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


func tab_of(row: Button) -> ColorRect:
	return row.find_child("IndexTab", true, false) as ColorRect if row != null else null


func shown_tabs(list: Object) -> Array[String]:
	var out: Array[String] = []
	for id in list.ids():
		var tab := tab_of(list.row(id))
		if tab != null and tab.is_visible_in_tree():
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
		eq(box.shadow_color.to_html(), Palette.SHADOW.to_html(), "ListRow %s: a hard shadow" % state)
		check(box.shadow_size > 0 and box.shadow_offset.x > 0 and box.shadow_offset.y > 0, "ListRow %s: on a plinth" % state)
		eq([box.expand_margin_left, box.expand_margin_right], [-float(Tokens.SPACE_2), float(Tokens.SPACE_2)],
			"ListRow %s: pulled 8 px out toward the trailing side" % state)
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
		eq((list.row(id) as Button).theme_type_variation, &"ListRow", "row %s is a ListRow" % id)
	close_main(main)


# --- AC4: the index tab ---

func test_only_the_selected_row_shows_its_index_tab() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	list.select("b")
	await wait_frames()
	eq(list.selected, "b", "b selected")
	eq(shown_tabs(list), ["b"] as Array[String], "one tab, on b")
	eq([(list.row("a") as Button).button_pressed, (list.row("b") as Button).button_pressed], [false, true], "b pressed")
	var tab := tab_of(list.row("b"))
	if tab != null:
		eq(tab.color.to_html(), Palette.ACCENT.to_html(), "signal orange")
		eq(tab.size.x, float(Tokens.SPACE_1), "4 px wide")
		var strip_left: float = (list.row("b") as Control).get_global_rect().position.x + Tokens.SPACE_2
		eq(tab.get_global_rect().position.x, strip_left, "on the pulled strip's leading edge")
	list.select("c")
	await wait_frames()
	eq(shown_tabs(list), ["c"] as Array[String], "the tab moves to c")
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
	eq(shown_tabs(list), ["a"] as Array[String], "the tab follows the arrows")
	close_main(main)


# --- AC5: focus is not selection ---

func test_a_list_rows_focus_is_the_ring_not_the_selection() -> void:
	var main := open_main()
	var list: Object = await three_rows(main, [])
	var row := list.row("a") as Button
	var ring := row.get_theme_stylebox("focus") as StyleBoxFlat
	check(ring != null and not ring.draw_center, "the focus ring draws no fill")
	if ring != null:
		eq(ring.border_color.to_html(), Palette.FOCUS.to_html(), "the teal ring")
	list.select("a")
	row.grab_focus()
	press_key(main, KEY_TAB)
	await wait_frames()
	eq(main.get_viewport().gui_get_focus_owner(), list.row("b"), "Tab moves the focus to b")
	eq(list.selected, "a", "a stays selected")
	eq(shown_tabs(list), ["a"] as Array[String], "the tab stays on a")
	check(not (list.row("b") as Button).button_pressed, "the focused row is not pressed")
	close_main(main)
