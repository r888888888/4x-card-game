extends "res://tests/lib/test_case.gd"
## Card slots in the real main scene: a slot is created at the height its card will rest at, so a row doesn't change
## height when a flying card lands (backlog 075). No frames run, so new cards are still flying when these checks run.


## The slot heights of the card views for zone_name's cards, in zone order.
func slot_heights(main: Node, zone_name: String) -> Array[float]:
	var out: Array[float] = []
	for card in Game.engine.zone(zone_name).cards:
		out.append(main.views[card.uid].slot.custom_minimum_size.y)
	return out


## n copies of height.
func heights(height: float, n: int) -> Array[float]:
	var out: Array[float] = []
	for i in n:
		out.append(height)
	return out


func test_bug_075_frontier_slot_starts_at_compact_height() -> void:
	var main := open_main()
	main.start_game(7)
	var e := Game.engine
	var scout := e.create_card("scout", "hand", null)
	check(e.play_card(scout.uid), "Scout played")
	check(e.choose(e.pending().options[0]), "a territory kept")
	eq(slot_heights(main, "frontier"), heights(CardView.COMPACT_SIZE.y, 1), "frontier slot heights")
	close_main(main)


func test_bug_075_known_slot_starts_at_compact_height() -> void:
	var main := open_main()
	main.start_game(7)
	var e := Game.engine
	e.resources[GameEngine.WEALTH] = 99
	var insight := e.create_card("research", "hand", null)
	check(e.play_card(insight.uid), "Research card played")
	check(e.buy_tech(e.pending().options[0]), "a tech bought")
	eq(slot_heights(main, "researched"), heights(CardView.COMPACT_SIZE.y, 1), "known slot heights")
	close_main(main)


## Realm cards pop in already at rest, and headless (no layout) their text wraps at zero width, so only the hand is
## checked here.
func test_hand_slots_keep_their_height() -> void:
	var main := open_main()
	main.start_game(7)
	var e := Game.engine
	eq(slot_heights(main, "hand"), heights(CardView.HAND_SIZE.y + Anim.LIFT_ROOM, e.zone("hand").size()), "hand slot heights")
	close_main(main)
