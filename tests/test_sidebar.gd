extends "res://tests/lib/test_case.gd"
## The right sidebar (backlog 202) in the real main scene at 1920×1080: the civilization's name and its government at
## the board's right edge, full height under the top strip, opening the civilization modal. Hooks: main.sidebar
## (heading, name_button, government_button).
## In detail (from docs/testing.md, 331): The right sidebar (202) in the real `main.tscn`: the civilization's name and
## government link (`main.sidebar`: `heading`, `name_button`, `government_button`), at the right edge under the top
## strip with the Realm and hand to its left (1280×720, 1920×1080), opening the civilization modal (click, Enter),
## following Anarchy, no top-bar button, in the focus order after the strip, hidden on the start screens; the mock's
## frame (221): the top bar on a full-bleed ruled `Strip`, the open `Rail` with a hairline, the government as a
## `CapsLink`, the Realm heading level with the rail's rule

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
	eq(bar.government_button.text, "%s ›" % gov_name().to_upper(), "the government as a link, in capitals (221)")
	eq(bar.government_button.theme_type_variation, &"CapsLink", "the CapsLink look (221)")
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
	check(e.anarchy() != -1 and e.government() == -1, "precondition: Anarchy, no government (253)")
	eq(main.sidebar.government_button.text, "ANARCHY ›", "the sidebar names Anarchy while no government rules")
	close_at(main)


# --- AC4: no top-bar button ---

func test_the_top_bar_has_no_civilization_button() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var methods: Array = (load("res://ui/top_bar.gd") as Script).get_script_method_list().map(func(m): return m.name)
	check(not methods.has("identity_button"), "TopBar.identity_button() is gone")
	var strip: Node = top_strip(main)
	for b in UIKit.buttons_in(strip):
		check(not b.text.contains(civ_name()) and not b.text.contains(gov_name()), "no '%s' in the top strip" % b.text)
	close_at(main)


## main's top strip, the TopBar holding the counters (218: they sit in a row of their own inside it).
func top_strip(main: Node) -> Node:
	var node: Node = main.counter(GameEngine.FOOD)
	while node != null and not node is TopBar:
		node = node.get_parent()
	return node


# --- AC5: focus order ---

func test_tab_from_the_strips_last_button_reaches_the_sidebar() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var strip: Node = top_strip(main)
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


# --- 221: the mock's strip, open rail, type and alignment ---

## The strip the top bar sits on: the TopBar's parent, or null.
func strip_panel(main: Node) -> Control:
	var bar: Node = top_strip(main)
	return bar.get_parent() as Control if bar != null else null


func test_the_top_bar_sits_on_a_full_bleed_strip_ruled_underneath() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var main: Node = await open_at(size)
		var strip := strip_panel(main)
		var viewport: Vector2 = main.get_viewport_rect().size
		eq(strip.theme_type_variation, &"Strip", "%s: the Strip look" % size)
		var r := strip.get_global_rect()
		eq(r.position, Vector2.ZERO, "%s: from the window's top-left corner" % size)
		check(absf(r.size.x - viewport.x) <= TOLERANCE, "%s: the window's full width: %d of %d" % [size, r.size.x, viewport.x])
		var box := strip.get_theme_stylebox("panel") as StyleBoxFlat
		check(box != null, "%s: a flat box" % size)
		if box != null:
			eq(box.bg_color, Palette.RAISED, "%s: RAISED" % size)
			eq(box.border_color, Palette.TEXT, "%s: a TEXT rule" % size)
			eq([box.border_width_left, box.border_width_top, box.border_width_right, box.border_width_bottom], [0, 0, 0, 3],
				"%s: 3 px along the bottom only" % size)
		close_at(main)


func test_the_rail_is_open_on_the_board_with_a_hairline_to_its_left() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var main: Node = await open_at(size)
		var bar: Control = main.sidebar
		var viewport: Vector2 = main.get_viewport_rect().size
		eq(bar.theme_type_variation, &"Rail", "%s: the Rail look" % size)
		var box := bar.get_theme_stylebox("panel") as StyleBoxFlat
		check(box != null, "%s: a flat box" % size)
		if box != null:
			check(not box.draw_center or box.bg_color.a == 0.0 or box.bg_color == Palette.BACKGROUND,
				"%s: no fill of its own, or the board's (224: a sliding screen passes under it)" % size)
			eq(box.border_color, Palette.HAIRLINE, "%s: a HAIRLINE rule" % size)
			eq([box.border_width_left, box.border_width_top, box.border_width_right, box.border_width_bottom], [1, 0, 0, 0],
				"%s: 1 px on the left only" % size)
		var rail := bar.get_global_rect()
		var strip := strip_panel(main).get_global_rect()
		check(absf(rail.position.y - strip.end.y) <= TOLERANCE, "%s: from the strip's bottom: %d, strip ends %d" % [size, rail.position.y, strip.end.y])
		check(absf(viewport.y - rail.end.y) <= TOLERANCE, "%s: to the window's bottom: %d of %d" % [size, rail.end.y, viewport.y])
		check(absf(viewport.x - rail.end.x) <= TOLERANCE, "%s: to the window's right: %d of %d" % [size, rail.end.x, viewport.x])
		close_at(main)


func test_the_government_link_is_in_the_heading_face_under_a_3_px_rule() -> void:
	var main: Node = await open_at(Vector2i(1920, 1080))
	var gov: Button = main.sidebar.government_button
	eq(gov.get_theme_font_size("font_size"), Tokens.TYPE_HEADING, "at TYPE_HEADING")
	var font := gov.get_theme_font("font") as FontVariation
	check(font != null and font.base_font == GameTheme.LABEL_SEMIBOLD and font.spacing_glyph > 0, "the heading face, tracked")
	eq(gov.get_theme_color("font_color"), Palette.TEXT_DIM, "TEXT_DIM")
	eq(gov.get_theme_color("font_hover_color"), Palette.TEXT, "TEXT on hover")
	var rule: ColorRect = main.sidebar.column.get_node("Rule")
	eq(rule.size.y, 3.0, "a 3 px rule")
	eq(rule.color, Palette.TEXT, "in TEXT")
	close_at(main)


func test_the_realm_heading_and_the_rails_rule_line_up_space_4_under_the_strip() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var main: Node = await open_at(size)
		var heading := (main.tableau as Control).get_parent().get_child(0) as Label
		eq(heading.text, "Realm", "%s: precondition: the Realm heading" % size)
		var rule: Control = main.sidebar.column.get_node("Rule")
		var strip := strip_panel(main).get_global_rect()
		var top: float = strip.end.y + Tokens.SPACE_4
		check(absf(heading.get_global_rect().position.y - top) <= TOLERANCE, "%s: the heading SPACE_4 under the strip: %d, want %d" % [size, heading.get_global_rect().position.y, top])
		check(absf(rule.get_global_rect().position.y - top) <= TOLERANCE, "%s: the rule SPACE_4 under the strip: %d, want %d" % [size, rule.get_global_rect().position.y, top])
		check(absf(heading.get_global_rect().position.x - Tokens.SPACE_4) <= TOLERANCE, "%s: the heading SPACE_4 from the left: %d" % [size, heading.get_global_rect().position.x])
		close_at(main)
