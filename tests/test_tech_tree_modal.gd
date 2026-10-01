extends "res://tests/lib/tech_case.gd"
## The Knowledge (tech tree) modal in the real main scene (backlog 059): the Knowledge button and T open it with one
## column per era, named from era_names; T or Esc closes it. Since 140 an available tech's tile has a Learn button
## beside it (in the same row). Hook: main.tech_tree.shown() is the column titles ([] while hidden).


func knowledge_button(main: Node) -> Button:
	for b in main.find_children("*", "Button", true, false):
		if b.text.begins_with("Knowledge"):
			return b
	return null


func test_t_opens_the_tree_by_era_and_esc_closes_it() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	eq(main.tech_tree.shown(), ["Stone Age", "Bronze Age"] as Array[String], "one column per era, by name")
	press_key(main, KEY_ESCAPE)
	eq(main.tech_tree.shown(), [] as Array[String], "Esc closes")
	press_key(main, KEY_T)
	press_key(main, KEY_T)
	eq(main.tech_tree.shown(), [] as Array[String], "T toggles it closed")
	close_main(main)


func test_knowledge_button_opens_the_tree() -> void:
	var main := open_main()
	main.start_game(1)
	var button := knowledge_button(main)
	check(button != null, "a Knowledge button")
	if button != null:
		button.pressed.emit()
		check(not main.tech_tree.shown().is_empty(), "the tree is open")
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
	var button := knowledge_button(main)
	if button != null:
		out[0] = button.tooltip_text
	press_key(main, KEY_T)
	for label in main.tech_tree.find_children("*", "Label", true, false):
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
	await body.call(main)
	close_main(main)
	Game.engine = real


## The tech tile (a Button) in the open tree whose text names tech_name, or null.
func tile(main: Node, tech_name: String) -> Button:
	for b in main.tech_tree.find_children("*", "Button", true, false):
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
		press_key(main, KEY_T)
		press_key(main, KEY_T)  # reopen, so the tree reads 4 insight
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
		for label in main.tech_tree.find_children("*", "Label", true, false):
			if label.text.begins_with("Insight"):
				header = label.text
		eq(header, "Insight 5 · play a Research card for more", "header"))


func test_the_board_has_no_research_choice() -> void:
	await with_tree(func(main: Node):
		check(not "research_row" in main.choices, "no research overlay")
		var declines := main.find_children("*", "Button", true, false).filter(func(b): return b.text == "Decline")
		eq(declines.size(), 0, "no Decline button"))

