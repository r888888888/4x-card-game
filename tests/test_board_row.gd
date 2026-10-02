extends "res://tests/lib/tech_case.gd"
## One board row (backlog 137): active events, then frontier territories, then the Realm's own cards share the Realm's
## wrapping row (main.tableau.row); there is no Frontier, Known or Events row, and known techs have no view on the
## board. Runs the real main scene on a board_engine game through with_main (test_case.gd). Test hooks: main.views_in(row),
## main.section_headings(), main.relieve_button().


## The uids of the cards in the board row, in order.
func row_uids(main: Node) -> Array[int]:
	var out: Array[int] = []
	for view in main.views_in(main.tableau.row):
		out.append(view.uid)
	return out


## Each play-area heading's text ("Realm", "In Hand" since 204).
func heading_words(main: Node) -> Array[String]:
	var out: Array[String] = []
	for h in main.section_headings():
		out.append(h.text)
	return out


# --- AC1: events, then frontier, then the Realm ---

func test_events_then_frontier_then_the_realm_share_one_row() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		to_frontier(e, ["hills", "grassland"])
		var frontier: Array[int] = []
		for card in e.zone("frontier").cards:
			frontier.append(card.uid)
		var shrine: CardInstance = e.create_card("shrine", "tableau", null)  # on no territory
		var winds: CardInstance = e.create_card("trade_winds", "active_events", null)
		var harvest: CardInstance = e.create_card("harvest", "active_events", null)
		e.changed.emit()
		await wait_frames()
		var expected: Array[int] = [winds.uid, harvest.uid]
		expected.append_array(frontier)
		expected.append_array([home, grass, shrine.uid])
		eq(row_uids(main), expected, "events in draw order, frontier in zone order, then the Realm"))


# --- AC2: one heading for the board ---

func test_the_only_section_headings_are_realm_and_hand() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		to_frontier(e, ["hills"])
		e.create_card("trade_winds", "active_events", null)
		e.changed.emit()
		await wait_frames()
		eq(heading_words(main), ["Realm", "In Hand"] as Array[String], "play area headings"))


# --- AC3: known techs leave the board ---

func test_a_bought_tech_has_no_view_on_the_board() -> void:
	await with_main(tech_engine(["pottery", "writing"]), func(main: Node):
		var e := Game.engine
		var tech: int = e.zone("research_deck").cards[0].uid
		check(e.buy_tech(tech), "buy_tech: %s" % e.buy_tech_error(tech))
		await wait_frames()
		check(e.zone("researched").find(tech) != null, "the tech is known")
		check(not main.views.has(tech), "no view for the known tech"))


# --- AC4: settling moves the card within the row ---

func test_settling_a_frontier_territory_keeps_its_view_and_moves_it_into_the_realm() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		to_frontier(e, ["grassland", "hills"])
		var a := uid_of(e.zone("frontier"), "grassland")
		var b := uid_of(e.zone("frontier"), "hills")
		var pioneer := put_in_hand(e, "pioneer")
		e.resources.food = 5
		e.changed.emit()
		await wait_frames()
		var view_before: CardView = main.views[a]
		check(e.play_card(pioneer, a), "settle A: %s" % e.play_error(pioneer, a))
		await wait_frames()
		check(main.views.get(a) == view_before, "A keeps its view")
		eq(row_uids(main), [b, home, a] as Array[int], "B, the home territory, then A"))


# --- AC5: drops and the frontier explanation ---

func test_a_city_dropped_on_a_frontier_card_in_the_row_targets_it() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		to_frontier(e, ["hills"])
		var hills := uid_of(e.zone("frontier"), "hills")
		var pioneer := put_in_hand(e, "pioneer")
		e.resources.food = 5
		e.changed.emit()
		await wait_frames()
		await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout  # cards pop in and land
		var view: CardView = main.views[hills]
		check(view.slot.get_parent() == main.tableau.row, "the frontier card rests in the board row")
		main.drag.begin_drag(main.views[pioneer], Vector2.ZERO)
		eq(main.drag.target_at(view.get_global_rect().get_center()), hills, "a drop on its card targets it")
		main.drag.end_drag())


func test_a_frontier_card_explains_the_frontier_in_its_tooltip() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		to_frontier(e, ["hills"])
		e.changed.emit()
		await wait_frames()
		var tip: String = (main.views[uid_of(e.zone("frontier"), "hills")] as CardView).tooltip_text
		check(tip.contains("Territories discovered, not yet settled. Play a city card on one to settle it."),
			"frontier tooltip: '%s'" % tip))


# --- AC6: Relieve without an Events section ---

func test_relieve_shows_during_a_famine_with_no_events_heading() -> void:
	var famine: Dictionary = FAMINE.merged({"relief": {"wealth": 5}})
	await with_main(board_engine({"population": HUNGRY_POP.merged({"famine": famine})}), func(main: Node):
		var e := Game.engine
		var relieve: Button = main.relieve_button()
		check(not relieve.is_visible_in_tree(), "hidden with no Famine")
		e.zone("tableau").find(home_uid(e)).pop = 4
		e.resources.food = 0
		e.end_turn()  # hungry upkeep: a Famine arrives
		check(e.famine_counters() > 0, "a Famine is active")
		await wait_frames()
		check(relieve.is_visible_in_tree(), "Relieve shows during the Famine")
		check(not heading_words(main).has("Events"), "no Events heading: %s" % [heading_words(main)]))


func test_an_event_card_explains_events_in_its_tooltip() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		var winds: CardInstance = e.create_card("trade_winds", "active_events", null)
		e.changed.emit()
		await wait_frames()
		var tip: String = (main.views[winds.uid] as CardView).tooltip_text
		check(tip.contains("One event is drawn at the end of each turn. It stays active until its turns run out."),
			"event tooltip: '%s'" % tip))
