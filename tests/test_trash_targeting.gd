extends "res://tests/lib/test_case.gd"
## Trash targeting in the real main scene (backlog 082): a double-clicked trash card lights the other hand cards as
## pickable targets, and picking one trashes it. Uses main.drag (targeting, lit) and main.views. The fixture Purge
## is local: no real card trashes since Winnow left the game (277).

const PURGE := {"id": "purge", "name": "Purge", "type": "action", "cost": {"food": 1}, "effects": [{"op": "trash"}]}


## Runs body(main, uid) on a started fixture game with a Purge added to the hand and food to pay for it.
func with_purge(body: Callable) -> void:
	await with_main(make_engine({"farm": 10}, {}, 1, [PURGE]), func(main: Node):
		var uid := put_in_hand(Game.engine, "purge")
		Game.engine.resources.food = 5
		Game.engine.changed.emit()  # put_in_hand bypasses the actions that refresh the board
		await wait_frames()
		await body.call(main, uid))


func test_double_clicked_trash_card_lights_the_other_hand_cards() -> void:
	await with_purge(func(main: Node, purge: int):
		var others: Array[int] = []
		for card in Game.engine.zone("hand").cards:
			if card.uid != purge:
				others.append(card.uid)
		main.card_actions.on_double_clicked(main.views[purge])
		check(main.drag.targeting == main.views[purge], "targeting Purge")
		eq(sorted(main.drag.lit), sorted(others), "the other hand cards are lit")
		for uid in others:
			check((main.views[uid] as CardView).pickable, "hand card %d is pickable" % uid))


func test_picking_a_lit_hand_card_trashes_it() -> void:
	await with_purge(func(main: Node, purge: int):
		main.card_actions.on_double_clicked(main.views[purge])
		var target: int = main.drag.lit[0] if not main.drag.lit.is_empty() else -1
		check(target != -1, "a lit target")
		if target != -1:
			main.card_actions.on_picked(main.views[target])
			check(Game.engine.zone("trashed").find(target) != null, "the picked card is trashed")
			check(main.drag.targeting == null, "targeting ended")
			check(not main.views.has(target), "its view left the board"))
