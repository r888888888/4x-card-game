extends "res://tests/lib/test_case.gd"
## The active events (backlog 068; in the Realm's row since 137): the real main scene shows them with their turns
## left. The tests run main on TEST_CARDS + TEST_EVENTS through with_event_engine. MainProbe.event_panel(main) is the test hook:
## {visible, tooltip, views: [{uid, id, text}]}.


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
			var ids := view_ids(MainProbe.event_panel(m))
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
		e.end_turn()  # Trade Winds drawn at turn 2's start, after its upkeep: 2 turns left (237)
		var uid := uid_of(e.zone("active_events"), "trade_winds")
		var texts := {}
		for v in MainProbe.event_panel(main).get("views", []):
			texts[v.uid] = v.text
		check(texts.get(uid, "").contains("2 turns left"), "Trade Winds view says '2 turns left': %s" % [texts])
		close_main(main))


# --- AC4: no events ---

func test_event_panel_is_hidden_without_an_event_deck() -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		var panel: Dictionary = MainProbe.event_panel(main)
		eq(panel.get("visible"), false, "panel hidden with no event deck")
		eq(view_ids(panel), [] as Array[String], "no event views")
		close_main(main), {})
