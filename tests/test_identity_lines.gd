extends "res://tests/lib/test_case.gd"
## The civilization and government as side-panel lines (backlog 088), in the real main scene on the real data
## (the default civilization and Chiefdom at the start). Hooks: main.identity_lines() is [{text, tooltip}] for the
## visible lines, top to bottom; main.identity_buttons() are the same lines as buttons, to press.


## The real card id of the civilization or government in play, or "".
func id_in(zone_name: String) -> String:
	var z := Game.engine.zone(zone_name)
	return z.cards[0].def.id if not z.is_empty() else ""


func tooltip_of(card_id: String) -> String:
	return Game.engine.card_db[card_id].rules_tooltip(Game.engine.card_db)


# --- AC1: rows gone ---

func test_no_civilization_or_government_rows_in_the_play_area() -> void:
	var main := open_main()
	main.start_game(1)
	for h in main.section_headings():
		check(not h.text in ["Civilization", "Government"], "no %s heading" % h.text)
	check(not main.views.has(Game.engine.civilization()), "no view for the civilization")
	check(not main.views.has(Game.engine.government()), "no view for the government")
	close_main(main)


# --- AC2, AC3: lines and tooltips ---

func test_side_panel_shows_civilization_then_government() -> void:
	var main := open_main()
	main.start_game(1)
	var lines: Array = main.identity_lines()
	var civ_name: String = Game.engine.card_db[id_in("civilization")].name
	eq(lines.map(func(l): return l.text), ["Civilization: " + civ_name, "Government: Chiefdom"], "lines")
	if lines.size() == 2:
		eq(lines[0].tooltip, tooltip_of(id_in("civilization")), "civilization tooltip is its rules_tooltip")
		eq(lines[1].tooltip, "No bonus.", "Chiefdom has no rules text")
	close_main(main)


func test_identity_lines_sit_above_the_knowledge_button() -> void:
	var main := open_main()
	main.start_game(1)
	var buttons: Array = main.identity_buttons()
	var knowledge: Button = null
	for b in UIKit.buttons_in(main):
		if b.text.begins_with("Knowledge"):
			knowledge = b
	check(knowledge != null and buttons.size() == 2, "Knowledge button and 2 lines found")
	if knowledge != null and buttons.size() == 2:
		check(buttons[0].get_parent() == knowledge.get_parent(), "the lines are in the side panel with Knowledge")
		check(buttons[0].get_index() < buttons[1].get_index() and buttons[1].get_index() < knowledge.get_index(),
			"civilization, government, then Knowledge")
	close_main(main)


# --- AC4: details ---

func test_pressing_a_line_opens_its_details() -> void:
	var main := open_main()
	main.start_game(1)
	var buttons: Array = main.identity_buttons()
	check(buttons.size() == 2, "2 lines")
	if buttons.size() == 2:
		buttons[0].pressed.emit()
		eq(main.details.shown().get("name", ""), Game.engine.card_db[id_in("civilization")].name, "civilization details")
		main.details.close()
		buttons[1].pressed.emit()
		eq(main.details.shown().get("name", ""), "Chiefdom", "government details")
	close_main(main)


# --- AC5: government changes ---

func test_playing_a_government_updates_its_line() -> void:
	var main := open_main()
	main.start_game(1)
	var kingship := put_in_hand(Game.engine, "kingship")
	check(Game.engine.play_card(kingship), "play Kingship: %s" % Game.engine.play_error(kingship))
	var lines: Array = main.identity_lines()
	check(lines.size() == 2, "2 lines")
	if lines.size() == 2:
		eq(lines[1].text, "Government: Kingship", "government line")
		eq(lines[1].tooltip, tooltip_of("kingship"), "Kingship's rules")
	check(not main.views.has(kingship), "no view left for Kingship")
	close_main(main)


# --- AC6: none ---

func test_no_lines_without_a_civilization_or_government() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 5}), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	var main := open_main()
	main.start_game(1)
	# Guarded so the real engine is restored even before the hook exists (red phase).
	var lines: Array = main.identity_lines() if main.has_method("identity_lines") else ["no identity_lines hook"]
	close_main(main)
	Game.engine = real
	eq(lines, [], "no lines")


# --- AC7: fits the screen ---

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


## Backlog 107 (AC7): the civilization's details show its flavor and quote, attributed.
func test_civilization_details_show_its_flavor_and_quote() -> void:
	var main := open_main()
	main.start_game(1)
	var buttons: Array = main.identity_buttons()
	check(buttons.size() == 2, "2 lines")
	if buttons.size() == 2:
		buttons[0].pressed.emit()
		var d: Dictionary = main.details.shown()
		var body: String = main.details.body_text()
		check(d.get("flavor", "") != "" and d.flavor in body, "the body shows the flavor: %s" % body)
		var quote: Dictionary = d.get("quote", {})
		check(not quote.is_empty() and quote.text in body and quote.by in body,
			"the body shows the quote and who said it: %s" % body)
	close_main(main)
