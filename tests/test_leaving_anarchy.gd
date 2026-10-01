extends "res://tests/lib/anarchy_case.gd"
## Leaving Anarchy (backlog 146): a government is accepted during Anarchy only at unrest of at most half its limit
## (the unrest_limit modifier added before halving); restore_order() pays config unrest.relief and the fallback
## government rules, with unrest at most half its limit. The Restore order button sits beside Relieve famine; the bot
## pays after 2 counters. Fixtures: tests/lib/anarchy_case.gd (relief 6 wealth).


## A game in Anarchy (fallen_engine) with unrest and wealth set.
func anarchy_with(unrest: int, wealth := 10, block := {}) -> GameEngine:
	var e := fallen_engine(block)
	e.resources["unrest"] = unrest
	e.resources["wealth"] = wealth
	return e


# --- AC1: a government the people accept ---

func test_a_government_is_refused_above_half_its_limit() -> void:
	var e := anarchy_with(4)
	var kings := put_in_hand(e, "kings")
	eq(e.play_error(kings), "The people won't accept Kings until unrest is 3 or less.", "7 / 2 = 3")
	check(not e.play_card(kings), "play_card refuses")
	eq(ruling(e), "anarchy", "Anarchy still rules")


func test_the_unrest_limit_modifier_counts_before_halving() -> void:
	var e := anarchy_with(4)
	build_on(e, home_uid(e), ["altar"])
	eq(e.play_error(put_in_hand(e, "kings")), "", "(7 + 1) / 2 = 4")


func test_a_government_at_half_its_limit_ends_anarchy() -> void:
	var e := anarchy_with(3)
	var anarchy: int = e.anarchy()
	var kings := put_in_hand(e, "kings")
	check(e.play_card(kings), "Kings at 3: %s" % e.play_error(kings))
	eq(ruling(e), "kings", "Kings rules")
	check(e.zone("removed").find(anarchy) != null, "the Anarchy card is removed")
	eq(e.resources.get("unrest"), 3, "unrest stays 3")


func test_outside_anarchy_a_government_has_no_unrest_condition() -> void:
	var e := anarchy_engine()
	e.resources["unrest"] = 5
	var kings := put_in_hand(e, "kings")
	check(e.play_card(kings), "Kings at 5 outside Anarchy: %s" % e.play_error(kings))
	eq(ruling(e), "kings", "Kings rules")


# --- AC2: paying to restore order ---

func test_restore_order_pays_and_the_fallback_rules() -> void:
	var e := anarchy_with(5, 6)
	var recorded := record_messages(e)
	var anarchy: int = e.anarchy()
	eq(e.order_relief(), {"wealth": 6}, "order_relief")
	check(e.restore_order(), "restore_order: %s" % e.restore_order_error())
	eq(e.resources.get("wealth"), 0, "6 − 6")
	eq(ruling(e), "chiefs", "the fallback rules")
	check(e.zone("removed").find(anarchy) != null, "the Anarchy card is removed")
	eq(e.resources.get("unrest"), 2, "min(5, 5 / 2)")
	check_noticed(recorded, "Order restored")


func test_order_relief_is_empty_without_relief() -> void:
	var e := anarchy_engine({"relief": null})
	eq(e.order_relief(), {}, "no relief configured")


func test_unrest_relief_validation() -> void:
	var with_relief := func(relief: Variant) -> Dictionary: return anarchy_raw({"relief": relief})
	check_cases([
		["not an object", with_relief.call(6), "config.json: unrest.relief"],
		["empty", with_relief.call({}), "config.json: unrest.relief"],
		["unknown resource", with_relief.call({"gold": 6}), "config.json: unrest.relief: unknown resource 'gold'"],
		["0", with_relief.call({"wealth": 0}), "config.json: unrest.relief: 'wealth' must be an integer >= 1"],
		["unrest", with_relief.call({"unrest": 1}), "config.json: unrest.relief: unrest can't be paid"],
	], config_errors)


# --- AC3: restore_order_error ---

func test_restore_order_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	eq(anarchy_engine().restore_order_error(), "There is no anarchy.", "outside Anarchy")
	var short := anarchy_with(5, 5)
	eq(short.restore_order_error(), "Restoring order needs 6 wealth (you have 5).", "short")
	check(not short.restore_order(), "restore_order refuses")
	eq([short.resources.get("wealth"), ruling(short), short.resources.get("unrest")], [5, "anarchy", 5], "unchanged")
	var over := anarchy_with(5)
	over.is_over = true
	eq(over.restore_order_error(), "The game is over.", "game over")
	var none := anarchy_with(5, 10, {"relief": null})
	eq(none.restore_order_error(), "Order can't be bought.", "no relief configured")
	eq(anarchy_with(5, 6).restore_order_error(), "", "can pay")


func test_restore_order_waits_for_a_pending_discard() -> void:
	var e := anarchy_with(5)
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "farm")
	e.end_turn()  # the hand is over its limit: a discard is owed
	eq(e.restore_order_error(), "Discard down to %d cards first." % e.config.hand_limit, "pending discard")


# --- AC4: the Restore order button ---

func test_the_restore_order_button_shows_in_anarchy_beside_relieve_famine() -> void:
	await with_main(anarchy_engine(), func(main: Node):
		var e := Game.engine
		var restore: Button = main.restore_order_button()
		await wait_frames()
		check(not restore.is_visible_in_tree(), "hidden outside Anarchy")
		e.resources["unrest"] = 5
		e.resources["wealth"] = 6
		e.end_turn()
		await wait_frames()
		check(restore.is_visible_in_tree(), "shown in Anarchy")
		eq(restore.text, "Restore order (6 wealth)", "text")
		check(not restore.disabled, "enabled when it can pay")
		eq(restore.get_parent(), main.relieve_button().get_parent(), "beside Relieve famine")
		e.resources["wealth"] = 5
		e.changed.emit()
		await wait_frames()
		check(restore.disabled, "disabled when short")
		eq(restore.tooltip_text, "Restoring order needs 6 wealth (you have 5).", "the reason in the tooltip"))


func test_the_restore_order_button_hides_without_relief() -> void:
	await with_main(anarchy_engine({"relief": null}), func(main: Node):
		var e := Game.engine
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		check(e.anarchy() != -1, "in Anarchy")
		check(not main.restore_order_button().is_visible_in_tree(), "no relief, no button"))


# --- AC5: the bot pays after 2 counters ---

func test_the_bot_restores_order_after_2_counters() -> void:
	var one := anarchy_with(5, 10)
	one.zone("government").cards[0].counters = 1
	ScriptedBot.take_turn(one, "baseline")
	eq(ruling(one), "anarchy", "1 counter: the bot waits")
	var two := anarchy_with(5, 10)
	two.zone("government").cards[0].counters = 2
	ScriptedBot.take_turn(two, "baseline")
	eq(ruling(two), "chiefs", "2 counters: the bot pays")
	eq(two.resources.get("wealth"), 4, "10 − 6")
