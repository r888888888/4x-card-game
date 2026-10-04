extends "res://tests/lib/test_case.gd"
## Barbarian raids (backlog 162): an event with `raid` {strength, targets, pop} is announced when drawn, aimed at the
## weakest settled territory it may hit, and strikes at the next event phase: repelled when the target's defence is
## at least its strength (its `repel` effects), else pillaged (its `pillage` effects, pop and the units stationed
## there lost). `raid_target`, `raid_forecast` and `raid_resolved`.

const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
## Levy: a unit of strength 2; Town: a city with defense 1. Raiders: strength 3 aimed at mountains, +1 insight when
## drawn; repelled +2 wealth −1 unrest, pillaged −2 food +1 unrest. Horde: strength 1, any territory, pop 1 by default.
const RAID_CARDS := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2},
	{"id": "town", "name": "Town", "type": "city", "vp": 1, "tags": ["city"], "defense": 1},
	{"id": "raiders", "name": "Raiders", "type": "event", "raid": {"strength": 3, "targets": ["mountain"]}, "effects": [
		{"op": "gain", "resource": "insight", "amount": 1},
		{"op": "gain", "resource": "wealth", "amount": 2, "trigger": "repel"},
		{"op": "lose", "resource": "unrest", "amount": 1, "trigger": "repel"},
		{"op": "lose", "resource": "food", "amount": 2, "trigger": "pillage"},
		{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "pillage"}]},
	{"id": "horde", "name": "Horde", "type": "event", "raid": {"strength": 1}},
]


## TEST_CARDS, TEST_EVENTS and RAID_CARDS plus extra, parsed with unrest listed: {cards, errors, warnings}.
func raid_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_EVENTS, RAID_CARDS], RESOURCES)


## A raid_load card "x" of type event with a raid and these fields merged in, for loader cases.
func raid_with(fields: Dictionary) -> Array:
	var card := {"id": "x", "name": "X", "type": "event", "raid": {"strength": 2}}
	card.merge(fields, true)
	return [card]


## A game on raid_load's cards: Levies in the deck, population on (Homeland at 3 pop, no food upkeep), Hills settled
## at 1 pop, 50 food and 1 unrest, and the event deck event_deck with ids_on_top arranged on top (the turn-2 event
## first). Still turn 1. null (after a failed check) when the data doesn't load.
func raid_engine(ids_on_top := ["raiders"], event_deck := {"raiders": 1, "horde": 1, "omen": 3}, overrides := {}) -> GameEngine:
	var r := raid_load()
	check(r.errors.is_empty(), "test cards should load: %s" % [r.errors])
	if not r.errors.is_empty():
		return null
	var o := {"resources": RESOURCES, "keywords": keywords(), "event_deck": event_deck,
		"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"hills": 1, "grassland": 1, "river": 1}}
	o.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"levy": 10}, o), RESOURCES, r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	settle(e, ["hills"])
	e.zone("tableau").find(hills_of(e)).pop = 1
	e.resources.food = 50
	e.resources.unrest = 1
	arrange(e.zone("event_deck"), ids_on_top)
	return e


## Hills' uid in e's tableau.
func hills_of(e: Object) -> int:
	return uid_of(e.zone("tableau"), "hills")


## The uid of the active event id, or -1.
func active_uid(e: Object, id: String) -> int:
	return uid_of(e.zone("active_events"), id)


## Recruits a Levy from e's hand onto territory uid.
func recruit(e: Object, uid: int) -> void:
	var levy := uid_of(e.zone("hand"), "levy")
	check(e.play_card(levy, uid), "Levy recruited: %s" % e.play_error(levy, uid))


## Records every raid_resolved outcome e emits into the returned array.
func record_raids(e: Object) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	e.connect("raid_resolved", func(o: Dictionary): outcomes.append(o))
	return outcomes


# --- AC1: loading ---

func test_raid_loads_on_an_event() -> void:
	var r := raid_load()
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if not r.cards.has("raiders"):
		return
	var raiders: Object = r.cards.raiders
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


# --- AC2: the announcement and its target ---

func test_a_drawn_raid_is_announced_at_the_weakest_matching_territory() -> void:
	var e: Object = raid_engine()
	if e == null:
		return
	var insight: int = e.resources.insight
	e.end_turn()
	var raid := active_uid(e, "raiders")
	check(raid != -1, "Raiders active on turn 2")
	eq(e.resources.insight - insight, 1, "its play effects resolved")
	eq(e.raid_target(raid), hills_of(e), "the mountain")


func test_a_raid_with_no_targets_picks_the_weakest_then_the_most_pop() -> void:
	var e: Object = raid_engine(["horde"])
	if e == null:
		return
	e.end_turn()
	eq(e.raid_target(active_uid(e, "horde")), home_uid(e), "Homeland: defence 0 like Hills, but 3 pop")


func test_a_raid_whose_targets_match_nothing_picks_among_all_territories() -> void:
	var e: Object = raid_engine()
	if e == null:
		return
	var hills: CardInstance = e.zone("tableau").find(hills_of(e))
	e.zone("tableau").remove(hills)
	e.zone("territory_deck").add(hills)
	e.end_turn()
	eq(e.raid_target(active_uid(e, "raiders")), home_uid(e), "no mountain settled: Homeland")


func test_a_raid_avoids_stronger_land_and_breaks_full_ties_by_tableau_order() -> void:
	var e: Object = raid_engine(["horde"])
	if e == null:
		return
	settle(e, ["grassland"])
	var grassland := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grassland).pop = 1
	build_on(e, home_uid(e), ["town"])
	e.end_turn()
	eq(e.raid_target(active_uid(e, "horde")), hills_of(e), "Hills before Grassland (both 0 defence, 1 pop)")


func test_raid_target_is_minus_1_for_anything_but_an_active_raid() -> void:
	var e: Object = raid_engine(["omen", "raiders"])
	if e == null:
		return
	e.end_turn()
	for uid in [active_uid(e, "omen"), uid_of(e.zone("event_deck"), "raiders"), home_uid(e), 9999]:
		eq(e.raid_target(uid), -1, "raid_target(%d)" % uid)


# --- AC3: it strikes at the next event phase ---

func test_a_raid_strikes_at_the_next_event_phase_then_is_discarded() -> void:
	var e: Object = raid_engine(["raiders", "omen"])
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var raid := active_uid(e, "raiders")
	eq(outcomes.size(), 0, "not on the turn it is drawn")
	e.end_turn()
	eq(outcomes.size(), 1, "struck once at the turn-3 event phase")
	eq(uid_of(e.zone("event_discard"), "raiders"), raid, "Raiders in the event discard")
	eq(active_uid(e, "raiders"), -1, "no longer active")
	check(active_uid(e, "omen") != -1, "the turn-3 event drawn after it")
	if outcomes.is_empty():
		return
	var o: Dictionary = outcomes[0]
	for key in ["uid", "target", "strength", "defense", "repelled", "units_lost", "pop_lost", "gained", "lost", "vp"]:
		check(o.has(key), "outcome has %s: %s" % [key, o])
	eq(o.get("uid"), raid, "uid")
	eq(o.get("target"), hills_of(e), "target")
	eq(o.get("strength"), 3, "strength")


func test_the_target_stays_fixed_when_defence_changes_elsewhere() -> void:
	var e: Object = raid_engine(["horde"])
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	recruit(e, home_uid(e))
	eq(e.raid_target(active_uid(e, "horde")), home_uid(e), "still Homeland, now stronger than Hills")
	e.end_turn()
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq(outcomes[0].target, home_uid(e), "struck Homeland")
	eq(outcomes[0].defense, 2, "against the Levy")
	eq(outcomes[0].repelled, true, "repelled")


# --- AC4: repelled ---

func test_a_raid_meeting_enough_defence_is_repelled() -> void:
	var e: Object = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	var hills := hills_of(e)
	build_on(e, hills, ["town"])
	recruit(e, hills)
	var levy := uid_of(e.zone("tableau"), "levy")
	var wealth: int = e.resources.wealth
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
	var e: Object = raid_engine()
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
	var e: Object = raid_engine()
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.zone("tableau").find(hills_of(e)).pop = 0
	e.end_turn()
	eq(e.zone("tableau").find(hills_of(e)).pop, 0, "Hills' pop")
	eq(outcomes.size(), 1, "one raid resolved")
	if outcomes.size() == 1:
		eq(outcomes[0].pop_lost, 0, "pop_lost")


# --- AC6: the forecast ---

func test_raid_forecast_lists_announced_raids_with_live_defence() -> void:
	var e: Object = raid_engine()
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
	var e: Object = raid_engine(["raiders", "horde"], {"raiders": 1, "horde": 1, "omen": 3}, {"turn_limit": 3})
	if e == null:
		return
	var outcomes := record_raids(e)
	e.end_turn()
	e.end_turn()
	eq(outcomes.size(), 1, "Raiders struck as turn 3 began")
	check(active_uid(e, "horde") != -1, "Horde drawn in the final turn")
	e.end_turn()
	check(e.is_over, "game over")
	eq(outcomes.size(), 1, "Horde never struck")


func test_a_fork_keeps_each_raids_target() -> void:
	var e: Object = raid_engine()
	if e == null:
		return
	e.end_turn()
	var raid := active_uid(e, "raiders")
	var f: Object = e.fork()
	eq(f.raid_target(raid), hills_of(e), "the fork's target")
	eq(f.raid_forecast(), e.raid_forecast(), "the fork's forecast")
