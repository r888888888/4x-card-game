extends "res://tests/lib/test_case.gd"
## Modals as the specimen's drafting sheets (backlog 207), in the real main scene: the sheet's look (paper, 341, in
## a 2 px TEXT rule, square, on a soft shadow), its title block (a 4 px TEXT bar, the title left, context caps right),
## a body at most Modal.BODY_MAX_WIDTH wide and a footer under a 1 px rule with the buttons right (primary rightmost);
## the game menu and the game-over sheet as Modals on main.modals; the rise on opening, the stacked offset and the drop
## on closing. Hooks on Modal: title, context, title_label, context_label, bar, body, footer, footer_rule,
## sheet_offset() (how far the sheet is from its place), sheet_alpha(), scrim_alpha(). 344: the ledger sheet's sizes
## (Modal.LEDGER_*: 384 + 32 + 264, 12 rows of 40 px) and the card sheet's aside outside the body's cap.
## In detail (from docs/testing.md, 331): Modals as drafting sheets (207) in the real `main.tscn` at 1920×1080: each
## modal's sheet (paper, 2 px TEXT rule, soft shadow), title block (4 px bar, title, context caps), body at most
## 640 px, footer under a 1 px rule (primary rightmost); the menu and game over on `main.modals` (game over stays); the
## rise, the stacked +8,+8, the drop, Reduce motion fades; hooks `sheet_offset()`, `sheet_alpha()`, `scrim_alpha()`

const Looks := preload("res://tests/lib/surface_looks.gd")
const RISE := 24.0  # px below its place a sheet starts
const DROP := 12.0  # px below its place a closing sheet ends
const STACK := Vector2(8, 8)
const MODAL_PATH := "res://ui/modal.gd"


## Waits past a sheet's longest motion (the rise, Anim's 0.24 s).
func wait_sheet() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(0.24 + 0.15).timeout


## The texts of the buttons in modal's footer, left to right.
func footer_texts(modal: Object) -> Array[String]:
	var out: Array[String] = []
	for b in (modal.footer as Control).get_children():
		if b is Button and (b as Button).visible:
			out.append((b as Button).text)
	return out


## Checks modal (open, settled) is a sheet titled title with context (or none for "") and a footer reading footer.
func check_sheet(modal: Object, what: String, title: String, context: String, footer: Array[String]) -> void:
	check(modal is Modal, "%s is a Modal" % what)
	if not modal is Modal:
		return
	var surface := (modal.panel as Control).get_theme_stylebox("panel")
	var paper := Looks.mismatch(surface, Looks.paper())
	check(paper == "", "%s: on paper (341): %s" % [what, paper])
	var box := Looks.frame_of(surface)
	check(box != null, "%s: a framed sheet" % what)
	if box != null:
		eq(box.border_color, Palette.TEXT, "%s: TEXT rule" % what)
		eq([box.border_width_left, box.border_width_top, box.border_width_right, box.border_width_bottom], [2, 2, 2, 2],
			"%s: 2 px rule" % what)
		eq(box.corner_radius_top_left, Tokens.RADIUS_0, "%s: square" % what)
		eq(Color(box.shadow_color, 1.0), Color(Palette.SHADOW, 1.0), "%s: SHADOW" % what)
		eq(box.shadow_offset, Vector2(0, 16), "%s: a soft shadow straight down 16 (341)" % what)
	var bar := modal.bar as ColorRect
	check(bar != null and bar.is_visible_in_tree(), "%s: the title block's bar" % what)
	if bar != null:
		eq(bar.color, Palette.TEXT, "%s: the bar is ink" % what)
		eq(bar.size.y, 4.0, "%s: the bar is 4 px" % what)
	var title_label := modal.title_label as Label
	eq(modal.title, title, "%s: title" % what)
	eq(title_label.text, title, "%s: the title label" % what)
	eq(title_label.theme_type_variation, &"Title", "%s: the title in the Title variation" % what)
	var context_label := modal.context_label as Label
	if context == "":
		check(not context_label.is_visible_in_tree(), "%s: no context" % what)
	else:
		eq(modal.context, context, "%s: context" % what)
		check(context_label.is_visible_in_tree() and context_label.uppercase, "%s: context in caps" % what)
		eq(context_label.text, context, "%s: the context label" % what)
		check(context_label.get_global_rect().position.x > title_label.get_global_rect().end.x,
			"%s: the context right of the title" % what)
		check(bar.get_global_rect().end.y <= title_label.get_global_rect().position.y + 1.0, "%s: the bar on top" % what)
	var body := modal.body as Control
	eq(load(MODAL_PATH).get("BODY_MAX_WIDTH"), 640, "the body's limit")
	check(body.size.x <= 640, "%s: the body is %d px, at most 640" % [what, body.size.x])
	eq(footer_texts(modal), footer, "%s: footer buttons, primary rightmost" % what)
	var rule := modal.footer_rule as ColorRect
	check(rule != null and rule.is_visible_in_tree(), "%s: a rule over the footer" % what)
	if rule != null:
		eq(rule.color, Palette.CONTROL_DISABLED_BORDER, "%s: the rule's colour" % what)
		eq(rule.size.y, 1.0, "%s: a 1 px rule" % what)
		check(rule.get_global_rect().end.y <= (modal.footer as Control).get_global_rect().position.y + 1.0,
			"%s: the rule above the buttons" % what)
	var footer_box := modal.footer as Control
	var panel_rect := (modal.panel as Control).get_global_rect()
	var last := footer_box.get_children().filter(func(c): return c is Button and c.visible)
	if not last.is_empty():
		var right: float = (last.back() as Control).get_global_rect().end.x
		check(panel_rect.end.x - right <= Tokens.SPACE_6 + 2, "%s: the buttons sit at the right (%d px from the edge)" % [
			what, panel_rect.end.x - right])


# --- AC1, AC2: every modal is a sheet ---

func test_card_details_is_a_sheet_titled_with_the_card_and_its_type() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		var card: CardInstance = Game.engine.zone("hand").cards[0]
		main.details.open(main.views[card.uid])
		await wait_sheet()
		check_sheet(main.details, "card details", card.def.name, card.def.type.capitalize(),
			["Close", "Play"] as Array[String])  # a hand card's details offer Play (225)
		eq(accent_footer(main.details), ["Play"] as Array[String], "251: Play is the one primary")
		close_game(main))


func test_the_civilization_modal_is_a_sheet() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		check_sheet(main.identity_modal, "civilization", "Civilization", "", ["Close"] as Array[String])
		eq(accent_footer(main.identity_modal), [] as Array[String], "251: nothing to do, no primary")
		close_game(main))


func test_the_event_modal_is_a_sheet_with_the_turn_as_context() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		for i in 10:
			Game.engine.end_turn()
			if not MainProbe.event_modal(main).is_empty() and MainProbe.event_option_buttons(main).is_empty():
				break
			close_event(main)  # a choice event has no OK: wait for one that does
		check(not MainProbe.event_modal(main).is_empty(), "precondition: an event without choices within 10 turns of seed 1")
		await wait_sheet()
		var modal: Object = main.modals.top()
		var def: CardDef = Game.engine.card_db[MainProbe.event_modal(main).id]
		check_sheet(modal, "event", def.name, "Turn %d" % Game.engine.turn, ["OK (Enter)"] as Array[String])
		eq(accent_footer(modal), ["OK (Enter)"] as Array[String], "251: OK is the primary")
		close_game(main))


func test_the_menu_is_a_sheet_on_the_modal_stack() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.open_menu()
		await wait_sheet()
		eq(main.modals.depth(), 1, "the menu is on main.modals")
		check_sheet(main.modals.top(), "menu", "Menu", "", ["Close", "Exit game"] as Array[String])
		eq(accent_footer(main.modals.top()), [] as Array[String], "251: the menu has no primary")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		eq(main.modals.depth(), 0, "Esc closes it")
		close_game(main))


func test_game_over_is_a_sheet_on_the_modal_stack_that_stays() -> void:
	await with_temp_settings(func():
		(Engine.get_main_loop() as SceneTree).root.size = Vector2i(1920, 1080)
		var main := open_main()
		main.quit_hook = func(): pass  # the test never quits the run
		play_seed_1(main, func(_m): pass)
		await wait_sheet()
		check(Game.engine.is_over, "precondition: game over")
		while not MainProbe.event_modal(main).is_empty():  # the last turn's event, if any, closes first
			MainProbe.event_modal_ok_button(main).pressed.emit()
		await wait_sheet()
		eq(main.modals.depth(), 1, "the game-over sheet is on main.modals")
		var sheet: Object = main.modals.top()
		check_sheet(sheet, "game over", "Game over", "", ["New game", "Replay this seed"] as Array[String])
		eq(accent_footer(sheet), ["Replay this seed"] as Array[String], "251: Replay is the primary")
		press_key(main, KEY_ESCAPE)
		var outside := Vector2(4, 4)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = outside
			event.global_position = outside
			main.get_viewport().push_input(event, true)
		await wait_frames()
		eq(main.modals.top(), sheet, "Esc and a click outside leave it open")
		close_game(main))


# --- 251: the primary action in the signal colour ---

func test_a_primary_footer_button_wears_the_accent_look_and_the_others_stay_plain() -> void:
	var main := open_main()
	var modal := Modal.new(main.modals)
	var cancel := modal.add_footer_button(UIKit.button("Cancel", func(): pass))
	var go := modal.add_footer_button(UIKit.button("Go", func(): pass), true)
	eq(go.theme_type_variation, &"AccentButton", "the primary is an AccentButton")
	eq(cancel.theme_type_variation, &"", "the other keeps the plain Button look")
	close_game(main)


func test_settings_and_board_card_details_have_no_primary() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		await open_settings_modal(main)
		check(main.settings_modal.is_open(), "precondition: Settings open")
		eq(accent_footer(main.settings_modal), [] as Array[String], "Settings: no primary")
		main.settings_modal.close()
		main.details.open(main.views[home_uid(Game.engine)])
		await wait_frames()
		eq(footer_texts(main.details), ["Close"] as Array[String], "a board card's details: Close only")
		eq(accent_footer(main.details), [] as Array[String], "a board card's details: no primary")
		close_game(main))


# --- AC3: laid down ---

func test_a_sheet_rises_into_place_and_its_scrim_fades_in() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		var modal: Object = main.identity_modal
		eq(modal.sheet_offset(), Vector2(0, RISE), "starts 24 px below its place")
		eq(modal.sheet_alpha(), 0.0, "starts see-through")
		eq(modal.scrim_alpha(), 0.0, "its scrim starts clear")
		await wait_seconds(0.135)
		check(is_equal_approx(modal.sheet_alpha(), 1.0), "opaque by 0.12 s: %.2f" % modal.sheet_alpha())
		check(modal.sheet_offset().y > 0.0 and modal.sheet_offset().y < RISE, "still rising at 0.13 s: %s" % modal.sheet_offset())
		check(modal.scrim_alpha() > 0.0 and modal.scrim_alpha() < 1.0, "the scrim still fading at 0.13 s: %.2f" % modal.scrim_alpha())
		await wait_seconds(0.15)
		eq(modal.sheet_offset(), Vector2.ZERO, "in place by 0.24 s")
		eq(modal.scrim_alpha(), 1.0, "the scrim in by 0.16 s")
		check(modal.panel.get_global_rect().get_center().distance_to(main.get_viewport_rect().get_center()) <= 1.0,
			"centred once in place")
		close_game(main))


func test_with_reduce_motion_a_sheet_only_fades_in() -> void:
	await with_temp_settings(func():
		Settings.store.reduce_motion = true
		var main: Node = await open_game(true)
		main.identity_modal.open()
		var modal: Object = main.identity_modal
		eq(modal.sheet_offset(), Vector2.ZERO, "no rise")
		eq(modal.sheet_alpha(), 0.0, "a fade")
		await wait_seconds(0.135)
		eq(modal.sheet_alpha(), 1.0, "opaque by 0.12 s")
		eq(modal.sheet_offset(), Vector2.ZERO, "never moved")
		close_game(main))


# --- AC4: stacked ---

func test_a_sheet_over_another_sits_8_8_from_it_and_rises_without_a_second_scrim_fade() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
		eq(main.details.sheet_offset(), Vector2(0, RISE), "it rises too")
		eq(main.details.scrim_alpha(), 1.0, "its scrim shows at once: no second fade")
		await wait_sheet()
		var below: Rect2 = main.identity_modal.panel.get_global_rect()
		var above: Rect2 = main.details.panel.get_global_rect()
		var shift: Vector2 = above.get_center() - main.get_viewport_rect().get_center()
		check(shift.distance_to(STACK) <= 1.0, "+8,+8 from centre: %s" % shift)
		check(below.get_center().distance_to(main.get_viewport_rect().get_center()) <= 1.0, "the one below stays centred")
		close_game(main))


# --- AC5: lifted off ---

func test_a_closing_sheet_drops_and_fades_while_the_one_below_takes_input() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
		await wait_sheet()
		var details: Object = main.details
		details.close()
		eq(main.modals.top(), main.identity_modal, "the one below is on top at once")
		check(details.panel.is_visible_in_tree(), "the closing sheet is still drawn")
		check(details.sheet_alpha() > 0.5, "and starts opaque")
		check(details.shown().is_empty(), "but no longer counts as shown")
		await wait_seconds(0.08)
		check(details.sheet_offset().y > 0.0 and details.sheet_offset().y < DROP, "dropping: %s" % details.sheet_offset())
		press_key(main, KEY_ESCAPE)
		eq(main.modals.depth(), 0, "Esc while it leaves closes the one below")
		await wait_seconds(0.12)
		check(not details.panel.is_visible_in_tree(), "gone by 0.16 s")
		close_game(main))


func test_a_closed_sheet_ends_12_px_below_clear_and_comes_back_in_place() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		main.identity_modal.close()
		await wait_seconds(0.12)  # three quarters through (a later sample races the reset at its end)
		var off: Vector2 = main.identity_modal.sheet_offset()
		check(off.y > DROP * 0.3 and off.y <= DROP, "dropping toward 12 px below, gathering speed: %s" % off)
		check(main.identity_modal.sheet_alpha() < 0.5, "most of the way to clear")
		await wait_sheet()
		main.identity_modal.open()
		eq(main.identity_modal.sheet_offset(), Vector2(0, RISE), "reopened: rises from 24 px again")
		close_game(main))


func test_closing_several_sheets_at_once_lifts_them_together() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
		await wait_sheet()
		main.modals.close_all()
		eq(main.modals.depth(), 0, "both closed at once")
		check(main.identity_modal.panel.is_visible_in_tree() and main.details.panel.is_visible_in_tree(), "both still drawn")
		await wait_seconds(0.08)
		check(main.identity_modal.sheet_offset().y > 0.0 and main.details.sheet_offset().y > 0.0, "both dropping")
		await wait_seconds(0.12)
		check(not main.identity_modal.panel.is_visible_in_tree() and not main.details.panel.is_visible_in_tree(), "both gone")
		close_game(main))


func test_with_reduce_motion_a_closing_sheet_only_fades() -> void:
	await with_temp_settings(func():
		Settings.store.reduce_motion = true
		var main: Node = await open_game(true)
		main.identity_modal.open()
		await wait_sheet()
		main.identity_modal.close()
		await wait_seconds(0.06)
		eq(main.identity_modal.sheet_offset(), Vector2.ZERO, "no drop")
		check(main.identity_modal.sheet_alpha() < 1.0, "fading")
		await wait_sheet()
		check(not main.identity_modal.panel.is_visible_in_tree(), "gone")
		close_game(main))


# --- Backlog 344: the modal layouts (text, card and ledger sheets) ---

func test_the_ledger_sizes_are_modal_constants() -> void:
	eq(Modal.LEDGER_LIST_WIDTH, Tokens.SPACE_9 * 4, "the list column: 384")
	eq(Modal.LEDGER_GAP, Tokens.SPACE_6, "the gap: 32")
	eq(Modal.LEDGER_DETAIL_WIDTH, int(CardView.HAND_SIZE.x), "the detail column: a hand card's width, 264")
	eq(Modal.LEDGER_ROWS, 12, "12 one-line rows before the list scrolls")
	eq(Modal.LEDGER_WIDTH, 680, "the ledger: 384 + 32 + 264")
	eq(Modal.BODY_MAX_WIDTH, 640, "a text sheet's cap is unchanged")


func test_the_ledger_list_is_twelve_one_line_rows_tall() -> void:
	var root := Control.new()
	root.theme = GameTheme.build()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	var list := UIKit.select_list()
	root.add_child(list)
	var row := list.add_row("a", "Farm   2 food")
	await wait_frames()
	eq(Modal.LEDGER_LIST_HEIGHT, 480, "480 px")
	eq(row.get_combined_minimum_size().y * Modal.LEDGER_ROWS, float(Modal.LEDGER_LIST_HEIGHT), "12 one-line rows")
	root.free()


func test_a_ledger_and_the_sheets_padding_fit_the_viewport() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		var modal: Modal = main.details
		var sheet := (modal.panel as Control).get_theme_stylebox("panel")
		var padding := sheet.get_margin(SIDE_LEFT) + sheet.get_margin(SIDE_RIGHT)
		var width := Modal.LEDGER_WIDTH
		check(width + padding <= main.get_viewport().get_visible_rect().size.x,
			"a %d px ledger in %d px of padding fits" % [width, padding])
		close_game(main))


func test_a_card_sheet_keeps_its_hand_size_card_left_of_a_capped_body() -> void:
	await with_temp_settings(func():
		var main: Node = await open_game(true)
		var card: CardInstance = Game.engine.zone("hand").cards[0]
		main.details.open(main.views[card.uid])
		await wait_sheet()
		var aside: Control = main.details.aside
		var body: Control = main.details.body
		var shown := aside.find_children("*", "CardView", true, false)
		check(aside.is_visible_in_tree() and not shown.is_empty(), "the card is in the aside")
		if not shown.is_empty():
			eq((shown[0] as CardView).size, CardView.HAND_SIZE, "at hand size")
		check(aside.get_global_rect().end.x <= body.get_global_rect().position.x, "left of the body")
		check(body.size.x <= Modal.BODY_MAX_WIDTH, "the body is %d px, the aside outside the cap" % body.size.x)
		close_game(main))
