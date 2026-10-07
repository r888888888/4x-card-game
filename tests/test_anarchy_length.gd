extends "res://tests/lib/anarchy_case.gd"
## Anarchy's length (backlogs 155, 384): unrest is its clock. Anarchy falls with the unrest it has, carries no counters,
## and at the end of each of its turns unrest drops by 1 (never below 0); at the end of a turn where unrest is 0 it ends
## and the government choice is owed before the next turn starts. Calming shortens it. Fixtures:
## tests/lib/anarchy_case.gd (Chiefs, limit 5; Feast, an order card, −2 unrest).


# --- AC1: unrest is the clock ---

func test_anarchy_lasts_until_unrest_reaches_0_losing_1_each_turn() -> void:
	var e := fallen_engine()
	var anarchy := e.anarchy()
	e.set_unrest(3)
	eq(e.event_counters(anarchy), 0, "Anarchy carries no counters")
	e.end_turn()
	eq([e.turn, e.anarchy() != -1, e.resources.unrest], [3, true, 2], "turn 3: −1 unrest, Anarchy still rules")
	eq(e.event_counters(anarchy), 0, "still no counters")
	e.end_turn()
	eq([e.turn, e.anarchy() != -1, e.resources.unrest], [4, true, 1], "turn 4: 1 unrest")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.resources.unrest], [4, -1, 0], "the end of turn 4 brings unrest to 0: it ends")
	check(e.zone("removed").find(anarchy) != null, "the Anarchy card is removed")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed before turn 5")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e), e.resources.unrest], [5, "chiefs", 0], "turn 5 under Chiefs, unrest 0")


# --- AC2: calming shortens it; 0 is checked at the turn's end ---

func test_calming_shortens_anarchy_and_0_is_checked_at_the_turns_end() -> void:
	var e := fallen_engine()
	e.set_unrest(3)
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast: %s" % e.play_error(feast))
	eq([e.resources.unrest, e.anarchy() != -1], [1, true], "Feast calms to 1: Anarchy still rules this turn")
	var farm := put_in_hand(e, "farm")
	eq(e.play_error(farm), ONLY_ORDER, "a non-order card is still refused")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.resources.unrest], [2, -1, 0], "the turn's end: 1 − 1 = 0, Anarchy ends")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed")


func test_unrest_never_goes_below_0_at_an_anarchy_turns_end() -> void:
	var e := fallen_engine()
	e.set_unrest(0)
	e.end_turn()
	eq([e.anarchy(), e.resources.unrest], [-1, 0], "0 unrest: it ends, unrest stays 0")


# --- AC3: a natural fall and a revolution ---

func test_a_fall_at_the_limit_lasts_as_many_turns_as_its_unrest() -> void:
	var e := fallen_engine()
	eq([e.turn, e.resources.unrest], [2, 5], "fell at turn 2's start with Chiefs' 5")
	for left in [4, 3, 2, 1]:
		e.end_turn()
		eq([e.anarchy() != -1, e.resources.unrest], [true, left], "turn %d" % e.turn)
	e.end_turn()
	eq([e.turn, e.anarchy(), e.resources.unrest], [6, -1, 0], "the end of its 5th turn (turn 6) ends it")


func test_a_revolution_falls_with_the_unrest_it_had() -> void:
	var e := revolted_engine(2)
	eq([e.turn, e.anarchy() != -1, e.resources.unrest], [2, true, 2], "Anarchy falls at turn 2 with 2 unrest")
	e.end_turn()
	eq([e.turn, e.anarchy() != -1, e.resources.unrest], [3, true, 1], "its 2nd turn: 1 unrest")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.resources.unrest], [3, -1, 0], "the end of its 2nd turn ends it")


func test_a_1_turn_anarchy_and_the_next_upkeep_runs_under_the_chosen_government() -> void:
	var e := revolted_engine(1)
	var home := home_uid(e)
	eq([e.turn, e.anarchy() != -1], [2, true], "Anarchy rules turn 2 with 1 unrest")
	eq(e.pop(home), 5, "turn 2 had an Anarchy upkeep (⟳ −1 pop)")
	e.end_turn()
	eq([e.turn, e.anarchy()], [2, -1], "the end of turn 2 ends it, before turn 3 starts")
	eq(e.end_turn_error(), "Choose a government first.", "the turn can't end again")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e)], [3, "chiefs"], "choosing finishes the turn: turn 3 under Chiefs")
	eq(e.pop(home), 5, "turn 3's upkeep ran under Chiefs: no pop lost")


func test_anarchys_end_comes_after_the_hand_limit_discard() -> void:
	var e := revolted_engine(1)
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_DISCARD, "the discard comes first")
	eq([e.anarchy() != -1, e.resources.unrest], [true, 1], "Anarchy still rules while the discard is owed")
	e.discard_card(first_in_hand(e))
	eq([e.turn, e.anarchy(), e.resources.unrest, e.pending().get("kind")], [2, -1, 0, GameEngine.PENDING_GOVERNMENT],
		"then unrest drops to 0 and the choice is owed")
