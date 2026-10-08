extends "res://tests/lib/anarchy_case.gd"
## Anarchy's length (backlogs 155, 384): Anarchy falls with unrest.anarchy_turns counters on its card, whatever the
## unrest; one comes off at the end of each of its turns, and at 0 it ends and the government choice is owed before the
## next turn starts. Unrest doesn't change its length. Choosing the government sets unrest to 0. Fixtures:
## tests/lib/anarchy_case.gd (Chiefs, limit 5; Kings, limit 7; Feast, −2 unrest; anarchy_turns 3).


# --- AC1: a fixed 3 turns ---

func test_anarchy_lasts_3_turns_counting_down_its_counters() -> void:
	var e := fallen_engine()
	var anarchy := e.anarchy()
	for row in [[2, 3], [3, 2], [4, 1]]:
		eq([e.turn, e.anarchy() != -1, e.event_counters(anarchy)], [row[0], true, row[1]], "turn %d" % row[0])
		if row[0] < 4:
			e.end_turn()
	e.end_turn()
	eq([e.turn, e.anarchy()], [4, -1], "the end of turn 4 ends it, before turn 5 starts")
	check(e.zone("removed").find(anarchy) != null, "the Anarchy card is removed")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed")
	check(e.choose_government(uid_of(e.zone("governments"), "kings")), "choose Kings")
	eq([e.turn, ruling(e), e.resources.unrest], [5, "kings", 0], "turn 5 under Kings, unrest 0")


func test_a_revolution_with_1_unrest_also_lasts_3_turns() -> void:
	var e := revolted_engine(1)
	eq([e.turn, e.anarchy() != -1, e.event_counters(e.anarchy())], [2, true, 3], "falls at turn 2's start with 3")
	e.end_turn()
	e.end_turn()
	eq([e.turn, e.anarchy() != -1], [4, true], "still rules on turn 4")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.pending().get("kind")], [4, -1, GameEngine.PENDING_GOVERNMENT],
		"ends at the end of turn 4")


func test_its_length_is_the_configs_anarchy_turns() -> void:
	var e := anarchy_engine({"anarchy_turns": 1})
	e.resources["unrest"] = 5
	e.end_turn()
	eq([e.turn, e.event_counters(e.anarchy())], [2, 1], "1 counter")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.pending().get("kind")], [2, -1, GameEngine.PENDING_GOVERNMENT],
		"anarchy_turns 1: it ends at the end of the turn it fell")


func test_the_next_upkeep_runs_under_the_chosen_government() -> void:
	var e := revolted_engine(1)
	var home := home_uid(e)
	eq(e.pop(home), 5, "turn 2 had an Anarchy upkeep (⟳ −1 pop)")
	e.end_turn()
	e.end_turn()
	eq(e.pop(home), 3, "turns 3 and 4 too")
	e.end_turn()
	eq(e.end_turn_error(), "Choose a government first.", "the turn can't end again")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e)], [5, "chiefs"], "choosing finishes the turn: turn 5 under Chiefs")
	eq(e.pop(home), 3, "turn 5's upkeep ran under Chiefs: no pop lost")


func test_anarchys_end_comes_after_the_hand_limit_discard() -> void:
	var e := anarchy_engine({"anarchy_turns": 1})
	e.resources["unrest"] = 5
	e.end_turn()
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_DISCARD, "the discard comes first")
	check(e.anarchy() != -1, "Anarchy still rules while the discard is owed")
	e.discard_card(first_in_hand(e))
	eq([e.turn, e.anarchy(), e.pending().get("kind")], [2, -1, GameEngine.PENDING_GOVERNMENT],
		"then its last counter comes off and the choice is owed")


# --- AC2: unrest doesn't change its length ---

func test_calming_doesnt_shorten_anarchy() -> void:
	var e := fallen_engine()
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast: %s" % e.play_error(feast))
	eq([e.resources.unrest, e.event_counters(e.anarchy())], [3, 3], "unrest 3, counters still 3")
	var again := put_in_hand(e, "feast")
	check(e.play_card(again), "a second Feast: %s" % e.play_error(again))
	eq([e.resources.unrest, e.event_counters(e.anarchy())], [1, 3], "unrest 1, counters still 3")
	e.end_turn()
	e.end_turn()
	check(e.anarchy() != -1, "still rules on its 3rd turn")
	e.end_turn()
	eq([e.turn, e.anarchy()], [4, -1], "ends at the end of its 3rd turn")


func test_more_unrest_doesnt_lengthen_anarchy_and_choosing_sets_it_to_0() -> void:
	var e := fallen_engine()
	e.set_unrest(12)
	eq(e.resources.unrest, 12, "no government, no limit to cap it")
	e.end_turn()
	e.end_turn()
	e.end_turn()
	eq([e.turn, e.anarchy(), e.pending().get("kind")], [4, -1, GameEngine.PENDING_GOVERNMENT], "ends after its 3rd turn")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq(e.resources.unrest, 0, "unrest 0")
