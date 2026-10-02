extends "res://tests/lib/anarchy_case.gd"
## Revolution (backlogs 148, 155): with a government ruling and no Anarchy you may revolt at any time; Anarchy falls at
## the next turn's start, before upkeep, with counters by the unrest share of the fallen limit (test_anarchy_length.gd).
## The Revolt button sits below the Realm; the bot revolts to a better government when the Anarchy would last 1 turn.
## Fixtures: tests/lib/anarchy_case.gd (Chiefs, limit 5; Kings, limit 7; TEST_GOVS' Council, no limit).


## An anarchy game with unrest set and governments created into the government deck (154).
func revolt_engine(unrest := 2, governments := []) -> GameEngine:
	var e := anarchy_engine()
	for id in governments:
		e.create_card(id, "discard", null)
	e.resources["unrest"] = unrest
	return e


# --- AC4: revolting at any time ---

func test_revolting_needs_no_event_and_changes_nothing_this_turn() -> void:
	var e := revolt_engine()
	var recorded := record_messages(e)
	var actions: int = e.actions_left()
	eq(e.revolt_error(), "", "revolt_error with Chiefs ruling and no event")
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	eq([ruling(e), e.anarchy(), e.pending(), e.actions_left()], ["chiefs", -1, {}, actions],
		"Chiefs still rules, nothing owed, no action used")
	eq(card_ids(e.zone("governments")), [] as Array[String], "Chiefs hasn't fallen yet")
	check_noticed(recorded, "Anarchy")


func test_anarchy_falls_at_the_next_turns_start_before_upkeep() -> void:
	var e := revolt_engine()
	var home := home_uid(e)
	e.revolt()
	e.end_turn()
	eq(ruling(e), "anarchy", "Anarchy rules turn 2")
	check(uid_of(e.zone("governments"), "chiefs") != -1, "Chiefs went to the government deck")
	eq(e.pop(home), 5, "before upkeep: turn 2 has Anarchy's ⟳ −1 pop")


func test_revolt_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var twice := revolt_engine()
	twice.revolt()
	eq(twice.revolt_error(), "A revolution is already under way.", "after a revolt this turn")
	var before := twice.state.copy()
	check(not twice.revolt(), "revolt refuses")
	eq(state_diff(twice.state, before), "", "a refusal changes nothing")
	eq(fallen_engine().revolt_error(), "Anarchy already rules.", "during Anarchy")
	var over := revolt_engine()
	over.is_over = true
	eq(over.revolt_error(), "The game is over.", "game over")


func test_revolt_waits_for_a_pending_discard() -> void:
	var e := revolt_engine()
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()  # the hand is over its limit: a discard is owed
	eq(e.revolt_error(), "Discard down to %d cards first." % e.config.hand_limit, "pending discard")


func test_bug_155_no_revolt_without_a_government_to_overthrow() -> void:
	var e := anarchy_engine({}, {"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland"}})
	eq(ruling(e), "", "no government rules")
	eq(e.revolt_error(), "There is no government to overthrow.", "revolt_error")
	check(not e.revolt(), "revolt refuses")
	e.end_turn()
	eq([e.turn, e.anarchy(), e.pending()], [2, -1, {}], "no Anarchy, no government choice from an empty deck")


func test_without_an_unrest_block_there_is_no_revolution() -> void:
	var e := anarchy_engine({}, {"unrest": null})
	eq(e.revolt_error(), "Without unrest there is no revolution.", "revolt_error")
	check(not e.revolt(), "revolt refuses")
	eq(e.revolt_forecast(), 0, "nothing to forecast")


# --- The revolt field is gone (Design notes) ---

func test_an_events_revolt_field_is_unknown() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	DataLoader.parse_cards({"cards": TEST_CARDS.cards + [{"id": "reform", "name": "Reform", "type": "event",
		"revolt": true}]}, RESOURCES, "cards.json", errors, warnings, keywords())
	eq(errors, [] as Array[String], "errors")
	has_msg(warnings, "unknown field 'revolt'")


# --- AC7: the bot revolts ---

func test_revolt_forecast_is_the_counters_a_revolution_would_bring() -> void:
	var e: Object = revolt_engine(2)
	eq(e.revolt_forecast(), 2, "unrest 2 of Chiefs' 5")
	var with_altar := revolt_engine(3)
	build_on(with_altar, home_uid(with_altar), ["altar"])
	var altar: Object = with_altar
	eq(altar.revolt_forecast(), 2, "unrest 3 of 6")


func test_the_bot_revolts_to_a_better_government_when_anarchy_would_last_1_turn() -> void:
	var e := revolt_engine(1, ["kings"])
	ScriptedBot.take_turn(e, "baseline")
	eq(e.revolt_error(), "A revolution is already under way.", "Kings (limit 7) beats Chiefs (5): revolted")
	ScriptedBot.play(e, "baseline")
	check(e.is_over, "the game still plays to its end")


func test_the_bot_doesnt_revolt_otherwise() -> void:
	var restless := revolt_engine(3, ["kings"])
	ScriptedBot.take_turn(restless, "baseline")
	eq(restless.revolt_error(), "", "unrest 3: 3 counters, no revolt")
	var worse := revolt_engine(1, ["council"])
	ScriptedBot.take_turn(worse, "baseline")
	eq(worse.revolt_error(), "", "Council ranks below Chiefs: no revolt")
	var none := revolt_engine(1)
	ScriptedBot.take_turn(none, "baseline")
	eq(none.revolt_error(), "", "an empty government deck: no revolt")


# --- AC8: the Revolt button ---

func test_the_revolt_button_shows_while_you_may_revolt_and_forecasts_the_anarchy() -> void:
	await with_main(revolt_engine(2), func(main: Node):
		var e := Game.engine
		var revolt: Button = main.revolt_button()
		e.resources["unrest"] = 2  # start_game restarted the game
		e.changed.emit()
		await wait_frames()
		check(revolt.is_visible_in_tree(), "shown with Chiefs ruling and no event")
		check(revolt.tooltip_text.contains("next turn"), "Anarchy starts next turn: %s" % revolt.tooltip_text)
		check(revolt.tooltip_text.contains("about 2 turns"), "unrest 2 of 5: about 2 turns: %s" % revolt.tooltip_text)
		revolt.pressed.emit()
		await wait_frames()
		eq(e.revolt_error(), "A revolution is already under way.", "pressing it revolts")
		check(not revolt.is_visible_in_tree(), "hidden once a revolution is under way"))
