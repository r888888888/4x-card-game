extends "res://tests/lib/anarchy_case.gd"
## Anarchy's length (backlog 155): when Anarchy falls it gets ⌈max_counters × unrest ÷ L⌉ counters (1 to max_counters),
## L the fallen government's unrest_limit(); calming lowers the counters left for good; one comes off at the end of each
## Anarchy turn, and at 0 the government choice is owed before the next turn starts. Fixtures: tests/lib/anarchy_case.gd
## (Chiefs, limit 5; max_counters 4; Altar, limit +1).


# --- AC1: counters by the share of the fallen government's limit ---

func test_anarchy_gets_counters_by_its_share_of_the_fallen_limit() -> void:
	for row in [[5, 4], [2, 2], [1, 1], [0, 1]]:
		var e := revolted_engine(row[0])
		eq([ruling(e), e.anarchy_counters()], ["anarchy", row[1]], "Chiefs (limit 5), unrest %d" % row[0])
	eq(revolted_engine(3, ["altar"]).anarchy_counters(), 2, "Altar: limit 6, unrest 3: ⌈4 × 3 ÷ 6⌉")


func test_a_forced_anarchy_at_the_limit_gets_max_counters() -> void:
	eq(fallen_engine().anarchy_counters(), 4, "unrest 5 of Chiefs' 5")


# --- AC2: calming lowers the counters left, for good ---

func test_calming_lowers_the_counters_left_for_good() -> void:
	var e := fallen_engine()
	eq(e.anarchy_counters(), 4, "unrest 5: 4")
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast: %s" % e.play_error(feast))
	eq(e.anarchy_counters(), 3, "unrest 3: ⌈4 × 3 ÷ 5⌉")
	e.set_unrest(2)
	eq(e.anarchy_counters(), 2, "unrest 2: ⌈4 × 2 ÷ 5⌉")
	e.set_unrest(5)
	eq(e.anarchy_counters(), 2, "unrest back up to 5: still 2")
	e.set_unrest(0)
	eq(e.anarchy_counters(), 1, "unrest 0: never below 1 while Anarchy rules")


# --- AC3: a counter comes off at the end of each Anarchy turn ---

func test_a_counter_comes_off_at_the_end_of_each_anarchy_turn() -> void:
	var e := fallen_engine()
	for left in [3, 2, 1]:
		e.end_turn()
		eq([ruling(e), e.anarchy_counters()], ["anarchy", left], "turn %d" % e.turn)
	e.end_turn()
	eq(e.turn, 5, "the 4th Anarchy turn hasn't ended yet")
	eq(e.anarchy(), -1, "the last counter came off: no Anarchy")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed")


func test_a_1_counter_anarchy_lasts_one_turn_and_the_next_upkeep_runs_under_the_chosen_government() -> void:
	var e := revolted_engine(1)
	var home := home_uid(e)
	eq([e.turn, ruling(e), e.anarchy_counters()], [2, "anarchy", 1], "Anarchy rules turn 2 with 1 counter")
	eq(e.pop(home), 5, "turn 2 had an Anarchy upkeep (⟳ −1 pop)")
	e.end_turn()
	eq([e.turn, e.anarchy()], [2, -1], "the end of turn 2 ends it, before turn 3 starts")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed")
	eq(e.end_turn_error(), "Choose a government first.", "the turn can't end again")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e)], [3, "chiefs"], "choosing finishes the turn: turn 3 under Chiefs")
	eq(e.pop(home), 5, "turn 3's upkeep ran under Chiefs: no pop lost")


func test_the_counter_comes_off_after_the_hand_limit_discard() -> void:
	var e := revolted_engine(1)
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_DISCARD, "the discard comes first")
	eq(ruling(e), "anarchy", "Anarchy still rules while the discard is owed")
	e.discard_card(first_in_hand(e))
	eq([e.turn, e.anarchy(), e.pending().get("kind")], [2, -1, GameEngine.PENDING_GOVERNMENT],
		"then the counter comes off and the choice is owed")
