extends "res://tests/lib/tech_case.gd"
## The changed signal (backlog 048): every successful action emits it exactly once, a refused one never.


## Calls action and returns how many times e emitted changed meanwhile.
func changes_during(e: Object, action: Callable) -> int:
	var count := [0]
	var on_changed := func(): count[0] += 1
	e.changed.connect(on_changed)
	action.call()
	e.changed.disconnect(on_changed)
	return count[0]


## Asserts that action returns ok and emits changed expected times.
func expect_changes(label: String, e: Object, action: Callable, ok: bool, expected: int) -> void:
	var result := [null]
	var n := changes_during(e, func(): result[0] = action.call())
	if result[0] != null:
		eq(result[0], ok, "%s: result" % label)
	eq(n, expected, "%s: changed emitted" % label)


## A game with the choice from an Explorer pending (hills and grassland revealed).
func explore_engine() -> Object:
	var e: Object = make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}})
	check(e.play_card(first_in_hand(e)), "play Explorer")
	return e


# --- AC3: finishing the forced discard ---

func test_bug_048_discarding_the_last_owed_card_emits_changed_once() -> void:
	var e: Object = make_engine({"scout": 10}, {"hand_limit": 5})
	check(e.play_card(first_in_hand(e)), "play Scout")  # hand 6
	e.end_turn()
	eq(e.discard_needed(), 1, "1 owed")
	expect_changes("discard_card", e, func(): return e.discard_card(first_in_hand(e)), true, 1)
	eq(e.turn, 2, "the discard ended the turn")


# --- AC4: once per successful action, none when refused ---

func test_bug_048_each_successful_action_emits_changed_once() -> void:
	var e: Object = make_engine({"farm": 10})
	expect_changes("play_card", e, func(): return e.play_card(first_in_hand(e)), true, 1)

	e = explore_engine()
	expect_changes("choose", e, func(): return e.choose(e.pending_choice.options[0]), true, 1)

	e = make_engine({"farm": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}})
	e.resources.food = 5
	expect_changes("grow", e, func(): return e.grow(home_uid(e)), true, 1)

	e = tech_engine(["pottery", "writing"], {"farm": 10}, {"supply": {"scout": {"price": 2, "count": 2}}})
	expect_changes("buy", e, func(): return e.buy("scout"), true, 1)

	e = research_engine()
	expect_changes("buy_tech", e, func(): return e.buy_tech(uid_of(e.zone("research_reveal"), "pottery")), true, 1)

	e = research_engine()
	expect_changes("decline_research", e, func(): return e.decline_research(), true, 1)

	e = make_engine({"farm": 10})
	expect_changes("voluntary discard_card", e, func(): return e.discard_card(first_in_hand(e)), true, 1)

	e = make_engine({"farm": 10})
	expect_changes("end_turn", e, func(): e.end_turn(), true, 1)

	e = make_engine({"scout": 10}, {"hand_limit": 5})
	check(e.play_card(first_in_hand(e)), "play Scout")  # hand 6
	expect_changes("end_turn starting a discard", e, func(): e.end_turn(), true, 1)

	e = make_engine({"farm": 10}, {"turn_limit": 1})
	expect_changes("end_turn ending the game", e, func(): e.end_turn(), true, 1)
	check(e.is_over, "the game is over")


func test_bug_048_refused_actions_emit_no_changed() -> void:
	var e: Object = make_engine({"farm": 10})
	expect_changes("play_card", e, func(): return e.play_card(-1), false, 0)
	expect_changes("choose", e, func(): return e.choose(-1), false, 0)
	expect_changes("grow", e, func(): return e.grow(-1), false, 0)
	expect_changes("discard_card", e, func(): return e.discard_card(-1), false, 0)

	e = tech_engine(["pottery", "writing"], {"farm": 10}, {"supply": {"scout": {"price": 2, "count": 2}}})
	expect_changes("buy", e, func(): return e.buy("farm"), false, 0)
	expect_changes("buy_tech", e, func(): return e.buy_tech(-1), false, 0)
	expect_changes("decline_research", e, func(): return e.decline_research(), false, 0)

	e = explore_engine()
	var turn: int = e.turn
	expect_changes("end_turn with a choice pending", e, func(): e.end_turn(), true, 0)
	eq(e.turn, turn, "turn unchanged")
