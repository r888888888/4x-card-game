extends "res://tests/lib/test_case.gd"
## The right sidebar (backlog 202) in the real main scene at 1920×1080: the civilization's name and its government at
## the board's right edge, full height under the top strip, opening the civilization modal. Hooks: main.sidebar
## (heading, name_button, government_button).

const TOLERANCE := 1.0

var _old_window_size := Vector2i.ZERO


func open_at(size: Vector2i) -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = size
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	return main


func close_at(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


func civ_name() -> String:
	return Game.engine.zone("civilization").cards[0].def.name


func gov_name() -> String:
	return Game.engine.zone("government").cards[0].def.name


# --- AC1: the rail ---

func test_the_sidebar_names_the_civilization_and_its_government() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var bar: Control = main.sidebar
	check(bar.is_visible_in_tree(), "shown")
	eq(bar.heading.text, "Civilization", "the heading")
	check(bar.heading.uppercase and bar.heading.theme_type_variation == &"Heading", "in Heading caps")
	eq(bar.name_button.text, civ_name(), "the civilization's name")
	eq(bar.name_button.get_theme_font_size("font_size"), Tokens.TYPE_TITLE, "at title size")
	eq(bar.government_button.text, "%s ›" % gov_name(), "the government as a link")
	eq(bar.government_button.theme_type_variation, &"Link", "the Link look")
	close_at(main)


func test_the_sidebar_runs_down_the_right_edge_with_the_realm_and_hand_to_its_left() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var main: Node = await open_at(size)
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		var viewport: Vector2 = main.get_viewport_rect().size
		var strip: Rect2 = (main.counter(GameEngine.FOOD) as Control).get_parent().get_global_rect()
		check(viewport.x - rail.end.x <= Tokens.SPACE_4 + TOLERANCE, "%s: at the right edge: ends at %d of %d" % [size, rail.end.x, viewport.x])
		check(rail.position.y >= strip.end.y - TOLERANCE, "%s: under the top strip: %d, strip ends %d" % [size, rail.position.y, strip.end.y])
		check(viewport.y - rail.end.y <= Tokens.SPACE_4 + TOLERANCE, "%s: full height: ends at %d of %d" % [size, rail.end.y, viewport.y])
		for what in ["realm", "hand"]:
			var r: Rect2 = (main.tableau.row if what == "realm" else main.hand_scroll).get_global_rect()
			check(r.end.x <= rail.position.x + TOLERANCE, "%s: the %s ends left of the rail: %d, rail at %d" % [size, what, r.end.x, rail.position.x])
		close_at(main)


# --- AC2: opening the civilization modal ---

func test_the_name_or_the_government_opens_the_civilization_modal() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	for b: Button in [main.sidebar.name_button, main.sidebar.government_button]:
		b.pressed.emit()
		eq(main.identity_modal.shown(), [civ_name(), gov_name()], "'%s' opens it" % b.text)
		main.modals.close_all()
		b.grab_focus()
		press_key(main, KEY_ENTER)
		eq(main.identity_modal.shown(), [civ_name(), gov_name()], "Enter on '%s' opens it" % b.text)
		main.modals.close_all()
	close_at(main)


# --- AC3: following the government ---

func test_under_anarchy_the_sidebar_reads_anarchy() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var e := Game.engine
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	e.end_turn()
	if not main.event_modal().is_empty():
		main.event_modal_ok_button().pressed.emit()
	await wait_frames()
	eq(gov_name(), "Anarchy", "precondition: Anarchy rules")
	eq(main.sidebar.government_button.text, "Anarchy ›", "the sidebar follows")
	close_at(main)


# --- AC4: no top-bar button ---

func test_the_top_bar_has_no_civilization_button() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var top_bar := TopBar.new(func(): pass, func(): pass, func(): pass, func(): pass)
	check(not top_bar.has_method("identity_button"), "TopBar.identity_button() is gone")
	top_bar.free()
	var strip: Control = (main.counter(GameEngine.FOOD) as Control).get_parent()
	for b in UIKit.buttons_in(strip):
		check(not b.text.contains(civ_name()) and not b.text.contains(gov_name()), "no '%s' in the top strip" % b.text)
	close_at(main)


# --- AC5: focus order ---

func test_tab_from_the_strips_last_button_reaches_the_sidebar() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var strip: Control = (main.counter(GameEngine.FOOD) as Control).get_parent()
	var buttons := UIKit.buttons_in(strip).filter(func(b): return b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE)
	(buttons.back() as Button).grab_focus()
	press_key(main, KEY_TAB)
	eq(main.get_viewport().gui_get_focus_owner(), main.sidebar.name_button, "Tab from '%s' reaches the name" % buttons.back().text)
	press_key(main, KEY_TAB)
	eq(main.get_viewport().gui_get_focus_owner(), main.sidebar.government_button, "then the government")
	close_at(main)


# --- AC6: hidden with the board ---

func test_the_sidebar_is_hidden_on_the_title_and_new_game_screens() -> void:
	var main := open_main()
	await wait_frames()
	check(main.start_screen.is_open(), "precondition: the title screen")
	check(not (main.sidebar as Control).is_visible_in_tree(), "hidden on the title screen")
	main.show_new_game_screen()
	await wait_frames()
	check(not (main.sidebar as Control).is_visible_in_tree(), "hidden on the new game screen")
	close_main(main)
