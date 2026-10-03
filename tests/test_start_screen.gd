extends "res://tests/lib/test_case.gd"
## The title, new game and settings screens in the real main scene (backlog 063, 064, 099).
## main.start_screen is the title screen (is_open, overlay, new_game_button, settings_button, exit_button);
## main.new_game_screen picks the civilization and seed (is_open, overlay, seed_edit, start_button, back_button,
## selected, select, civilization_ids, civilization_row, detail_pane, detail_title, detail_text; 212);
## main.settings_modal (206: a Modal over the title screen, replacing the settings screen) holds Reduce motion (is_open,
## motion_toggle, close_button;
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


## Which of the three are open, as "title", "new game", "settings" (the Settings modal, over the title screen) in order.
func open_screens(main: Node) -> Array[String]:
	var out: Array[String] = []
	if main.start_screen.is_open():
		out.append("title")
	if main.new_game_screen.is_open():
		out.append("new game")
	if main.settings_modal.is_open():
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
		func(l): return l.text.replace("\n", " ") == ProjectSettings.get_setting("application/config/name"))  # on two lines (213)
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
	eq(screen.back_button.text, "◂ Main menu", "the header's tab back (104, 118, 241)")
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


# --- 212: a list of civilizations and the selected one's detail ---

## The visible text of the new game screen's detail pane, without markup.
func detail_text(main: Node) -> String:
	return main.new_game_screen.detail_text()


func test_the_list_has_a_row_per_civilization_and_the_preselected_one_pressed() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[1]
		var main := open_new_game_screen()
		var screen: Object = main.new_game_screen
		eq(screen.civilization_ids(), civs, "one row per civilization, in config order")
		for i in civs.size():
			var row: Button = screen.civilization_row(civs[i])
			check(row != null and row.is_visible_in_tree(), "a row for %s" % civs[i])
			if row == null:
				continue
			eq(row.text, Game.engine.card_db[civs[i]].name, "%s: its name" % civs[i])
			check(row.toggle_mode, "%s: a list row (toggle)" % civs[i])
			eq(row.button_pressed, i == 1, "%s: pressed only when selected" % civs[i])
			check(row.find_child("Edge", true, false) == null, "%s: no type band (217: the index tab marks the selection)" % civs[i])
		eq(focus_owner(main), screen.civilization_row(civs[1]), "the preselected row has the focus")
		close_main(main))


func test_the_detail_pane_shows_the_selected_civilizations_story_rules_and_home() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		var main := open_new_game_screen()
		main.new_game_screen.select(civs[2])
		var def: CardDef = Game.engine.card_db[civs[2]]
		var details := Game.engine.def_details(civs[2])
		eq(main.new_game_screen.detail_title(), def.name, "its name as the pane's title")
		var text := detail_text(main)
		check(def.flavor != "" and text.contains(def.flavor), "its flavor: %s" % text)
		check(text.contains(details.quote.text) and text.contains(details.quote.by), "its quote, attributed: %s" % text)
		for line in details.rules:
			check(text.contains(line), "its rule '%s': %s" % [line, text])
		if def.home != "":
			var home: CardDef = Game.engine.card_db[def.home]
			check(text.contains(home.name), "its home territory: %s" % text)
			for k in home.keywords:
				check(text.contains(k.capitalize()), "its home's keyword %s: %s" % [k.capitalize(), text])
		close_main(main))


func test_a_click_or_the_arrows_select_without_opening_details() -> void:
	with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[0]
		var main := open_new_game_screen()
		var screen: Object = main.new_game_screen
		(screen.civilization_row(civs[3]) as Button).pressed.emit()
		eq(screen.selected, civs[3], "a click selects")
		eq(screen.detail_title(), Game.engine.card_db[civs[3]].name, "the pane follows")
		eq(main.details.shown(), {}, "no details modal")
		check((screen.civilization_row(civs[3]) as Button).button_pressed, "its row pressed")
		check(not (screen.civilization_row(civs[0]) as Button).button_pressed, "the old row released")
		(screen.civilization_row(civs[3]) as Button).grab_focus()
		press_key(main, KEY_DOWN)
		eq(focus_owner(main), screen.civilization_row(civs[4]), "Down moves to the next row")
		eq(screen.selected, civs[4], "and selects it")
		press_key(main, KEY_UP)
		eq(screen.selected, civs[3], "Up selects the one above")
		eq(Settings.store.civilization, civs[3], "the choice is remembered")
		close_main(main))


func test_the_seed_field_and_start_sit_at_the_foot_of_the_pane() -> void:
	var main := open_new_game_screen()
	await wait_frames()
	var screen: Object = main.new_game_screen
	var pane: Control = screen.detail_pane
	check(pane.is_ancestor_of(screen.seed_edit) and pane.is_ancestor_of(screen.start_button), "in the detail pane")
	var list_rect: Rect2 = (screen.civilization_row(Game.engine.civilizations()[0]) as Control).get_global_rect()
	check(screen.start_button.get_global_rect().position.x > list_rect.end.x, "right of the list")
	check(screen.start_button.get_global_rect().position.y >= screen.detail_body.get_global_rect().end.y - 1.0, "under the text")
	close_main(main)


# --- 217: a sheet that holds still, and the selectable list ---

## Opens the new game screen and waits out its transition, so rects are final.
func open_settled_new_game_screen() -> Node:
	var main := open_new_game_screen()
	await wait_screen_transition()
	await wait_frames()
	return main


## The new game screen's IndexTab-showing rows, by civilization id.
func rows_with_a_tab(screen: Object) -> Array[String]:
	var out: Array[String] = []
	for id in screen.civilization_ids():
		var tab := (screen.civilization_row(id) as Node).find_child("IndexTab", true, false) as Control
		if tab != null and tab.is_visible_in_tree():
			out.append(id)
	return out


func test_the_sheet_keeps_its_size_and_place_whichever_civilization_is_selected() -> void:
	await with_temp_settings(func():
		var main: Node = await open_settled_new_game_screen()
		var screen: Object = main.new_game_screen
		var panel := (screen.overlay as Node).get_meta("panel") as Control
		var rects := {}
		for id in screen.civilization_ids():
			screen.select(id)
			await wait_frames()
			rects[panel.get_global_rect()] = true
			var body: RichTextLabel = screen.detail_body
			check(body.get_content_height() <= body.size.y + 0.5, "%s: its detail fits (%s in %s)" % [id, body.get_content_height(), body.size.y])
		eq(rects.size(), 1, "one panel rect for every civilization: %s" % [rects.keys()])
		close_main(main))


func test_start_sits_under_a_footer_rule_and_stays_put() -> void:
	await with_temp_settings(func():
		var main: Node = await open_settled_new_game_screen()
		var screen: Object = main.new_game_screen
		var pane: Control = screen.detail_pane
		var rule := pane.find_child("FooterRule", true, false) as Control
		check(rule != null and rule.is_visible_in_tree(), "a footer rule in the pane")
		if rule != null:
			eq(rule.get_global_rect().size.y, 1.0, "a 1 px hairline")
			eq(rule.get_global_rect().size.x, pane.get_global_rect().size.x, "across the pane")
			check(rule.get_global_rect().end.y <= (screen.seed_edit as Control).get_global_rect().position.y, "above the seed field")
			check(rule.get_global_rect().position.y >= (screen.detail_body as Control).get_global_rect().end.y, "below the text")
		var places := {}
		for id in screen.civilization_ids():
			screen.select(id)
			await wait_frames()
			places[(screen.start_button as Control).get_global_rect().position] = true
		eq(places.size(), 1, "Start in one place for every civilization: %s" % [places.keys()])
		close_main(main))


func test_the_civilizations_are_a_select_list_with_one_index_tab() -> void:
	await with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[0]
		var main: Node = await open_settled_new_game_screen()
		var screen: Object = main.new_game_screen
		var list: Object = screen.civilization_list
		var script := (list as Node).get_script() as Script
		eq(script.resource_path if script != null else "", "res://ui/select_list.gd", "the list is a SelectList")
		for id in civs:
			check((screen.civilization_row(id) as Button).theme_type_variation in [&"ListRow", &"ListRowQuiet"],
				"%s: a ListRow" % id)
		eq(rows_with_a_tab(screen), [civs[0]] as Array[String], "the preselected row carries the tab")
		(screen.civilization_row(civs[3]) as Button).pressed.emit()
		await wait_frames()
		eq(rows_with_a_tab(screen), [civs[3]] as Array[String], "a click moves the tab")
		(screen.civilization_row(civs[3]) as Button).grab_focus()
		press_key(main, KEY_DOWN)
		await wait_frames()
		eq(screen.selected, civs[4], "Down selects the next")
		eq(rows_with_a_tab(screen), [civs[4]] as Array[String], "the arrows move the tab")
		close_main(main))


func test_moving_the_focus_off_the_selected_row_keeps_the_selection() -> void:
	await with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[0]
		var main: Node = await open_settled_new_game_screen()
		var screen: Object = main.new_game_screen
		eq(focus_owner(main), screen.civilization_row(civs[0]), "the selected row has the focus")
		press_key(main, KEY_TAB)
		await wait_frames()
		eq(focus_owner(main), screen.civilization_row(civs[1]), "Tab moves the focus to the next row")
		eq(screen.selected, civs[0], "the selection stays")
		check((screen.civilization_row(civs[0]) as Button).button_pressed, "the selected row stays pressed")
		check(not (screen.civilization_row(civs[1]) as Button).button_pressed, "the focused row is not pressed")
		eq(rows_with_a_tab(screen), [civs[0]] as Array[String], "the tab stays on the selected row")
		close_main(main))


func test_with_no_civilizations_the_pane_says_so_and_start_still_works() -> void:
	var real := Game.engine
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 5}), resources(), cards, "test", errors, warnings)
	Game.engine = GameEngine.new(cards, config)
	var main := open_new_game_screen()
	var screen: Object = main.new_game_screen
	eq(screen.civilization_ids(), [] as Array[String], "no rows")
	var list: Control = screen.get("civilization_list")  # read by name: the test must put the real engine back
	check(list != null and not list.is_visible_in_tree(), "the list hidden")
	var text: String = detail_text(main) if screen.has_method("detail_text") else ""
	check(text.contains("offers no civilizations"), "the pane says so: %s" % text)
	eq(screen.selected, "", "nothing selected")
	screen.start_button.pressed.emit()
	eq(Game.engine.turn, 1, "Start still starts")
	close_main(main)
	Game.engine = real


func test_the_new_game_screen_opens_no_details_modal() -> void:
	var main := open_new_game_screen()
	for id in Game.engine.civilizations():
		(main.new_game_screen.civilization_row(id) as Button).pressed.emit()
	eq(main.details.shown(), {}, "no details opened from the list")
	check(main.new_game_screen.overlay.find_children("*", "CardView", true, false).is_empty(), "no civilization cards")
	close_main(main)


# --- AC4: Settings, and Back ---

func test_settings_opens_the_settings_modal_with_the_motion_toggle() -> void:
	var main := open_main()
	var changes := engine_changes(func(): main.start_screen.settings_button.pressed.emit())
	var modal: Object = main.settings_modal
	eq(open_screens(main), ["title", "settings"] as Array[String], "the Settings modal over the title screen (206)")
	eq(changes, 0, "no game started")
	var toggle_row: Node = modal.motion_toggle.get_parent()
	check(toggle_row.get_children().any(func(c): return c is Label and c.text == "Reduce motion"),
		"Reduce motion: a labelled key (182)")
	check(modal.is_ancestor_of(modal.motion_toggle), "the key on the modal")
	eq(modal.close_button.text, "Close (Esc)", "its Close")
	close_main(main)


func test_the_settings_modals_toggle_is_the_setting() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_screen.settings_button.pressed.emit()
		var toggle: Button = main.settings_modal.motion_toggle
		Settings.set_reduce_motion(true)
		check(toggle.button_pressed, "the key follows the setting on")
		await wait_frames()
		eq(shown_state(toggle), "ON", "its state (182; beside it since 219)")
		toggle.button_pressed = false  # the player turns it off
		eq(Settings.reduce_motion, false, "setting off")
		await wait_frames()
		eq(shown_state(toggle), "OFF", "its state follows")
		var saved := SettingsStore.new(Settings.store.path)  # the temp file with_temp_settings saves to
		saved.reduce_motion = true
		saved.load()
		eq(saved.reduce_motion, false, "saved off")
		close_main(main))


func test_back_returns_to_the_title_screen_from_both() -> void:
	var main := open_main()
	var changes := engine_changes(func():
		main.start_screen.new_game_button.pressed.emit()
		main.new_game_screen.back_button.pressed.emit()
		eq(open_screens(main), ["title"] as Array[String], "Back from new game: the title screen")
		main.start_screen.settings_button.pressed.emit()
		main.settings_modal.close_button.pressed.emit()
		eq(open_screens(main), ["title"] as Array[String], "Close on Settings: the title screen"))
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
	eq(focus_owner(main), main.new_game_screen.civilization_row(main.new_game_screen.selected), "new game: the selected row focused (212)")
	main.new_game_screen.back_button.pressed.emit()
	eq(focus_owner(main), main.start_screen.new_game_button, "back on the title: New game focused")
	main.start_screen.settings_button.pressed.emit()
	eq(focus_owner(main), main.settings_modal.motion_toggle, "settings: its first key focused (206)")
	close_main(main)


func test_enter_presses_the_focused_button() -> void:
	var main := open_main()
	var changes := engine_changes(func(): press_key(main, KEY_ENTER))
	eq(changes, 0, "Enter on New game starts no game")
	eq(open_screens(main), ["new game"] as Array[String], "Enter on New game: the new game screen")
	main.new_game_screen.start_button.grab_focus()  # the selected row has the focus first (212)
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
	var stops: int = ng.civilization_ids().size() + 3  # the rows, the seed field, Start and Back (212)
	var seen := focus_after(main, KEY_TAB, stops * 2)
	check(seen.has(ng.seed_edit), "Tab reaches the seed field")
	check(seen.has(ng.back_button), "Tab reaches Back")
	for id in ng.civilization_ids():
		check(seen.has(ng.civilization_row(id)), "Tab reaches the %s row" % id)
	check(seen.all(func(c): return c != null and ng.overlay.is_ancestor_of(c)), "focus stays on the new game screen")
	eq(seen.count(ng.start_button), 2, "Tab wraps back to Start")
	ng.back_button.pressed.emit()
	title.settings_button.pressed.emit()
	var st: Object = main.settings_modal
	seen = focus_after(main, KEY_TAB, 7)  # three keys, three sliders and Close (206)
	check(seen.has(st.motion_toggle), "Tab wraps back to the toggle")
	check(seen.all(func(c): return c != null and st.is_ancestor_of(c)), "focus stays on the Settings modal")
	close_main(main)


func test_esc_goes_back_from_the_new_game_and_settings_screens() -> void:
	var main := open_main()
	var changes := engine_changes(func():
		main.start_screen.new_game_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		eq(open_screens(main), ["title"] as Array[String], "Esc on new game: the title screen")
		main.start_screen.settings_button.pressed.emit()
		press_key(main, KEY_ESCAPE)
		eq(open_screens(main), ["title"] as Array[String], "Esc on Settings: the title screen alone"))
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


func test_the_new_game_screen_opens_with_no_ring_until_a_key() -> void:
	await with_temp_settings(func():
		var civs: Array[String] = Game.engine.civilizations()
		Settings.store.civilization = civs[0]
		var main: Node = await open_settled_new_game_screen()
		var screen: Object = main.new_game_screen
		var row: Button = screen.civilization_row(civs[0])
		eq(focus_owner(main), row, "the selected row has the focus")
		check(row.get_theme_stylebox("focus") is StyleBoxEmpty, "and draws no ring")
		press_key(main, KEY_DOWN)
		await wait_frames()
		var next: Button = screen.civilization_row(civs[1])
		eq(focus_owner(main), next, "Down focuses the next row")
		var ring := next.get_theme_stylebox("focus") as StyleBoxFlat
		check(ring != null and ring.border_color == Palette.FOCUS, "which draws the ring")
		close_main(main))
