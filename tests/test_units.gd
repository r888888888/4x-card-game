extends "res://tests/lib/test_case.gd"
## Unit cards (backlog 160): the `unit` type and its `strength`, recruited from the hand onto a settled territory, its
## home, where it uses a worker but no slot; its station; idle units; card text and score.

## Levy: a unit costing 1 food, strength 2, 1 VP, ⟳ −1 food.
const TEST_UNITS := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "vp": 1, "strength": 2,
	 "effects": [{"op": "lose", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
]


## TEST_CARDS plus TEST_UNITS and extra, parsed: {cards, errors, warnings}.
func unit_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_UNITS])


## A new game on TEST_CARDS + TEST_UNITS with Levies in the deck, 50 food, and Homeland at pop (population off when
## pop is -1); null (after a failed check) when the data doesn't load. overrides replace config keys.
func unit_engine(pop := 2, deck := {"levy": 10}, overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(unit_load(), errors, warnings)
	var o := {}
	if pop >= 0:
		o["population"] = {"start": pop, "food_upkeep": 0, "vp_per_pop": 0}
	o.merge(overrides, true)
	var config := DataLoader.parse_config(raw_config(deck, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var engine := GameEngine.new(cards, config)
	engine.new_game(1)
	engine.resources.food = 50
	return engine


## The AC2 game: Homeland at 2 pop with a Farm, 3 food, Levies in hand.
func recruit_engine() -> GameEngine:
	var e := unit_engine(2)
	if e != null:
		build_on(e, home_uid(e), ["farm"])
		e.resources.food = 3
	return e


# --- AC1: loading ---

func test_unit_loads_with_its_strength() -> void:
	var r := unit_load()
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	check(r.cards.has("levy"), "Levy loaded")
	if r.cards.has("levy"):
		eq(r.cards.levy.type, CardDef.UNIT, "type")
		eq(r.cards.levy.strength, 2, "strength")
		check(r.cards.levy.is_permanent(), "a unit is permanent")


func test_bad_unit_strength_is_a_load_error() -> void:
	check_cases([
		["missing", [{"id": "x", "name": "X", "type": "unit"}], ["card 'x'", "strength"], "one_error"],
		["below 1", [{"id": "x", "name": "X", "type": "unit", "strength": 0}], ["card 'x'", "strength"], "one_error"],
		["not an int", [{"id": "x", "name": "X", "type": "unit", "strength": "two"}], ["card 'x'", "strength"], "one_error"],
		["on a building", [{"id": "x", "name": "X", "type": "building", "strength": 2}],
			"card 'x': 'strength' only applies to units", "warning_only"],
	], unit_load)


func test_unit_with_fixed_land_is_a_load_error() -> void:
	var land := {"op": "grow", "amount": 1, "where": "here", "trigger": "upkeep"}
	var keyword := {"op": "gain", "resource": "food", "amount": 1, "keyword": "mountain"}
	check_cases([
		["requires", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "requires": ["mountain"]}],
			["card 'x'", "a unit can't have 'requires'"], "one_error"],
		["keyword effect", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "effects": [keyword]}],
			["card 'x'", "a unit effect can't use 'keyword'"], "one_error"],
		["grow here", [{"id": "x", "name": "X", "type": "unit", "strength": 1, "effects": [land]}],
			["card 'x'", "a unit effect can't act on its own territory"], "one_error"],
		["grow each", [{"id": "x", "name": "X", "type": "unit", "strength": 1,
			"effects": [{"op": "grow", "amount": 1, "where": "each"}]}], [], "warning_only"],
	], unit_load)


func test_unit_decks_in_config() -> void:
	var r := unit_load()
	eq(r.errors, [] as Array[String], "cards load")
	check_cases([
		["territory_deck", {"territory_deck": {"levy": 1}}, "territory_deck: 'levy' is not a territory"],
		["research_deck", {"research_deck": {"levy": 1}}, "research_deck: 'levy' is not a tech"],
		["event_deck", {"event_deck": {"levy": 1}}, "event_deck: 'levy' is not a event"],
	], func(o): return config_errors_for(r.cards, o))
	eq(config_errors_for(r.cards, {"supply": {"levy": {"price": 2, "count": 6}}}, {"levy": 2}), [] as Array[String],
		"a unit in the deck and the supply")


# --- AC2: recruiting ---

func test_playing_a_unit_puts_it_on_its_home() -> void:
	var e: GameEngine = recruit_engine()
	if e == null:
		return
	var home := home_uid(e)
	var slots: int = e.free_slots(home)
	var levy := first_in_hand(e)
	check(e.play_card(levy, home), "Levy played")
	var card: CardInstance = e.zone("tableau").find(levy)
	check(card != null, "Levy in the tableau")
	if card != null:
		eq(card.territory_uid, home, "home")
	eq(e.unit_station(levy), home, "station")
	eq(e.resources.food, 2, "food 3 - 1")
	eq(e.state.actions_used, 1, "one action used")
	eq(e.free_slots(home), slots, "no slot used")


func test_unit_station_is_minus_1_for_anything_else() -> void:
	var e: GameEngine = recruit_engine()
	if e == null:
		return
	var levy := first_in_hand(e)
	eq(e.unit_station(levy), -1, "a unit in the hand")
	eq(e.unit_station(uid_of(e.zone("tableau"), "farm")), -1, "a building")
	eq(e.unit_station(9999), -1, "no card")


func test_station_survives_a_state_copy() -> void:
	var e: GameEngine = recruit_engine()
	if e == null:
		return
	var levy := first_in_hand(e)
	e.play_card(levy, home_uid(e))
	eq(e.fork().unit_station(levy), home_uid(e), "the fork's station")


# --- AC3: workers ---

func test_unit_uses_a_worker_on_its_home() -> void:
	var e: GameEngine = recruit_engine()
	if e == null:
		return
	var home := home_uid(e)
	e.play_card(first_in_hand(e), home)
	eq(e.free_workers(home), 0, "2 pop - Farm - Levy")
	var levy := first_in_hand(e)
	eq(e.valid_targets(levy), [] as Array[int], "no target for another Levy")
	eq(e.play_error(levy), "No territory with a free worker: every pop already works a building or unit.", "another Levy")
	var farm := put_in_hand(e, "farm")
	e.resources.food = 10
	eq(e.play_error(farm), "No territory with a free worker: every pop already works a building or unit.", "a Farm")


func test_units_need_no_worker_without_population() -> void:
	var e: GameEngine = unit_engine(-1)
	if e == null:
		return
	var home := home_uid(e)
	for i in 3:
		var levy := first_in_hand(e)
		eq(e.play_error(levy), "", "Levy %d" % (i + 1))
		check(e.play_card(levy, home), "Levy %d played" % (i + 1))


# --- AC4: targets ---

## A unit_engine game with Grassland settled at 1 pop and Hills on the frontier.
func two_homes_engine() -> GameEngine:
	var e := unit_engine(2, {"levy": 10}, {"territory_deck": {"grassland": 1, "hills": 1}})
	if e != null:
		settle(e, ["grassland"])
		to_frontier(e, ["hills"])
		e.zone("tableau").find(uid_of(e.zone("tableau"), "grassland")).pop = 1
	return e


func test_unit_chooses_between_territories_with_a_free_worker() -> void:
	var e: GameEngine = two_homes_engine()
	if e == null:
		return
	var home := home_uid(e)
	var grass := uid_of(e.zone("tableau"), "grassland")
	var levy := first_in_hand(e)
	check(e.needs_target_choice(levy), "a choice")
	eq(sorted(e.valid_targets(levy)), sorted([home, grass]), "both territories")
	eq(e.play_error(levy), "Choose a territory for Levy.", "no target given")
	eq(e.play_error(levy, home), "", "Homeland")
	eq(e.play_error(levy, grass), "", "Grassland")


func test_unit_refuses_invalid_targets() -> void:
	var e: GameEngine = two_homes_engine()
	if e == null:
		return
	var grass_card: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "grassland"))
	grass_card.pop = 0
	var levy := first_in_hand(e)
	eq(e.play_error(levy, uid_of(e.zone("frontier"), "hills")), "That target isn't valid.", "a frontier territory")
	eq(e.play_error(levy, grass_card.uid), "Grassland has no free worker: it has no pop, and a building or unit needs one.",
		"no free worker (347)")
	eq(e.play_error(levy, uid_of(e.zone("tableau"), "capital")), "That target isn't valid.", "a city")


# --- AC5: idle units ---

## A unit_engine game with a Farm placed on Homeland (2 pop), then a Levy played there: its uid.
func farm_then_levy(e: GameEngine) -> int:
	build_on(e, home_uid(e), ["farm"])
	var levy := first_in_hand(e)
	check(e.play_card(levy, home_uid(e)), "Levy played")
	return levy


func test_units_go_idle_after_earlier_buildings() -> void:
	var e: GameEngine = unit_engine(2)
	if e == null:
		return
	var levy := farm_then_levy(e)
	var farm := uid_of(e.zone("tableau"), "farm")
	set_home_pop(e, 1)
	check(e.is_idle(levy), "the Levy is idle")
	check(not e.is_idle(farm), "the Farm works")
	eq(e.upkeep_forecast().food, 3, "forecast: Capital 2 + Farm 1, no Levy upkeep")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 3, "upkeep: Capital 2 + Farm 1, the idle Levy skipped")


func test_idle_unit_works_again_when_pop_returns() -> void:
	var e: GameEngine = unit_engine(2)
	if e == null:
		return
	var levy := farm_then_levy(e)
	set_home_pop(e, 1)
	e.end_turn()
	set_home_pop(e, 2)
	check(not e.is_idle(levy), "working again")
	eq(e.upkeep_forecast().food, 2, "forecast: Capital 2 + Farm 1 - Levy 1")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 2, "upkeep: the Levy eats again")


# --- AC6: text and score ---

func test_unit_text_shows_strength() -> void:
	var db: Dictionary = unit_load().cards
	check(db.has("levy"), "Levy loaded")
	if not db.has("levy"):
		return
	check("Strength 2" in db.levy.rules_text(db), "face: %s" % db.levy.rules_text(db))
	check("Strength 2" in db.levy.rules_tooltip(db), "tooltip: %s" % db.levy.rules_tooltip(db))


func test_unit_scores_its_printed_vp() -> void:
	var e: GameEngine = unit_engine(1)
	if e == null:
		return
	var before: int = e.score()
	var levy := first_in_hand(e)
	check(e.play_card(levy, home_uid(e)), "Levy played")
	eq(e.score() - before, 1, "Levy's 1 VP")
	set_home_pop(e, 0)
	check(e.is_idle(levy), "idle")
	eq(e.score() - before, 1, "an idle Levy keeps its VP")


# --- AC8: what the territory view and details show ---

func test_units_at_lists_the_units_stationed_on_a_territory() -> void:
	var e: GameEngine = unit_engine(3)
	var home := home_uid(e)
	build_on(e, home, ["farm"])
	var first := first_in_hand(e)
	e.play_card(first, home)
	var second := first_in_hand(e)
	e.play_card(second, home)
	eq(e.units_at(home), [first, second] as Array[int], "both Levies, in the order recruited")
	eq(e.units_at(uid_of(e.zone("tableau"), "capital")), [] as Array[int], "a city has none")


func test_details_and_tooltip_count_units_as_workers() -> void:
	var e: GameEngine = unit_engine(1)
	var home := home_uid(e)
	var levy := first_in_hand(e)
	e.play_card(levy, home)
	check("Free workers: 0 (each building or unit needs one)" in e.territory_tooltip(home), e.territory_tooltip(home))
	set_home_pop(e, 0)
	var state: Array[String] = []
	state.assign(e.card_details(levy).state)
	has_msg(state, "Idle: no free worker (skips upkeep)")
	check(e.card_details(levy).terms.any(func(t): return t.term == "Workers"), "the Workers term")
