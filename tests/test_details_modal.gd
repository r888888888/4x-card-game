extends "res://tests/lib/test_case.gd"
## The card details modal in the real main scene (backlog 056): I opens it for the focused card, Esc closes it, it
## blocks the board's keys while open, and supply piles show their definition. Hook: main.details.shown() is the
## details on show ({} while hidden).


## Sends a key press and release through main's viewport, as the keyboard would.
func press_key(main: Node, keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		main.get_viewport().push_input(event)


func test_i_opens_details_for_the_focused_card_and_esc_closes_them() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_RIGHT)
	var focused: CardView = main.focus.focused
	check(focused != null, "Right focuses the first hand card")
	press_key(main, KEY_I)
	var name: String = Game.engine.zone("hand").find(focused.uid).def.name if focused != null else "?"
	eq(main.details.shown().get("name", ""), name, "details of the focused card")
	press_key(main, KEY_ESCAPE)
	eq(main.details.shown(), {}, "Esc closes the details")
	check(main.focus.focused == focused, "the focus stays on the card")
	close_main(main)


func test_open_details_block_the_board_keys() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_RIGHT)
	press_key(main, KEY_I)
	var turn := Game.engine.turn
	press_key(main, KEY_E)
	eq(Game.engine.turn, turn, "E doesn't end the turn under the details")
	check(not main.details.shown().is_empty(), "details still open")
	close_main(main)


func test_supply_pile_details_come_from_its_definition() -> void:
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var piles: Array = main.supply.views()
	check(not piles.is_empty(), "the supply is open with piles")
	if not piles.is_empty():
		main.details.open(piles[0])
		check(main.details.shown().get("name", "") != "", "a pile's details have its name")
		eq(main.details.shown().get("state"), [] as Array[String], "a pile has no live state")
	close_main(main)
