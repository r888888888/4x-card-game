extends "res://tests/lib/test_case.gd"
## Sheet, screen and notice sounds (189) in the real main.tscn, its sound clock frozen: ModalStack lays a sheet down
## and lifts it off (a stacked one quieter, one lift for close_all), Navigator runs a screen in and back, Toasts rings a
## notice's bell (hints are silent), a modal opened with a notice gives the bell the lead, and a sheet or screen the
## player opened or closed is their input.


func tokens(main: Node, from := 0) -> Array:
	return main.sfx.played().slice(from).map(func(r): return r.token)


func records(main: Node, token: StringName, from := 0) -> Array:
	return main.sfx.played().slice(from).filter(func(r): return r.token == token)


## Main with seed 1 started and its sound clock at 0.
func open_game() -> Node:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.sfx.set_clock(0.0)
	return main


func first_card_id() -> String:
	return Game.engine.zone("hand").cards[0].def.id


# --- AC1: modals ---

func test_a_modal_lays_a_sheet_down_and_a_stacked_one_is_quieter() -> void:
	var main: Node = await open_game()
	main.details.open_def(first_card_id())
	main.tech_tree.open()
	var opens := records(main, Sfx.SHEET_OPEN)
	eq(opens.map(func(r): return r.db), [0.0, -1.0], "the first sheet, then one stacked on it 1 dB quieter")
	close_main(main)


func test_closing_the_top_modal_lifts_its_sheet_once() -> void:
	var main: Node = await open_game()
	main.details.open_def(first_card_id())
	main.tech_tree.open()
	var before: int = main.sfx.played().size()
	main.modals.close(main.modals.top())
	eq(tokens(main, before), [Sfx.SHEET_CLOSE], "one lift")
	close_main(main)


func test_close_all_lifts_once_however_many_are_open() -> void:
	var main: Node = await open_game()
	main.details.open_def(first_card_id())
	main.tech_tree.open()
	main.identity_modal.open()
	eq(main.modals.depth(), 3, "three open")
	var before: int = main.sfx.played().size()
	main.modals.close_all()
	eq(tokens(main, before), [Sfx.SHEET_CLOSE], "one lift for all three")
	before = main.sfx.played().size()
	main.modals.close_all()
	eq(tokens(main, before), [], "nothing open: nothing to lift")
	close_main(main)


# --- AC2: screens ---

func test_a_screen_runs_in_and_back_and_the_root_and_clear_are_silent() -> void:
	var main := open_main()
	await wait_frames()
	main.sfx.set_clock(0.0)
	eq(tokens(main), [], "the title screen (set_root) is silent")
	main.start_screen.new_game_button.pressed.emit()  # Settings is a modal since 206: New game is the screen
	eq(tokens(main), [Sfx.NAV_FORWARD], "New game runs in")
	main.nav.back()
	eq(tokens(main), [Sfx.NAV_FORWARD, Sfx.NAV_BACK], "Back runs it out")
	main.nav.back()
	eq(tokens(main).size(), 2, "back at the root: nothing")
	main.start_game(1)
	await wait_frames()
	eq(tokens(main).filter(func(t): return t == Sfx.NAV_FORWARD or t == Sfx.NAV_BACK).size(), 2, "clearing the screens is silent")
	close_main(main)


# --- AC3: notices ---

func test_each_notice_rings_once_400_ms_apart_and_hints_are_silent() -> void:
	var main: Node = await open_game()
	var before: int = main.sfx.played().size()
	for message in ["One.", "Two.", "Three.", "Four."]:
		main.toasts.notice(message)
	var bells := records(main, Sfx.NOTIFICATION_INFO, before)
	eq(bells.size(), 4, "four bells, the one whose toast was pushed out too")
	eq(bells.map(func(r): return snappedf(r.at, 0.001)), [0.0, 0.4, 0.8, 1.2], "each 0.4 s after the one before")
	before = main.sfx.played().size()
	main.toasts.hint("Choose a territory.")
	eq(tokens(main, before), [], "a hint is silent")
	close_main(main)


# --- AC4: the bell leads ---

func test_a_modal_opened_with_a_notice_is_3_db_quieter() -> void:
	var main: Node = await open_game()
	main.toasts.notice("A new event.")
	main.details.open_def(first_card_id())
	eq(records(main, Sfx.SHEET_OPEN).map(func(r): return r.db), [-3.0], "the sheet under the bell")
	main.modals.close_all()
	await wait_frames()
	main.details.open_def(first_card_id())
	eq(records(main, Sfx.SHEET_OPEN).map(func(r): return r.db), [-3.0, 0.0], "a later frame: its own level")
	close_main(main)


# --- AC5: the player's input; Reduce motion ---

func test_a_sheet_the_player_opens_or_closes_is_their_input() -> void:
	var main: Node = await open_game()
	main.tech_tree.open()
	eq(records(main, Sfx.SHEET_OPEN).map(func(r): return r.input), [false], "opened by the game: a system sound")
	main.modals.close_all()
	await wait_frames()
	press_key(main, KEY_T)
	await wait_frames()
	check(main.modals.top() == main.tech_tree, "T opens the tree")
	eq(records(main, Sfx.SHEET_OPEN).map(func(r): return r.input), [false, true], "opened by T: the player's")
	press_key(main, KEY_ESCAPE)
	await wait_frames()
	var closes := records(main, Sfx.SHEET_CLOSE)
	eq(closes.map(func(r): return r.input).slice(-1), [true], "closed by Esc: the player's")
	close_main(main)


func test_a_screen_the_player_opens_is_their_input() -> void:
	var main := open_main()
	await wait_frames()
	main.sfx.set_clock(0.0)
	var new_game: Button = main.start_screen.new_game_button  # a screen (Settings is a modal since 206)
	new_game.grab_focus()
	press_key(main, KEY_ENTER)
	await wait_frames()
	eq(records(main, Sfx.NAV_FORWARD).map(func(r): return r.input), [true], "Enter on New game")
	close_main(main)


func test_with_reduce_motion_sheets_and_screens_sound_at_the_change() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		await wait_frames()
		main.sfx.set_clock(0.0)
		main.start_screen.new_game_button.pressed.emit()  # a screen (Settings is a modal since 206)
		main.nav.back()
		main.start_game(1)
		await wait_frames()
		main.sfx.set_clock(10.0)
		main.details.open_def(first_card_id())
		main.modals.close_all()
		var ats: Array = main.sfx.played().filter(func(r): return [Sfx.NAV_FORWARD, Sfx.NAV_BACK, Sfx.SHEET_OPEN, Sfx.SHEET_CLOSE].has(r.token)) \
			.map(func(r): return [r.token, r.at])
		eq(ats, [[Sfx.NAV_FORWARD, 0.0], [Sfx.NAV_BACK, 0.0], [Sfx.SHEET_OPEN, 10.0], [Sfx.SHEET_CLOSE, 10.0]], "at the change")
		close_main(main))
