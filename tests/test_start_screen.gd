extends "res://tests/lib/test_case.gd"
## The start screen in the real main scene (backlog 063). main.start_screen is the StartScreen component
## (is_open, overlay, seed_edit, new_game_button, motion_toggle); main.board_shown() says whether the board is visible.
## Game.engine is shared by every UI test, so "no game started" is checked as "opening main didn't touch the engine".

const SETTINGS_PATH := "user://test_start_screen_settings.cfg"


## The first Button under root whose text starts with prefix, or null.
func button_starting(root: Node, prefix: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func menu_button(main: Node, prefix: String) -> Button:
	for b in main.menu_buttons():
		if b.text.begins_with(prefix):
			return b
	return null


func focus_owner(main: Node) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## Opens main and presses the start screen's New game with seed_text in the seed field.
func open_and_start(seed_text: String) -> Node:
	var main := open_main()
	main.start_screen.seed_edit.text = seed_text
	main.start_screen.new_game_button.pressed.emit()
	return main


## Runs body with the Settings autoload saving to a temp file, then puts the player's settings back.
func with_temp_settings(body: Callable) -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var original: SettingsStore = Settings.store
	Settings.store = SettingsStore.new(SETTINGS_PATH)
	body.call()
	Settings.store = original
	Settings.changed.emit()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


# --- AC1: the screen on launch ---

func test_launch_shows_the_start_screen_and_starts_no_game() -> void:
	var e := Game.engine
	var changes := [0]
	var count := func(): changes[0] += 1
	e.changed.connect(count)
	var turn := e.turn
	var log_size := e.log_lines.size()
	var main := open_main()
	e.changed.disconnect(count)
	check(main.start_screen.is_open(), "start screen open")
	check(not main.board_shown(), "board hidden")
	eq(changes[0], 0, "no game started (engine changed signals)")
	eq(e.turn, turn, "turn untouched")
	eq(e.log_lines.size(), log_size, "nothing logged")
	eq(main.views.size(), 0, "no card views")
	close_main(main)


func test_start_screen_has_title_new_game_seed_field_and_motion_toggle() -> void:
	var main := open_main()
	var screen: Object = main.start_screen
	var titles: Array = screen.overlay.find_children("*", "Label", true, false).filter(
		func(l): return l.text == ProjectSettings.get_setting("application/config/name"))
	eq(titles.size(), 1, "one title label with the game's name")
	eq(screen.new_game_button.text, "New game", "New game button")
	check(screen.overlay.is_ancestor_of(screen.new_game_button), "New game is on the screen")
	eq(screen.seed_edit.text, "", "seed field starts empty (random)")
	check(screen.overlay.is_ancestor_of(screen.seed_edit), "seed field is on the screen")
	check(screen.motion_toggle.text.begins_with("Reduce motion"), "Reduce motion toggle")
	check(screen.overlay.is_ancestor_of(screen.motion_toggle), "toggle is on the screen")
	close_main(main)


# --- AC2: New game ---

func test_new_game_with_seed_42_starts_that_seed() -> void:
	var main := open_and_start("42")
	eq(Game.engine.seed_value, 42, "seed")
	eq(Game.engine.turn, 1, "turn 1")
	check(not main.start_screen.is_open(), "start screen hidden")
	check(main.board_shown(), "board shown")
	eq(main.hand_view_count(), Game.engine.zone("hand").size(), "hand views dealt")
	close_main(main)


func test_new_game_with_an_empty_or_bad_seed_uses_a_random_seed() -> void:
	for text in ["", "abc", "4.5"]:
		var e := Game.engine
		var starts := [0]
		var count := func(): starts[0] += 1
		e.changed.connect(count)
		var main := open_and_start(text)
		e.changed.disconnect(count)
		check(starts[0] > 0, "'%s': a game started" % text)
		eq(e.turn, 1, "'%s': turn 1" % text)
		check(e.seed_value >= 1 and e.seed_value <= 999999, "'%s': random seed %d" % [text, e.seed_value])
		check(not main.start_screen.is_open(), "'%s': start screen hidden" % text)
		close_main(main)


# --- AC3: one Reduce motion setting ---

func test_start_screen_and_menu_toggles_share_the_setting() -> void:
	with_temp_settings(func():
		var main := open_main()
		var screen_toggle: Button = main.start_screen.motion_toggle
		Settings.set_reduce_motion(true)
		check(screen_toggle.button_pressed, "start screen toggle on")
		eq(screen_toggle.text, "Reduce motion: on", "start screen toggle text")
		check(menu_button(main, "Reduce motion").button_pressed, "menu toggle on")
		screen_toggle.button_pressed = false  # the player turns it off on the start screen
		eq(Settings.reduce_motion, false, "setting off")
		eq(menu_button(main, "Reduce motion").text, "Reduce motion: off", "menu toggle follows")
		var saved := SettingsStore.new(SETTINGS_PATH)
		saved.reduce_motion = true
		saved.load()
		eq(saved.reduce_motion, false, "saved off")
		close_main(main))


# --- AC4: the menu's New game and Restart; game-over replay ---

func test_menu_new_game_returns_to_the_start_screen() -> void:
	var main := open_and_start("5")
	press_key(main, KEY_ESCAPE)  # nothing focused: opens the menu
	menu_button(main, "New game").pressed.emit()
	check(main.start_screen.is_open(), "start screen open")
	check(not main.board_shown(), "board hidden")
	eq(main.views.size(), 0, "the old game's views are gone")
	check(not main.menu_buttons()[0].is_visible_in_tree(), "menu closed")
	main.start_screen.seed_edit.text = "6"
	main.start_screen.new_game_button.pressed.emit()
	eq(Game.engine.seed_value, 6, "the next game starts from the screen")
	eq(main.hand_view_count(), Game.engine.zone("hand").size(), "only the new hand is dealt")
	close_main(main)


func test_menu_restart_replays_the_seed_without_the_start_screen() -> void:
	var main := open_and_start("5")
	Game.engine.end_turn()
	press_key(main, KEY_ESCAPE)
	menu_button(main, "Restart").pressed.emit()
	eq(Game.engine.seed_value, 5, "same seed")
	eq(Game.engine.turn, 1, "a fresh game")
	check(not main.start_screen.is_open(), "start screen stays hidden")
	check(main.board_shown(), "board shown")
	close_main(main)


func test_game_over_replay_starts_straight_away() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	check(Game.engine.is_over, "game over")
	button_starting(main, "Replay").pressed.emit()
	eq(Game.engine.seed_value, 1, "same seed")
	eq(Game.engine.turn, 1, "a fresh game")
	check(not main.start_screen.is_open(), "start screen stays hidden")
	close_main(main)


# --- AC5: keyboard ---

func test_new_game_has_the_focus_and_enter_starts() -> void:
	var main := open_main()
	eq(focus_owner(main), main.start_screen.new_game_button, "New game focused")
	var e := Game.engine
	var starts := [0]
	var count := func(): starts[0] += 1
	e.changed.connect(count)
	press_key(main, KEY_ENTER)
	e.changed.disconnect(count)
	check(starts[0] > 0, "Enter started a game")
	check(not main.start_screen.is_open(), "start screen hidden")
	close_main(main)


func test_tab_reaches_the_seed_field_and_the_toggle() -> void:
	var main := open_main()
	var seen := []
	for i in 4:
		press_key(main, KEY_TAB)
		seen.append(focus_owner(main))
	check(seen.has(main.start_screen.seed_edit), "Tab reaches the seed field")
	check(seen.has(main.start_screen.motion_toggle), "Tab reaches the toggle")
	check(seen.all(func(c): return c != null and main.start_screen.overlay.is_ancestor_of(c)), "focus stays on the screen")
	close_main(main)


# --- Backlog 064: choosing a civilization on the start screen ---
# start_screen.civilization_ids() lists the civilization cards shown, start_screen.selected is the chosen id, and
# start_screen.select(id) is what clicking a card does.

func civ_now() -> Array[String]:
	return card_ids(Game.engine.zone("civilization"))


func test_start_screen_shows_the_listed_civilizations() -> void:
	var main := open_main()
	var civs: Array[String] = Game.engine.civilizations()
	check(civs.size() >= 3, "real data lists civilizations")
	eq(main.start_screen.civilization_ids(), civs, "cards shown, in config order")
	close_main(main)


func test_the_saved_civilization_is_preselected() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[1]
		var main := open_main()
		eq(main.start_screen.selected, civs[1], "saved choice selected")
		close_main(main)
		Settings.store.civilization = "not_a_civilization"
		main = open_main()
		eq(main.start_screen.selected, civs[0], "unknown saved choice: the first")
		close_main(main))


func test_selecting_a_civilization_saves_it_and_new_game_uses_it() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_main()
		main.start_screen.select(civs[2])
		eq(main.start_screen.selected, civs[2], "selected")
		eq(Settings.store.civilization, civs[2], "remembered")
		main.start_screen.new_game_button.pressed.emit()
		eq(civ_now(), [civs[2]] as Array[String], "the game is played as it")
		close_main(main))


func test_restart_keeps_the_civilization() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_main()
		main.start_screen.select(civs[1])
		main.start_screen.new_game_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		menu_button(main, "Restart").pressed.emit()
		eq(civ_now(), [civs[1]] as Array[String], "same civilization after Restart")
		close_main(main))


func test_menu_and_game_over_name_the_civilization() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	var civ_name: String = Game.engine.zone("civilization").cards[0].def.name
	check(main.game_over_text().contains(civ_name), "game over names %s in '%s'" % [civ_name, main.game_over_text()])
	main.start_game(1)
	press_key(main, KEY_ESCAPE)
	var names := main.find_children("*", "Label", true, false).filter(
		func(l): return l.is_visible_in_tree() and l.text.contains(civ_name))
	check(not names.is_empty(), "the open menu names %s" % civ_name)
	close_main(main)
