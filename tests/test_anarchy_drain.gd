extends "res://tests/lib/anarchy_case.gd"
## Anarchy's drain (backlog 156): config unrest.drain_pct (0 to 100, absent = 0): each turn that starts under Anarchy
## (after any fall that turn, before the draw) loses that share of stored food and wealth, rounded up; the upkeep
## forecast includes it when Anarchy will rule next turn. Fixtures: tests/lib/anarchy_case.gd.

const DRAIN := {"drain_pct": 20}
const HUNGRY := {"population": {"start": 6, "food_upkeep": 1, "vp_per_pop": 0, "famine": FAMINE}}


## An anarchy game (block merged into the unrest block) that falls into Anarchy at turn 2's start with food and wealth
## after upkeep and feeding: they are set from the forecast before the turn ends.
func drained_engine(food: int, wealth: int, block := DRAIN, overrides := {}) -> GameEngine:
	var e := anarchy_engine(block, overrides)
	var f := e.upkeep_forecast()
	e.resources["food"] = food - f.food
	e.resources["wealth"] = wealth - f.wealth
	e.resources["unrest"] = 5
	e.end_turn()
	return e


# --- AC1: the config field ---

func test_drain_pct_loads_and_is_optional() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(anarchy_raw(DRAIN), RESOURCES, anarchy_db(), "config.json", errors, warnings)
	eq([errors, warnings], [[] as Array[String], [] as Array[String]], "errors and warnings")
	eq(config.unrest.get("drain_pct"), 20, "drain_pct")
	var none := DataLoader.parse_config(anarchy_raw(), RESOURCES, anarchy_db(), "config.json", errors, warnings)
	eq(none.unrest.get("drain_pct", 0), 0, "absent: no drain")


func test_drain_pct_validation() -> void:
	var message := "config.json: unrest.drain_pct: must be an integer from 0 to 100"
	check_cases([
		["-1", anarchy_raw({"drain_pct": -1}), message],
		["101", anarchy_raw({"drain_pct": 101}), message],
		["not a number", anarchy_raw({"drain_pct": "20"}), message],
		["a fraction", anarchy_raw({"drain_pct": 2.5}), message],
	], raw_config_errors)


# --- AC2: a turn under Anarchy drains ---

func test_a_turn_under_anarchy_loses_a_share_of_food_and_wealth() -> void:
	var before := anarchy_engine(DRAIN)
	var insight: int = before.resources.insight + before.upkeep_forecast().insight
	var e := drained_engine(10, 7)
	eq(ruling(e), "anarchy", "fell into Anarchy at turn 2's start")
	eq([e.resources.food, e.resources.wealth], [8, 5], "20% of 10 and of 7, rounded up: 2 and 2")
	eq(e.resources.insight, insight, "insight untouched")
	check(e.state.log_lines.any(func(l): return l.contains("Anarchy") and l.contains("food")),
		"a log line names Anarchy: %s" % [e.state.log_lines.slice(-6)])


func test_nothing_is_lost_from_empty_stores() -> void:
	var e := drained_engine(0, 7, DRAIN, HUNGRY)
	eq([e.resources.food, e.resources.wealth], [0, 5], "0 food: nothing lost; wealth still drained")


# --- AC3: no drain without Anarchy ---

func test_no_drain_without_anarchy() -> void:
	var e := anarchy_engine(DRAIN)
	var f := e.upkeep_forecast()
	var expected := [e.resources.food + f.food, e.resources.wealth + f.wealth]
	e.end_turn()
	eq([e.resources.food, e.resources.wealth], expected, "unrest below the limit: just upkeep")


func test_no_drain_with_drain_0() -> void:
	var e := drained_engine(10, 7, {})
	eq([e.resources.food, e.resources.wealth], [10, 7], "drain_pct absent")


# --- AC4: the forecast ---

## The forecast's food and wealth on two otherwise equal games, one with drain 20 and one without, after prepare.
func forecasts(prepare: Callable) -> Array:
	var out := []
	for block in [DRAIN, {}]:
		var e := anarchy_engine(block)
		prepare.call(e)
		var f := e.upkeep_forecast()
		out.append([f.food, f.wealth, e.resources.food + f.food, e.resources.wealth + f.wealth])
	return out


func test_the_forecast_includes_the_drain_when_a_revolution_is_pending() -> void:
	var r := forecasts(func(e: GameEngine):
		e.resources["unrest"] = 2
		e.revolt())
	var plain: Array = r[1]
	eq([r[0][0], r[0][1]], [plain[0] - ceili(plain[2] * 0.2), plain[1] - ceili(plain[3] * 0.2)],
		"the drain on the stores after upkeep")


func test_the_forecast_includes_the_drain_while_anarchy_has_2_counters_left() -> void:
	var fallen := func(e: GameEngine):
		e.resources["unrest"] = 5
		e.end_turn()
	var r := forecasts(fallen)
	var plain: Array = r[1]
	eq([r[0][0], r[0][1]], [plain[0] - ceili(plain[2] * 0.2), plain[1] - ceili(plain[3] * 0.2)], "4 counters left")
	var last := forecasts(func(e: GameEngine):
		fallen.call(e)
		e.set_unrest(1))
	eq(last[0], last[1], "1 counter left: Anarchy ends this turn, no drain forecast")


func test_the_forecast_has_no_drain_without_anarchy_ahead() -> void:
	var r := forecasts(func(_e: GameEngine): pass)
	eq(r[0], r[1], "no Anarchy, no revolution")
