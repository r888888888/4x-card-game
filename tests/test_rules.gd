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


## Discards 3 hand cards (hand 2, discard 3, deck 1) and returns their uids.
func _discard_three(e: GameEngine) -> Array[int]:
	var discarded: Array[int] = []
	for i in 3:
		var uid := first_in_hand(e)
		check(e.discard_card(uid), "discard %d" % uid)
		discarded.append(uid)
	return discarded


func _uids(zone: Zone) -> Array[int]:
	var result: Array[int] = []
	for card in zone.cards:
		result.append(card.uid)
	return result


func test_bug_040_turn_end_draw_reshuffles_discard_into_deck() -> void:
	var e := make_engine({"farm": 6})
	var discarded := _discard_three(e)
	eq(e.zone("discard").size(), 3, "discard before end_turn")
	e.end_turn()  # draws the 1 deck card, reshuffles the 3 discarded, draws 2 of them
	eq(e.zone("hand").size(), 5, "hand")
	eq(e.zone("deck").size(), 1, "deck")
	eq(e.zone("discard").size(), 0, "discard")
	var hand_and_deck := _uids(e.zone("hand")) + _uids(e.zone("deck"))
	for uid in discarded:
		check(uid in hand_and_deck, "discarded %d back in hand or deck" % uid)


func test_bug_040_reshuffle_is_reproducible_with_a_seed() -> void:
	var a := make_engine({"farm": 6}, {}, 42)
	var b := make_engine({"farm": 6}, {}, 42)
	_discard_three(a)
	_discard_three(b)
	a.end_turn()
	b.end_turn()
	eq(_uids(a.zone("hand")), _uids(b.zone("hand")), "hands")
	eq(_uids(a.zone("deck")), _uids(b.zone("deck")), "decks")


func test_bug_040_draw_with_empty_deck_and_discard_draws_nothing() -> void:
	var e := make_engine({"scout": 5}, {}, 1)
	var outcomes: Array = []
	e.card_played.connect(func(o): outcomes.append(o))
	var scout := first_in_hand(e)
	check(e.play_card(scout), "play Scout")
	eq(e.zone("hand").size(), 4, "hand")
	eq(e.zone("deck").size(), 0, "deck")
	eq(_uids(e.zone("discard")), [scout], "discard holds only the Scout")
	eq(outcomes.size(), 1, "one outcome")
	eq(outcomes[0].drawn, [], "drawn")


func test_create_card() -> void:
	var e := make_engine({"settler": 10})
	check(e.play_card(first_in_hand(e)))
	eq(card_ids(e.zone("tableau")), ["homeland", "capital", "city"], "tableau")
	eq(e.score(), 4, "score")


func test_create_card_without_a_source_puts_a_new_copy_in_the_zone() -> void:
	var e := make_engine({"farm": 10})
	var before := e.zone("hand").size()
	var card: CardInstance = e.create_card("scout", "hand", null)
	eq(e.zone("hand").size(), before + 1, "hand")
	eq(e.zone("hand").cards.back(), card, "the new copy is in the hand")
	eq(card.def.id, "scout", "card id")
	check(e.log_lines.back().contains("Created Scout."), "logged without a source: %s" % e.log_lines.back())


func test_bug_048_create_puts_the_card_in_each_allowed_zone() -> void:
	for zone_name in ["tableau", "hand", "discard", "deck"]:
		var maker := {"id": "maker", "name": "Maker", "type": "action",
			"effects": [{"op": "create", "card": "scout", "zone": zone_name}]}
		var errors: Array[String] = []
		var warnings: Array[String] = []
		var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + [maker]}, resources(), "test", errors, warnings, keywords())
		var config := DataLoader.parse_config(raw_config({"maker": 10}), resources(), cards, "test", errors, warnings)
		eq(errors, [] as Array[String], "%s: errors" % zone_name)
		var e := GameEngine.new(cards, config)
		e.new_game(1)
		var before := card_ids(e.zone(zone_name)).count("scout")
		check(e.play_card(first_in_hand(e)), "%s: play Maker" % zone_name)
		eq(card_ids(e.zone(zone_name)).count("scout"), before + 1, "%s: a new Scout" % zone_name)


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


## Backlog 066: the same rule at the real game's length.
func test_a_100_turn_game_ends_after_turn_100_with_no_forecast_on_it() -> void:
	var e := make_engine({"scout": 10}, {"turn_limit": 100})
	for i in 99:
		e.end_turn()
	eq(e.turn, 100, "turn 100")
	check(not e.is_over, "not over during turn 100")
	eq(e.upkeep_forecast(), {}, "no next upkeep on turn 100")
	e.end_turn()
	check(e.is_over, "over after turn 100's end_turn")
	eq(e.turn, 100, "still turn 100")


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
