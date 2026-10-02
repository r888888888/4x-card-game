extends "res://tests/lib/tech_case.gd"
## The Knowledge screen in the real main scene (backlog 208; the tech tree modal of 059 and 140 before it): the
## Knowledge button and T push it on the play area's navigator with a header ("Realm › Knowledge") and one row of tech
## tiles per era, named from era_names; T, Esc or the header's link go back. An available tech's tile has a Learn
## button beside it (140). Hooks on main.knowledge: shown() (the era names, top to bottom; [] while closed), is_open(),
## open(), close(), header, context_text(), era_heading(i) (the i-th row's heading Label), slide_offset() (how far
## the screen sits right of its place) and realm_shift() (how far the screen below has moved left).


## Whether main has its Knowledge screen (checked, so a test without it fails instead of crashing and leaving a
## fixture engine in Game.engine for the tests after it).
func has_knowledge(main: Node) -> bool:
	var ok: bool = main.get("knowledge") != null
	check(ok, "main.knowledge exists")
	return ok


func knowledge_button(main: Node) -> Button:
	for b in main.find_children("*", "Button", true, false):
		if b.text.begins_with("Knowledge"):
			return b
	return null


func test_t_opens_knowledge_by_era_and_esc_closes_it() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	var names: Array[String] = []
	for era in Game.engine.tech_eras():
		names.append(Game.engine.era_name(era.era))
	check(names.size() >= 2, "the real tree has several eras: %s" % [names])
	eq(main.knowledge.shown(), names, "one row per era, by name")
	press_key(main, KEY_ESCAPE)
	eq(main.knowledge.shown(), [] as Array[String], "Esc closes")
	await wait_screen_transition()
	press_key(main, KEY_T)
	press_key(main, KEY_T)
	eq(main.knowledge.shown(), [] as Array[String], "T toggles it closed")
	close_main(main)


func test_the_knowledge_button_opens_the_screen() -> void:
	var main := open_main()
	main.start_game(1)
	var button := knowledge_button(main)
	check(button != null, "a Knowledge button")
	if button != null:
		button.pressed.emit()
		check(not main.knowledge.shown().is_empty(), "the screen is open")
	close_main(main)


# --- Backlog 092: the hint names the research card from the engine ---

const TREE_TOOLTIP := "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives.\nEra: Era 1."  # the fixture has no era names


## Opens main on a fixture game (TECHS in the research deck) with main deck deck, starts it, opens the tree and
## returns [Knowledge tooltip, tree header]. Puts the real engine back afterwards.
func hints_with_deck(deck: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config(deck, {"research_deck": {"pottery": 1, "writing": 1}}),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	var main := open_main()
	main.start_game(1)
	var out: Array[String] = ["", ""]
	if not has_knowledge(main):
		close_main(main)
		Game.engine = real
		return out
	var button := knowledge_button(main)
	if button != null:
		out[0] = button.tooltip_text
	press_key(main, KEY_T)
	for label in main.knowledge.find_children("*", "Label", true, false):
		if label.text.begins_with("Insight"):
			out[1] = label.text
	close_main(main)
	Game.engine = real
	return out


func test_hints_name_the_research_card() -> void:
	var hints := hints_with_deck({"farm": 5, "study": 1})
	eq(hints[0], TREE_TOOLTIP + "\nPlay a Research card for more insight.", "Knowledge tooltip")
	eq(hints[1], "Insight 0 · play a Research card for more", "tree header names Research")


func test_hints_leave_out_the_research_sentence_without_a_research_card() -> void:
	var hints := hints_with_deck({"farm": 5})
	eq(hints[0], TREE_TOOLTIP, "Knowledge tooltip")
	eq(hints[1], "Insight 0", "tree header without a research card")


# --- Backlog 140 AC6: learning from the tree ---

## Runs body(main) on the real main scene with Game.engine swapped for a fixture game: research deck Pottery (2),
## Writing (3), Bronze Working (5) and Iron Working (6, prereq Bronze), insight 5, a Research card in the deck;
## the tree is open. Puts the real engine back.
func with_tree(body: Callable) -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing", "bronze", "iron"], {"farm": 5, "study": 1},
		{"starting": {"resources": {"food": 2, "insight": 5}, "tableau": ["capital"], "territory": "homeland"}})
	var main := open_main()
	main.start_game(1)
	Game.engine.resources["insight"] = 5
	Game.engine.changed.emit()
	press_key(main, KEY_T)
	if has_knowledge(main):
		await body.call(main)
	close_main(main)
	Game.engine = real


## The tech tile (a Button) in the open tree whose text names tech_name, or null.
func tile(main: Node, tech_name: String) -> Button:
	for b in main.knowledge.find_children("*", "Button", true, false):
		var first: String = b.text.split("\n")[0]
		if b.is_visible_in_tree() and (first.ends_with(" " + tech_name) or first.contains(" %s ·" % tech_name)):
			return b
	return null


## The Learn button in the same row as tech_name's tile, or null.
func learn_button(main: Node, tech_name: String) -> Button:
	var t := tile(main, tech_name)
	if t == null:
		return null
	for b in t.get_parent().get_children():
		if b is Button and b != t and b.text == "Learn":
			return b
	return null


func test_an_available_tech_has_a_learn_button_that_learns_it() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		var button := learn_button(main, "Pottery")
		check(button != null, "Pottery has a Learn button")
		if button == null:
			return
		check(not button.disabled, "enabled: 5 insight is enough")
		button.pressed.emit()
		check(e.zone("researched").cards.any(func(c): return c.def.id == "pottery"), "Pottery learned")
		eq(e.resources.get("insight"), 3, "5 − 2")
		var t := tile(main, "Pottery")
		check(t != null and t.text.contains("✔") and t.text.contains("Researched"), "the tree shows Pottery researched: %s" % [
			t.text if t != null else "no tile"])
		check(learn_button(main, "Pottery") == null, "no Learn button once researched"))


func test_a_learn_button_you_cant_use_is_disabled_with_the_reason() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		e.resources["insight"] = 4
		e.changed.emit()
		main.knowledge.close()
		main.knowledge.open()  # reopen, so the screen reads 4 insight
		var button := learn_button(main, "Bronze Working")
		check(button != null, "Bronze Working has a Learn button")
		if button == null:
			return
		check(button.disabled, "disabled: 4 insight is too little")
		eq(button.tooltip_text, e.buy_tech_error(uid_of(e.zone("research_deck"), "bronze")), "the tooltip is buy_tech_error"))


func test_a_locked_tech_says_what_it_needs_and_has_no_learn_button() -> void:
	await with_tree(func(main: Node):
		var t := tile(main, "Iron Working")
		check(t != null, "an Iron Working tile")
		if t == null:
			return
		check(t.text.contains("🔒") and t.text.contains("Locked"), "locked: %s" % t.text)
		check(t.text.contains("needs Bronze Working"), "names its prereq: %s" % t.text)
		check(learn_button(main, "Iron Working") == null, "no Learn button"))


func test_the_tree_header_counts_insight_and_names_the_research_card() -> void:
	await with_tree(func(main: Node):
		var header := ""
		for label in main.knowledge.find_children("*", "Label", true, false):
			if label.text.begins_with("Insight"):
				header = label.text
		eq(header, "Insight 5 · play a Research card for more", "header"))


func test_the_board_has_no_research_choice() -> void:
	await with_tree(func(main: Node):
		check(not "research_row" in main.choices, "no research overlay")
		var declines := main.find_children("*", "Button", true, false).filter(func(b): return b.text == "Decline")
		eq(declines.size(), 0, "no Decline button"))



# --- 208: a navigated screen ---

func test_knowledge_is_a_screen_on_the_play_areas_navigator_with_a_header() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var screen: Control = main.knowledge
		check(main.knowledge.is_open(), "open")
		eq(main.modals.depth(), 0, "not a modal")
		check(not main.tableau.is_visible_in_tree(), "in place of the Realm")
		eq(screen.header.breadcrumb_text(), "Realm › Knowledge", "its breadcrumb")
		eq(main.knowledge.context_text(), "Turn 1 · %s" % Game.engine.era_name(Game.engine.era()), "its context")
		check(not FileAccess.file_exists("res://ui/tech_tree_modal.gd"), "the tech tree modal is gone")
		check(main.get("tech_tree") == null, "and main has no tech_tree"))


func test_each_era_is_a_row_headed_in_caps() -> void:
	await with_tree(func(main: Node):
		var eras: Array = Game.engine.tech_eras()
		eq(main.knowledge.shown(), eras.map(func(era): return era.name), "a row per era, top to bottom")
		for i in eras.size():
			var heading: Label = main.knowledge.era_heading(i)
			eq(heading.text, eras[i].name, "row %d's heading" % i)
			check(heading.uppercase, "in caps")
		check(tile(main, "Pottery") != null, "Pottery's tile")
		check(tile(main, "Pottery").text.contains("○") and tile(main, "Pottery").text.contains("Available"), "a mark and a word"))


func test_a_future_era_row_is_dimmed_and_shows_its_unlocks() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 5}, {"research_deck": {"pottery": 1, "writing": 1, "optics": 1},
		"era_unlocks": {"2": {"pop": 8}}}, [{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}])
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	await wait_screen_transition()
	if not has_knowledge(main):
		close_main(main)
		Game.engine = real
		return
	var eras: Array = Game.engine.tech_eras()
	var future := eras.find_custom(func(era): return not era.reached)
	check(future != -1, "precondition: an era not reached")
	if future != -1:
		var row: Control = main.knowledge.era_heading(future).get_parent()
		eq(row.modulate, Palette.FUTURE, "dimmed in FUTURE")
		var texts := row.find_children("*", "Label", true, false).map(func(l): return l.text)
		check(texts.any(func(t): return t.contains("8 pop")), "its unlock threshold: %s" % [texts])
	close_main(main)
	Game.engine = real


func test_a_click_on_a_tile_opens_its_details_over_the_screen() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		tile(main, "Writing").pressed.emit()
		eq(main.details.shown().get("name", ""), "Writing", "Writing's details")
		check(main.knowledge.is_open(), "over the open screen"))


func test_back_esc_t_and_the_realm_link_go_back_and_give_the_focus_back() -> void:
	for way in ["esc", "t", "link"]:
		await with_tree(func(main: Node):
			await wait_screen_transition()
			match way:
				"esc":
					press_key(main, KEY_ESCAPE)
				"t":
					press_key(main, KEY_T)
				"link":
					(main.knowledge.header.back_button as Button).pressed.emit()
			await wait_screen_transition()
			check(not main.knowledge.is_open(), "%s: closed" % way)
			check(main.tableau.is_visible_in_tree(), "%s: the Realm is back" % way))


func test_it_slides_in_from_the_right_as_the_realm_shifts_left() -> void:
	await with_reduce_motion(false, func():
		await with_tree(func(main: Node):
			main.knowledge.close()
			await wait_screen_transition()
			main.knowledge.open()
			var width: float = (main.knowledge as Control).size.x
			check(main.knowledge.slide_offset() >= width - 1.0, "starts off the right edge: %s" % main.knowledge.slide_offset())
			eq(main.knowledge.realm_shift(), 0.0, "the Realm in place")
			await (Engine.get_main_loop() as SceneTree).create_timer(0.32 + 0.1).timeout
			eq(main.knowledge.slide_offset(), 0.0, "in place by 0.32 s")
			eq(main.knowledge.realm_shift(), -24.0, "the Realm 24 px left")
			main.knowledge.close()
			await (Engine.get_main_loop() as SceneTree).create_timer(0.26 + 0.1).timeout
			eq(main.knowledge.realm_shift(), 0.0, "the Realm back by 0.26 s")
			check(not (main.knowledge as Control).is_visible_in_tree(), "the screen gone")))


func test_with_reduce_motion_it_only_fades() -> void:
	await with_reduce_motion(true, func():
		await with_tree(func(main: Node):
			eq(main.knowledge.slide_offset(), 0.0, "no slide")
			eq(main.knowledge.realm_shift(), 0.0, "the Realm stays")
			check((main.knowledge as Control).modulate.a < 1.0, "a fade")
			await (Engine.get_main_loop() as SceneTree).create_timer(0.12 + 0.1).timeout
			eq((main.knowledge as Control).modulate.a, 1.0, "in by 0.12 s")))


func test_over_a_territory_view_it_pushes_on_top_and_back_returns_to_the_view() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 5})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var home := home_uid(Game.engine)
	main.views[home].details_requested.emit(main.views[home])  # opens its territory view
	await wait_screen_transition()
	check(main.territory_view.is_open(), "precondition: the territory view")
	var home_name: String = Game.engine.zone("tableau").find(home).def.name
	press_key(main, KEY_T)
	await wait_screen_transition()
	if not has_knowledge(main):
		close_main(main)
		Game.engine = real
		return
	eq(main.knowledge.header.breadcrumb_text(), "Realm › %s › Knowledge" % home_name, "over the view")
	press_key(main, KEY_ESCAPE)
	await wait_screen_transition()
	check(not main.knowledge.is_open(), "closed")
	check(main.territory_view.is_open(), "back to the territory view")
	close_main(main)
	Game.engine = real
