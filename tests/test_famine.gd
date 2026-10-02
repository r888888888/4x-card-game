extends "res://tests/lib/test_case.gd"
## The Famine (backlog 083) replaces starvation: a short upkeep brings a lasting Famine event with a counter (up to
## max_counters), each counter kills 1 pop (the lose_pop rule), growth stops, and a fed upkeep ends it. The fixture
## Famine card and the famine block come from test_case (TEST_CARDS, FAMINE via raw_config).

const POP := {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}


## A game (population on, Capital +2 food) at turn 1, with the Homeland at home_pop and food on hand. extra cards are
## built on the Homeland.
func famine_engine(home_pop: int, food := 0, extra: Array = []) -> GameEngine:
	var e: GameEngine = make_engine({"farm": 10}, {"population": POP})
	e.zone("tableau").find(home_uid(e)).pop = home_pop
	build_on(e, home_uid(e), extra)
	e.resources.food = food
	return e


func home_pop(e: GameEngine) -> int:
	return e.pop(home_uid(e))


## Card ids named id in every zone.
func famines_anywhere(e: GameEngine) -> int:
	var n := 0
	for z in GameEngine.ZONES:
		n += card_ids(e.zone(z)).count("famine")
	return n


# --- AC1: arrives ---

func test_a_short_upkeep_brings_a_famine_with_1_counter() -> void:
	var e := famine_engine(4)
	e.end_turn()  # +2, 4 pop eat 2: short
	eq(card_ids(e.zone("active_events")), ["famine"] as Array[String], "a Famine is active")
	eq(e.famine_counters(), 1, "1 counter")
	eq(home_pop(e), 3, "1 pop dies, not 2 (one per food short)")
	eq(e.resources.food, 0, "food")


## Backlog 116: a famine arriving and ending are notices.
func test_a_famine_arriving_and_ending_are_notices() -> void:
	var e := famine_engine(4)
	var recorded := record_messages(e)
	e.end_turn()  # +2, 4 pop eat 2: short
	check_noticed(recorded, "Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
	e.resources.food = 10
	e.end_turn()  # fed
	check_noticed(recorded, "Famine ends.", GameEngine.NOTICE_INFO)


## Backlog 116: pop eating and fed upkeeps are not notices.
func test_fed_upkeeps_are_not_notices() -> void:
	var e := famine_engine(2, 10)
	var recorded := record_messages(e)
	e.end_turn()
	e.end_turn()
	check(recorded.any(func(l: String): return l.begins_with("log: Pop eats")), "pop ate: %s" % [recorded])
	eq(notices_in(recorded), [] as Array[String], "no notices")


# --- AC2: escalates ---

func test_a_famine_escalates_each_hungry_upkeep() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.end_turn()  # +2, 3 pop: short
	eq(e.famine_counters(), 2, "2 counters")
	eq(home_pop(e), 1, "2 more die: 3 -> 1")


func test_famine_deaths_use_the_most_pop_rule() -> void:
	var e: GameEngine = make_engine({"farm": 10}, {"population": POP, "territory_deck": {"hills": 1}})
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	e.zone("tableau").find(home_uid(e)).pop = 2
	e.zone("tableau").find(hills).pop = 3
	e.resources.food = 0
	e.end_turn()  # +2, 5 pop: short, 1 death
	eq(e.pop(hills), 2, "Hills has the most pop")
	eq(home_pop(e), 2, "Homeland untouched")


# --- AC3: cap and one Famine ---

func test_counters_stop_at_max_and_there_is_one_famine() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1
	e.zone("active_events").cards[0].counters = 3
	e.zone("tableau").find(home_uid(e)).pop = 6
	e.resources.food = 0
	e.end_turn()  # +2, 6 pop: short
	eq(e.famine_counters(), 3, "stays at max_counters 3")
	eq(home_pop(e), 3, "3 die: 6 -> 3")
	eq(card_ids(e.zone("active_events")).count("famine"), 1, "one Famine")


# --- AC4: ends ---

func test_a_fed_upkeep_ends_the_famine_and_it_leaves_the_game() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.end_turn()  # famine 2: 3 -> 1
	e.resources.food = 0
	e.end_turn()  # +2, 1 pop eats 1: fed
	eq(home_pop(e), 1, "nobody dies")
	eq(e.famine_counters(), 0, "no counters")
	eq(famines_anywhere(e), 0, "the Famine is in no zone")


func test_fed_with_exactly_0_food_left_ends_the_famine() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.zone("tableau").find(home_uid(e)).pop = 2
	e.resources.food = 0
	e.end_turn()  # +2, 2 pop eat 2: food 0, fed
	eq(e.resources.food, 0, "food 0")
	eq(e.famine_counters(), 0, "ended")
	eq(home_pop(e), 2, "nobody dies")


func test_a_later_short_upkeep_brings_a_new_famine() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1
	e.zone("tableau").find(home_uid(e)).pop = 1
	e.end_turn()  # fed: ends
	e.zone("tableau").find(home_uid(e)).pop = 4
	e.resources.food = 0
	e.end_turn()  # short again
	eq(e.famine_counters(), 1, "a new Famine with 1 counter")


# --- AC5: no growth ---

func test_no_growth_during_a_famine() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.resources.food = 20
	var home := home_uid(e)
	eq(e.grow_error(home), "Famine: pop can't grow.", "grow_error")
	check(not e.grow(home), "grow refused")
	var rally := put_in_hand(e, "rally")
	check(e.play_card(rally, home), "Rally can still be played: %s" % e.play_error(rally, home))
	eq(home_pop(e), 3, "Rally adds no pop")


func test_growth_works_again_after_the_famine() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.zone("tableau").find(home_uid(e)).pop = 1
	e.end_turn()  # fed: ends
	e.resources.food = 20
	var home := home_uid(e)
	eq(e.grow_error(home), "", "grow allowed")
	check(e.grow(home), "grow")
	eq(home_pop(e), 2, "1 -> 2")


# --- AC6: the Granary guard ---

func test_a_guard_saves_the_first_famine_death_on_its_territory() -> void:
	var with_silo := famine_engine(4)
	with_silo.end_turn()  # famine 1: 4 -> 3
	with_silo.zone("tableau").find(home_uid(with_silo)).pop = 4
	build_on(with_silo, home_uid(with_silo), ["silo"])
	with_silo.resources.food = 0
	with_silo.end_turn()  # +2, 4 pop: short, famine 2: first death saved
	eq(with_silo.famine_counters(), 2, "2 counters")
	eq(home_pop(with_silo), 3, "with a Silo: 1 of 2 deaths")
	var without := famine_engine(4)
	without.end_turn()
	without.zone("tableau").find(home_uid(without)).pop = 4
	without.resources.food = 0
	without.end_turn()
	eq(home_pop(without), 2, "without: 2 deaths")


## Backlog 116: a building saving pop from the famine is a notice.
func test_a_guard_saving_pop_is_a_notice() -> void:
	var e := famine_engine(4)
	e.end_turn()  # famine 1: 4 -> 3
	e.zone("tableau").find(home_uid(e)).pop = 4
	build_on(e, home_uid(e), ["silo"])
	e.resources.food = 0
	var recorded := record_messages(e)
	e.end_turn()  # famine 2: first death saved
	check_noticed(recorded, "1 pop saved from famine", GameEngine.NOTICE_CAUTION)


# --- AC7: forecast ---

func test_forecast_starve_is_the_famines_deaths() -> void:
	var e := famine_engine(4)
	eq(e.upkeep_forecast().starve, 1, "no Famine yet: a new one kills 1")
	e.end_turn()  # famine 1: 4 -> 3
	e.resources.food = 0
	eq(e.upkeep_forecast().starve, 2, "the Famine would go to 2 counters")
	eq(e.upkeep_forecast().food, -1, "food: +2 made, 3 eaten")
	e.zone("tableau").find(home_uid(e)).pop = 1
	eq(e.upkeep_forecast().starve, 0, "pop would be fed")


# --- AC8: loader ---

## Loader errors for population overrides and extra cards (famine is not added for you here).
func population_errors(population: Variant, overrides := {}, extra: Array = []) -> Array[String]:
	return config_errors_for(fixture_load(extra).cards, overrides.merged({"population": population}, true))


func test_famine_config_validation() -> void:
	var pop := func(famine: Variant) -> Dictionary:
		var p := POP.duplicate()
		if famine != null:
			p["famine"] = famine
		return p
	check_cases([
		["missing famine", pop.call(null), "config.json: population.famine"],
		["unknown card", pop.call({"card": "zzz", "max_counters": 3}), "config.json: population.famine.card: unknown card 'zzz'"],
		["not an event", pop.call({"card": "farm", "max_counters": 3}), "population.famine.card 'farm' is not an event"],
		["max_counters 0", pop.call({"card": "famine", "max_counters": 0}), "population.famine: 'max_counters' must be an integer >= 1"],
	], func(p): return population_errors(p))
	eq(population_errors(pop.call(FAMINE)), [] as Array[String], "a valid famine block")


func test_the_famine_card_is_never_in_the_event_deck_and_has_no_discard() -> void:
	has_msg(population_errors(POP.merged({"famine": FAMINE}), {"event_deck": {"famine": 1}}), "event_deck: 'famine' is the famine card")
	var lasting := {"id": "blight", "name": "Blight", "type": "event", "discard": {"turns": 2}}
	has_msg(population_errors(POP.merged({"famine": {"card": "blight", "max_counters": 3}}), {}, [lasting]),
		"population.famine.card 'blight' can't have a discard")


# --- Design note: the event panel shows the Famine's counters ---

func test_event_counters_are_the_famines_and_0_for_other_events() -> void:
	var e := famine_engine(4)
	eq(e.event_counters(12345), 0, "an unknown uid")
	e.end_turn()  # famine 1
	var famine: int = uid_of(e.zone("active_events"), "famine")
	eq(e.event_counters(famine), 1, "the Famine's counters")
	e.end_turn()  # famine 2
	eq(e.event_counters(famine), 2, "after it gets worse")
