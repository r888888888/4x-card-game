extends "res://tests/lib/tech_case.gd"
## Button widths in the real main scene (backlog 100), measured after layout at 1920×1080. A button fits its text
## (its width is its minimum width); a stacked column of buttons in a menu or a screen shares the widest button's
## width and is centred in its panel; tech tiles and seed fields fill.

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
			what, b.get("text") if b is Button else b.name, b.size.x, widest])
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
	var keys: Array = [title.new_game_button, title.settings_button, title.exit_button]  # flush left since 213
	for b in keys:
		eq(b.size.x, keys[0].size.x, "title screen: '%s' shares the column's width" % b.text)
		eq(b.get_global_rect().position.x, keys[0].get_global_rect().position.x, "title screen: '%s' flush left" % b.text)
	title.settings_button.pressed.emit()
	await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout  # the sheet's rise (207)
	var settings: Object = main.settings_modal  # the Settings modal since 206
	check_column(settings.motion_toggle.get_parent().get_parent().get_children(), "Settings modal")  # 182, 185: its rows
	check_fits(settings.close_button, "Settings modal's Close")
	settings.close_button.pressed.emit()
	title.new_game_button.pressed.emit()
	await wait_frames()
	check_fits(main.new_game_screen.start_button, "new game screen's Start")  # at the detail pane's foot (212)
	check_fits(main.new_game_screen.back_button, "new game screen's header back")  # 104: Back moved to the header
	close_at_1080(main)


func test_the_menu_column_shares_one_width_and_footer_buttons_fit_their_text() -> void:
	var main := open_at_1080()
	main.start_game(1)
	main.open_menu()
	await wait_frames()
	var column: Array = []  # untyped: menu_buttons() is Array[Button]
	var footer: Array = main.menu_buttons().filter(func(b): return b.text in ["Close (Esc)", "Exit"])  # in the sheet's footer (207)
	eq(footer.size(), 2, "Close and Exit in the menu's footer")
	for b in footer:
		check_fits(b, "menu footer %s" % b.text)
	column.assign(main.menu_buttons().filter(func(b): return not footer.has(b)))  # Restart, New game, Settings (206)
	check_column(column, "menu")
	press_key(main, KEY_ESCAPE)
	play_seed_1(main, func(_m): pass)
	await wait_frames()
	check(Game.engine.is_over, "game over")
	for b in main.game_over_buttons():  # in the sheet's footer since 207
		check_fits(b, "game over %s" % b.text)
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


# --- AC4: the side panel is gone (115): the top bar's buttons fit their text (test_board_layout) ---


# --- AC5: tech tiles fill their era column ---

func test_tech_tiles_fill_their_era_column() -> void:
	var main := open_at_1080()
	main.start_game(1)
	main.tech_tree.open()
	await wait_frames()
	# Each tech is a row in its era column: the tile, then (140) a Learn button while it can be learned.
	var tiles := UIKit.buttons_in(main.tech_tree).filter(func(b): return b.is_visible_in_tree() \
		and b.get_parent() is HBoxContainer and b.get_index() == 0 and b.get_parent() != main.tech_tree.footer)  # 207: not the sheet's footer
	check(not tiles.is_empty(), "tech tiles shown")
	for b in tiles:
		var row: HBoxContainer = b.get_parent()
		var column: Control = row.get_parent()
		check(absf(row.size.x - column.size.x) <= TOLERANCE, "row fills its column: %d, %d" % [row.size.x, column.size.x])
		var rest := 0.0  # the Learn button and the gap before it
		if row.get_child_count() > 1:
			rest = (row.get_child(1) as Control).size.x + row.get_theme_constant("separation")
		check(absf(b.size.x + rest - row.size.x) <= TOLERANCE, "tile takes the rest of its row: %d + %d, %d" % [
			b.size.x, rest, row.size.x])
	close_at_1080(main)


# --- AC6: seed fields still fill their row ---

func test_seed_fields_still_fill_their_row() -> void:
	var main := open_at_1080()
	main.start_screen.new_game_button.pressed.emit()
	await wait_frames()
	check_fills_row(main.new_game_screen.seed_edit, "new game screen")
	main.start_game(1)
	await open_settings_modal(main)  # the seed field is in the Settings modal's Game section since 206
	await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout
	check_fills_row(main.settings_modal.seed_edit, "Settings modal")
	close_at_1080(main)


func check_fills_row(field: Control, what: String) -> void:
	var gap: float = field.get_parent().get_global_rect().end.x - field.get_global_rect().end.x
	check(absf(gap) <= TOLERANCE, "%s: seed field reaches its row's right edge (gap %d)" % [what, gap])
