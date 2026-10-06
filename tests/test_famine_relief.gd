extends "res://tests/lib/test_case.gd"
## Relieving a Famine with wealth (backlog 084): relieve_famine() pays population.famine.relief and the Famine leaves
## the game at once; relieve_famine_error() says why it can't. Setup as in test_famine.gd (population on, Capital
## +2 food), with relief {"wealth": 5}.

const POP := {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}
const RELIEF := {"wealth": 5}


## A game with relief on the famine block (none when relief is {}), the Homeland at home_pop and food and wealth on
## hand. overrides replace config keys.
func relief_engine(home_pop: int, food := 0, wealth := 0, relief: Dictionary = RELIEF, overrides := {}) -> GameEngine:
	var famine: Dictionary = FAMINE.duplicate()
	if not relief.is_empty():
		famine["relief"] = relief
	var o := {"population": POP.merged({"famine": famine})}
	o.merge(overrides, true)
	var e: GameEngine = make_engine({"farm": 10}, o)
	set_home_pop(e, home_pop)
	e.resources.food = food
	e.resources.wealth = wealth
	return e


## relief_engine at 4 pop after two hungry upkeeps: a Famine with 2 counters, 1 pop left, then wealth on hand.
## overrides replace config keys.
func two_counter_engine(wealth: int, overrides := {}) -> GameEngine:
	var e := relief_engine(4, 0, 0, RELIEF, overrides)
	e.end_turn()  # famine 1: 4 -> 3
	e.end_turn()  # famine 2: 3 -> 1
	check(e.famine_counters() == 2, "a Famine with 2 counters")
	e.resources.wealth = wealth
	return e


## Card ids named famine in every zone.
func famines_anywhere(e: GameEngine) -> int:
	var n := 0
	for z in GameEngine.ZONES:
		n += card_ids(e.zone(z)).count("famine")
	return n


## What a refused relief must leave alone.
func snapshot(e: GameEngine) -> Array:
	return [e.resources.duplicate(), e.famine_counters(), famines_anywhere(e), e.total_pop(), e.turn]


# --- AC1: relief ---

func test_relieving_pays_wealth_and_the_famine_leaves_the_game() -> void:
	var e := two_counter_engine(7)
	var changes := [0]
	e.changed.connect(func(): changes[0] += 1)
	check(e.relieve_famine(), "relieve_famine")
	eq(e.resources.wealth, 2, "wealth: 7 - 5")
	eq(famines_anywhere(e), 0, "the Famine is in no zone")
	eq(e.famine_counters(), 0, "no counters")
	eq(changes[0], 1, "changed emitted once")
	var pop := e.total_pop()
	var festival := put_in_hand(e, "festival")
	check(e.play_card(festival), "play Festival: %s" % e.play_error(festival))
	eq(e.total_pop(), pop + 1, "growth works again")


## Backlog 116: relieving the famine is a notice.
func test_relieving_the_famine_is_a_notice() -> void:
	var e := two_counter_engine(7)
	var recorded := record_messages(e)
	check(e.relieve_famine(), "relieve_famine")
	check_noticed(recorded, "Relieved the famine", GameEngine.NOTICE_INFO)


func test_a_short_upkeep_after_relief_brings_a_new_famine_with_1_counter() -> void:
	var e := two_counter_engine(7)
	check(e.relieve_famine(), "relieve_famine")
	set_home_pop(e, 4)
	e.resources.food = 0
	e.end_turn()  # +2, 4 pop: short
	eq(e.famine_counters(), 1, "a new Famine with 1 counter")


# --- AC2: rejections ---

func test_relieve_famine_error_names_each_reason_and_relief_changes_nothing() -> void:
	var over := relief_engine(4, 0, 20, RELIEF, {"turn_limit": 2})
	over.end_turn()  # famine 1
	over.end_turn()  # the game ends
	check(over.is_over, "the game is over")
	var choice := two_counter_engine(20, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(choice.play_card(put_in_hand(choice, "explorer")), "play Explorer")
	check(not choice.pending().is_empty(), "an explore choice is open")
	var cases := [
		["no famine", relief_engine(2, 10, 20), "There is no famine."],
		["3 wealth", two_counter_engine(3), "Relieving the famine needs 5 wealth (you have 3)."],
		["game over", over, "The game is over."],
		["explore choice open", choice, "Choose a territory first."],
	]
	for row in cases:
		var e: GameEngine = row[1]
		eq(e.relieve_famine_error(), row[2], "%s: relieve_famine_error" % row[0])
		var before := snapshot(e)
		check(not e.relieve_famine(), "%s: relieve_famine refused" % row[0])
		eq(snapshot(e), before, "%s: nothing changed" % row[0])


# --- AC3: forecast ---

## 173: a short price of several resources names each one you have.
func test_relief_short_of_a_two_resource_price_names_both() -> void:
	var e := relief_engine(4, 0, 0, {"food": 2, "wealth": 5})
	e.end_turn()  # a hungry upkeep brings the Famine
	e.resources.food = 0
	e.resources.wealth = 1
	eq(e.relieve_famine_error(), "Relieving the famine needs 2 food, 5 wealth (you have 0 food, 1 wealth).",
		"two resources")


func test_forecast_after_relief_is_0_when_fed_else_1() -> void:
	var e := two_counter_engine(20)
	check(e.relieve_famine(), "relieve")
	set_home_pop(e, 2)
	e.resources.food = 0
	eq(e.upkeep_forecast().starve, 0, "+2 food feeds 2 pop")
	set_home_pop(e, 4)
	eq(e.upkeep_forecast().starve, 1, "short: a new Famine's first death")


# --- AC4: loader ---

func relief_errors(relief: Variant) -> Array[String]:
	var famine: Dictionary = FAMINE.duplicate()
	famine["relief"] = relief
	return config_errors_for(fixture_load([]).cards, {"population": POP.merged({"famine": famine})})


func test_famine_relief_validation() -> void:
	eq(relief_errors({"wealth": 5}), [] as Array[String], "a valid relief")
	check_cases([
		["not an object", 5, "population.famine.relief"],
		["unknown resource", {"gold": 5}, "population.famine.relief: unknown resource 'gold'"],
		["0", {"wealth": 0}, "population.famine.relief: 'wealth' must be an integer >= 1"],
		["not an integer", {"wealth": "x"}, "population.famine.relief: 'wealth' must be an integer >= 1"],
		["empty", {}, "population.famine.relief"],
	], relief_errors)


func test_a_famine_without_relief_cant_be_relieved() -> void:
	var e := relief_engine(4, 0, 20, {})
	e.end_turn()  # famine 1
	eq(e.relieve_famine_error(), "The famine can't be relieved.", "no relief configured")
	check(not e.relieve_famine(), "refused")


# --- UI support: the price for the Relieve button ---

func test_famine_relief_is_the_configured_price_or_empty() -> void:
	var e: GameEngine = relief_engine(4)
	eq(e.famine_relief(), RELIEF, "the configured relief")
	e = relief_engine(4, 0, 0, {})
	eq(e.famine_relief(), {}, "no relief configured")
	eq(make_engine({"farm": 10}).famine_relief(), {}, "population off")
