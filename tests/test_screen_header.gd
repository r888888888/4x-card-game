extends "res://tests/lib/test_case.gd"
## The screen header and transitions in the real main scene (backlog 104): the new game and settings screens and
## the territory view each carry a ScreenHeader (`header`: back_button, title_text()), and a territory's view
## slides in from the right like Knowledge (359). with_reduce_motion (test_case.gd) sets Reduce motion for the transition test.
## In detail (from docs/testing.md, 331): The header on the new game and settings screens and the territory view in the
## real `main.tscn` (104; 118: the parent title is the only button, a link back), and a territory's view sliding in from the
## right and back out (359); uses `with_reduce_motion` and `wait_screen_transition`


## Runs body(main) on the real main scene with Game.engine swapped for a TEST_CARDS game on seed 1.
func with_farm_main(body: Callable) -> void:
	var real := Game.engine
	Game.engine = make_engine({"farm": 10})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


# --- AC3: every navigated screen has the header ---

func test_the_new_game_screen_has_a_header() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	var header: Object = main.new_game_screen.header
	eq(header.back_button.text, "◂ Main menu", "new game: the tab back (118, 241)")
	eq(header.title_text(), "New game", "new game: its title")
	eq(main.new_game_screen.back_button, header.back_button, "its Back is the header's")
	header.back_button.pressed.emit()  # Settings is a modal since 206: no screen, no header
	close_main(main)


func test_the_territory_view_has_a_header() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])  # a click on the territory
		var header: Object = main.territory_view.header
		eq(header.back_button.text, "◂ Realm", "the tab back (118, 241)")
		eq(header.title_text(), "Homeland", "its title")
		eq(main.territory_view.back_button, header.back_button, "its Back is the header's")
		header.back_button.pressed.emit()
		check(not main.territory_view.is_open(), "the header's back closes the view"))


# --- AC6, 359: a territory's view slides in from the right, like Knowledge (208) ---

func test_a_territory_view_slides_in_from_the_right_and_back_out() -> void:
	await with_reduce_motion(false, func():
		await with_farm_main(func(main: Node):
			var home := home_uid(Game.engine)
			main.views[home].details_requested.emit(main.views[home])
			var view: Control = main.territory_view
			var realm: Control = main.territory_view.nav.below(view)
			var width := view.size.x
			check(Navigator.offset_of(view).x >= width - 1.0, "starts off the right edge: %s" % Navigator.offset_of(view))
			eq(Navigator.offset_of(realm).x, 0.0, "the Realm in place")
			await wait_seconds(Navigator.SLIDE_IN + 0.1)
			eq(Navigator.offset_of(view).x, 0.0, "in place by SLIDE_IN")
			eq(Navigator.offset_of(realm).x, Navigator.SHIFT, "the Realm moved aside")
			eq(view.scale, Vector2.ONE, "never scaled")
			eq(view.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED, "never clipped")
			view.back_button.pressed.emit()
			check(not view.is_open(), "closed at once")
			check(view.visible, "still drawn while it runs out")
			await wait_seconds(Navigator.SLIDE_OUT / 2.0)
			var mid := Navigator.offset_of(view).x
			check(mid > 0.0 and mid < width, "running out to the right: %s" % mid)
			await wait_seconds(Navigator.SLIDE_OUT / 2.0 + 0.1)
			eq(Navigator.offset_of(realm).x, 0.0, "the Realm back by SLIDE_OUT")
			check(not view.visible, "then hidden")))


func test_with_reduce_motion_a_territory_view_only_fades() -> void:
	await with_reduce_motion(true, func():
		await with_farm_main(func(main: Node):
			var home := home_uid(Game.engine)
			main.views[home].details_requested.emit(main.views[home])
			var view: Control = main.territory_view
			eq(Navigator.offset_of(view).x, 0.0, "no slide")
			check(view.modulate.a < 1.0, "a fade")
			await wait_seconds(Navigator.SLIDE_FADE + 0.1)
			eq(view.modulate.a, 1.0, "in by SLIDE_FADE")
			view.back_button.pressed.emit()
			eq(Navigator.offset_of(view).x, 0.0, "no slide out")
			check(view.modulate.a < 1.0 or not view.visible, "a fade out")
			await wait_seconds(Navigator.SLIDE_FADE + 0.1)
			check(not view.visible, "then hidden")))


# --- 118, 241: the parent title is the way back, on a divider tab ---

## Checks header's way back: the parent's title on a divider tab ("◂ Realm": hand cursor, "Back to …" tooltip, the
## DividerTab look), first in the header, followed by the current title as plain text; the tab is the header's only
## button and nothing in the header mentions Esc (241).
func check_link_back(header: Control, parent_title: String, title: String) -> void:
	var link: Button = header.back_button
	eq(link.text, "◂ " + parent_title, "the tab names the screen below")
	eq(link.theme_type_variation, &"DividerTab", "the divider tab's look")
	eq(link.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "a hand cursor")
	eq(link.tooltip_text, "Back to %s" % parent_title, "tooltip")
	eq(header.title_text(), title, "the title after it")
	var buttons := UIKit.buttons_in(header)
	eq(buttons, [link], "the tab is the header's only button: the current title is plain text")
	check(not buttons.any(func(b: Button): return b.text.contains("←")), "no ← button")
	for c in header.find_children("*", "Control", true, false):
		var text: String = c.get("text") if c.get("text") is String else ""
		check(not text.to_lower().contains("esc") and not (c as Control).tooltip_text.to_lower().contains("esc"),
			"no Esc badge or hint: %s" % c.name)


## The texts of the header's labels, in tree order (the title, then any context).
func label_texts(header: Control) -> Array[String]:
	var texts: Array[String] = []
	for l in header.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree():
			texts.append((l as Label).text)
	return texts


## The colour header's bar is filled with.
func bar_fill(header: Control) -> Color:
	var box := header.get_theme_stylebox("panel") as StyleBoxFlat
	return box.bg_color if box != null and box.draw_center else Color.TRANSPARENT


func test_the_territory_header_goes_back_through_its_realm_link() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])
		check_link_back(main.territory_view.header, "Realm", "Homeland")
		main.territory_view.header.back_button.pressed.emit()
		check(not main.territory_view.is_open(), "the link closes the view"))


func test_the_new_game_header_goes_back_through_its_main_menu_link() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	check_link_back(main.new_game_screen.header, "Main menu", "New game")
	main.new_game_screen.header.back_button.pressed.emit()
	check(not main.new_game_screen.is_open(), "the link goes back to the title screen")
	check(main.start_screen.is_open(), "back on the title screen")
	close_main(main)


# --- 241: the title bar ---

func test_a_territory_opens_under_a_territory_coloured_bar() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])
		var header: Control = main.territory_view.header
		check(header is PanelContainer, "the header is a bar")
		eq(bar_fill(header), Palette.TERRITORY, "filled with the territory colour")
		eq(label_texts(header), ["Homeland"] as Array[String], "the title in the bar, no context line"))


func test_new_game_opens_under_a_civilization_coloured_bar() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	var header: Control = main.new_game_screen.header
	eq(bar_fill(header), Palette.CIVILIZATION, "filled with the civilization colour")
	eq(label_texts(header), ["New game"] as Array[String], "the title in the bar, no context line")
	close_main(main)


func test_the_realm_has_no_bar() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])
		main.territory_view.back_button.pressed.emit()
		await wait_screen_transition()
		check(main.tableau.is_visible_in_tree(), "precondition: the Realm shows")
		var shown := main.find_children("*", "ScreenHeader", true, false).filter(
			func(h: Control): return h.is_visible_in_tree())
		eq(shown.size(), 0, "no screen header shows on the Realm"))
