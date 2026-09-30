extends "res://tests/lib/test_case.gd"
## Collapsing territory groups in the real main scene (backlog 087). Seed 1 starts on River Meadow with the Capital and
## 2 pop; 3 Farms are put on it with build_on, so 1 is idle. Hooks on main.tableau: set_collapsed / is_collapsed,
## has_toggle, group_summary (the summary label's text, "" while hidden), group_frame, reveal. The "Collapse all" /
## "Expand all" button is found by its text.


## Starts seed 1 with 3 Farms on the home territory, laid out; returns the home territory's uid.
func start(main: Node) -> int:
	main.start_game(1)
	var home := home_uid(Game.engine)
	add(home, ["farm", "farm", "farm"])
	await wait_frames()
	return home


## Puts new copies of ids on territory uid and refreshes the board.
func add(uid: int, ids: Array) -> void:
	build_on(Game.engine, uid, ids)
	Game.engine.changed.emit()  # build_on bypasses the actions that refresh the board


## The uids of the tableau cards in territory uid's group, the territory card first.
func group_cards(uid: int) -> Array[int]:
	var out: Array[int] = []
	for group in Game.engine.territory_groups():
		if group.territory == uid:
			out.assign(group.cards)
	return out


func shown(main: Node, uid: int) -> bool:
	return main.views.has(uid) and (main.views[uid] as CardView).is_visible_in_tree()


func button(main: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(main):
		if b.text.begins_with(prefix) and b.is_visible_in_tree():
			return b
	return null


# --- AC3: collapse and expand one group ---

func test_collapsing_a_group_hides_its_city_and_buildings() -> void:
	var main := open_main()
	var home: int = await start(main)
	var cards := group_cards(home)
	eq(cards.size(), 5, "territory, Capital, 3 Farms")
	var expanded: float = main.tableau.group_frame(home).size.y
	main.tableau.set_collapsed(home, true)
	await wait_frames()
	check(main.tableau.is_collapsed(home), "collapsed")
	check(shown(main, cards[0]), "the territory card stays")
	for uid in cards.slice(1):
		check(not shown(main, uid), "card %d hidden" % uid)
	check(button(main, "Grow") != null, "Grow stays")
	eq(main.tableau.group_summary(home), "1 city · 3 buildings (1 idle)", "summary")
	var collapsed: float = main.tableau.group_frame(home).size.y
	check(collapsed < expanded, "the group is shorter collapsed (%d) than expanded (%d)" % [collapsed, expanded])
	main.tableau.set_collapsed(home, false)
	await wait_frames()
	for uid in cards:
		check(shown(main, uid), "card %d shown again" % uid)
	eq(main.tableau.group_summary(home), "", "summary hidden")
	close_main(main)


# --- AC4: stays collapsed through a refresh ---

func test_a_collapsed_group_stays_collapsed_when_a_building_arrives() -> void:
	var main := open_main()
	var home: int = await start(main)
	main.tableau.set_collapsed(home, true)
	add(home, ["farm"])
	await wait_frames()
	var farm: int = group_cards(home)[-1]
	check(main.tableau.is_collapsed(home), "still collapsed")
	check(main.views.has(farm) and not shown(main, farm), "the new Farm's view is hidden")
	check(main.tableau.group_summary(home).begins_with("1 city · 4 buildings"), "summary: %s" % main.tableau.group_summary(home))
	close_main(main)


# --- AC5: collapse all, expand all ---

func test_collapse_all_and_expand_all() -> void:
	var main := open_main()
	var home: int = await start(main)
	var e := Game.engine
	settle(e, [e.zone("territory_deck").cards[0].def.id])
	var second: int = e.zone("tableau").cards[-1].uid
	e.create_card("shrine", "tableau", null)  # on no territory
	e.changed.emit()
	await wait_frames()
	check(not main.tableau.has_toggle(-1), "the no-territory group has no toggle")
	check(main.tableau.has_toggle(home), "a territory group has one")
	var collapse := button(main, "Collapse all")
	check(collapse != null, "a Collapse all button")
	if collapse == null:
		close_main(main)
		return
	collapse.pressed.emit()
	check(main.tableau.is_collapsed(home) and main.tableau.is_collapsed(second), "both territories collapsed")
	check(not main.tableau.is_collapsed(-1), "the no-territory group isn't")
	var expand := button(main, "Expand all")
	check(expand != null, "the button now says Expand all")
	if expand != null:
		expand.pressed.emit()
		check(not main.tableau.is_collapsed(home) and not main.tableau.is_collapsed(second), "both expanded")
	close_main(main)


func test_new_territories_and_new_games_start_expanded() -> void:
	var main := open_main()
	var home: int = await start(main)
	var e := Game.engine
	main.tableau.set_collapsed(home, true)
	settle(e, [e.zone("territory_deck").cards[0].def.id])
	var later: int = e.zone("tableau").cards[-1].uid
	e.changed.emit()
	check(not main.tableau.is_collapsed(later), "a territory settled later starts expanded")
	main.start_game(1)  # same seed: the home territory has the same uid again
	check(not main.tableau.is_collapsed(home_uid(Game.engine)), "a new game starts expanded")
	close_main(main)


# --- AC6: still a drop target ---

func test_a_collapsed_group_is_still_a_drop_target() -> void:
	var main := open_main()
	var home: int = await start(main)
	main.tableau.set_collapsed(home, true)
	await wait_frames()
	var frame: Control = main.tableau.group_frame(home)
	eq(main.tableau.group_at(frame.get_global_rect().get_center()), home, "group_at inside the collapsed frame")
	main.tableau.move_ghost(home)
	await wait_frames()
	var row: Node = main.tableau.ghost.get_parent()
	check(main.tableau.ghost.visible, "ghost shown")
	var before: Array = []
	for child in row.get_children():
		if child == main.tableau.ghost:
			break
		if (child as Control).visible:
			before.append(child)
	eq(before, [main.views[group_cards(home)[0]].slot], "only the territory card is shown before the ghost")
	close_main(main)


# --- AC7: targeting reveals ---

func test_revealing_a_card_expands_its_group() -> void:
	var main := open_main()
	var home: int = await start(main)
	main.tableau.set_collapsed(home, true)
	main.tableau.reveal(group_cards(home)[2])
	check(not main.tableau.is_collapsed(home), "revealing a Farm expands its group")
	check(shown(main, group_cards(home)[2]), "the Farm is shown")
	close_main(main)
