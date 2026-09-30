extends "res://tests/lib/test_case.gd"
## A territory group's cards wrap instead of widening the tableau (backlog 078). Runs the real main scene; cards are
## put straight on the Capital's territory with build_on. No frames run, so these check minimum sizes and structure,
## not laid-out positions.


## Starts seed 1 and returns the home territory's uid (it holds the territory card's group: Capital so far).
func start(main: Node) -> int:
	main.start_game(1)
	return home_uid(Game.engine)


## Puts n more Farms on territory uid and refreshes the board.
func add_farms(uid: int, n: int) -> void:
	var ids: Array = []
	for i in n:
		ids.append("farm")
	build_on(Game.engine, uid, ids)
	Game.engine.changed.emit()  # build_on bypasses the actions that refresh the board


## The uids of the tableau cards on territory uid (the territory card itself included).
func group_cards(uid: int) -> Array[int]:
	var out: Array[int] = []
	for group in Game.engine.territory_groups():
		if group.territory == uid:
			out.assign(group.cards)
	return out


func test_bug_078_many_cards_do_not_widen_the_tableau() -> void:
	var main := open_main()
	var home := start(main)
	var before: float = main.tableau.get_combined_minimum_size().x
	add_farms(home, 10 - group_cards(home).size())
	eq(group_cards(home).size(), 10, "10 tableau cards on the home territory")
	var after: float = main.tableau.get_combined_minimum_size().x
	check(after <= before, "tableau minimum width with 10 cards (%d) is no greater than at the start (%d)" % [after, before])
	close_main(main)


func test_bug_078_every_card_stays_in_its_group() -> void:
	var main := open_main()
	var home := start(main)
	add_farms(home, 10 - group_cards(home).size())
	main.tableau.move_ghost(home)  # the ghost goes into the home group's row: use it to find that row
	var row: Node = main.tableau.ghost.get_parent()
	var cards := group_cards(home)
	for uid in cards:
		check(main.views.has(uid), "card %d has a view" % uid)
	# 087: the territory is the group's title bar; every other card is in the row.
	if main.views.has(home):
		check(main.tableau.group_header(home).is_ancestor_of(main.views[home]), "the territory is in the header")
	for uid in cards.slice(1):
		if main.views.has(uid):
			check((main.views[uid] as CardView).slot.get_parent() == row, "card %d is in the home group's row" % uid)
	close_main(main)


func test_bug_078_ghost_goes_after_the_groups_last_card() -> void:
	var main := open_main()
	var home := start(main)
	add_farms(home, 10 - group_cards(home).size())
	main.tableau.move_ghost(home)
	var row: Node = main.tableau.ghost.get_parent()
	check(main.tableau.ghost.visible, "ghost shown")
	eq(main.tableau.ghost.get_index(), row.get_child_count() - 1, "ghost is the row's last child")
	var last: CardView = main.views.get(group_cards(home)[-1])
	check(last != null and last.slot.get_parent() == row, "the last card shares the ghost's row")
	close_main(main)
