extends "res://tests/lib/test_case.gd"
## The title, new game and settings screens in the real main scene (backlog 063, 064, 099).
## main.start_screen is the title screen (is_open, overlay, new_game_button, settings_button, exit_button);
## main.new_game_screen picks the civilization and seed (is_open, overlay, seed_edit, start_button, back_button,
## selected, select, civilization_ids); main.settings_screen holds Reduce motion (is_open, overlay, motion_toggle,
## back_button). main.board_shown() says whether the board is visible.
## Game.engine is shared by every UI test, so "no game started" is checked as "no engine changed signal".

const SETTINGS_PATH := "user://test_start_screen_settings.cfg"


func menu_button(main: Node, prefix: String) -> Button:
	for b in main.menu_buttons():
		if b.text.begins_with(prefix):
			return b
	return null


## The first Button under root whose text starts with prefix, or null.
func button_starting(root: Node, prefix: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func focus_owner(main: Node) -> Control:
	return main.get_viewport().gui_get_focus_owner()


## How many times the engine's changed signal fired while body ran (0: no game started).
func engine_changes(body: Callable) -> int:
	var e := Game.engine
	var changes := [0]
	var count := func(): changes[0] += 1
	e.changed.connect(count)
	body.call()
	e.changed.disconnect(count)
	return changes[0]


## Opens main and goes from the title screen to the new game screen.
func open_new_game_screen() -> Node:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	return main


## Opens main, goes to the new game screen and presses Start with seed_text in the seed field.
func open_and_start(seed_text: String) -> Node:
	var main := open_new_game_screen()
	main.new_game_screen.seed_edit.text = seed_text
	main.new_game_screen.start_button.pressed.emit()
	return main


func button_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	for b in UIKit.buttons_in(root):
		texts.append(b.text)
	return texts


## Which of the three screens are open, as "title", "new game", "settings" in that order.
func open_screens(main: Node) -> Array[String]:
	var out: Array[String] = []
	if main.start_screen.is_open():
		out.append("title")
	if main.new_game_screen.is_open():
		out.append("new game")
	if main.settings_screen.is_open():
		out.append("settings")
	return out


# --- AC1: the title screen on launch ---

func test_launch_shows_the_title_screen_and_starts_no_game() -> void:
	var e := Game.engine
	var turn := e.turn
	var log_size := e.log_lines.size()
	var holder := []
	var changes := engine_changes(func(): holder.append(open_main()))
	var main: Node = holder[0]
	eq(open_screens(main), ["title"] as Array[String], "only the title screen open")
	check(not main.board_shown(), "board hidden")
	eq(changes, 0, "no game started (engine changed signals)")
	eq(e.turn, turn, "turn untouched")
	eq(e.log_lines.size(), log_size, "nothing logged")
	eq(main.views.size(), 0, "no card views")
	close_main(main)


func test_title_screen_has_the_title_and_three_buttons() -> void:
	var main := open_main()
	var overlay: Control = main.start_screen.overlay
	var titles: Array = overlay.find_children("*", "Label", true, false).filter(
		func(l): return l.text == ProjectSettings.get_setting("application/config/name"))
	eq(titles.size(), 1, "one title label with the game's name")
	eq(button_texts(overlay), ["New game", "Settings", "Exit"] as Array[String], "exactly three buttons, in order")
	eq(overlay.find_children("*", "LineEdit", true, false).size(), 0, "no seed field")
	eq(overlay.find_children("*", "CardView", true, false).size(), 0, "no civilization cards")
	close_main(main)


# --- AC2: New game opens the new game screen ---

func test_new_game_opens_the_new_game_screen_without_starting() -> void:
	var holder := []
	var changes := engine_changes(func(): holder.append(open_new_game_screen()))
	var main: Node = holder[0]
	var screen: Object = main.new_game_screen
	eq(open_screens(main), ["new game"] as Array[String], "title hidden, new game screen open")
	check(not main.board_shown(), "board hidden")
	eq(changes, 0, "no game started")
	eq(screen.civilization_ids(), Game.engine.civilizations(), "civilization cards, in config order")
	check(screen.overlay.is_ancestor_of(screen.seed_edit), "seed field on the screen")
	eq(screen.seed_edit.text, "", "seed field starts empty (random)")
	eq(screen.start_button.text, "Start", "Start button")
	check(screen.overlay.is_ancestor_of(screen.start_button), "Start on the screen")
	eq(screen.back_button.text, "Main menu", "the header's link back (104, 118)")
	check(screen.overlay.is_ancestor_of(screen.back_button), "Back on the screen")
	close_main(main)


func test_the_saved_civilization_is_preselected() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		check(civs.size() >= 3, "real data lists civilizations")
		Settings.store.civilization = civs[1]
		var main := open_new_game_screen()
		eq(main.new_game_screen.selected, civs[1], "saved choice selected")
		close_main(main)
		Settings.store.civilization = "not_a_civilization"
		main = open_new_game_screen()
		eq(main.new_game_screen.selected, civs[0], "unknown saved choice: the first")
		close_main(main))


# --- AC3: Start ---

func test_start_with_seed_42_starts_that_seed() -> void:
	var main := open_and_start("42")
	eq(Game.engine.seed_value, 42, "seed")
	eq(Game.engine.turn, 1, "turn 1")
	eq(open_screens(main), [] as Array[String], "no screen open")
	check(main.board_shown(), "board shown")
	eq(main.hand_view_count(), Game.engine.zone("hand").size(), "hand views dealt")
	close_main(main)


func test_start_with_an_empty_or_bad_seed_uses_a_random_seed() -> void:
	for text in ["", "abc", "4.5"]:
		var e := Game.engine
		var holder := []
		var changes := engine_changes(func(): holder.append(open_and_start(text)))
		var main: Node = holder[0]
		check(changes > 0, "'%s': a game started" % text)
		eq(e.turn, 1, "'%s': turn 1" % text)
		check(e.seed_value >= 1 and e.seed_value <= 999999, "'%s': random seed %d" % [text, e.seed_value])
		check(not main.new_game_screen.is_open(), "'%s': new game screen hidden" % text)
		close_main(main)


func test_enter_in_the_seed_field_starts() -> void:
	var main := open_new_game_screen()
	var screen: Object = main.new_game_screen
	screen.seed_edit.grab_focus()
	screen.seed_edit.text = "7"
	press_key(main, KEY_ENTER)
	eq(Game.engine.seed_value, 7, "seed from the field")
	eq(Game.engine.turn, 1, "turn 1")
	check(not screen.is_open(), "new game screen hidden")
	check(main.board_shown(), "board shown")
	close_main(main)


func test_selecting_a_civilization_saves_it_and_start_uses_it() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_new_game_screen()
		main.new_game_screen.select(civs[2])
		eq(main.new_game_screen.selected, civs[2], "selected")
		eq(Settings.store.civilization, civs[2], "remembered")
		main.new_game_screen.start_button.pressed.emit()
		eq(civ_now(), [civs[2]] as Array[String], "the game is played as it")
		close_main(main))


## Backlog 107 (AC9): a click on a civilization card selects it and opens its details: flavor first, then every bonus.
func test_clicking_a_civilization_selects_it_and_shows_its_flavor_and_bonuses() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_new_game_screen()
		var view: CardView = main.new_game_screen.civilization_view(civs[1])
		check(view != null, "a card for %s" % civs[1])
		if view != null:
			view.picked.emit(view)
			eq(main.new_game_screen.selected, civs[1], "selected")
			var def: CardDef = Game.engine.card_db[civs[1]]
			eq(main.details.shown().get("name", ""), def.name, "its details are open")
			var body: String = main.details.body_text()
			check(body.begins_with(def.flavor), "the details start with the flavor: %s" % body)
			for line in def.rules_tooltip(Game.engine.card_db).split("\n"):
				check(line in body, "the details show the bonus '%s': %s" % [line, body])
		close_main(main))


## A real left click (press and release) at the centre of c, in viewport coordinates.
func mouse_click(main: Node, c: Control) -> void:
	var at: Vector2 = c.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event, true)


## The details modal's Close button, or null.
func details_close_button(main: Node) -> Button:
	for b in UIKit.buttons_in(main.details):
		if b.text.begins_with("Close"):
			return b
	return null


## Backlog 107 (AC11, bug): the details open over the new game screen, and a real click on Close closes them (the
## screen, later in the tree, took the click).
func test_a_click_on_close_closes_the_details_over_the_new_game_screen() -> void:
	var original: SettingsStore = Settings.store
	Settings.store = SettingsStore.new(SETTINGS_PATH)  # the click saves the choice (with_temp_settings can't await)
	var main := open_new_game_screen()
	var civs: Array[String] = Game.engine.civilizations()
	var view: CardView = main.new_game_screen.civilization_view(civs[0])
	view.picked.emit(view)
	await wait_frames()
	check(not main.details.shown().is_empty(), "the details are open")
	var close := details_close_button(main)
	check(close != null, "a Close button")
	if close != null:
		mouse_click(main, close)
		await wait_frames()
		eq(main.details.shown(), {}, "a click on Close closes the details")
	close_main(main)
	Settings.store = original
	Settings.changed.emit()
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


## Backlog 107 (AC12): the details of a civilization on the new game screen offer "Play as <name>", which selects it
## and starts a game as it with the seed in the field.
func test_play_as_in_the_details_starts_a_game_as_that_civilization() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_new_game_screen()
		main.new_game_screen.seed_edit.text = "42"
		var view: CardView = main.new_game_screen.civilization_view(civs[2])
		view.picked.emit(view)
		var play: Button = main.details.action_button()
		var civ_name: String = Game.engine.card_db[civs[2]].name
		check(play.visible and civ_name in play.text, "a visible Play as %s button (got '%s')" % [civ_name, play.text])
		play.pressed.emit()
		eq(civ_now(), [civs[2]] as Array[String], "the game is played as it")
		eq(Game.engine.seed_value, 42, "with the seed in the field")
		eq(Settings.store.civilization, civs[2], "the choice is remembered")
		eq(main.details.shown(), {}, "the details closed")
		check(not main.new_game_screen.is_open(), "the new game screen closed")
		close_main(main))


## Backlog 107 (AC12): details opened anywhere else have no Play as button.
func test_details_in_play_have_no_play_as_button() -> void:
	var main := open_main()
	main.start_game(1)
	main.details.open(main.views[first_in_hand(Game.engine)])  # a hand card's details (the identity has its own modal, 119)
	check(not main.details.action_button().visible, "no action button in play")
	close_main(main)


# --- AC4: Settings, and Back ---

func test_settings_opens_the_settings_screen_with_the_motion_toggle() -> void:
	var main := open_main()
	var changes := engine_changes(func(): main.start_screen.settings_button.pressed.emit())
	var screen: Object = main.settings_screen
	eq(open_screens(main), ["settings"] as Array[String], "title hidden, settings screen open")
	eq(changes, 0, "no game started")
	var toggle_row: Node = screen.motion_toggle.get_parent()
	check(toggle_row.get_children().any(func(c): return c is Label and c.text == "Reduce motion"),
		"Reduce motion: a labelled key (182)")
	check(screen.overlay.is_ancestor_of(screen.motion_toggle), "toggle on the screen")
	eq(screen.back_button.text, "Main menu", "the header's link back (104, 118)")
	check(screen.overlay.is_ancestor_of(screen.back_button), "Back on the screen")
	close_main(main)


func test_settings_and_menu_toggles_share_the_setting() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		var screen_toggle: Button = main.settings_screen.motion_toggle
		Settings.set_reduce_motion(true)
		check(screen_toggle.button_pressed, "settings screen toggle on")
		await wait_frames()
		eq(screen_toggle.text, "ON", "settings screen key's legend (182)")
		check(main.menu_motion_toggle().button_pressed, "menu toggle on")
		screen_toggle.button_pressed = false  # the player turns it off on the settings screen
		eq(Settings.reduce_motion, false, "setting off")
		await wait_frames()
		eq(main.menu_motion_toggle().text, "OFF", "menu toggle follows")
		var saved := SettingsStore.new(Settings.store.path)  # the temp file with_temp_settings saves to
		saved.reduce_motion = true
		saved.load()
		eq(saved.reduce_motion, false, "saved off")
		close_main(main))


func test_back_returns_to_the_title_screen_from_both_screens() -> void:
	var main := open_main()
	var changes := engine_changes(func():
		main.start_screen.new_game_button.pressed.emit()
		main.new_game_screen.back_button.pressed.emit()
		eq(open_screens(main), ["title"] as Array[String], "Back from new game: the title screen")
		main.start_screen.settings_button.pressed.emit()
		main.settings_screen.back_button.pressed.emit()
		eq(open_screens(main), ["title"] as Array[String], "Back from settings: the title screen"))
	eq(changes, 0, "no game started")
	check(not main.board_shown(), "board hidden")
	close_main(main)


# --- AC5: Exit ---

func test_exit_on_the_title_screen_calls_the_quit_hook_once() -> void:
	var main := open_main()
	var quits := [0]
	main.quit_hook = func(): quits[0] += 1
	main.start_screen.exit_button.pressed.emit()
	eq(quits[0], 1, "quit hook calls")
	close_main(main)


# --- AC6: the menu's New game and Restart; game-over replay ---

func test_menu_new_game_opens_the_new_game_screen() -> void:
	var main := open_and_start("5")
	press_key(main, KEY_ESCAPE)  # nothing focused: opens the menu
	menu_button(main, "New game").pressed.emit()
	eq(open_screens(main), ["new game"] as Array[String], "the new game screen, not the title screen")
	check(not main.board_shown(), "board hidden")
	eq(main.views.size(), 0, "the old game's views are gone")
	check(not main.modals.is_open(), "menu closed")  # 207: a sheet on the stack, still lifting off
	main.new_game_screen.seed_edit.text = "6"
	main.new_game_screen.start_button.pressed.emit()
	eq(Game.engine.seed_value, 6, "the next game starts from the screen")
	eq(main.hand_view_count(), Game.engine.zone("hand").size(), "only the new hand is dealt")
	close_main(main)


func test_back_after_the_menu_new_game_goes_to_the_title_screen() -> void:
	var main := open_and_start("5")
	press_key(main, KEY_ESCAPE)
	menu_button(main, "New game").pressed.emit()
	main.new_game_screen.back_button.pressed.emit()
	eq(open_screens(main), ["title"] as Array[String], "the title screen")
	check(not main.board_shown(), "board hidden")
	close_main(main)


func test_menu_restart_replays_the_seed_without_a_screen() -> void:
	var main := open_and_start("5")
	Game.engine.end_turn()
	press_key(main, KEY_ESCAPE)
	menu_button(main, "Restart").pressed.emit()
	eq(Game.engine.seed_value, 5, "same seed")
	eq(Game.engine.turn, 1, "a fresh game")
	eq(open_screens(main), [] as Array[String], "no screen open")
	check(main.board_shown(), "board shown")
	close_main(main)


func test_game_over_replay_starts_straight_away() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	check(Game.engine.is_over, "game over")
	button_starting(main, "Replay").pressed.emit()
	eq(Game.engine.seed_value, 1, "same seed")
	eq(Game.engine.turn, 1, "a fresh game")
	eq(open_screens(main), [] as Array[String], "no screen open")
	close_main(main)


func test_restart_keeps_the_civilization() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_new_game_screen()
		main.new_game_screen.select(civs[1])
		main.new_game_screen.start_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		menu_button(main, "Restart").pressed.emit()
		eq(civ_now(), [civs[1]] as Array[String], "same civilization after Restart")
		close_main(main))


func civ_now() -> Array[String]:
	return card_ids(Game.engine.zone("civilization"))


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


# --- AC7: keyboard ---

func test_each_screen_focuses_its_first_button() -> void:
	var main := open_main()
	eq(focus_owner(main), main.start_screen.new_game_button, "title: New game focused")
	main.start_screen.new_game_button.pressed.emit()
	eq(focus_owner(main), main.new_game_screen.start_button, "new game: Start focused")
	main.new_game_screen.back_button.pressed.emit()
	eq(focus_owner(main), main.start_screen.new_game_button, "back on the title: New game focused")
	main.start_screen.settings_button.pressed.emit()
	eq(focus_owner(main), main.settings_screen.back_button, "settings: Back focused")
	close_main(main)


func test_enter_presses_the_focused_button() -> void:
	var main := open_main()
	var changes := engine_changes(func(): press_key(main, KEY_ENTER))
	eq(changes, 0, "Enter on New game starts no game")
	eq(open_screens(main), ["new game"] as Array[String], "Enter on New game: the new game screen")
	changes = engine_changes(func(): press_key(main, KEY_ENTER))
	check(changes > 0, "Enter on Start started a game")
	eq(open_screens(main), [] as Array[String], "no screen open")
	close_main(main)


## Presses key presses times on main, returning the focus owner after each press.
func focus_after(main: Node, key: Key, presses: int) -> Array:
	var seen := []
	for i in presses:
		press_key(main, key)
		seen.append(focus_owner(main))
	return seen


func test_tab_and_arrows_stay_on_the_open_screen_and_wrap() -> void:
	var main := open_main()
	var title: Object = main.start_screen
	for key in [KEY_TAB, KEY_DOWN]:
		var seen := focus_after(main, key, 3)
		eq(seen, [title.settings_button, title.exit_button, title.new_game_button], "title: %s wraps" % OS.get_keycode_string(key))
	title.new_game_button.pressed.emit()
	var ng: Object = main.new_game_screen
	var seen := focus_after(main, KEY_TAB, 6)
	check(seen.has(ng.seed_edit), "Tab reaches the seed field")
	check(seen.has(ng.back_button), "Tab reaches Back")
	check(seen.all(func(c): return c != null and ng.overlay.is_ancestor_of(c)), "focus stays on the new game screen")
	eq(seen.count(ng.start_button), 2, "Tab wraps back to Start")
	ng.back_button.pressed.emit()
	title.settings_button.pressed.emit()
	var st: Object = main.settings_screen
	seen = focus_after(main, KEY_TAB, 4)
	check(seen.has(st.motion_toggle), "Tab reaches the toggle")
	check(seen.all(func(c): return c != null and st.overlay.is_ancestor_of(c)), "focus stays on the settings screen")
	close_main(main)


func test_esc_goes_back_from_the_new_game_and_settings_screens() -> void:
	var main := open_main()
	var changes := engine_changes(func():
		main.start_screen.new_game_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		eq(open_screens(main), ["title"] as Array[String], "Esc on new game: the title screen")
		main.start_screen.settings_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		eq(open_screens(main), ["title"] as Array[String], "Esc on settings: the title screen"))
	eq(changes, 0, "no game started")
	close_main(main)


func test_esc_on_the_title_screen_does_nothing() -> void:
	var main := open_main()
	var quits := [0]
	main.quit_hook = func(): quits[0] += 1
	var changes := engine_changes(func(): press_key(main, KEY_ESCAPE))
	eq(open_screens(main), ["title"] as Array[String], "the title screen stays open alone")
	check(not main.board_shown(), "board hidden")
	check(not main.menu_buttons()[0].is_visible_in_tree(), "no menu")
	eq(changes, 0, "no game started")
	eq(quits[0], 0, "no quit")
	close_main(main)
