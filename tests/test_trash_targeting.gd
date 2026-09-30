extends "res://tests/lib/test_case.gd"
## Trash targeting in the real main scene (backlog 082): a double-clicked Winnow lights the other hand cards as
## pickable targets, and picking one trashes it. Uses main.drag (targeting, lit) and main.views.


## Starts seed 1 with a Winnow added to the hand and food to pay for it; returns Winnow's uid.
func winnow_in_hand(main: Node) -> int:
	main.start_game(1)
	var uid := put_in_hand(Game.engine, "winnow")
	Game.engine.resources.food = 5
	Game.engine.changed.emit()  # put_in_hand bypasses the actions that refresh the board
	return uid


func test_double_clicked_winnow_lights_the_other_hand_cards() -> void:
	var main := open_main()
	var winnow := winnow_in_hand(main)
	var others: Array[int] = []
	for card in Game.engine.zone("hand").cards:
		if card.uid != winnow:
			others.append(card.uid)
	main.on_double_clicked(main.views[winnow])
	check(main.drag.targeting == main.views[winnow], "targeting Winnow")
	eq(sorted(main.drag.lit), sorted(others), "the other hand cards are lit")
	for uid in others:
		check((main.views[uid] as CardView).pickable, "hand card %d is pickable" % uid)
	close_main(main)


func test_picking_a_lit_hand_card_trashes_it() -> void:
	var main := open_main()
	var winnow := winnow_in_hand(main)
	main.on_double_clicked(main.views[winnow])
	var target: int = main.drag.lit[0] if not main.drag.lit.is_empty() else -1
	check(target != -1, "a lit target")
	if target != -1:
		main.on_picked(main.views[target])
		check(Game.engine.zone("trashed").find(target) != null, "the picked card is trashed")
		check(main.drag.targeting == null, "targeting ended")
		check(not main.views.has(target), "its view left the board")
	close_main(main)
