extends "res://tests/lib/anarchy_case.gd"
## Anarchy as an event (backlog 253): it falls into the active events with its counters on show, the government slot
## stands empty while it lasts, upkeep neither counts it down nor discards it, and it gives 1 action plus the actions
## modifier. Fixtures: tests/lib/anarchy_case.gd (Chiefs, limit 5; Anarchy, an event; max_counters 4; Drill, +1 action).

const DRILL := {"id": "drill", "name": "Drill", "type": "building", "modifiers": {"actions": 1}}


# --- AC1: falling puts the event in the active events ---

func test_anarchy_falls_into_the_active_events_and_the_government_slot_empties() -> void:
	var e := fallen_engine()
	var events := e.zone("active_events")
	eq(card_ids(events).has("anarchy"), true, "Anarchy is an active event")
	eq(e.anarchy(), uid_of(events, "anarchy"), "anarchy() is the event's uid")
	eq(e.government(), -1, "no government rules")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs waits in the government deck")
	eq(e.anarchy_counters(), 4, "unrest 5 of 5: max_counters")


# --- AC2: its counters are the event's ---

func test_anarchys_event_counters_are_its_counters_left() -> void:
	var e := fallen_engine()
	e.set_unrest(3)  # calming: ⌈4 × 3 ÷ 5⌉ = 3 left
	eq(e.event_counters(e.anarchy()), 3, "3 counters on show")
	e.end_turn()
	eq(e.event_counters(e.anarchy()), 2, "one off at the end of the turn")


# --- AC3: upkeep doesn't count it down or discard it ---

func test_upkeep_neither_counts_anarchy_down_nor_discards_it() -> void:
	var e := fallen_engine()
	var uid := e.anarchy()
	for i in 3:
		e.end_turn()
	check(e.zone("active_events").find(uid) != null, "still active after 3 more upkeeps (1 counter left)")
	e.end_turn()
	eq(e.zone("active_events").find(uid), null, "burned out: no longer active")
	check(e.zone("removed").find(uid) != null, "removed")
	eq(e.zone("event_discard").find(uid), null, "not in the event discard")
	eq(e.zone("event_deck").find(uid), null, "not in the event deck")


func test_restoring_order_removes_the_anarchy_event() -> void:
	var e := second_turn_engine(5)
	var uid := e.anarchy()
	check(e.restore_order(), "restore: %s" % e.restore_order_error())
	eq(e.zone("active_events").find(uid), null, "no longer active")
	check(e.zone("removed").find(uid) != null, "removed")


# --- AC4: its action ---

func test_anarchy_gives_1_action_plus_the_actions_modifier() -> void:
	var e := anarchy_engine({}, {}, [DRILL])
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.actions_per_turn(), 1, "Anarchy's 1 action")
	build_on(e, home_uid(e), ["drill"])
	eq(e.actions_per_turn(), 2, "1 + Drill's +1")


# --- AC6: the loader wants an event ---

func test_unrest_anarchy_must_be_an_event_outside_the_event_deck() -> void:
	var with_block := func(block: Dictionary) -> Dictionary: return anarchy_raw(block)
	check_cases([
		["anarchy a government", with_block.call({"anarchy": "kings"}),
			["config.json: unrest.anarchy 'kings' is not an event"]],
		["anarchy a building", with_block.call({"anarchy": "farm"}),
			["config.json: unrest.anarchy 'farm' is not an event"]],
		["anarchy with a discard", with_block.call({"anarchy": "fleeting"}),
			["config.json: unrest.anarchy 'fleeting' can't have a discard"]],
		["anarchy in the event deck", anarchy_raw({}, {"event_deck": {"anarchy": 1}}),
			["config.json: unrest.anarchy 'anarchy' can't be in event_deck"]],
	], raw_config_errors)


# --- AC7: a revolution, and copies ---

func test_a_revolution_brings_the_anarchy_event() -> void:
	var e := revolted_engine(5)
	check(e.anarchy() != -1 and e.zone("active_events").find(e.anarchy()) != null, "Anarchy is an active event")
	eq(e.government(), -1, "no government rules")


func test_a_copy_keeps_the_active_anarchy_and_its_counters() -> void:
	var e := fallen_engine()
	e.set_unrest(3)
	var f := e.fork()
	eq(f.anarchy(), e.anarchy(), "the same uid")
	eq(f.anarchy_counters(), 3, "its counters")
	f.end_turn()
	eq([f.anarchy_counters(), e.anarchy_counters()], [2, 3], "the fork counts down alone")


func test_an_event_may_carry_a_quote() -> void:
	var r := fixture_load([{"id": "omen_q", "name": "Omen", "type": "event", "quote": {"text": "Things fall apart.",
		"by": "Yeats"}}])
	eq(r.errors, [] as Array[String], "loads")
	eq([r.cards.omen_q.quote_text, r.cards.omen_q.quote_by], ["Things fall apart.", "Yeats"], "the quote is read (253)")
