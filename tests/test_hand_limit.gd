extends "res://tests/lib/test_case.gd"
## Hand limit (backlog 024): unplayed cards stay in hand, draw up to hand_size, and ending the turn
## over hand_limit starts a pending discard (discard_needed / discard_card).


## An engine on turn 1 after playing n Scouts (each nets +1 card: play 1, draw 2). Hand is 5 + n.
func scout_engine(n: int, overrides := {}) -> GameEngine:
	var e := make_engine({"scout": 10}, overrides)
	for i in n:
		check(e.play_card(first_in_hand(e)), "play scout %d" % i)
	return e


func in_zone(e: GameEngine, zone_name: String, uid: int) -> bool:
	return e.zone(zone_name).find(uid) != null


# --- AC1: keep the hand ---

func test_unplayed_cards_stay_in_hand() -> void:
	var e := make_engine({"farm": 10})
	check(e.play_card(first_in_hand(e)), "play farm")
	e.end_turn()
	eq(e.turn, 2, "turn")
	eq(card_ids(e.zone("hand")), ["farm", "farm", "farm", "farm", "farm"], "4 kept + 1 drawn")
	eq(e.zone("discard").size(), 0, "nothing discarded")
	eq(e.zone("deck").size(), 4, "drew only 1")


# --- AC2: draw up to hand size ---

func test_no_draw_when_hand_is_above_hand_size() -> void:
	var e := scout_engine(1)  # hand 6, deck 3
	e.end_turn()
	eq(e.turn, 2, "turn")
	eq(e.zone("hand").size(), 6, "hand kept")
	eq(e.zone("deck").size(), 3, "no draw")


func test_empty_hand_draws_hand_size() -> void:
	var e := make_engine({"farm": 10})
	e.zone("hand").take_all()
	e.end_turn()
	eq(e.zone("hand").size(), 5, "drew 5")


# --- AC3: at or under the limit ---

func test_end_turn_at_the_limit_needs_no_discard() -> void:
	var e := scout_engine(2)  # hand 7
	e.end_turn()
	eq(e.discard_needed(), 0, "nothing to discard")
	eq(e.turn, 2, "turn advanced")
	eq(e.zone("hand").size(), 7, "hand kept")


# --- AC4: over the limit starts a discard ---

func test_end_turn_over_the_limit_waits_for_discard() -> void:
	var e := scout_engine(3)  # hand 8
	var changes := []
	e.changed.connect(func(): changes.append(true))
	e.end_turn()
	eq(e.turn, 1, "turn not advanced")
	eq(e.discard_needed(), 1, "1 to discard")
	eq(e.zone("hand").size(), 8, "hand untouched")
	check(changes.size() >= 1, "changed emitted")


# --- AC5: discarding finishes the turn ---

func test_discarding_down_to_the_limit_ends_the_turn() -> void:
	var e := scout_engine(3)
	e.end_turn()
	var uid := first_in_hand(e)
	check(e.discard_card(uid), "discard succeeds")
	check(in_zone(e, "discard", uid), "card is in the discard pile")
	eq(e.turn, 2, "turn ended by itself")
	eq(e.zone("hand").size(), 7, "hand at limit, no draw")
	eq(e.discard_needed(), 0, "nothing pending")


func test_discard_two_cards_takes_two_calls() -> void:
	var e := scout_engine(4)  # hand 9
	e.end_turn()
	eq(e.discard_needed(), 2, "2 to discard")
	check(e.discard_card(first_in_hand(e)), "first discard")
	eq(e.turn, 1, "still turn 1")
	eq(e.discard_needed(), 1, "1 left")
	check(e.discard_card(first_in_hand(e)), "second discard")
	eq(e.turn, 2, "turn ended")
	eq(e.zone("hand").size(), 7, "hand at limit")


# --- AC6: blocked while discarding ---

func test_play_is_blocked_while_discarding() -> void:
	var e := scout_engine(3)
	e.end_turn()
	var uid := first_in_hand(e)
	eq(e.play_error(uid), "Discard down to 7 cards first.", "play_error")
	check(not e.play_card(uid), "play fails")
	eq(e.zone("hand").size(), 8, "hand unchanged")
	eq(e.zone("tableau").size(), 2, "tableau unchanged")


func test_end_turn_again_does_nothing_while_discarding() -> void:
	var e := scout_engine(4)
	e.end_turn()
	e.end_turn()
	eq(e.turn, 1, "still turn 1")
	eq(e.discard_needed(), 2, "same count")
	eq(e.zone("hand").size(), 9, "hand unchanged")


# --- AC7: voluntary discard ---

func test_discard_without_pending_discards_one_card() -> void:
	var e := make_engine({"farm": 10})
	var uid := first_in_hand(e)
	check(e.discard_card(uid), "discard succeeds")
	check(in_zone(e, "discard", uid), "card is in the discard pile")
	eq(e.zone("hand").size(), 4, "hand")
	eq(e.turn, 1, "turn unchanged")
	eq(e.discard_needed(), 0, "nothing pending")
	eq(e.zone("deck").size(), 5, "nothing drawn")


func test_voluntary_discard_avoids_the_forced_discard() -> void:
	var e := scout_engine(3)  # hand 8
	check(e.discard_card(first_in_hand(e)), "discard 1")
	e.end_turn()
	eq(e.turn, 2, "turn advanced")
	eq(e.discard_needed(), 0, "nothing pending")
	eq(e.zone("hand").size(), 7, "hand at limit")


func test_discarding_the_whole_hand_redraws_next_turn() -> void:
	var e := make_engine({"farm": 10})
	for i in 5:
		check(e.discard_card(first_in_hand(e)), "discard %d" % i)
	eq(e.zone("hand").size(), 0, "hand empty")
	e.end_turn()
	eq(e.zone("hand").size(), 5, "drew 5")


# --- AC7b: bad discards ---

func test_discard_refused_while_a_choice_is_pending() -> void:
	var e := make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(first_in_hand(e)), "explore")
	check(e.pending().get("kind") == GameEngine.PENDING_EXPLORE, "choice pending")
	var uid := first_in_hand(e)
	check(not e.discard_card(uid), "refused")
	check(in_zone(e, "hand", uid), "still in hand")


func test_discard_refused_when_the_game_is_over() -> void:
	var e := make_engine({"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	check(not e.discard_card(-1), "refused")


func test_discard_refused_for_a_card_not_in_hand() -> void:
	var e := scout_engine(3)
	e.end_turn()
	var capital: int = e.zone("tableau").cards[1].uid
	check(not e.discard_card(capital), "capital refused")
	check(not e.discard_card(-1), "unknown uid refused")
	eq(e.discard_needed(), 1, "still pending")
	eq(e.zone("hand").size(), 8, "hand unchanged")
	eq(e.zone("tableau").size(), 2, "tableau unchanged")


func test_discard_refused_for_a_card_already_discarded() -> void:
	var e := scout_engine(4)
	e.end_turn()
	var uid := first_in_hand(e)
	check(e.discard_card(uid), "first discard")
	check(not e.discard_card(uid), "same uid again refused")
	eq(e.discard_needed(), 1, "1 left")


# --- AC8: last turn ---

func test_no_discard_on_the_last_turn() -> void:
	var e := scout_engine(3, {"turn_limit": 1})  # hand 8
	e.end_turn()
	eq(e.discard_needed(), 0, "no discard asked")
	check(e.is_over, "game over")


# --- AC9: config ---

func test_hand_limit_defaults_to_7() -> void:
	check_loads([
		["default", {}, {"config.hand_limit": 7}],
	], config_load)


func test_hand_limit_is_read_from_config() -> void:
	var e := make_engine({"scout": 10}, {"hand_limit": 6})
	eq(e.config.hand_limit, 6, "configured")
	check(e.play_card(first_in_hand(e)), "play scout")
	check(e.play_card(first_in_hand(e)), "play scout")  # hand 7
	e.end_turn()
	eq(e.discard_needed(), 1, "7 - 6")
	eq(e.play_error(first_in_hand(e)), "Discard down to 6 cards first.", "message uses the limit")


func test_hand_limit_validation() -> void:
	check_cases([
		["below hand_size", {"hand_limit": 4}, ["config.json", "hand_limit"]],
		["not an integer", {"hand_limit": "many"}, ["config.json", "hand_limit"]],
	], config_load)
