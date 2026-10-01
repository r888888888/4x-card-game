extends "res://tests/lib/test_case.gd"
## The event panel (backlog 068): the real main scene shows the active events with their turns left (the event piles'
## counts are hidden since 122). The tests run main on TEST_CARDS + TEST_EVENTS through with_event_engine. main.event_panel() is the test hook: {visible, info, tooltip, views: [{uid, id, text}]}.


## The card ids of the event views, in panel order.
func view_ids(panel: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for v in panel.get("views", []):
		ids.append(v.id)
	return ids


# --- AC1: active events row ---

func test_event_views_match_the_active_events_after_every_turn() -> void:
	with_event_engine(func():
		var main := open_main()
		var mismatches: Array[String] = []
		var shown := [0]
		play_seed_1(main, func(m):
			var ids := view_ids(m.event_panel())
			shown[0] += ids.size()
			var active := card_ids(Game.engine.zone("active_events"))
			if ids != active:
				mismatches.append("turn %d: views %s, active %s" % [Game.engine.turn, ids, active]))
		eq(mismatches, [] as Array[String], "event views vs active events")
		check(shown[0] > 0, "some event was shown during the game")
		close_main(main))


# --- AC2: turns left ---

func test_event_view_shows_its_turns_left() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		var e := Game.engine
		arrange(e.zone("event_deck"), ["trade_winds"])
		e.end_turn()  # Trade Winds drawn; turn 2's upkeep leaves 1 turn
		var uid := uid_of(e.zone("active_events"), "trade_winds")
		var texts := {}
		for v in main.event_panel().get("views", []):
			texts[v.uid] = v.text
		check(texts.get(uid, "").contains("1 turn left"), "Trade Winds view says '1 turn left': %s" % [texts])
		close_main(main))


# --- AC3: event info (no pile counts since 122) ---

const TOOLTIP := "One event is drawn at the end of each turn. It stays active until its turns run out."


func test_the_events_heading_names_no_pile_counts() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		var e := Game.engine
		arrange(e.zone("event_deck"), ["trade_winds"])
		e.end_turn()  # Trade Winds drawn: active for another turn
		var panel: Dictionary = main.event_panel()
		eq(panel.get("info"), "Events", "just 'Events' (122)")
		var headings: Array = main.section_headings().map(func(h): return h.text)
		check(headings.has("Events"), "the Events heading: %s" % [headings])
		check(not headings.any(func(h: String): return h.contains("deck") or h.contains("discard")), "no counts: %s" % [headings])
		eq(panel.get("tooltip"), TOOLTIP, "the tooltip explains the draw only")
		close_main(main))


## Backlog 122 (AC2): the section shows only while an event is active.
func test_the_events_section_shows_only_while_an_event_is_active() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		var e := Game.engine
		eq(main.event_panel().get("visible"), false, "hidden at the start: nothing active")
		arrange(e.zone("event_deck"), ["trade_winds", "windfall"])
		e.end_turn()  # Trade Winds drawn: active
		eq(main.event_panel().get("visible"), true, "shown while Trade Winds is active")
		e.end_turn()  # Windfall drawn; turn 3's upkeep ends both
		eq(card_ids(e.zone("active_events")), [] as Array[String], "nothing active")
		eq(main.event_panel().get("visible"), false, "hidden again")
		close_main(main))


# --- AC4: no events ---

func test_event_panel_is_hidden_without_an_event_deck() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		var panel: Dictionary = main.event_panel()
		eq(panel.get("visible"), false, "panel hidden with no event deck")
		eq(view_ids(panel), [] as Array[String], "no event views")
		close_main(main), {})
