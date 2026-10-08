extends "res://tests/lib/raid_case.gd"
## Barbarian raids (backlog 162): an event with `raid` {strength, targets, pop} is announced when drawn, aimed at the
## weakest settled territory it may hit (discarded unseen when there is none, 372, 416), and strikes two event phases later (257):
## repelled when the target's defence is at least its strength (its `repel` effects), else pillaged (its `pillage` effects, pop and the units stationed
## there lost). `raid_target`, `raid_forecast` and `raid_resolved`.
## In detail (from docs/testing.md, 331): Barbarian raids (162): loading `raid` and the `repel` / `pillage` triggers,
## the raid's text, its target when drawn (`raid_target`), striking two event phases later (`raid_resolved`, 257),
## repelled and pillaged, `raid_forecast`, the final turn and forks, the strike's line (`raid_outcome_text`, logged not
## noticed, 271); raids that grow with the food and wealth held (`raid_strength`) and plunder them (374), a share
## that grows with the era (`raid_plunder_pct`, 377)


# --- AC1: loading ---

func test_raid_loads_on_an_event() -> void:
	check_loads([
		["Raiders, Horde (no targets) and a plain event", [], {
			"cards.raiders.raid.strength": 3,
			"cards.raiders.raid.targets": ["mountain"] as Array[String],
			"cards.raiders.raid.pop": 1,
			"cards.horde.raid.targets": [] as Array[String],
			"cards.omen.raid": {},
		}],
	], raid_load)


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
	eq(e.military.raid_target(raid), hills_of(e), "the mountain")


func test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop() -> void:
	var e: GameEngine = raid_engine(["horde"])
	if e == null:
		return
	e.end_turn()
	eq(e.military.raid_target(active_uid(e, "horde")), home_uid(e), "Homeland: defence 0 like Hills, but 3 pop")


func test_bug_372_a_raid_whose_targets_match_nothing_fizzles_into_the_discard() -> void:
	var e := fixture_no_mountain()
	if e == null:
		return
	var raid := uid_of(e.zone("event_deck"), "raiders")
	var insight: int = e.resources.insight
	var recorded := record_messages(e)
	e.end_turn()
	eq(active_uid(e, "raiders"), -1, "not active")
	check(e.zone("event_discard").find(raid) != null, "in the event discard")
	eq(e.military.raid_target(raid), -1, "no target")
	eq(e.military.raid_forecast(), [] as Array[Dictionary], "nothing forecast")
	eq(notices_in(recorded).filter(func(m): return "Raiders" in m), [] as Array[String], "no announcement")
	eq(e.resources.insight, insight, "its play effects don't resolve")


func test_bug_372_a_fizzled_raid_never_strikes_or_starts_the_raid_gap() -> void:
	var e := fixture_no_mountain()
	if e == null:
		return
	var outcomes := record_raids(e)
	var home: CardInstance = e.zone("tableau").find(home_uid(e))
	var pop := home.pop
	for i in 4:
		e.end_turn()
	eq(outcomes, [] as Array[Dictionary], "no raid_resolved")
	eq(home.pop, pop, "Homeland keeps its pop")
	eq(e.state.last_raid_turn, 0, "no raid gap started")


## 416 replaced 372's rule that a raid with no target was still the turn's event.
func test_a_raid_whose_targets_match_nothing_is_discarded_unseen_and_the_next_event_drawn() -> void:
	var e := fixture_no_mountain()
	if e == null:
		return
	var raid := uid_of(e.zone("event_deck"), "raiders")
	var omen := e.zone("event_deck").cards[-2].uid
	var seen: Array[Dictionary] = []
	e.event_drawn.connect(func(o: Dictionary): seen.append(o))
	e.end_turn()
	eq(seen.map(func(o): return o.uid), [omen], "event_drawn once, for the Omen under Raiders")
	eq(active_uid(e, "omen"), omen, "the Omen is the turn's event")
	check(e.zone("event_discard").find(raid) != null, "Raiders in the event discard")
	eq(e.military.raid_target(raid), -1, "no target")
	eq(e.state.last_raid_turn, 0, "no raid gap started")


func test_a_raid_avoids_stronger_land_and_breaks_full_ties_by_tableau_order() -> void:
	var e: GameEngine = raid_engine(["horde"])
	if e == null:
		return
	settle(e, ["grassland"])
	var grassland := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grassland).pop = 1
	build_on(e, home_uid(e), ["town"])
	e.end_turn()
	eq(e.military.raid_target(active_uid(e, "horde")), hills_of(e), "Hills before Grassland (both 0 defence, 1 pop)")


func test_raid_target_is_minus_1_for_anything_but_an_active_raid() -> void:
	var e: GameEngine = raid_engine(["omen", "raiders"])
	if e == null:
		return
	e.end_turn()
	for uid in [active_uid(e, "omen"), uid_of(e.zone("event_deck"), "raiders"), home_uid(e), 9999]:
		eq(e.military.raid_target(uid), -1, "raid_target(%d)" % uid)


# --- AC3: it strikes two event phases after it is drawn (257) ---

func test_a_raid_strikes_two_event_phases_after_it_is_drawn_then_is_discarded() -> void:
	var e: GameEngine = raid_engine(["raiders", "omen", "omen"])
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var target := e.military.raid_target(raid)
	eq(outcomes.size(), 0, "not on the turn it is drawn")
	e.end_turn()
	eq(outcomes.size(), 0, "not at the next event phase either")
	eq(active_uid(e, "raiders"), raid, "still active on turn 3")
	eq(e.military.raid_target(raid), target, "its target unchanged")
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
	eq(e.military.raid_target(active_uid(e, "horde")), home_uid(e), "still Homeland, now stronger than Hills")
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
	check(e.military.move(levy, hills), "the Levy marches to Hills")
	eq(e.military.raid_target(active_uid(e, "raiders")), hills, "the target stays Hills")
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
	check(e.military.move(levy, home_uid(e)), "the Levy leaves Hills")
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
	check(e.military.move(levy, hills_of(e)), "the Levy marches to Hills")
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
	eq(e.military.raid_forecast(), [], "no raid on turn 1")
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.military.raid_forecast(), [{"uid": raid, "target": hills, "strength": 3, "defense": 0}], "announced")
	recruit(e, hills)
	eq(e.military.raid_forecast(), [{"uid": raid, "target": hills, "strength": 3, "defense": 2}], "a Levy on Hills")


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
	eq(f.military.raid_target(raid), hills_of(e), "the fork's target")
	eq(f.military.raid_forecast(), e.military.raid_forecast(), "the fork's forecast")


# --- AC8 (added at green, for the Manual check): what the UI shows ---

func test_raid_line_tag_and_shortfall_for_the_ui() -> void:
	var e: GameEngine = raid_engine(["raiders", "omen"])
	if e == null:
		return
	var recorded := record_messages(e)
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.military.raid_line(raid), "Raiders will strike Hills in 2 turns: 3 against your 0.", "the line")
	check_noticed(recorded, "Raiders will strike Hills in 2 turns", GameEngine.NOTICE_CAUTION)
	eq(e.military.raid_tag(raid), "Hills 3 vs 0", "the board tag")
	check(e.military.raid_short(raid), "short while defence 0 < 3")
	eq(e.military.raid_warning(hills), "Raiders strike in 2 turns: 3 vs 0", "the target's mark")
	check("Raiders strike in 2 turns: 3 vs 0" in e.territory_tooltip(hills), e.territory_tooltip(hills))
	eq(e.military.raid_warning(home_uid(e)), "", "no mark on Homeland")
	build_on(e, hills, ["town"])
	recruit(e, hills)
	check(not e.military.raid_short(raid), "not short at 3 against 3")
	eq(e.military.raid_tag(raid), "Hills 3 vs 3", "live")
	var omen := uid_of(e.zone("event_deck"), "omen")
	for uid in [omen, hills, 9999]:
		eq([e.military.raid_line(uid), e.military.raid_tag(uid), e.military.raid_short(uid)], ["", "", false], "nothing for %d" % uid)


## 271 AC1: the strike's line is logged and returned by raid_outcome_text, but no longer a notice (the raid modal shows it).
func test_the_strike_line_says_what_it_cost_or_gave_and_is_logged_not_noticed() -> void:
	var e := raid_engine()
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
	var line: String = e.military.outcome_text(outcomes[0])
	check(line.begins_with("Raiders pillaged Hills: "), "pillaged line: %s" % line)
	for fragment in ["+1 unrest", "−2 food", "−1 pop", "1 unit lost"]:
		check(fragment in line, "'%s' in %s" % [fragment, line])
	check(recorded.has("log: " + line), "logged: %s" % [recorded])
	eq(notices_in(recorded).filter(func(m): return "pillaged" in m), [], "no notice")

	var r := raid_engine()
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
	eq(r.military.outcome_text(repels[0]), "Raiders repelled at Hills: +2 wealth, −1 unrest.", "repelled line")
	check(repelled.has("log: Raiders repelled at Hills: +2 wealth, −1 unrest."), "logged: %s" % [repelled])
	eq(notices_in(repelled).filter(func(m): return "repelled" in m), [], "no notice")

# --- 374: raids grow with the food and wealth held ---

## hoard_engine's config: +1 strength per 10 food and wealth held, 20% plunder.
const HOARD := {"raid_hoard_step": 10, "raid_plunder_pct": 20}


## A raid_engine game with Raiders (printed 3) on top and HOARD merged with overrides, its food and wealth set so that
## they are food and wealth when Raiders is drawn (after turn 2's upkeep). Still turn 1. null when the data doesn't load.
func hoard_engine(food: int, wealth: int, overrides := {}) -> GameEngine:
	var o := HOARD.duplicate()
	o.merge(overrides, true)
	var e := raid_engine(["raiders", "omen", "omen"], {"raiders": 1, "horde": 1, "omen": 3}, o)
	if e == null:
		return null
	hold_after_upkeep(e, food, wealth)
	return e


## Sets e's food and wealth so they are food and wealth after the next upkeep (upkeep_forecast).
func hold_after_upkeep(e: GameEngine, food: int, wealth: int) -> void:
	var forecast: Dictionary = e.upkeep_forecast()
	e.resources.food = food - forecast.food
	e.resources.wealth = wealth - forecast.wealth
	check(e.resources.food >= 0 and e.resources.wealth >= 0, "can hold %d food, %d wealth after upkeep" % [food, wealth])


## Recruits two Levies on Homeland and marches both to Hills: defence 4 there.
func garrison_two(e: GameEngine) -> void:
	for i in 2:
		recruit(e, home_uid(e))
	for c in e.zone("tableau").cards:
		if c.def.id == "levy":
			check(e.military.move(c.uid, hills_of(e)), "a Levy marches to Hills: %s" % e.military.move_error(c.uid, hills_of(e)))


func test_374_a_raid_drawn_gains_1_strength_per_raid_hoard_step_of_food_and_wealth_held() -> void:
	for row in [[13, 9, 5, "hoard 22"], [5, 4, 3, "hoard 9"], [6, 4, 4, "hoard 10"], [2, 0, 3, "hoard 2"]]:
		var e := hoard_engine(row[0], row[1])
		if e == null:
			return
		e.end_turn()
		eq([e.resources.food, e.resources.wealth], [row[0], row[1]], "%s: held when drawn" % row[3])
		var raid := active_uid(e, "raiders")
		eq(e.military.raid_strength(raid), row[2], "%s: raid_strength" % row[3])
		eq(e.military.raid_forecast().map(func(f): return f.strength), [row[2]], "%s: raid_forecast's strength" % row[3])


func test_374_raid_strength_is_0_for_anything_but_an_active_raid() -> void:
	var e := hoard_engine(13, 9)
	if e == null:
		return
	var queued := uid_of(e.zone("event_deck"), "omen")
	e.end_turn()
	for uid in [queued, home_uid(e), 9999]:
		eq(e.military.raid_strength(uid), 0, "raid_strength(%d)" % uid)


func test_374_the_strength_stays_as_announced_when_the_hoard_changes() -> void:
	for held in [0, 50]:
		var e := hoard_engine(9, 6)  # hoard 15: strength 4
		if e == null:
			return
		var outcomes := record_raids(e)
		e.end_turn()
		var raid := active_uid(e, "raiders")
		e.resources.food = held
		e.resources.wealth = held
		eq(e.military.raid_strength(raid), 4, "held %d: raid_strength" % held)
		eq(e.military.raid_forecast().map(func(f): return f.strength), [4], "held %d: raid_forecast" % held)
		e.end_turn()  # announced 2 turns ahead (257)
		e.end_turn()
		eq(outcomes.map(func(r): return r.strength), [4], "held %d: struck at 4" % held)


func test_374_the_strike_compares_defence_with_the_announced_strength() -> void:
	var short := hoard_engine(9, 6)  # strength 4
	if short == null:
		return
	var pillaged := record_raids(short)
	short.end_turn()
	build_on(short, hills_of(short), ["town"])
	recruit(short, hills_of(short))
	short.end_turn()
	short.end_turn()
	eq(pillaged.map(func(r): return [r.strength, r.defense, r.repelled]), [[4, 3, false]], "defence 3 is pillaged")

	var held := hoard_engine(9, 6)
	if held == null:
		return
	var repelled := record_raids(held)
	held.end_turn()
	garrison_two(held)
	held.end_turn()
	held.end_turn()
	eq(repelled.map(func(r): return [r.strength, r.defense, r.repelled]), [[4, 4, true]], "defence 4 repels it")


func test_374_raid_lines_show_the_announced_strength() -> void:
	var e := hoard_engine(13, 9)  # strength 5
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var hills := hills_of(e)
	eq(e.military.raid_line(raid), "Raiders will strike Hills in 2 turns: 5 against your 0.", "the line")
	eq(e.military.raid_tag(raid), "Hills 5 vs 0", "the board tag")
	eq(e.military.raid_warning(hills), "Raiders strike in 2 turns: 5 vs 0", "the target's mark")
	garrison_two(e)
	check(e.military.raid_short(raid), "short at 4 against 5")
	build_on(e, hills, ["town"])
	check(not e.military.raid_short(raid), "not short at 5 against 5")


func test_374_a_pillage_also_plunders_raid_plunder_pct_of_the_food_and_wealth_left() -> void:
	var e := hoard_engine(5, 0)
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.end_turn()
	hold_after_upkeep(e, 17, 7)
	e.end_turn()  # strikes Hills (defence 0): −2 food (17 → 15), then 20% of 15 food and 7 wealth, rounded up
	eq([e.resources.food, e.resources.wealth], [12, 5], "food 17 → 12, wealth 7 → 5")
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq(outcomes[0].repelled, false, "pillaged")
	eq(outcomes[0].lost, {"food": 5, "wealth": 2}, "lost")
	var line: String = e.military.outcome_text(outcomes[0])
	for fragment in ["−5 food", "−2 wealth"]:
		check(fragment in line, "'%s' in %s" % [fragment, line])


func test_374_a_repelled_raid_plunders_nothing() -> void:
	var e := hoard_engine(5, 0)
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	build_on(e, hills_of(e), ["town"])
	recruit(e, hills_of(e))
	e.end_turn()
	hold_after_upkeep(e, 17, 7)
	e.end_turn()
	eq([e.resources.food, e.resources.wealth], [17, 9], "only its repel effects: +2 wealth")
	if outcomes.size() == 1:
		eq([outcomes[0].repelled, outcomes[0].lost], [true, {"unrest": 1}], "repelled, lost")
	else:
		check(false, "one raid resolved: %s" % [outcomes])


func test_374_a_pillage_plunders_nothing_from_empty_stores() -> void:
	var e := hoard_engine(5, 0)
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.end_turn()
	hold_after_upkeep(e, 2, 0)
	e.end_turn()  # −2 food leaves 0, and 0 wealth: nothing to plunder
	eq([e.resources.food, e.resources.wealth], [0, 0], "food and wealth")
	if outcomes.size() == 1:
		eq(outcomes[0].lost, {"food": 2}, "only its own −2 food")
	else:
		check(false, "one raid resolved: %s" % [outcomes])


func test_374_hoard_config_0_turns_each_part_off() -> void:
	var e := hoard_engine(30, 20, {"raid_hoard_step": 0, "raid_plunder_pct": 0})
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	eq(e.military.raid_strength(active_uid(e, "raiders")), 3, "printed strength with step 0")
	e.end_turn()
	hold_after_upkeep(e, 17, 7)
	e.end_turn()
	eq([e.resources.food, e.resources.wealth], [15, 7], "only its own −2 food with pct 0")
	if outcomes.size() == 1:
		eq(outcomes[0].strength, 3, "struck at 3")


## Config errors for raid_load's cards with overrides.
func hoard_config_errors(overrides: Dictionary) -> Array[String]:
	var o := {"keywords": keywords()}
	o.merge(overrides, true)
	return config_errors_for(raid_load().cards, o)


func test_374_hoard_config_defaults_to_0_and_rejects_bad_values() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	eq([e.config.get("raid_hoard_step"), e.config.get("raid_plunder_pct")], [0, 0], "defaults")
	eq(hoard_config_errors({"raid_hoard_step": 10, "raid_plunder_pct": 100}), [] as Array[String], "valid")
	check_cases([
		["raid_hoard_step below 0", {"raid_hoard_step": -1}, "'raid_hoard_step' must be an integer >= 0", "one_error"],
		["raid_plunder_pct below 0", {"raid_plunder_pct": -1}, "raid_plunder_pct", "one_error"],
		["raid_plunder_pct over 100", {"raid_plunder_pct": 101}, "raid_plunder_pct", "one_error"],
		["raid_plunder_pct not an int", {"raid_plunder_pct": "lots"}, "raid_plunder_pct", "one_error"],
	], hoard_config_errors)


func test_374_a_fork_keeps_the_announced_strength() -> void:
	var e := hoard_engine(13, 9)  # strength 5
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var f: GameEngine = e.fork()
	f.resources.food = 0
	f.resources.wealth = 0
	eq(f.military.raid_strength(raid), 5, "the fork's raid_strength")
	var outcomes := record_raids(f)
	f.end_turn()
	f.end_turn()
	eq(outcomes.map(func(r): return r.strength), [5], "the fork strikes at 5")

# --- 377: the plunder share grows with the era ---

## plunder_engine's plunder config: 50% in era 1, +10 points per era after it.
const ERA_PLUNDER := {"raid_plunder_pct": 50, "raid_plunder_era_pct": 10}


## A hoard_engine game (Raiders, strength 3 at 5 food) with ERA_PLUNDER merged with overrides. Still turn 1.
func plunder_engine(overrides := {}) -> GameEngine:
	var o := ERA_PLUNDER.duplicate()
	o.merge(overrides, true)
	return hoard_engine(5, 0, o)


## Plays e on until Raiders strikes undefended Hills in era: the era is added before the strike, and e holds food and
## wealth as it strikes. Returns the raid_resolved outcomes.
func strike_in_era(e: GameEngine, era: int, food: int, wealth: int) -> Array[Dictionary]:
	var outcomes := record_raids(e)
	e.end_turn()  # Raiders announced in era 1
	eq(e.era(), 1, "announced in era 1")
	e.end_turn()
	if era > 1:
		e.add_era(era)
	hold_after_upkeep(e, food, wealth)
	e.end_turn()  # strikes
	return outcomes


func test_377_the_plunder_share_grows_by_raid_plunder_era_pct_each_era() -> void:
	var e := plunder_engine()
	if e == null:
		return
	var shares := [e.military.plunder_pct()]
	for era in [2, 3]:
		e.add_era(era)
		shares.append(e.military.plunder_pct())
	eq(shares, [50, 60, 70], "eras 1, 2, 3")


func test_377_a_pillage_plunders_the_share_of_the_era_it_strikes_in() -> void:
	# −2 food (17 → 15), then the era's share of 15 food and 7 wealth, each rounded up
	for row in [[1, 7, 3, {"food": 10, "wealth": 4}], [2, 6, 2, {"food": 11, "wealth": 5}],
			[3, 4, 2, {"food": 13, "wealth": 5}]]:
		var e := plunder_engine()
		if e == null:
			return
		var outcomes := strike_in_era(e, row[0], 17, 7)
		eq([e.resources.food, e.resources.wealth], [row[1], row[2]], "era %d: food and wealth" % row[0])
		if outcomes.size() != 1:
			check(false, "era %d: one raid resolved: %s" % [row[0], outcomes])
			continue
		eq(outcomes[0].repelled, false, "era %d: pillaged" % row[0])
		eq(outcomes[0].lost, row[3], "era %d: lost" % row[0])
		var line: String = e.military.outcome_text(outcomes[0])
		for fragment in ["−%d food" % row[3].food, "−%d wealth" % row[3].wealth]:
			check(fragment in line, "era %d: '%s' in %s" % [row[0], fragment, line])


func test_377_a_raid_drawn_in_era_1_plunders_at_the_share_of_the_era_it_strikes_in() -> void:
	var e := plunder_engine()
	if e == null:
		return
	var outcomes := strike_in_era(e, 2, 17, 7)  # hoard 24 at the strike: 5 if it were fixed then
	eq([e.resources.food, e.resources.wealth], [6, 2], "plundered at 60%")
	eq(outcomes.map(func(r): return r.strength), [3], "struck at the strength announced in era 1")


func test_377_the_plunder_share_is_capped_at_100() -> void:
	var e := plunder_engine({"raid_plunder_pct": 80, "raid_plunder_era_pct": 30})
	if e == null:
		return
	var outcomes := strike_in_era(e, 2, 17, 7)
	eq(e.military.plunder_pct(), 100, "80 + 30 in era 2")
	eq([e.resources.food, e.resources.wealth], [0, 0], "everything left taken")
	if outcomes.size() == 1:
		eq(outcomes[0].lost, {"food": 17, "wealth": 7}, "lost")
	else:
		check(false, "one raid resolved: %s" % [outcomes])


func test_377_with_raid_plunder_era_pct_0_the_share_is_raid_plunder_pct_in_every_era() -> void:
	var e := plunder_engine({"raid_plunder_era_pct": 0})
	if e == null:
		return
	var shares := [e.military.plunder_pct()]
	for era in [2, 3]:
		e.add_era(era)
		shares.append(e.military.plunder_pct())
	eq(shares, [50, 50, 50], "eras 1, 2, 3")


func test_377_with_raid_plunder_pct_0_only_later_eras_plunder() -> void:
	for row in [[1, 0, 15, 7], [2, 10, 13, 6]]:  # era 2: 10% of 15 food and 7 wealth, rounded up: 2 and 1
		var e := plunder_engine({"raid_plunder_pct": 0})
		if e == null:
			return
		strike_in_era(e, row[0], 17, 7)
		eq(e.military.plunder_pct(), row[1], "era %d: share" % row[0])
		eq([e.resources.food, e.resources.wealth], [row[2], row[3]], "era %d: food and wealth" % row[0])


func test_377_a_repelled_raid_plunders_nothing_in_a_later_era() -> void:
	var e := plunder_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	build_on(e, hills_of(e), ["town"])
	recruit(e, hills_of(e))
	e.end_turn()
	e.add_era(3)
	hold_after_upkeep(e, 17, 7)
	e.end_turn()
	eq([e.resources.food, e.resources.wealth], [17, 9], "only its repel effects: +2 wealth")
	eq(outcomes.map(func(r): return r.repelled), [true], "repelled")


func test_377_raid_plunder_era_pct_defaults_to_0_and_rejects_bad_values() -> void:
	var e: GameEngine = raid_engine()
	if e == null:
		return
	eq(e.config.get("raid_plunder_era_pct"), 0, "default")
	eq(hoard_config_errors({"raid_plunder_era_pct": 10}), [] as Array[String], "valid")
	check_cases([
		["below 0", {"raid_plunder_era_pct": -1}, "'raid_plunder_era_pct' must be an integer >= 0", "one_error"],
		["not an int", {"raid_plunder_era_pct": "lots"}, "raid_plunder_era_pct", "one_error"],
	], hoard_config_errors)
