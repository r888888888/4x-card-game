extends "res://tests/lib/raid_case.gd"
## Veteran units (backlog 165): each working unit stationed on a territory that repels a raid gains a veteran counter
## (`unit_veterancy`), +1 strength each, up to config `veteran_max`; it keeps them when it moves and loses them when it
## leaves the tableau. `raid_resolved`'s outcome lists the units as `veterans`.

const VETERANS := {"veteran_max": 2}


## raid_engine's game (Raiders on top, aimed at Hills) with veteran_max 2 and overrides; null when it doesn't load.
func veteran_engine(overrides := VETERANS) -> GameEngine:
	return raid_engine(["raiders", "omen", "omen", "omen"], {"raiders": 1, "horde": 1, "omen": 3}, overrides)


## Turn 2 of veteran_engine's game: Raiders announced at Hills, a Town on Hills and a Levy recruited there (defence 3,
## enough to repel it). Returns the Levy's uid.
func garrison_hills(e: GameEngine) -> int:
	e.end_turn()
	build_on(e, hills_of(e), ["town"])
	recruit(e, hills_of(e))
	return uid_of(e.zone("tableau"), "levy")


## Ends turns until the active Raiders strikes.
func await_strike(e: GameEngine) -> void:
	var raid := active_uid(e, "raiders")
	check(raid != -1, "Raiders active")
	for i in e.raid_turns_left(raid):
		e.end_turn()


## Puts the Raiders card (from the event discard) back on top of the event deck and plays until it has been drawn and
## has struck.
func raid_again(e: GameEngine) -> void:
	var raid: CardInstance = e.zone("event_discard").find_id("raiders")
	check(raid != null, "Raiders in the event discard")
	if raid == null:
		return
	e.zone("event_discard").remove(raid)
	e.zone("event_deck").add(raid)
	e.end_turn()
	await_strike(e)


# --- AC1: config ---

func test_veteran_max_defaults_to_0_and_rejects_bad_values() -> void:
	var e := raid_engine()
	if e == null:
		return
	eq(e.config.get("veteran_max"), 0, "default")
	var cards: Dictionary = raid_load().cards
	var errors_for := func(o: Dictionary) -> Array[String]:
		var with_keywords := {"keywords": keywords()}
		with_keywords.merge(o, true)
		return config_errors_for(cards, with_keywords)
	eq(errors_for.call({"veteran_max": 2}), [] as Array[String], "valid")
	check_cases([
		["below 0", {"veteran_max": -1}, "'veteran_max' must be an integer >= 0"],
		["not an int", {"veteran_max": "two"}, "'veteran_max' must be an integer >= 0"],
	], errors_for)


# --- AC2: gain ---

func test_working_units_on_a_territory_that_repels_a_raid_become_veterans() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	var levy := garrison_hills(e)
	eq([e.unit_veterancy(levy), e.unit_strength(levy)], [0, 2], "a fresh Levy")
	await_strike(e)
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq(outcomes[0].repelled, true, "repelled")
	eq(e.unit_veterancy(levy), 1, "1 counter")
	eq(e.unit_strength(levy), 3, "Levy 2 + 1 veteran")
	eq(outcomes[0].get("veterans"), [levy], "the outcome lists it")


func test_idle_units_and_units_elsewhere_dont_become_veterans() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	var guard := garrison_hills(e)
	var home := home_uid(e)
	recruit(e, home)
	recruit(e, home)
	var levies: Array[int] = []
	for c in e.zone("tableau").cards:
		if c.def.id == "levy" and c.uid != guard:
			levies.append(c.uid)
	var at_home := levies[0]
	var idle := levies[1]
	check(e.move_unit(idle, hills_of(e)), "the second Levy marches to Hills: %s" % e.move_unit_error(idle, hills_of(e)))
	set_home_pop(e, 1)
	check(e.is_idle(idle) and not e.is_idle(at_home), "one Levy from Homeland idle on Hills, the other working at home")
	await_strike(e)
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq(outcomes[0].repelled, true, "repelled")
	eq([e.unit_veterancy(guard), e.unit_veterancy(idle), e.unit_veterancy(at_home)], [1, 0, 0], "veterancy")
	eq(outcomes[0].get("veterans"), [guard], "only the working Levy on Hills")


func test_no_veterans_when_veteran_max_is_0_or_the_raid_pillages() -> void:
	var off := raid_engine()
	if off == null:
		return
	var off_outcomes := record_raids(off)
	off.end_turn()
	build_on(off, hills_of(off), ["town"])
	recruit(off, hills_of(off))
	var levy := uid_of(off.zone("tableau"), "levy")
	await_strike(off)
	eq(off.unit_veterancy(levy), 0, "veteran_max 0")
	eq(off_outcomes.map(func(o): return [o.repelled, o.get("veterans")]), [[true, []]], "repelled, no veterans")
	var e := veteran_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	recruit(e, hills_of(e))
	await_strike(e)
	eq(outcomes.map(func(o): return [o.repelled, o.get("veterans")]), [[false, []]], "pillaged, no veterans")


# --- AC3: cap ---

func test_a_unit_at_veteran_max_gains_no_more() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	var levy := garrison_hills(e)
	await_strike(e)
	raid_again(e)
	eq(e.unit_veterancy(levy), 2, "2 counters after two repelled raids")
	raid_again(e)
	eq(outcomes.map(func(o): return o.repelled), [true, true, true], "three raids repelled")
	eq(e.unit_veterancy(levy), 2, "still 2: the cap")
	eq(e.unit_strength(levy), 4, "Levy 2 + 2 veteran")
	if outcomes.size() == 3:
		eq(outcomes[2].get("veterans"), [], "none listed at the cap")


# --- AC4: keep and lose ---

func test_a_veteran_keeps_its_counters_when_it_moves() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var levy := garrison_hills(e)
	await_strike(e)
	check(e.move_unit(levy, home_uid(e)), "the Levy marches home: %s" % e.move_unit_error(levy, home_uid(e)))
	eq(e.unit_veterancy(levy), 1, "still a veteran")
	eq(e.unit_strength(levy), 3, "Levy 2 + 1 veteran")


func test_a_disbanded_veteran_starts_again_at_0() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var levy := garrison_hills(e)
	await_strike(e)
	check(e.disband(levy), "disbanded: %s" % e.disband_error(levy))
	eq(e.unit_veterancy(levy), 0, "no veterancy out of the tableau")
	var card: CardInstance = e.zone("discard").find(levy)
	check(card != null, "the Levy is in the discard")
	if card == null:
		return
	e.zone("discard").remove(card)
	e.zone("hand").add(card)
	check(e.play_card(levy, hills_of(e)), "played again: %s" % e.play_error(levy, hills_of(e)))
	eq(e.unit_veterancy(levy), 0, "starts at 0")
	eq(e.unit_strength(levy), 2, "printed strength")


func test_a_veteran_lost_in_a_raid_starts_again_at_0() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	var levy := garrison_hills(e)
	await_strike(e)
	e.zone("tableau").find(hills_of(e)).pop = 0
	check(e.is_idle(levy), "the veteran idle: Hills has no worker for it")
	raid_again(e)
	eq(outcomes.map(func(o): return [o.repelled, o.units_lost]), [[true, []], [false, [levy]]],
		"repelled, then pillaged and the Levy lost")
	eq(e.unit_veterancy(levy), 0, "no veterancy out of the tableau")
	var card: CardInstance = e.zone("discard").find(levy)
	check(card != null, "the Levy is in the discard")
	if card == null:
		return
	e.zone("tableau").find(hills_of(e)).pop = 1
	e.zone("discard").remove(card)
	e.zone("hand").add(card)
	check(e.play_card(levy, hills_of(e)), "played again: %s" % e.play_error(levy, hills_of(e)))
	eq(e.unit_veterancy(levy), 0, "starts at 0")


func test_unit_veterancy_is_0_for_anything_but_a_unit_in_the_tableau() -> void:
	var e := veteran_engine()
	if e == null:
		return
	garrison_hills(e)
	for uid in [home_uid(e), uid_of(e.zone("tableau"), "town"), uid_of(e.zone("hand"), "levy"), 9999]:
		eq(e.unit_veterancy(uid), 0, "unit_veterancy of %d" % uid)


# --- AC5: text ---

func test_veteran_details_show_its_counters() -> void:
	var e := veteran_engine()
	if e == null:
		return
	var levy := garrison_hills(e)
	var state: Array[String] = []
	state.assign(e.card_details(levy).state)
	check(not state.any(func(s): return s.begins_with("Veteran")), "no veteran line on a fresh Levy: %s" % [state])
	await_strike(e)
	state.assign(e.card_details(levy).state)
	has_msg(state, "Veteran 1 (+1 strength)")
	check(not state.any(func(s): return "training" in s), "veterancy isn't training: %s" % [state])
