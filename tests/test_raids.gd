extends "res://tests/lib/raid_case.gd"
## Barbarian raids (backlog 162): an event with `raid` {strength, targets, pop} is announced when drawn, aimed at the
## weakest settled territory it may hit, and strikes two event phases later (257): repelled when the target's defence is
## at least its strength (its `repel` effects), else pillaged (its `pillage` effects, pop and the units stationed
## there lost). `raid_target`, `raid_forecast` and `raid_resolved`.


# --- AC1: loading ---

func test_raid_loads_on_an_event() -> void:
	var r := raid_load()
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if not r.cards.has("raiders"):
		return
	var raiders: CardDef = r.cards.raiders
	eq(raiders.raid.strength, 3, "strength")
	eq(raiders.raid.targets, ["mountain"] as Array[String], "targets")
	eq(raiders.raid.pop, 1, "pop defaults to 1")
	eq(r.cards.horde.raid.targets, [] as Array[String], "no targets")
	eq(r.cards.omen.raid, {}, "a plain event has no raid")


func test_bad_raid_is_a_load_error() -> void:
	check_cases([
		["no strength", raid_with({"raid": {"pop": 1}}), ["card 'x'", "raid", "strength"], "one_error"],
		["strength 0", raid_with({"raid": {"strength": 0}}), ["card 'x'", "raid", "strength"], "one_error"],
		["strength not an int", raid_with({"raid": {"strength": "3"}}), ["card 'x'", "raid", "strength"], "one_error"],
		["pop below 0", raid_with({"raid": {"strength": 2, "pop": -1}}), ["card 'x'", "raid", "pop"], "one_error"],
		["unknown target", raid_with({"raid": {"strength": 2, "targets": ["swamp"]}}), ["card 'x'", "raid", "swamp"], "one_error"],
		["targets not an array", raid_with({"raid": {"strength": 2, "targets": "mountain"}}), ["card 'x'", "raid", "targets"], "one_error"],
		["not an object", raid_with({"raid": 3}), ["card 'x'", "raid"], "one_error"],
		["with discard", raid_with({"discard": {"turns": 2}}), ["card 'x'", "raid", "discard"], "one_error"],
		["on a building", [{"id": "x", "name": "X", "type": "building", "raid": {"strength": 2}}],
			"card 'x': 'raid' only applies to events", "warning_only"],
	], raid_load)


func test_repel_and_pillage_effects_only_go_on_raids() -> void:
	var on_raid := func(effect: Dictionary) -> Array:
		return raid_with({"effects": [effect]})
	var gain_on := func(trigger: String) -> Dictionary:
		return {"op": "gain", "resource": "food", "amount": 1, "trigger": trigger}
	eq(raid_load(on_raid.call(gain_on.call("pillage"))).errors, [] as Array[String], "pillage gain on a raid")
	check_cases([
		["repel on a plain event", [{"id": "x", "name": "X", "type": "event", "effects": [gain_on.call("repel")]}],
			["card 'x'", "repel"], "one_error"],
		["pillage on a building", [{"id": "x", "name": "X", "type": "building", "effects": [gain_on.call("pillage")]}],
			["card 'x'", "pillage"], "one_error"],
		["a draw on repel", on_raid.call({"op": "draw", "amount": 1, "trigger": "repel"}), ["card 'x'", "draw", "repel"], "one_error"],
		["an explore on pillage", on_raid.call({"op": "explore", "trigger": "pillage"}), ["card 'x'", "explore", "pillage"]],
	], raid_load)


func test_raid_text() -> void:
	var db: Dictionary = raid_load().cards
	if not db.has("raiders"):
		check(false, "Raiders loaded")
		return
	var tip: String = db.raiders.rules_tooltip(db)
	for fragment in ["Raid 3", "mountain", "If repelled: +2 wealth", "If pillaged: −2 food"]:
		check(fragment in tip, "'%s' in: %s" % [fragment, tip])
	check("Lasts" not in tip, "a raid lasts until it strikes: %s" % tip)
	var face: String = db.raiders.rules_text(db)
	eq(face.split("\n")[0], "Raid 3 (mountain)", "the face's first line, which the board shows")
	eq(db.horde.rules_text(db).split("\n")[0], "Raid 1", "Horde's, with no targets")


# --- AC2: the announcement and its target ---

func test_a_drawn_raid_is_announced_at_the_weakest_matching_territory() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var insight: int = e.resources.insight
	e.end_turn()
	var raid := active_uid(e, "raiders")
	check(raid != -1, "Raiders active on turn 2")
	eq(e.resources.insight - insight, 1, "its play effects resolved")
	eq(e.raid_target(raid), hills_of(e), "the mountain")


func test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop() -> void:
	var e: GameEngine = raid_engine(["horde"])
	if e == null:
		return
	e.end_turn()
	eq(e.raid_target(active_uid(e, "horde")), home_uid(e), "Homeland: defence 0 like Hills, but 3 pop")


func test_a_raid_whose_targets_match_nothing_picks_among_all_territories() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var hills: CardInstance = e.zone("tableau").find(hills_of(e))
	e.zone("tableau").remove(hills)
	e.zone("territory_deck").add(hills)
	e.end_turn()
	eq(e.raid_target(active_uid(e, "raiders")), home_uid(e), "no mountain settled: Homeland")


func test_a_raid_avoids_stronger_land_and_breaks_full_ties_by_tableau_order() -> void:
	var e: GameEngine = raid_engine(["horde"])
	if e == null:
		return
	settle(e, ["grassland"])
	var grassland := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grassland).pop = 1
	build_on(e, home_uid(e), ["town"])
	e.end_turn()
	eq(e.raid_target(active_uid(e, "horde")), hills_of(e), "Hills before Grassland (both 0 defence, 1 pop)")


func test_raid_target_is_minus_1_for_anything_but_an_active_raid() -> void:
	var e: GameEngine = raid_engine(["omen", "raiders"])
	if e == null:
		return
	e.end_turn()
	for uid in [active_uid(e, "omen"), uid_of(e.zone("event_deck"), "raiders"), home_uid(e), 9999]:
		eq(e.raid_target(uid), -1, "raid_target(%d)" % uid)


# --- AC3: it strikes two event phases after it is drawn (257) ---

func test_a_raid_strikes_two_event_phases_after_it_is_drawn_then_is_discarded() -> void:
	var e: GameEngine = raid_engine(["raiders", "omen", "omen"])
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var target := e.raid_target(raid)
	eq(outcomes.size(), 0, "not on the turn it is drawn")
	e.end_turn()
	eq(outcomes.size(), 0, "not at the next event phase either")
	eq(active_uid(e, "raiders"), raid, "still active on turn 3")
	eq(e.raid_target(raid), target, "its target unchanged")
	var deck_size := e.zone("event_deck").size()
	e.end_turn()
	eq(outcomes.size(), 1, "struck once at the turn-4 event phase")
	eq(uid_of(e.zone("event_discard"), "raiders"), raid, "Raiders in the event discard")
	eq(active_uid(e, "raiders"), -1, "no longer active")
	eq(e.zone("event_deck").size(), deck_size - 1, "the turn-4 event drawn after it")
	check(active_uid(e, "omen") != -1, "an Omen active")
	if outcomes.is_empty():
		return
	var o: Dictionary = outcomes[0]
	for key in ["uid", "target", "strength", "defense", "repelled", "units_lost", "pop_lost", "gained", "lost", "vp"]:
		check(o.has(key), "outcome has %s: %s" % [key, o])
	eq(o.get("uid"), raid, "uid")
	eq(o.get("target"), hills_of(e), "target")
	eq(o.get("strength"), 3, "strength")


func test_the_target_stays_fixed_when_defence_changes_elsewhere() -> void:
	var e: GameEngine = raid_engine(["horde"])
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	recruit(e, home_uid(e))
	eq(e.raid_target(active_uid(e, "horde")), home_uid(e), "still Homeland, now stronger than Hills")
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq(outcomes[0].target, home_uid(e), "struck Homeland")
	eq(outcomes[0].defense, 2, "against the Levy")
	eq(outcomes[0].repelled, true, "repelled")


# --- AC4: repelled ---

func test_a_raid_meeting_enough_defence_is_repelled() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var hills := hills_of(e)
	build_on(e, hills, ["town"])
	recruit(e, hills)
	var levy := uid_of(e.zone("tableau"), "levy")
	var wealth: int = e.resources.wealth
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	eq(e.resources.wealth - wealth, 2, "+2 wealth")
	eq(e.resources.unrest, 0, "unrest 1 → 0")
	eq(e.zone("tableau").find(hills).pop, 1, "no pop lost")
	eq(e.unit_station(levy), hills, "the Levy stays")
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	var o: Dictionary = outcomes[0]
	eq([o.defense, o.repelled, o.pop_lost, o.units_lost], [3, true, 0, []], "defence, repelled, pop and units lost")
	eq(o.gained, {"wealth": 2}, "gained")
	eq(o.lost, {"unrest": 1}, "lost")


# --- AC5: pillaged ---

func test_a_raid_short_of_defence_pillages() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var hills := hills_of(e)
	recruit(e, hills)
	recruit(e, home_uid(e))
	var levies: Array[int] = []
	for c in e.zone("tableau").cards:
		if c.def.id == "levy":
			levies.append(c.uid)
	var guard: int = levies[0] if e.unit_station(levies[0]) == hills else levies[1]
	var other: int = levies[1] if guard == levies[0] else levies[0]
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	eq(e.resources.unrest, 2, "unrest 1 → 2")
	eq(e.zone("tableau").find(hills).pop, 0, "Hills loses 1 pop")
	check(e.zone("discard").find(guard) != null, "the Levy on Hills is in the discard")
	eq(e.unit_station(other), home_uid(e), "the Levy on Homeland is untouched")
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	var o: Dictionary = outcomes[0]
	eq([o.defense, o.repelled, o.pop_lost, o.units_lost], [2, false, 1, [guard]], "defence, repelled, pop and units lost")
	eq(o.lost, {"food": 2}, "lost")
	eq(o.gained, {"unrest": 1}, "gained")


func test_pillage_never_takes_pop_below_0() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.zone("tableau").find(hills_of(e)).pop = 0
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	eq(e.zone("tableau").find(hills_of(e)).pop, 0, "Hills' pop")
	eq(outcomes.size(), 1, "one raid resolved")
	if outcomes.size() == 1:
		eq(outcomes[0].pop_lost, 0, "pop_lost")


# --- 163 AC5: units moved to answer a raid ---

## The uid of the Levy in e's tableau, or -1.
func levy_in(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "levy")


func test_163_a_unit_moved_onto_the_target_defends_it() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var hills := hills_of(e)
	build_on(e, hills, ["town"])
	recruit(e, home_uid(e))
	var levy := levy_in(e)
	check(e.move_unit(levy, hills), "the Levy marches to Hills")
	eq(e.raid_target(active_uid(e, "raiders")), hills, "the target stays Hills")
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq([outcomes[0].target, outcomes[0].defense, outcomes[0].repelled], [hills, 3, true], "repelled at Hills by Town + Levy")
	eq(e.unit_station(levy), hills, "the Levy stays on Hills")


func test_163_a_unit_moved_off_the_target_doesnt_defend_it() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var hills := hills_of(e)
	build_on(e, hills, ["town"])
	recruit(e, hills)
	var levy := levy_in(e)
	check(e.move_unit(levy, home_uid(e)), "the Levy leaves Hills")
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq([outcomes[0].target, outcomes[0].defense, outcomes[0].repelled, outcomes[0].units_lost], [hills, 1, false, []],
		"pillaged against the Town alone")
	eq(e.unit_station(levy), home_uid(e), "the Levy is safe on Homeland")


func test_163_a_lost_garrison_goes_to_the_discard_whatever_its_home() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var home := home_uid(e)
	recruit(e, home)
	var levy := levy_in(e)
	check(e.move_unit(levy, hills_of(e)), "the Levy marches to Hills")
	var workers: int = e.free_workers(home)
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq([outcomes[0].repelled, outcomes[0].units_lost], [false, [levy]], "pillaged; the Levy lost")
	check(e.zone("discard").find(levy) != null, "the Levy is in the discard")
	eq(e.free_workers(home) - workers, 1, "its worker on Homeland is free again")


# --- AC6: the forecast ---

func test_raid_forecast_lists_announced_raids_with_live_defence() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	eq(e.raid_forecast(), [], "no raid on turn 1")
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.raid_forecast(), [{"uid": raid, "target": hills, "strength": 3, "defense": 0}], "announced")
	recruit(e, hills)
	eq(e.raid_forecast(), [{"uid": raid, "target": hills, "strength": 3, "defense": 2}], "a Levy on Hills")


# --- AC7: the end of the game and forks ---

func test_a_raid_strikes_in_the_final_turn_and_one_drawn_then_never_does() -> void:
	var e: GameEngine = raid_engine(["raiders", "omen"], {"raiders": 1, "horde": 1, "omen": 3}, {"turn_limit": 4})
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.end_turn()
	arrange(e.zone("event_deck"), ["horde"])
	e.end_turn()
	eq(outcomes.size(), 1, "Raiders struck as turn 4 began")
	check(active_uid(e, "horde") != -1, "Horde drawn in the final turn")
	e.end_turn()
	check(e.is_over, "game over")
	eq(outcomes.size(), 1, "Horde never struck")


func test_a_fork_keeps_each_raids_target() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var f: GameEngine = e.fork()
	eq(f.raid_target(raid), hills_of(e), "the fork's target")
	eq(f.raid_forecast(), e.raid_forecast(), "the fork's forecast")


# --- AC8 (added at green, for the Manual check): what the UI shows ---

func test_raid_line_tag_and_shortfall_for_the_ui() -> void:
	var e: GameEngine = raid_engine(["raiders", "omen"])
	if e == null:
		return
	var recorded := record_messages(e)
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.raid_line(raid), "Raiders will strike Hills in 2 turns: 3 against your 0.", "the line")
	check_noticed(recorded, "Raiders will strike Hills in 2 turns", GameEngine.NOTICE_CAUTION)
	eq(e.raid_tag(raid), "Hills 3 vs 0", "the board tag")
	check(e.raid_short(raid), "short while defence 0 < 3")
	eq(e.raid_warning(hills), "Raiders strike in 2 turns: 3 vs 0", "the target's mark")
	check("Raiders strike in 2 turns: 3 vs 0" in e.territory_tooltip(hills), e.territory_tooltip(hills))
	eq(e.raid_warning(home_uid(e)), "", "no mark on Homeland")
	build_on(e, hills, ["town"])
	recruit(e, hills)
	check(not e.raid_short(raid), "not short at 3 against 3")
	eq(e.raid_tag(raid), "Hills 3 vs 3", "live")
	var omen := uid_of(e.zone("event_deck"), "omen")
	for uid in [omen, hills, 9999]:
		eq([e.raid_line(uid), e.raid_tag(uid), e.raid_short(uid)], ["", "", false], "nothing for %d" % uid)


## 271 AC1: the strike's line is logged and returned by raid_outcome_text, but no longer a notice (the raid modal shows it).
func test_the_strike_line_says_what_it_cost_or_gave_and_is_logged_not_noticed() -> void:
	var e: Object = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	recruit(e, hills_of(e))
	var recorded := record_messages(e)
	e.end_turn()  # announced 2 turns ahead (257)
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	var line: String = e.raid_outcome_text(outcomes[0])
	check(line.begins_with("Raiders pillaged Hills: "), "pillaged line: %s" % line)
	for fragment in ["+1 unrest", "−2 food", "−1 pop", "1 unit lost"]:
		check(fragment in line, "'%s' in %s" % [fragment, line])
	check(recorded.has("log: " + line), "logged: %s" % [recorded])
	eq(notices_in(recorded).filter(func(m): return "pillaged" in m), [], "no notice")

	var r: Object = raid_engine()
	var repels := record_raids(r)
	r.end_turn()
	build_on(r, hills_of(r), ["town"])
	recruit(r, hills_of(r))
	var repelled := record_messages(r)
	r.end_turn()  # announced 2 turns ahead (257)
	r.end_turn()
	if repels.size() != 1:
		check(false, "one raid resolved: %s" % [repels])
		return
	eq(r.raid_outcome_text(repels[0]), "Raiders repelled at Hills: +2 wealth, −1 unrest.", "repelled line")
	check(repelled.has("log: Raiders repelled at Hills: +2 wealth, −1 unrest."), "logged: %s" % [repelled])
	eq(notices_in(repelled).filter(func(m): return "repelled" in m), [], "no notice")