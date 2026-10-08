extends "res://tests/lib/test_case.gd"
## Settlement tiers (backlog 281): a settled territory's pop sets its tier (config population.tiers), and each tier
## adds building slots. A drop in tier idles the buildings past the slots, and a change of tier is a notice.

const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
	{"id": "metropolis", "name": "Metropolis", "pop": 13, "slots": 3},
]
## Fixture cards: a wall (defence 2), a building with a hand_size modifier.
const TIER_CARDS := [
	{"id": "rampart", "name": "Rampart", "type": "building", "defense": 2},
	{"id": "scriptorium", "name": "Scriptorium", "type": "building", "modifiers": {"hand_size": 1}},
]


## Population on with the fixture tiers (or none when tiers is null), Grassland settled; Homeland at pop 0 so lose_pop
## and the Famine take from Grassland. vp_per_pop 0, food_upkeep 0 unless given, plenty of food.
func tier_engine(deck := {"farm": 10}, tiers: Variant = TIERS, food_upkeep := 0) -> GameEngine:
	var population := {"start": 1, "food_upkeep": food_upkeep, "vp_per_pop": 0}
	if tiers != null:
		population["tiers"] = tiers
	var e: GameEngine = make_engine(deck, {"population": population, "territory_deck": {"grassland": 2}}, 1, TIER_CARDS)
	settle(e, ["grassland"])
	e.zone("tableau").find(home_uid(e)).pop = 0
	e.resources.food = 50
	return e


func grassland_uid(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "grassland")


func set_pop(e: GameEngine, territory_uid: int, n: int) -> void:
	e.zone("tableau").find(territory_uid).pop = n


## The uids of the buildings on territory_uid, in the order they were placed.
func buildings_here(e: GameEngine, territory_uid: int) -> Array[int]:
	var out: Array[int] = []
	for c in e.zone("tableau").cards:
		if c.def.type == CardDef.BUILDING and c.territory_uid == territory_uid:
			out.append(c.uid)
	return out


## Collects every noticed message the engine emits into the returned array.
func notices(e: GameEngine) -> Array[String]:
	var out: Array[String] = []
	e.noticed.connect(func(message: String, _priority: StringName): out.append(message))
	return out


func tier_notices(messages: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for m in messages:
		for t in TIERS:
			if m.contains(t.name):
				out.append(m)
				break
	return out


# --- AC1: the tier from pop ---

func test_the_tier_follows_pop() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	var got := []
	for n in [0, 3, 4, 7, 8, 12, 13]:
		set_pop(e, g, n)
		got.append([n, e.tier(g), e.tier_name(g), e.next_tier_pop(g)])
	eq(got, [[0, 0, "Hamlet", 4], [3, 0, "Hamlet", 4], [4, 1, "Village", 8], [7, 1, "Village", 8],
		[8, 2, "Town", 13], [12, 2, "Town", 13], [13, 3, "Metropolis", 0]], "[pop, tier, name, next tier pop]")


func test_no_tier_without_tiers_or_for_a_card_that_isnt_a_settled_territory() -> void:
	var off := tier_engine({"farm": 10}, null)
	var g := grassland_uid(off)
	set_pop(off, g, 13)
	eq([off.tier(g), off.tier_name(g), off.next_tier_pop(g)], [-1, "", 0], "no population.tiers")
	var e := tier_engine()
	var capital := uid_of(e.zone("tableau"), "capital")
	var frontier := uid_of(e.zone("territory_deck"), "grassland")
	for uid in [capital, frontier, first_in_hand(e), 9999]:
		eq([e.tier(uid), e.tier_name(uid), e.next_tier_pop(uid)], [-1, "", 0], "not a settled territory: %d" % uid)


# --- AC2: tiers add slots ---

func test_a_tier_adds_its_slots() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	var got := []
	for n in [3, 4, 8, 13]:
		set_pop(e, g, n)
		got.append(e.total_slots(g))
	eq(got, [2, 3, 4, 5], "Grassland (2 slots) at pop 3, 4, 8, 13")


func test_tier_slots_add_to_city_slots() -> void:
	var e := tier_engine()
	var home := home_uid(e)
	var citadel: CardInstance = e.create_card("citadel", "tableau", null)
	citadel.territory_uid = home
	set_pop(e, home, 4)
	eq(e.total_slots(home), 10, "Homeland 5 + Citadel 4 + Village 1")


func test_without_tiers_pop_adds_no_slots() -> void:
	var e := tier_engine({"farm": 10}, null)
	var g := grassland_uid(e)
	set_pop(e, g, 13)
	eq(e.total_slots(g), 2, "Grassland at pop 13, no tiers")


func test_a_building_fits_the_slot_a_tier_adds() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	build_on(e, g, ["farm", "farm"])
	set_pop(e, g, 3)
	var farm := first_in_hand(e)
	check(not e.valid_targets(farm).has(g), "pop 3: 2 slots, both full: %s" % [e.valid_targets(farm)])
	set_pop(e, g, 4)
	check(e.valid_targets(farm).has(g), "pop 4: a Village's third slot: %s" % [e.valid_targets(farm)])
	check(e.play_card(farm, g), "the third building is played there: %s" % e.play_error(farm))
	eq(buildings_here(e, g).size(), 3, "3 buildings on Grassland")


# --- AC3: dropping a tier idles the buildings past the slots ---

func test_dropping_a_tier_idles_the_building_placed_last() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	build_on(e, g, ["farm", "farm", "farm"])
	var farms := buildings_here(e, g)
	e.lose_pop(1, e.zone("hand").cards[0])
	eq(e.pop(g), 3, "lose_pop took Grassland to 3")
	eq(farms.map(func(uid): return e.is_idle(uid)), [false, false, true], "the Farm placed last is idle")
	eq(e.free_slots(g), 0, "free slots never go negative")
	eq(e.territory_summary(g).get("idle"), 1, "the summary counts it idle")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2 + 2, "Capital +2, two working Farms +2")
	set_pop(e, g, 4)
	check(not e.is_idle(farms[2]), "back at pop 4 it works again")
	food = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2 + 3, "Capital +2, three Farms +3")


func test_a_building_idle_from_slots_keeps_its_printed_vp() -> void:
	var e := tier_engine({"temple": 10})
	var g := grassland_uid(e)
	set_pop(e, g, 3)
	build_on(e, g, ["temple", "temple", "temple"])
	check(e.is_idle(buildings_here(e, g)[2]), "the third Temple is idle")
	eq(e.score(), 2 + 3 + e.bonus_score, "Capital 2 + 3 printed Temple VP (the idle one too)")


func test_a_building_idle_from_slots_skips_its_modifiers_and_defence() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 3)
	build_on(e, g, ["guildhall", "guildhall", "scriptorium"])
	var before: int = e.modifier(Modifiers.HAND_SIZE)
	set_pop(e, g, 4)
	eq([before, e.modifier(Modifiers.HAND_SIZE)], [0, 1], "the Scriptorium's hand_size counts only in its slot")
	var walls := tier_engine()
	var wg := grassland_uid(walls)
	set_pop(walls, wg, 3)
	build_on(walls, wg, ["guildhall", "guildhall", "rampart"])
	var low: int = walls.military.defense_parts(wg).buildings
	set_pop(walls, wg, 4)
	eq([low, walls.military.defense_parts(wg).buildings], [0, 2], "the Rampart defends only in its slot")


func test_a_building_idle_from_slots_guards_no_pop_from_famine() -> void:
	# food_upkeep 1, no food: Grassland's pop eats more than the Capital's +2 makes, and the Famine takes 1 from
	# Grassland (the biggest) unless a working Silo saves it.
	var e := tier_engine({"farm": 10}, TIERS, 1)
	var g := grassland_uid(e)
	set_pop(e, g, 3)
	build_on(e, g, ["guildhall", "guildhall", "silo"])
	e.resources.food = 0
	eq(e.upkeep_forecast().get("starve"), 1, "pop 3: the Silo is past the 2 slots, so 1 starves")
	set_pop(e, g, 4)
	eq(e.upkeep_forecast().get("starve"), 0, "pop 4: the Silo works and saves the 1")


# --- AC4: slot idling and worker idling combine ---

func test_slot_and_worker_idling_combine() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	build_on(e, g, ["farm", "farm", "farm"])
	set_pop(e, g, 1)  # 1 worker: the 2nd and 3rd lack one; Hamlet's 2 slots: the 3rd is past them
	var farms := buildings_here(e, g)
	eq(farms.map(func(uid): return e.is_idle(uid)), [false, true, true], "the 2nd and 3rd are idle")
	eq(e.territory_summary(g).get("idle"), 2, "2 idle, not 3")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2 + 1, "Capital +2, one working Farm +1")


# --- AC5: notices ---

func test_growing_into_a_tier_is_a_notice() -> void:
	var e := tier_engine({"festival": 10})
	var g := grassland_uid(e)
	set_pop(e, g, 3)
	var messages := notices(e)
	check(e.play_card(uid_of(e.zone("hand"), "festival")), "Festival: %s" % e.play_error(first_in_hand(e)))
	eq(e.pop(g), 4, "Grassland grew to 4")
	var tiers := tier_notices(messages)
	eq(tiers.size(), 1, "one tier notice: %s" % [messages])
	if tiers.size() == 1:
		check(tiers[0].contains(e.territory_name(g)) and tiers[0].contains("Village"), "names Grassland and Village: %s" % tiers[0])


func test_shrinking_out_of_a_tier_is_a_notice() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	var messages := notices(e)
	e.lose_pop(1, e.zone("hand").cards[0])
	var tiers := tier_notices(messages)
	eq(tiers.size(), 1, "one tier notice: %s" % [messages])
	if tiers.size() == 1:
		check(tiers[0].contains(e.territory_name(g)) and tiers[0].contains("Hamlet"), "names Grassland and Hamlet: %s" % tiers[0])


func test_growing_within_a_tier_is_no_notice() -> void:
	var e := tier_engine({"festival": 10})
	var g := grassland_uid(e)
	build_on(e, g, ["silo"])  # housing 5: room to grow past 4
	set_pop(e, g, 4)
	var messages := notices(e)
	check(e.play_card(uid_of(e.zone("hand"), "festival")), "Festival: %s" % e.play_error(first_in_hand(e)))
	eq(e.pop(g), 5, "Grassland grew to 5")
	eq(tier_notices(messages), [] as Array[String], "4 to 5 stays a Village")


func test_settling_at_pop_1_is_no_notice() -> void:
	var e := tier_engine({"pioneer": 10})
	to_frontier(e, ["grassland"])
	var messages := notices(e)
	var pioneer := first_in_hand(e)
	var frontier := uid_of(e.zone("frontier"), "grassland")
	check(e.play_card(pioneer, frontier), "Pioneer settles: %s" % e.play_error(pioneer))
	eq(e.pop(frontier), 1, "settled at pop 1")
	eq(tier_notices(messages), [] as Array[String], "a new Hamlet is no notice")


# --- AC6: the loader ---

## TEST_CARDS and a config whose population block has tiers (none when null): {cards, config, errors, warnings}.
func tier_messages(tiers: Variant) -> Dictionary:
	var population := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	if tiers != null:
		population["tiers"] = tiers
	return config_load_on(fixture_load(), {"population": population.merged({"famine": FAMINE})})


func has_error(messages: Array, parts: Array) -> bool:
	return messages.any(func(m: String): return parts.all(func(p: String): return m.contains(p)))


func test_tiers_load_and_are_optional() -> void:
	check_loads([
		["the fixture tiers, in the normalized block", TIERS, {"config.population.tiers": TIERS}],
		["no tiers: []", null, {"config.population.tiers": []}],
	], tier_messages)


func test_tiers_must_be_a_non_empty_array_of_objects() -> void:
	for bad in ["many", {"hamlet": 0}, [], [5]]:
		check(has_error(tier_messages(bad).errors, ["population.tiers"]), "%s is refused: %s" % [bad, tier_messages(bad).errors])


func test_each_tier_needs_an_id_a_name_and_whole_pop_and_slots() -> void:
	var cases := [
		[{"name": "Hamlet", "pop": 0, "slots": 0}, "id"],
		[{"id": "", "name": "Hamlet", "pop": 0, "slots": 0}, "id"],
		[{"id": "hamlet", "pop": 0, "slots": 0}, "name"],
		[{"id": "hamlet", "name": "", "pop": 0, "slots": 0}, "name"],
		[{"id": "hamlet", "name": "Hamlet", "slots": 0}, "pop"],
		[{"id": "hamlet", "name": "Hamlet", "pop": -1, "slots": 0}, "pop"],
		[{"id": "hamlet", "name": "Hamlet", "pop": 0.5, "slots": 0}, "pop"],
		[{"id": "hamlet", "name": "Hamlet", "pop": 0}, "slots"],
		[{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": -1}, "slots"],
	]
	for c in cases:
		var errors: Array = tier_messages([c[0]]).errors
		check(has_error(errors, ["population.tiers", "0", c[1]]), "%s: an error naming tier 0's %s: %s" % [c[0], c[1], errors])


func test_tiers_start_at_pop_0_rise_strictly_and_never_lose_slots() -> void:
	var first: Array = tier_messages([{"id": "a", "name": "A", "pop": 1, "slots": 0}]).errors
	check(has_error(first, ["population.tiers", "0", "pop"]), "the first tier's pop must be 0: %s" % [first])
	var flat: Array = tier_messages([TIERS[0], {"id": "b", "name": "B", "pop": 0, "slots": 1}]).errors
	check(has_error(flat, ["population.tiers", "1", "pop"]), "pop must rise strictly: %s" % [flat])
	var falling: Array = tier_messages([TIERS[0], {"id": "b", "name": "B", "pop": 4, "slots": 2},
		{"id": "c", "name": "C", "pop": 8, "slots": 1}]).errors
	check(has_error(falling, ["population.tiers", "2", "slots"]), "slots must never fall: %s" % [falling])
	var twin: Array = tier_messages([TIERS[0], {"id": "hamlet", "name": "B", "pop": 4, "slots": 1}]).errors
	check(has_error(twin, ["population.tiers", "1", "id"]), "ids are unique: %s" % [twin])


func test_an_unknown_tier_field_is_a_warning() -> void:
	var r := tier_messages([{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0, "housing": 2}])
	eq(r.errors, [], "no error")
	check(has_error(r.warnings, ["population.tiers", "0", "housing"]), "a warning naming the field: %s" % [r.warnings])


# --- AC7: status, tooltip and glossary ---

func test_territory_status_names_the_tier_and_the_next_one() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	var s: Dictionary = e.territory_status(g)
	eq([s.get("tier_name"), s.get("next_tier_pop")], ["Village", 8], "a Village; a Town at 8")
	set_pop(e, g, 13)
	s = e.territory_status(g)
	eq([s.get("tier_name"), s.get("next_tier_pop")], ["Metropolis", 0], "the top tier")


func test_the_territory_tooltip_has_a_tier_line() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	var lines: PackedStringArray = e.territory_tooltip(g).split("\n")
	check(lines.has("Village: a Town at 8 pop"), "the tier and the next one: %s" % [lines])
	set_pop(e, g, 13)
	lines = e.territory_tooltip(g).split("\n")
	check(lines.has("Metropolis"), "just the top tier's name: %s" % [lines])


func test_the_territory_tooltip_has_no_tier_line_without_tiers() -> void:
	var e := tier_engine({"farm": 10}, null)
	var g := grassland_uid(e)
	set_pop(e, g, 4)
	var tooltip: String = e.territory_tooltip(g)
	check(not TIERS.any(func(t): return tooltip.contains(t.name)), "no tier line: %s" % tooltip)


# --- 346: the tier line ---

func test_the_tier_line_names_the_tier_and_the_next_one() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 5)
	eq(e.tier_line(g), "Village: a Town at 8 pop", "a Village at pop 5")


func test_the_tier_line_at_the_top_tier_is_its_name() -> void:
	var e := tier_engine()
	var g := grassland_uid(e)
	set_pop(e, g, 13)
	eq(e.tier_line(g), "Metropolis", "the top tier")


func test_no_tier_line_without_tiers_or_population_or_for_other_cards() -> void:
	var off := tier_engine({"farm": 10}, null)
	eq(off.tier_line(grassland_uid(off)), "", "no population.tiers")
	var no_pop: GameEngine = make_engine({"farm": 10}, {"territory_deck": {"grassland": 2}}, 1, TIER_CARDS)
	settle(no_pop, ["grassland"])
	eq(no_pop.tier_line(grassland_uid(no_pop)), "", "population off")
	var e := tier_engine()
	var capital := uid_of(e.zone("tableau"), "capital")
	var frontier := uid_of(e.zone("territory_deck"), "grassland")
	for uid in [capital, frontier, first_in_hand(e), 9999]:
		eq(e.tier_line(uid), "", "not a settled territory: %d" % uid)


func test_the_glossary_says_buildings_past_the_slots_are_idle() -> void:
	check(Glossary.text("Workers").contains("slots"), "Workers: %s" % Glossary.text("Workers"))
