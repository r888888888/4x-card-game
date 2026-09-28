extends "res://tests/lib/test_case.gd"
## GameEngine rules: setup, playing cards, turn loop, scoring, game end.


func test_new_game_setup() -> void:
	var e := make_engine({"farm": 10})
	eq(e.turn, 1, "turn")
	eq(e.zone("hand").size(), 5, "hand")
	eq(e.zone("deck").size(), 5, "deck")
	eq(e.resources.food, 4, "food (2 start + 2 capital upkeep)")
	eq(card_ids(e.zone("tableau")), ["homeland", "capital"], "tableau")
	eq(e.score(), 2, "score")


func test_same_seed_same_shuffle() -> void:
	var a := make_engine({"farm": 5, "scout": 5, "temple": 5}, {}, 42)
	var b := make_engine({"farm": 5, "scout": 5, "temple": 5}, {}, 42)
	eq(card_ids(a.zone("hand")) + card_ids(a.zone("deck")), card_ids(b.zone("hand")) + card_ids(b.zone("deck")))


func test_play_building_pays_and_produces() -> void:
	var e := make_engine({"farm": 10})
	check(e.play_card(first_in_hand(e)))
	eq(e.resources.food, 2, "food after paying 2")
	eq(card_ids(e.zone("tableau")), ["homeland", "capital", "farm"], "tableau")
	eq(e.zone("hand").size(), 4, "hand")
	e.end_turn()
	eq(e.turn, 2, "turn")
	eq(e.resources.food, 5, "food carries over + capital 2 + farm 1")


func test_cannot_afford() -> void:
	var e := make_engine({"farm": 10})
	e.resources.food = 1
	var uid := first_in_hand(e)
	check(e.play_error(uid) != "", "should report why")
	check(not e.play_card(uid), "play should fail")
	eq(e.zone("hand").size(), 5, "hand unchanged")
	eq(e.resources.food, 1, "food unchanged")


func test_action_draws_then_discards() -> void:
	var e := make_engine({"scout": 10})
	check(e.play_card(first_in_hand(e)))
	eq(e.zone("hand").size(), 6, "hand 5 - 1 + 2")
	eq(e.zone("discard").size(), 1, "discard")


func test_reshuffle_when_deck_runs_out() -> void:
	var e := make_engine({"farm": 6})
	e.end_turn()  # 5 discarded, 1 left in deck; draws 1 then reshuffles 5
	eq(e.zone("hand").size(), 5, "hand")
	eq(e.zone("deck").size(), 1, "deck")
	eq(e.zone("discard").size(), 0, "discard")


func test_create_card() -> void:
	var e := make_engine({"settler": 10})
	check(e.play_card(first_in_hand(e)))
	eq(card_ids(e.zone("tableau")), ["homeland", "capital", "city"], "tableau")
	eq(e.score(), 4, "score")


func test_gain_per_tag() -> void:
	var e := make_engine({"caravan": 10})
	check(e.play_card(first_in_hand(e)))
	eq(e.resources.food, 6, "4 + 2 per city (1 city)")


func test_upkeep_score() -> void:
	var e := make_engine({"temple": 10})
	check(e.play_card(first_in_hand(e)))
	eq(e.score(), 3, "capital 2 + temple 1")
	e.end_turn()
	eq(e.score(), 4, "+1 VP from temple upkeep")


func test_game_ends_at_turn_limit() -> void:
	var e := make_engine({"farm": 10}, {"turn_limit": 3})
	var final_scores := []
	e.game_over.connect(func(s): final_scores.append(s))
	e.end_turn()
	e.end_turn()
	check(not e.is_over, "not over on turn 3")
	e.end_turn()
	check(e.is_over, "over after turn 3")
	eq(e.turn, 3, "turn")
	eq(final_scores, [2], "game_over signal with final score")
	e.end_turn()
	eq(e.turn, 3, "end_turn is a no-op after game over")
	eq(e.zone("hand").size(), 0, "hand discarded")
