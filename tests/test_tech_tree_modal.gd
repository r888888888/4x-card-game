extends "res://tests/lib/tech_case.gd"
## The Knowledge (tech tree) modal in the real main scene (backlog 059): the Knowledge button and T open it with one
## column per era, named from era_names; T or Esc closes it. Hook: main.tech_tree.shown() is the column titles
## ([] while hidden).


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

const TREE_TOOLTIP := "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives."


## Opens main on a fixture game (TECHS in the research deck) with main deck deck, starts it, opens the tree and
## returns [Knowledge tooltip, tree header]. Puts the real engine back afterwards.
func hints_with_deck(deck: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config(deck, {"research_deck": {"pottery": 1, "writing": 1}}),
		tech_resources(), cards, "test", errors, warnings)
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
		if label.text.begins_with("Research deck"):
			out[1] = label.text
	close_main(main)
	Game.engine = real
	return out


func test_hints_name_the_research_card() -> void:
	var hints := hints_with_deck({"farm": 5, "study": 1})
	eq(hints[0], TREE_TOOLTIP + "\nPlay a Research card to reveal 2 techs.", "Knowledge tooltip")
	check(hints[1].ends_with(" · play a Research card to reveal 2 techs"), "tree header names Research: %s" % hints[1])


func test_hints_leave_out_the_research_sentence_without_a_research_card() -> void:
	var hints := hints_with_deck({"farm": 5})
	eq(hints[0], TREE_TOOLTIP, "Knowledge tooltip")
	check(hints[1].begins_with("Research deck") and not hints[1].contains("reveal"), "tree header: %s" % hints[1])

