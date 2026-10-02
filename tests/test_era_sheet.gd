extends "res://tests/lib/test_case.gd"
## The era ceremony (backlog 211) in the real main scene on a TEST_CARDS + TEST_EVENTS game whose eras 2 and 3 unlock at 50
## wealth: setting wealth to 50 and ending the turn adds both at the next turn's start (and draws an event). Hooks:
## main.era_sheet (a Control over the window): is_open(), finished(), covered_rect(), kicker_text(), era_text() (the
## name as shown so far), name_label, turn_text(), rings() (the rings drawn so far).

const WIPE := 0.40
const LETTER := 0.06
const SLACK := 0.06
const BOTH_ERAS := {"era_unlocks": {"2": {"wealth": 50}, "3": {"wealth": 50}}}
const ERA_2 := {"era_unlocks": {"2": {"wealth": 50}}}


func wait_seconds(s: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(s).timeout


## Runs body(main, e) on the event game with overrides, Reduce motion calm or not; main open and started on seed 1.
func with_era_game(calm: bool, overrides: Dictionary, body: Callable) -> void:
	await with_reduce_motion(calm, func():
		var errors: Array[String] = []
		var warnings: Array[String] = []
		var cards := event_db(errors, warnings)
		var config := DataLoader.parse_config(raw_config({"farm": 5}, {"event_deck": {"windfall": 1, "trade_winds": 1,
			"omen": 1}}.merged(overrides, true)), resources(), cards, "test", errors, warnings)
		check(errors.is_empty(), "test data should load: %s" % [errors])
		var real := Game.engine
		Game.engine = GameEngine.new(cards, config)
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		while not main.event_modal().is_empty():
			main.event_modal_ok_button().pressed.emit()
		await body.call(main, Game.engine)
		close_main(main)
		Game.engine = real)


## Ends e's turn with 50 wealth, so the eras unlock at the next turn's start.
func reach_new_era(e: GameEngine) -> void:
	e.resources[GameEngine.WEALTH] = 50
	e.end_turn()


func click(main: Node, at := Vector2(20, 20)) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event, true)


# --- AC1: the sheet ---

func test_a_new_era_covers_the_window_with_its_name_and_the_turn() -> void:
	await with_era_game(true, ERA_2, func(main: Node, e: GameEngine):
		check(not main.era_sheet.is_open(), "no sheet before")
		reach_new_era(e)
		eq(e.era(), 2, "precondition: era 2")
		await wait_frames()
		check(main.era_sheet.is_open(), "the sheet shows")
		check((main.era_sheet as Control).get_global_rect().encloses(main.get_viewport_rect()), "over the whole window")
		eq(main.era_sheet.kicker_text(), "A NEW ERA", "the kicker")
		eq(main.era_sheet.era_text(), e.era_name(e.era()), "the era's name (Reduce motion: whole at once)")
		eq((main.era_sheet.name_label as Label).get_theme_font_size("font_size"), Tokens.TYPE_DISPLAY_XL, "at display XL")
		eq(main.era_sheet.turn_text(), "Turn %d" % e.turn, "the turn"))


# --- AC2: the motion ---

func test_the_sheet_wipes_in_then_rings_then_the_name_letter_by_letter() -> void:
	await with_era_game(false, ERA_2, func(main: Node, e: GameEngine):
		reach_new_era(e)
		await wait_frames()
		var width: float = main.get_viewport_rect().size.x
		var start: Rect2 = main.era_sheet.covered_rect()
		check(start.position.x <= 1.0 and start.size.x < width / 4, "wiping in from the left: %s" % start)
		eq(main.era_sheet.era_text(), "", "no name yet")
		await wait_seconds(WIPE + SLACK)
		check(main.era_sheet.covered_rect().size.x >= width - 1.0, "covered by 0.40 s")
		var name := e.era_name(e.era())
		await wait_seconds(LETTER * 2)
		var part: String = main.era_sheet.era_text()
		check(part.length() < name.length() and name.begins_with(part), "the name coming in: '%s' of '%s'" % [part, name])
		eq(main.era_sheet.rings().size(), 3, "three rings drawn out")
		await wait_seconds(LETTER * name.length() + SLACK)
		eq(main.era_sheet.era_text(), name, "the whole name")
		check(main.era_sheet.finished(), "finished"))


func test_with_reduce_motion_the_finished_sheet_fades_in() -> void:
	await with_era_game(true, ERA_2, func(main: Node, e: GameEngine):
		reach_new_era(e)
		await wait_frames()
		check(main.era_sheet.finished(), "finished at once")
		eq(main.era_sheet.rings().size(), 3, "its rings drawn")
		check((main.era_sheet as Control).modulate.a < 1.0, "fading in")
		await wait_seconds(0.12 + SLACK)
		eq((main.era_sheet as Control).modulate.a, 1.0, "in by 0.12 s"))


# --- AC3: skip, then close ---

func test_a_click_skips_to_the_end_and_a_second_closes_it() -> void:
	await with_era_game(false, ERA_2, func(main: Node, e: GameEngine):
		reach_new_era(e)
		await wait_frames()
		click(main)
		await wait_frames()
		check(main.era_sheet.finished(), "skipped to its end")
		eq(main.era_sheet.era_text(), e.era_name(e.era()), "the whole name")
		check(main.era_sheet.is_open(), "still open")
		click(main)
		await wait_frames()
		check(not main.era_sheet.is_open(), "closing")
		await wait_seconds(0.16 + SLACK)
		check(not (main.era_sheet as Control).is_visible_in_tree(), "faded out"))


func test_a_key_skips_and_closes_and_nothing_else_takes_keys() -> void:
	await with_era_game(false, ERA_2, func(main: Node, e: GameEngine):
		reach_new_era(e)
		await wait_frames()
		var turn := e.turn
		press_key(main, KEY_E)
		check(main.era_sheet.finished(), "a key skips to the end")
		eq(e.turn, turn, "and doesn't end the turn")
		press_key(main, KEY_T)
		check(main.knowledge.shown().is_empty(), "T opens nothing under it")
		check(not main.era_sheet.is_open(), "the second key closes it")
		await wait_seconds(0.16 + SLACK)
		while not main.event_modal().is_empty():  # the turn's event, which waited for the sheet (AC6)
			main.event_modal_ok_button().pressed.emit()
		press_key(main, KEY_E)
		eq(e.turn, turn + 1, "then E ends the turn again"))


# --- AC4: one sheet per turn ---

func test_two_eras_on_one_turn_show_one_sheet_naming_the_later() -> void:
	await with_era_game(true, BOTH_ERAS, func(main: Node, e: GameEngine):
		reach_new_era(e)
		eq(e.era(), 3, "precondition: eras 2 and 3 added")
		await wait_frames()
		eq(main.era_sheet.era_text(), e.era_name(3), "names era 3")
		press_key(main, KEY_ENTER)
		await wait_seconds(0.16 + SLACK)
		check(not main.era_sheet.is_open() and not (main.era_sheet as Control).is_visible_in_tree(), "no second sheet"))


# --- AC5: never at setup ---

func test_a_new_game_that_starts_in_a_later_era_shows_no_sheet() -> void:
	await with_era_game(true, {"era_unlocks": {"2": {"wealth": 1}},
		"starting": {"resources": {"food": 2, "wealth": 1}, "tableau": ["capital"], "territory": "homeland"}}, func(main: Node, e: GameEngine):
		eq(e.era(), 2, "precondition: the setup added era 2")
		check(not main.era_sheet.is_open(), "no sheet")
		main.start_game(2)
		await wait_frames()
		check(not main.era_sheet.is_open(), "none on a restart either"))


# --- AC6: the event waits ---

func test_an_event_drawn_the_same_turn_opens_after_the_sheet_closes() -> void:
	await with_era_game(true, ERA_2, func(main: Node, e: GameEngine):
		var drawn := []
		e.event_drawn.connect(func(o): drawn.append(o))
		reach_new_era(e)
		await wait_frames()
		check(not drawn.is_empty(), "precondition: an event drawn this turn")
		check(main.era_sheet.is_open(), "the sheet first")
		check(main.event_modal().is_empty(), "the event waits")
		press_key(main, KEY_ENTER)
		await wait_seconds(0.16 + SLACK)
		check(not main.event_modal().is_empty(), "then the event opens"))
