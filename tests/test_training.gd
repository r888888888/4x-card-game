extends "res://tests/lib/test_case.gd"
## Training (backlog 164): `training` on buildings gives the units stationed on their territory more strength while
## the building works; `unit_strength(uid)`, which defence sums.

## Levy: a unit of strength 2; Drill Yard and Sparring Ring: buildings with training 1 and 2.
const TEST_TRAINING := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2},
	{"id": "drill_yard", "name": "Drill Yard", "type": "building", "training": 1},
	{"id": "sparring_ring", "name": "Sparring Ring", "type": "building", "training": 2},
]


## TEST_CARDS plus TEST_TRAINING and extra, parsed: {cards, errors, warnings}.
func training_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_TRAINING])


## A game on TEST_CARDS + TEST_TRAINING with population on, 50 food, Homeland at home_pop pop and Hills settled at 1
## pop, and a Levy recruited on Homeland (its first worker); null (after a failed check) when the data doesn't load.
func training_engine(home_pop := 3) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(training_load(), errors, warnings)
	var o := {"population": {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}, "territory_deck": {"hills": 1}}
	var config := DataLoader.parse_config(raw_config({"levy": 10}, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	e.resources.food = 50
	set_home_pop(e, home_pop)
	settle(e, ["hills"])
	e.zone("tableau").find(hills_of(e)).pop = 1
	var levy := put_in_hand(e, "levy")
	check(e.play_card(levy, home_uid(e)), "Levy recruited on Homeland: %s" % e.play_error(levy, home_uid(e)))
	return e


## The first Levy's uid in e's tableau.
func levy_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "levy")


# --- AC1: loading ---

func test_training_loads_on_buildings() -> void:
	check_loads([
		["Drill Yard and Sparring Ring", [], {"cards.drill_yard.training": 1, "cards.sparring_ring.training": 2}],
	], training_load)


func test_bad_training_is_a_load_error() -> void:
	check_cases([
		["0", [{"id": "x", "name": "X", "type": "building", "training": 0}], ["card 'x'", "training"], "one_error"],
		["not an int", [{"id": "x", "name": "X", "type": "building", "training": "one"}], ["card 'x'", "training"],
			"one_error"],
		["on a unit", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "training": 1}],
			"card 'x': 'training' only applies to buildings", "warning_only"],
	], training_load)


# --- AC2: strength ---

func test_working_training_building_adds_to_units_stationed_there() -> void:
	var e := training_engine()
	if e == null:
		return
	var home := home_uid(e)
	var levy := levy_of(e)
	var before: int = e.defense(home)
	build_on(e, home, ["drill_yard"])
	eq(e.unit_strength(levy), 3, "Levy 2 + Drill Yard 1")
	eq(e.defense_parts(home).units, 3, "Homeland's units")
	eq(e.defense(home) - before, 1, "Homeland's defence +1")


func test_training_buildings_on_a_territory_add_up() -> void:
	var e := training_engine()
	if e == null:
		return
	build_on(e, home_uid(e), ["drill_yard", "sparring_ring"])
	eq(e.unit_strength(levy_of(e)), 5, "Levy 2 + Drill Yard 1 + Sparring Ring 2")


# --- AC3: where ---

func test_a_unit_moved_away_loses_its_training() -> void:
	var e := training_engine()
	if e == null:
		return
	var levy := levy_of(e)
	build_on(e, home_uid(e), ["drill_yard"])
	check(e.move_unit(levy, hills_of(e)), "Levy moved to Hills: %s" % e.move_unit_error(levy, hills_of(e)))
	eq(e.unit_strength(levy), 2, "untrained on Hills")
	eq(e.defense_parts(hills_of(e)).units, 2, "Hills' units")


func test_a_unit_moved_onto_a_training_territory_gains_it() -> void:
	var e := training_engine()
	if e == null:
		return
	var home := home_uid(e)
	var hills := hills_of(e)
	build_on(e, home, ["drill_yard"])
	var recruit := put_in_hand(e, "levy")
	check(e.play_card(recruit, hills), "Levy recruited on Hills: %s" % e.play_error(recruit, hills))
	eq(e.unit_strength(recruit), 2, "untrained on Hills")
	check(e.move_unit(recruit, home), "Levy moved to Homeland: %s" % e.move_unit_error(recruit, home))
	eq(e.unit_strength(recruit), 3, "trained on Homeland")


func test_an_idle_training_building_trains_nobody() -> void:
	var e := training_engine(1)
	if e == null:
		return
	build_on(e, home_uid(e), ["drill_yard"])
	check(e.is_idle(uid_of(e.zone("tableau"), "drill_yard")), "Drill Yard idle (the Levy has the only worker)")
	eq(e.unit_strength(levy_of(e)), 2, "untrained")


# --- AC4: edges ---

func test_unit_strength_is_printed_strength_without_training() -> void:
	var e := training_engine()
	if e == null:
		return
	eq(e.unit_strength(levy_of(e)), 2, "Levy")


func test_unit_strength_is_0_for_an_idle_unit_or_a_non_unit() -> void:
	var e := training_engine()
	if e == null:
		return
	var home := home_uid(e)
	var levy := levy_of(e)
	build_on(e, home, ["drill_yard"])
	set_home_pop(e, 0)
	check(e.is_idle(levy), "Levy idle")
	eq(e.unit_strength(levy), 0, "idle Levy")
	var in_hand := put_in_hand(e, "levy")
	for uid in [in_hand, home, uid_of(e.zone("tableau"), "drill_yard"), 9999]:
		eq(e.unit_strength(uid), 0, "unit_strength of %d" % uid)


# --- AC5: text ---

func test_training_text() -> void:
	var db: Dictionary = training_load().cards
	check(db.has("drill_yard"), "drill_yard loaded")
	if not db.has("drill_yard"):
		return
	check("Units here have +1 strength" in db.drill_yard.rules_text(db), "face: %s" % db.drill_yard.rules_text(db))
	check("Units here have +1 strength" in db.drill_yard.rules_tooltip(db), "tooltip: %s" % db.drill_yard.rules_tooltip(db))


# --- Manual check support: the details and the face ---

func test_trained_unit_details_explain_its_strength() -> void:
	var e := training_engine()
	if e == null:
		return
	var levy := levy_of(e)
	var state: Array[String] = []
	state.assign(e.card_details(levy).state)
	check(not state.any(func(s): return s.begins_with("Strength")), "no strength line untrained: %s" % [state])
	build_on(e, home_uid(e), ["drill_yard"])
	state.assign(e.card_details(levy).state)
	has_msg(state, "Strength 3 (printed 2, +1 training)")


func test_strength_tag_shows_only_on_a_trained_unit() -> void:
	var e := training_engine()
	if e == null:
		return
	var home := home_uid(e)
	var levy := levy_of(e)
	eq(e.unit_strength_tag(levy), "", "untrained")
	build_on(e, home, ["drill_yard"])
	eq(e.unit_strength_tag(levy), "Strength 3", "trained")
	for uid in [home, uid_of(e.zone("tableau"), "drill_yard"), put_in_hand(e, "levy"), 9999]:
		eq(e.unit_strength_tag(uid), "", "tag of %d" % uid)
	set_home_pop(e, 0)
	eq(e.unit_strength_tag(levy), "", "idle")
