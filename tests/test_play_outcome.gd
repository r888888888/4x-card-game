extends "res://tests/lib/test_case.gd"
## GameEngine.card_played: the outcome reported for each card play (backlog 007).
## Food is 4 at the start of turn 1 (2 start + 2 Capital upkeep).


## Plays uid and returns the outcomes emitted by card_played.
func play_and_capture(e: GameEngine, uid: int) -> Array:
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	e.play_card(uid)
	return outcomes


func uids(cards: Array) -> Array[int]:
	var out: Array[int] = []
	for c in cards:
		out.append(c.uid)
	return out


func test_building_play_reports_tableau_and_cost() -> void:
	var e := make_engine({"farm": 10})
	var uid := first_in_hand(e)
	var events := []
	e.card_played.connect(func(o): events.append(["card_played", o]))
	e.changed.connect(func(): events.append(["changed"]))
	check(e.play_card(uid), "play should succeed")
	eq(events.size(), 2, "one card_played then one changed")
	eq(events[0][0], "card_played", "first signal")
	eq(events[1][0], "changed", "second signal")
	if events.size() != 2 or events[0][0] != "card_played":
		return
	var o: Dictionary = events[0][1]
	eq(o.uid, uid, "uid")
	eq(o.to_zone, "tableau", "to_zone")
	eq(o.paid, {"food": 2}, "paid")
	eq(o.gained, {}, "gained")
	eq(o.vp, 0, "vp")
	eq(Array(o.drawn), [], "drawn")
	eq(Array(o.created), [], "created")


func test_action_play_reports_discard_and_drawn_cards() -> void:
	var e := make_engine({"scout": 10})
	var deck := e.zone("deck").cards
	var expected: Array = [deck[deck.size() - 1].uid, deck[deck.size() - 2].uid]  # top first
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "card_played emitted once")
	if outcomes.size() != 1:
		return
	var o: Dictionary = outcomes[0]
	eq(o.to_zone, "discard", "to_zone")
	eq(o.paid, {}, "paid (Scout is free)")
	eq(Array(o.drawn), expected, "drawn = top 2 of deck, in draw order")
	eq(Array(o.drawn), Array(uids(e.zone("hand").cards.slice(-2))), "drawn are the last 2 in hand")


func test_gain_effect_reported_in_outcome() -> void:
	var e := make_engine({"caravan": 10})
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "card_played emitted once")
	if outcomes.size() != 1:
		return
	var o: Dictionary = outcomes[0]
	eq(o.paid, {}, "paid (Caravan is free)")
	eq(o.gained, {"food": 2}, "gained 2 per city x 1 city")
	eq(e.resources.food, 6, "food 4 + 2")


func test_zero_gain_reported_as_zero() -> void:
	var e := make_engine({"caravan": 10})
	e.zone("tableau").take_all()
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "card_played emitted once")
	if outcomes.size() != 1:
		return
	eq(outcomes[0].gained, {"food": 0}, "gained 2 per city x 0 cities")
	eq(e.resources.food, 4, "food unchanged")


func test_created_card_reported_in_outcome() -> void:
	var e := make_engine({"settler": 10})
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "card_played emitted once")
	if outcomes.size() != 1:
		return
	var o: Dictionary = outcomes[0]
	eq(o.paid, {"food": 3}, "paid")
	eq(o.to_zone, "discard", "to_zone")
	var tableau := e.zone("tableau").cards
	eq(card_ids(e.zone("tableau")), ["capital", "city"], "tableau")
	eq(Array(o.created), [tableau[1].uid], "created = the new City")


func test_score_effect_reported_in_outcome() -> void:
	var e := make_engine({"shrine": 10})
	eq(e.score(), 2, "score before (Capital)")
	var outcomes := play_and_capture(e, first_in_hand(e))
	eq(outcomes.size(), 1, "card_played emitted once")
	if outcomes.size() != 1:
		return
	eq(outcomes[0].vp, 1, "vp")
	eq(e.score(), 3, "score 2 + 1")


func test_failed_play_emits_no_outcome() -> void:
	var e := make_engine({"farm": 10})
	e.resources.food = 1
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	check(not e.play_card(first_in_hand(e)), "can't afford: play fails")
	eq(outcomes.size(), 0, "no card_played when unaffordable")


func test_play_after_game_over_emits_no_outcome() -> void:
	var e := make_engine({"farm": 10}, {"turn_limit": 1})
	var uid := first_in_hand(e)
	e.end_turn()
	check(e.is_over, "game over")
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	check(not e.play_card(uid), "play fails after game over")
	eq(outcomes.size(), 0, "no card_played after game over")
