extends "res://tests/lib/test_case.gd"
## The Knowledge (tech tree) modal in the real main scene (backlog 059): the Knowledge button and T open it with one
## column per era, named from era_names; T or Esc closes it. Hook: main.tech_tree.shown() is the column titles
## ([] while hidden).


## Sends a key press and release through main's viewport, as the keyboard would.
func press_key(main: Node, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		main.get_viewport().push_input(event)


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
