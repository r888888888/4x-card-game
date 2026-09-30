extends "res://tests/lib/tech_case.gd"
## Button widths in the real main scene (backlog 100), measured after layout at 1920×1080. A button fits its text
## (its width is its minimum width); a stacked column of buttons in a menu or a screen shares the widest button's
## width and is centred in its panel; list rows (the side panel's identity lines), tech tiles and seed fields fill.

const TOLERANCE := 1.0

var _old_window_size := Vector2i.ZERO


## Opens main at the base resolution. Pair with close_at_1080.
func open_at_1080() -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)  # headless starts at another size
	return open_main()


func close_at_1080(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


## The first button under root that is visible on screen and whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


## Checks that b is only as wide as its text and padding.
func check_fits(b: Button, what: String) -> void:
	check(b != null, "%s: a button" % what)
	if b == null:
		return
	var minimum := b.get_combined_minimum_size().x
	check(absf(b.size.x - minimum) <= TOLERANCE, "%s fits its text: width %d, minimum %d" % [what, b.size.x, minimum])


## Checks that buttons share the widest one's minimum width and are centred in their panel.
func check_column(buttons: Array, what: String) -> void:
	check(not buttons.is_empty() and not buttons.has(null), "%s: buttons %s" % [what, buttons])
	if buttons.is_empty() or buttons.has(null):
		return
	var widest := 0.0
	for b in buttons:
		widest = maxf(widest, b.get_combined_minimum_size().x)
	for b in buttons:
		check(absf(b.size.x - widest) <= TOLERANCE, "%s: '%s' is %d wide, the widest button's minimum is %d" % [
			what, b.text, b.size.x, widest])
	var panel := panel_of(buttons[0])
	var centre: float = buttons[0].get_global_rect().get_center().x
	var panel_centre := panel.get_global_rect().get_center().x
	check(absf(centre - panel_centre) <= TOLERANCE, "%s: column centre %d, panel centre %d" % [what, centre, panel_centre])


## The nearest PanelContainer holding c (an overlay's panel).
func panel_of(c: Control) -> Control:
	var node: Node = c.get_parent()
	while node != null and not node is PanelContainer:
		node = node.get_parent()
	return node


# --- AC1: stacked columns share one width, centred ---

func test_title_settings_and_new_game_columns_share_one_width() -> void:
	var main := open_at_1080()
	await wait_frames()
	var title: Object = main.start_screen
	check_column([title.new_game_button, title.settings_button, title.exit_button], "title screen")
	title.settings_button.pressed.emit()
	await wait_frames()
	check_column([main.settings_screen.motion_toggle, main.settings_screen.back_button], "settings screen")
	main.settings_screen.back_button.pressed.emit()
	title.new_game_button.pressed.emit()
	await wait_frames()
	check_column([main.new_game_screen.start_button, main.new_game_screen.back_button], "new game screen")
	close_at_1080(main)


func test_menu_and_game_over_columns_share_one_width() -> void:
	var main := open_at_1080()
	main.start_game(1)
	main.open_menu()
	await wait_frames()
	check_column(main.menu_buttons(), "menu")
	press_key(main, KEY_ESCAPE)
	play_seed_1(main, func(_m): pass)
	await wait_frames()
	check(Game.engine.is_over, "game over")
	check_column(main.game_over_buttons(), "game over")
	close_at_1080(main)


# --- AC2: modal and choice buttons fit their text ---

func test_modal_close_buttons_fit_their_text() -> void:
	var main := open_at_1080()
	main.start_game(1)
	main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
	await wait_frames()
	check_fits(shown_button(main.details, "Close"), "card details Close")
	main.details.close()
	main.open_supply()
	await wait_frames()
	check_fits(shown_button(main, "Close (S"), "Buy Cards Close")
	main.supply.close()
	main.tech_tree.open()
	await wait_frames()
	check_fits(shown_button(main.tech_tree, "Close"), "Knowledge Close")
	close_at_1080(main)


func test_event_ok_fits_its_text() -> void:
	var real := Game.engine
	var fixture := []
	with_event_engine(func(): fixture.append(Game.engine), {"windfall": 1})
	Game.engine = fixture[0]
	var main := open_at_1080()
	main.start_game(1)
	Game.engine.end_turn()
	await wait_frames()
	check_fits(main.event_modal_ok_button(), "event OK")
	close_at_1080(main)
	Game.engine = real


func test_research_decline_fits_its_text() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"])
	var main := open_at_1080()
	main.start_game(1)
	check(play_research(Game.engine), "research should open")
	await wait_frames()
	check_fits(shown_button(main, "Decline"), "Decline")
	close_at_1080(main)
	Game.engine = real


# --- AC3: board buttons fit their text ---

func test_board_buttons_fit_their_text() -> void:
	var main := open_at_1080()
	main.start_game(1)
	await wait_frames()
	check_fits(shown_button(main, "Menu"), "Menu")
	var home := home_uid(Game.engine)
	main.views[home].details_requested.emit(main.views[home])  # a click: the territory view (101, 102)
	await wait_frames()
	check_fits(main.territory_view.back_button, "territory view Back")
	check_fits(main.territory_view.grow_button, "territory view Grow")
	close_at_1080(main)


# --- AC4: the side panel ---

func test_side_panel_actions_fit_their_text_at_its_left_edge() -> void:
	var main := open_at_1080()
	main.start_game(1)
	await wait_frames()
	var knowledge := shown_button(main, "Knowledge")
	var side: Control = knowledge.get_parent() if knowledge != null else null
	for prefix in ["Buy Cards", "Knowledge", "End turn"]:
		var b := shown_button(main, prefix)
		check_fits(b, prefix)
		if b != null and side != null:
			eq(b.get_parent(), side, "%s is in the side panel" % prefix)
			check(absf(b.global_position.x - side.global_position.x) <= TOLERANCE, "%s at the side panel's left edge: %d, %d" % [
				prefix, b.global_position.x, side.global_position.x])
	close_at_1080(main)


func test_identity_lines_still_span_the_side_panel() -> void:
	var main := open_at_1080()
	main.start_game(1)
	await wait_frames()
	var lines: Array[Button] = main.identity_buttons()
	check(not lines.is_empty(), "the real data shows a civilization line")
	for b in lines:
		var side: Control = b.get_parent()
		check(absf(b.size.x - side.size.x) <= TOLERANCE, "'%s' spans the panel: %d, %d" % [b.text, b.size.x, side.size.x])
	close_at_1080(main)


# --- AC5: tech tiles fill their era column ---

func test_tech_tiles_fill_their_era_column() -> void:
	var main := open_at_1080()
	main.start_game(1)
	main.tech_tree.open()
	await wait_frames()
	var tiles := UIKit.buttons_in(main.tech_tree).filter(func(b): return b.is_visible_in_tree() and b.get_parent() is VBoxContainer \
		and not b.text.begins_with("Close"))
	check(not tiles.is_empty(), "tech tiles shown")
	for b in tiles:
		var column: Control = b.get_parent()
		check(absf(b.size.x - column.size.x) <= TOLERANCE, "tile fills its column: %d, %d" % [b.size.x, column.size.x])
	close_at_1080(main)


# --- AC6: seed fields still fill their row ---

func test_seed_fields_still_fill_their_row() -> void:
	var main := open_at_1080()
	main.start_screen.new_game_button.pressed.emit()
	await wait_frames()
	check_fills_row(main.new_game_screen.seed_edit, "new game screen")
	main.start_game(1)
	main.open_menu()
	await wait_frames()
	var fields := main.find_children("*", "LineEdit", true, false).filter(func(l): return l.is_visible_in_tree())
	eq(fields.size(), 1, "the menu's seed field")
	for field in fields:
		check_fills_row(field, "menu")
	close_at_1080(main)


func check_fills_row(field: Control, what: String) -> void:
	var gap: float = field.get_parent().get_global_rect().end.x - field.get_global_rect().end.x
	check(absf(gap) <= TOLERANCE, "%s: seed field reaches its row's right edge (gap %d)" % [what, gap])
