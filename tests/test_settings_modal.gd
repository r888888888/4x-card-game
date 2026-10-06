extends "res://tests/lib/test_case.gd"
## The Settings modal (backlog 206) in the real main scene: the menu shrinks to Restart, New game, Settings (and Close,
## Exit in its footer); Settings opens a SettingsModal over it with the Reduce motion, Day mode and sound rows and a
## Game section (the seed field and Restart with seed); the title screen's Settings opens the same modal without the
## Game section, and the settings screen is gone. Hooks: main.settings_modal (motion_toggle, day_toggle, sound_toggle,
## sliders, figures, seed_edit, restart_button, game_section), main.menu_buttons().

const Looks := preload("res://tests/lib/surface_looks.gd")
const SETTINGS_SCREEN_PATH := "res://ui/settings_screen.gd"


func button_named(buttons: Array, text: String) -> Button:
	for b in buttons:
		if b.text == text:
			return b
	return null


## Main on a seed-5 game with the menu open.
func open_menu_on(seed_value: int) -> Node:
	var main := open_main()
	main.start_game(seed_value)
	await wait_frames()
	main.open_menu()
	await wait_frames()
	return main


# --- AC1: the menu ---

func test_the_menu_holds_only_game_actions() -> void:
	await with_temp_settings(func():
		var main: Node = await open_menu_on(5)
		var texts: Array = main.menu_buttons().map(func(b): return b.text)
		eq(texts, ["Restart", "New game", "Settings", "Close", "Exit Game"], "the menu's buttons, in order")
		var menu: Control = main.modals.top()
		eq(menu.find_children("*", "LineEdit", true, false).size(), 0, "no seed field")
		eq(menu.find_children("*", "LegendKey", true, false).size(), 0, "no Reduce motion, Day mode or sound keys")
		eq(menu.find_children("*", "HSlider", true, false).size(), 0, "no volume sliders")
		close_main(main))


# --- AC2: Settings over the menu ---

func test_settings_in_the_menu_opens_the_settings_modal_over_it() -> void:
	await with_temp_settings(func():
		var main: Node = await open_menu_on(5)
		var menu: Object = main.modals.top()
		button_named(main.menu_buttons(), "Settings").pressed.emit()
		await wait_frames()
		var modal: Object = main.settings_modal
		check(modal is Modal, "a Modal")
		eq(main.modals.depth(), 2, "stacked on the menu")
		eq(main.modals.top(), modal, "on top")
		check(menu.is_open(), "the menu stays open under it")
		for key in [modal.motion_toggle, modal.day_toggle, modal.sound_toggle]:
			check((key as Control).is_visible_in_tree(), "%s shown" % key.name)
		eq(sorted(modal.sliders.keys()), sorted([Settings.MASTER, Settings.GAME, Settings.INTERFACE]), "a slider per bus")
		check((modal.game_section as Control).is_visible_in_tree(), "the Game section")
		eq(modal.seed_edit.text, "5", "the seed field holds this game's seed")
		eq(modal.restart_button.text, "Restart with seed", "its Restart")
		close_main(main))


# --- AC3: Restart with seed ---

func test_restart_with_seed_starts_that_seed_as_the_same_civilization() -> void:
	await with_temp_settings(func():
		var main := open_main()
		main.start_game(5, "sumer")
		await wait_frames()
		main.open_menu()
		button_named(main.menu_buttons(), "Settings").pressed.emit()
		var modal: Object = main.settings_modal
		modal.seed_edit.text = "42"
		modal.seed_edit.text_changed.emit("42")
		check(not modal.restart_button.disabled, "enabled for a whole number")
		modal.restart_button.pressed.emit()
		eq(Game.engine.seed_value, 42, "seed 42")
		eq(Game.engine.turn, 1, "a new game")
		eq(card_ids(Game.engine.zone("civilization")), ["sumer"] as Array[String], "the same civilization")
		eq(main.modals.depth(), 0, "every modal closed")
		close_main(main))


func test_enter_in_the_seed_field_restarts_and_a_bad_seed_cannot() -> void:
	await with_temp_settings(func():
		var main: Node = await open_menu_on(5)
		button_named(main.menu_buttons(), "Settings").pressed.emit()
		var modal: Object = main.settings_modal
		for bad in ["abc", ""]:
			modal.seed_edit.text = bad
			modal.seed_edit.text_changed.emit(bad)
			check(modal.restart_button.disabled, "'%s': Restart with seed disabled" % bad)
			modal.seed_edit.text_submitted.emit(bad)
			eq(Game.engine.seed_value, 5, "'%s': Enter does nothing" % bad)
			eq(main.modals.depth(), 2, "'%s': still open" % bad)
		modal.seed_edit.text = "7"
		modal.seed_edit.text_changed.emit("7")
		modal.seed_edit.text_submitted.emit("7")
		eq(Game.engine.seed_value, 7, "Enter on 7 restarts on seed 7")
		eq(main.modals.depth(), 0, "and closes the modals")
		close_main(main))


# --- AC4: the menu's Restart ---

func test_the_menus_restart_replays_this_games_seed() -> void:
	await with_temp_settings(func():
		var main: Node = await open_menu_on(5)
		Game.engine.end_turn()
		button_named(main.menu_buttons(), "Restart").pressed.emit()
		eq(Game.engine.seed_value, 5, "the current seed")
		eq(Game.engine.turn, 1, "from the start")
		eq(main.modals.depth(), 0, "the menu closed")
		close_main(main))


# --- AC5: from the title screen ---

func test_the_title_screens_settings_opens_the_modal_without_the_game_section() -> void:
	await with_temp_settings(func():
		var main := open_main()
		await wait_frames()
		main.start_screen.settings_button.pressed.emit()
		await wait_frames()
		check(main.start_screen.is_open(), "the title screen stays")
		eq(main.modals.top(), main.settings_modal, "the Settings modal over it")
		check(not (main.settings_modal.game_section as Control).is_visible_in_tree(), "no Game section")
		check((main.settings_modal.day_toggle as Control).is_visible_in_tree(), "its settings")
		eq(main.nav.depth(), 1, "no screen pushed")
		check(main.get("settings_screen") == null, "no settings screen on main")
		check(not FileAccess.file_exists(SETTINGS_SCREEN_PATH), "ui/settings_screen.gd is gone")
		press_key(main, KEY_ESCAPE)
		eq(main.modals.depth(), 0, "Esc closes it")
		check(main.start_screen.is_open(), "back on the title screen")
		close_main(main))


# --- AC6: settings apply at once; it closes alone ---

func test_a_setting_applies_at_once_and_esc_closes_only_the_settings_modal() -> void:
	await with_temp_settings(func():
		var main: Node = await open_menu_on(5)
		button_named(main.menu_buttons(), "Settings").pressed.emit()
		var modal: Object = main.settings_modal
		modal.day_toggle.button_pressed = true
		await wait_frames()
		check(Palette.day, "Day mode on at once")
		check(Settings.store.day_mode, "and saved")
		eq(main.modals.depth(), 2, "the menu and the modal stay open")
		var paper := Looks.mismatch(modal.panel.get_theme_stylebox("panel"), Looks.paper())
		check(paper == "", "the modal on Day paper: %s" % paper)
		modal.day_toggle.button_pressed = false
		await wait_frames()
		check(not Palette.day, "and off again")
		press_key(main, KEY_ESCAPE)
		eq(main.modals.depth(), 1, "Esc closes only the Settings modal")
		check(main.modals.top() != modal, "the menu is on top")
		close_main(main))
