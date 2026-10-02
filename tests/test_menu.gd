extends "res://tests/lib/test_case.gd"
## The in-game menu in the real main scene (backlog 067). Test hooks: main.menu_buttons() and
## main.game_over_buttons() list the overlays' buttons in order; main.quit_hook is called instead of quitting.


## Opens main with seed 1 and quit_hook swapped for a counter, so Exit doesn't end the test run.
func open_main_counting_quits(quits: Array) -> Node:
	var main := open_main()
	main.start_game(1)
	main.quit_hook = func(): quits[0] += 1
	return main


func button_texts(buttons: Array) -> Array[String]:
	var texts: Array[String] = []
	for b in buttons:
		texts.append(b.text)
	return texts


# --- AC1: Exit is the last menu button ---

func test_menu_ends_with_an_exit_button() -> void:
	var main := open_main_counting_quits([0])
	var texts := button_texts(main.menu_buttons())
	eq(texts.back() if not texts.is_empty() else "", "Exit", "last menu button in %s" % [texts])
	check(texts.size() >= 2 and texts[-2].begins_with("Close"), "Close comes just before Exit in %s" % [texts])
	close_main(main)


# --- AC2: pressing Exit quits once ---

func test_pressing_exit_calls_the_quit_hook_once() -> void:
	var quits := [0]
	var main := open_main_counting_quits(quits)
	var exit: Button = main.menu_buttons().back()
	exit.pressed.emit()
	eq(quits[0], 1, "quit hook calls")
	close_main(main)


# --- AC3: keyboard ---

func test_tab_from_close_reaches_exit_then_wraps_to_restart() -> void:
	var main := open_main_counting_quits([0])
	press_key(main, KEY_ESCAPE)  # nothing focused: opens the menu
	var buttons: Array = main.menu_buttons()
	var close: Button = buttons[-2]
	close.grab_focus()
	press_key(main, KEY_TAB)
	var owner := main.get_viewport().gui_get_focus_owner()
	eq(owner.get("text") if owner != null else null, "Exit", "focus after Tab from Close")
	press_key(main, KEY_TAB)
	owner = main.get_viewport().gui_get_focus_owner()
	eq(owner.get("text") if owner != null else null, "Restart", "Tab from Exit wraps to Restart (206: no seed field)")
	close_main(main)


func test_enter_on_exit_calls_the_quit_hook() -> void:
	var quits := [0]
	var main := open_main_counting_quits(quits)
	press_key(main, KEY_ESCAPE)
	var exit: Button = main.menu_buttons().back()
	exit.grab_focus()
	press_key(main, KEY_ENTER)
	eq(quits[0], 1, "quit hook calls")
	close_main(main)


# --- AC4: game over has no Exit ---

func test_game_over_overlay_has_no_exit_button() -> void:
	var main := open_main_counting_quits([0])
	var texts := button_texts(main.game_over_buttons())
	check(not texts.is_empty(), "game-over buttons found")
	check(not texts.has("Exit"), "no Exit in %s" % [texts])
	close_main(main)
