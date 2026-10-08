extends "res://tests/lib/raid_case.gd"
## Event preconditions (backlog 416): an event's `requires` (terrain keywords, met when a settled territory has any of
## them) and a raid's targets. An event drawn with its precondition unmet goes to the event discard unseen (no
## `event_drawn`, no effects) and the next event is drawn; raid pacing (257) still sends a raid to the deck's bottom.
## Fixture: Rockfall in RAID_CARDS (tests/lib/raid_case.gd).


## Records the uid of every event_drawn outcome e emits into the returned array.
func record_drawn(e: GameEngine) -> Array[int]:
	var uids: Array[int] = []
	e.event_drawn.connect(func(o: Dictionary): uids.append(o.uid))
	return uids


# --- AC1, AC2: requires on an event ---

func test_an_event_whose_requires_no_settled_territory_has_is_discarded_unseen() -> void:
	var e := fixture_no_mountain(["rockfall", "omen"], {"rockfall": 1, "omen": 3})
	if e == null:
		return
	var rockfall := uid_of(e.zone("event_deck"), "rockfall")
	var omen := e.zone("event_deck").cards[-2].uid
	var insight: int = e.resources.insight
	var drawn := record_drawn(e)
	e.end_turn()
	check(e.zone("event_discard").find(rockfall) != null, "Rockfall in the event discard")
	eq(active_uid(e, "rockfall"), -1, "Rockfall not active")
	eq(active_uid(e, "omen"), omen, "the Omen under it is the turn's event")
	eq(drawn, [omen] as Array[int], "event_drawn once, for the Omen")
	eq(e.resources.insight, insight, "Rockfall's play effects don't resolve")


func test_an_event_whose_requires_a_settled_territory_has_resolves() -> void:
	var e := raid_engine(["rockfall"], {"rockfall": 1, "omen": 3})
	if e == null:
		return
	var rockfall := uid_of(e.zone("event_deck"), "rockfall")
	var insight: int = e.resources.insight
	var drawn := record_drawn(e)
	e.end_turn()
	eq(active_uid(e, "rockfall"), rockfall, "Rockfall active (Hills is a mountain)")
	eq(drawn, [rockfall] as Array[int], "event_drawn for Rockfall")
	eq(e.resources.insight - insight, 2, "its play effects resolve")


func test_any_one_of_the_required_keywords_is_enough() -> void:
	var e := fixture_no_mountain(["rockfall"], {"rockfall": 1, "omen": 3})
	if e == null:
		return
	settle(e, ["river"])
	e.end_turn()
	check(active_uid(e, "rockfall") != -1, "River's flood plain meets Rockfall's requires")


func test_a_frontier_territory_does_not_meet_requires() -> void:
	var e := fixture_no_mountain(["rockfall", "omen"], {"rockfall": 1, "omen": 3})
	if e == null:
		return
	to_frontier(e, ["hills"])
	var rockfall := uid_of(e.zone("event_deck"), "rockfall")
	e.end_turn()
	eq(active_uid(e, "rockfall"), -1, "unsettled Hills don't count")
	check(e.zone("event_discard").find(rockfall) != null, "Rockfall in the event discard")


# --- AC4: pacing comes first ---

func test_a_raid_held_back_by_pacing_goes_to_the_deck_bottom_not_the_discard() -> void:
	var e := fixture_no_mountain(["raiders", "omen"], {"raiders": 1, "omen": 3}, {"raid_min_size": 999})
	if e == null:
		return
	var raid := uid_of(e.zone("event_deck"), "raiders")
	e.end_turn()
	eq(e.zone("event_discard").find(raid), null, "not discarded")
	eq(e.zone("event_deck").cards[0].uid, raid, "at the event deck's bottom")


# --- AC5: no loop when nothing qualifies ---

func test_unmet_events_are_discarded_and_the_discard_reshuffled_once_for_a_met_one() -> void:
	var e := fixture_no_mountain(["rockfall", "rockfall", "omen"], {"rockfall": 2, "omen": 1})
	if e == null:
		return
	var deck := e.zone("event_deck")
	var omen: CardInstance = deck.cards[-3]
	deck.remove(omen)
	e.zone("event_discard").add(omen)
	var drawn := record_drawn(e)
	e.end_turn()
	eq(drawn, [omen.uid] as Array[int], "the Omen, from the reshuffled discard, is the turn's event")
	eq(active_uid(e, "omen"), omen.uid, "the Omen active")
	eq(e.zone("active_events").size(), 1, "nothing else active")


func test_no_event_when_no_event_in_either_pile_is_met() -> void:
	var e := fixture_no_mountain(["rockfall", "rockfall"], {"rockfall": 2})
	if e == null:
		return
	var drawn := record_drawn(e)
	e.end_turn()
	eq(drawn, [] as Array[int], "no event_drawn")
	eq(e.zone("active_events").size(), 0, "nothing active")
	eq(e.zone("event_deck").size() + e.zone("event_discard").size(), 2, "both Rockfalls kept in the event piles")


# --- AC6: loading and text ---

func test_requires_loads_on_an_event() -> void:
	var r := raid_load()
	eq(r.errors, [] as Array[String], "no errors")
	eq(r.warnings.filter(func(w): return "rockfall" in w), [] as Array[String], "no warning for Rockfall's requires")
	eq(r.cards.rockfall.requires, ["mountain", "flood_plain"] as Array[String], "Rockfall's requires")


func test_bad_requires_on_an_event_is_a_load_error() -> void:
	check_cases([
		["unknown keyword", [{"id": "x", "name": "X", "type": "event", "requires": ["swamp"]}],
			["card 'x'", "requires", "swamp"], "one_error"],
		["on a raid", raid_with({"requires": ["mountain"]}), ["card 'x'", "requires", "raid"], "one_error"],
	], raid_load)


func test_an_events_text_shows_what_it_requires() -> void:
	var db: Dictionary = raid_load().cards
	var tip: String = db.rockfall.rules_tooltip(db)
	check("Requires Mountain or Flood Plain" in tip, "tooltip: %s" % tip)
	var face: String = db.rockfall.rules_text(db)
	check("Needs Mountain/Flood Plain" in face, "face: %s" % face)
