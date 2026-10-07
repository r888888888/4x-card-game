extends "res://tests/lib/anarchy_case.gd"
## Restoring order (backlogs 146, 155): from Anarchy's second turn restore_order() buys the rest of it off for
## c × (c + 1) wealth, c the counters left, and the government choice is owed at once (154). The Restore order button
## sits beside Relieve famine; the bot pays from the second turn with 2+ counters left or a starving upkeep ahead.
## Fixtures: tests/lib/anarchy_case.gd (Chiefs, limit 5; max_counters 4).


# --- AC5: the price ---

func test_order_relief_is_c_times_c_plus_1_wealth_for_the_counters_left() -> void:
	eq(anarchy_engine().order_relief(), {}, "no Anarchy")
	var e := fallen_engine()
	eq(e.order_relief(), {"wealth": 20}, "4 counters")
	for row in [[3, 12], [2, 6], [1, 2]]:
		e.set_unrest(row[0])  # calming lowers the counters left to row[0]
		eq(e.order_relief(), {"wealth": row[1]}, "%d counters" % row[0])


func test_retired_unrest_fields_are_load_warnings() -> void:
	check_cases([
		["relief is no longer read", anarchy_raw({"relief": {"wealth": 6}}), "config.json: unrest: unknown field 'relief'",
			"warning_only"],
	], raw_config_load)


# --- AC5: restore_order_error ---

func test_restore_order_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	eq(anarchy_engine().restore_order_error(), "There is no anarchy.", "outside Anarchy")
	var first := fallen_engine()
	first.resources["wealth"] = 30
	eq(first.restore_order_error(), "Order can't be restored on Anarchy's first turn.", "the turn it fell")
	check(not first.restore_order(), "refuses on the first turn")
	var short := second_turn_engine(5, 11)
	eq(short.restore_order_error(), "Restoring order needs 12 wealth (you have 11).", "3 counters left: 12")
	var before := short.state.copy()
	check(not short.restore_order(), "restore_order refuses")
	eq(state_diff(short.state, before), "", "a refusal changes nothing")
	var over := second_turn_engine(5)
	over.is_over = true
	eq(over.restore_order_error(), "The game is over.", "game over")
	eq(second_turn_engine(5, 12).restore_order_error(), "", "can pay")


func test_restore_order_waits_for_a_pending_discard() -> void:
	var e := second_turn_engine(5)
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()  # the hand is over its limit: a discard is owed
	eq(e.restore_order_error(), "Discard down to %d cards first." % e.config.hand_limit, "pending discard")


# --- AC5: restoring ---

func test_restore_order_pays_and_the_government_choice_is_owed_at_once() -> void:
	var e := second_turn_engine(5, 12)
	var recorded := record_messages(e)
	var anarchy: int = e.anarchy()
	check(e.restore_order(), "restore_order: %s" % e.restore_order_error())
	eq(e.resources.get("wealth"), 0, "12 − 12")
	check(e.zone("removed").find(anarchy) != null, "the Anarchy card is removed")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "the government choice is owed (154)")
	check_noticed(recorded, "Order restored", GameEngine.NOTICE_INFO)
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq([e.turn, ruling(e)], [3, "chiefs"], "Chiefs rules and the turn goes on")
	eq(e.resources.get("unrest"), 2, "min(5, 5 / 2)")


func test_a_government_chosen_mid_turn_counts_its_actions_at_once() -> void:
	var e := second_turn_engine(5, 12)
	e.create_card("court", "discard", null)  # into the government deck (154)
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast uses Anarchy's 1 action: %s" % e.play_error(feast))
	check(e.restore_order(), "restore_order: %s" % e.restore_order_error())
	check(e.choose_government(uid_of(e.zone("governments"), "court")), "choose Court")
	eq([e.actions_per_turn(), e.actions_left()], [3, 2], "Court's 3, 1 used (127 AC6)")


# --- AC5: the Restore order button ---

func test_the_restore_order_button_shows_in_anarchy_beside_relieve_famine() -> void:
	await with_main(anarchy_engine(), func(main: Node):
		var e := Game.engine
		var restore: Button = MainProbe.restore_order_button(main)
		await wait_frames()
		check(not restore.is_visible_in_tree(), "hidden outside Anarchy")
		e.resources["unrest"] = 5
		e.end_turn()
		e.resources["wealth"] = 30
		e.changed.emit()
		await wait_frames()
		check(restore.is_visible_in_tree(), "shown in Anarchy")
		check(restore.disabled, "disabled on its first turn")
		eq(restore.tooltip_text, "Order can't be restored on Anarchy's first turn.", "the reason in the tooltip")
		eq(restore.get_parent(), MainProbe.relieve_button(main).get_parent(), "beside Relieve famine")
		e.end_turn()
		await wait_frames()
		eq(restore.text, "Restore order (12 wealth)", "3 counters left: 12")
		check(not restore.disabled, "enabled when it can pay")
		e.resources["wealth"] = 5
		e.changed.emit()
		await wait_frames()
		check(restore.disabled, "disabled when short")
		eq(restore.tooltip_text, "Restoring order needs 12 wealth (you have 5).", "the reason in the tooltip"))


# --- AC7: the bot restores order ---
