extends "res://tests/lib/test_case.gd"
## The civilization and government (backlog 088; in the top bar since 115; one button and modal since 119), in the
## real main scene on the real data (the default civilization and Chiefdom at the start) or on TEST_CIVS / TEST_GOVS.
## Hooks: main.sidebar's name_button and government_button (202; the top-bar button until then) open the modal;
## main.identity_modal shows both: shown() is the
## names shown, top to bottom ([] while closed), body_text() the modal's text without markup, close_button, close().
## In detail (from docs/testing.md, 331): The civilization and government in the real `main.tscn` (088, 115, 119): one
## top-bar button naming both, the modal showing the civilization then the government (rules, then flavor; the quote
## only in details since 231; "No bonus."), Esc / Close, above the log drawer, one or neither, a new government, no
## empty lines; End turn on screen at 1920×1080; uses `identity_button()` and `identity_modal` (`shown()`,
## `body_text()`, `close_button`)


## The real card id of the civilization or government in play, or "".
func id_in(zone_name: String) -> String:
	var z := Game.engine.zone(zone_name)
	return z.cards[0].def.id if not z.is_empty() else ""


func name_in(zone_name: String) -> String:
	var id := id_in(zone_name)
	return Game.engine.card_db[id].name if id != "" else ""


## Runs body(main) on the real main scene with Game.engine swapped for engine (seed 1 started).
func with_engine(engine: GameEngine, body: Callable) -> void:
	var real := Game.engine
	Game.engine = engine
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


# --- 088 AC1: no rows ---

func test_no_civilization_or_government_rows_in_the_play_area() -> void:
	var main := open_main()
	main.start_game(1)
	for h in MainProbe.section_headings(main):
		check(not h.text in ["Civilization", "Government"], "no %s heading" % h.text)
	check(not main.views.has(Game.engine.civilization()), "no view for the civilization")
	check(not main.views.has(Game.engine.government()), "no view for the government")
	close_main(main)


# --- 119 AC2: the modal ---

func test_pressing_it_opens_one_modal_with_the_civilization_then_the_government() -> void:
	var main := open_main()
	main.start_game(1)
	main.sidebar.government_button.pressed.emit()
	var modal: Object = main.identity_modal
	eq(modal.shown(), [name_in("civilization"), "Chiefdom"], "civilization, then government")
	var body: String = modal.body_text()
	var civ: Dictionary = Game.engine.def_details(id_in("civilization"))
	check(civ.flavor != "" and body.contains(civ.flavor), "the civilization's flavor: %s" % body)
	check(not body.contains(civ.quote.text), "its quote is in its details, not here (231): %s" % body)
	for line in civ.rules:
		check(body.contains(line), "its rules ('%s'): %s" % [line, body])
	check(body.find(civ.rules[-1]) < body.find(civ.flavor), "rules, then the flavor at the card's foot (231): %s" % body)
	var gov_at := body.find("Chiefdom")
	check(gov_at > body.find(civ.flavor), "the government after the civilization: %s" % body)
	for line in Game.engine.def_details(id_in("government")).rules:  # since 127, at least its actions
		check(body.find(line, gov_at) != -1, "the government's rules ('%s'): %s" % [line, body])
	close_main(main)


func test_esc_and_close_close_it_and_it_blocks_the_board_keys() -> void:
	var main := open_main()
	main.start_game(1)
	var modal: Object = main.identity_modal
	main.sidebar.government_button.pressed.emit()
	press_key(main, KEY_E)
	eq(Game.engine.turn, 1, "E doesn't end the turn while it is open")
	press_key(main, KEY_ESCAPE)
	eq(modal.shown(), [], "Esc closes it")
	check(not MainProbe.menu_buttons(main)[0].is_visible_in_tree(), "and doesn't open the menu")
	main.sidebar.government_button.pressed.emit()
	modal.close_button.pressed.emit()
	eq(modal.shown(), [], "Close closes it")
	close_main(main)


func test_it_opens_above_the_log_drawer() -> void:
	var main := open_main()
	main.start_game(1)
	main.log_drawer.open()
	main.sidebar.government_button.pressed.emit()
	var modal := main.identity_modal as Control
	check(modal.z_index > (main.log_drawer as Control).z_index, "drawn above the drawer: %d, %d" % [
		modal.z_index, (main.log_drawer as Control).z_index])
	check(modal.get_index() > (main.log_drawer as Control).get_index(), "and later in the tree, so it takes input first")
	close_main(main)


# --- 119 AC3: one or neither ---

func test_with_only_a_civilization_the_sidebar_and_modal_show_it_alone() -> void:
	await with_engine(civ_engine("tribe"), func(main: Node):
		eq(main.sidebar.name_button.text, "Tribe", "names the civilization alone")
		check(not main.sidebar.government_button.visible, "no government")
		main.sidebar.name_button.pressed.emit()
		eq(main.identity_modal.shown(), ["Tribe"], "one section"))


func test_with_only_a_government_the_sidebar_and_modal_show_it_alone() -> void:
	await with_engine(gov_engine("council"), func(main: Node):
		check(not main.sidebar.name_button.visible, "no civilization")
		eq(main.sidebar.government_button.text, "COUNCIL ›", "names the government alone, in capitals (221)")
		main.sidebar.government_button.pressed.emit()
		eq(main.identity_modal.shown(), ["Council"], "one section"))


func test_with_neither_the_sidebar_names_nothing() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 5}), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	await with_engine(GameEngine.new(cards, config), func(main: Node):
		check(not main.sidebar.name_button.visible and not main.sidebar.government_button.visible, "both hidden"))


# --- 119 AC4: a new government ---

## Plays engine from a revolution at unrest 0 to the government choice, answering the hand-limit discard, any explore
## and any event choice with their first options.
func to_government_choice(e: GameEngine) -> void:
	e.resources["unrest"] = 0
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	e.end_turn()
	for i in 30:
		var p := e.pending()
		var first: int = p.get("options", [-1])[0] if not p.get("options", []).is_empty() else -1
		match p.get("kind", ""):
			GameEngine.PENDING_GOVERNMENT:
				return
			GameEngine.PENDING_DISCARD:
				e.discard_card(first)
			GameEngine.PENDING_EXPLORE:
				e.choose(first)
			GameEngine.PENDING_EVENT_CHOICE:
				e.choose_option(first)
			_:
				e.end_turn()
	check(false, "the government choice never came: %s" % [e.pending()])


func test_choosing_a_government_updates_the_sidebar_and_an_open_modal() -> void:
	var main := open_main()
	main.start_game(1)
	var e := Game.engine
	e.create_card("kingship", "discard", null)  # into the government deck (154)
	to_government_choice(e)
	main.modals.close_all()  # the earlier turns' event (237: choosing draws the next one, which comes back on top)
	main.sidebar.government_button.pressed.emit()
	var kingship := uid_of(e.zone("governments"), "kingship")
	check(e.choose_government(kingship), "choose Kingship: %s" % e.choose_government_error(kingship))
	eq(main.sidebar.government_button.text, "KINGSHIP ›", "the sidebar, in capitals (221)")
	eq(main.identity_modal.shown(), [name_in("civilization"), "Kingship"], "the open modal")
	var body: String = main.identity_modal.body_text()
	for line in e.def_details("kingship").rules:
		check(body.contains(line), "Kingship's rules ('%s'): %s" % [line, body])
	close_main(main)


# --- 119 AC5: no empty lines ---

func test_a_civilization_without_flavor_or_quote_shows_no_empty_lines() -> void:
	await with_engine(civ_engine("tribe"), func(main: Node):
		main.sidebar.government_button.pressed.emit()
		var body: String = main.identity_modal.body_text()
		check(not body.begins_with("\n") and not body.contains("\n\n\n"), "no empty flavor or quote lines: %s" % [body]))


# --- 088 AC7: fits the screen ---

func test_bug_088_end_turn_is_on_screen_at_1080() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var old_size := window.size
	window.size = Vector2i(1920, 1080)  # the base resolution; headless starts at another size
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var end_turn: Button = null
	for b in UIKit.buttons_in(main):
		if b.text.begins_with("End turn"):
			end_turn = b
	check(end_turn != null, "an End turn button")
	if end_turn != null:
		var viewport: Vector2 = main.get_viewport_rect().size
		eq(viewport, Vector2(1920, 1080), "the test viewport")
		var bottom: float = end_turn.get_global_rect().end.y
		check(bottom <= viewport.y, "End turn's bottom (%d) is on screen (%d)" % [bottom, viewport.y])
	close_main(main)
	window.size = old_size
