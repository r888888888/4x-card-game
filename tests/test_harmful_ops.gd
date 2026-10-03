extends "res://tests/lib/test_case.gd"
## Harmful ops (backlog 072): `lose` takes a resource (never below 0) and `lose_pop` takes pop from the territory with
## the most pop (ties: first in tableau order). Both may trigger on upkeep. Fixtures are local, not in TEST_CARDS or
## TEST_EVENTS, so other tests load while the ops are missing.

const LOSE_FOOD := {"op": "lose", "resource": "food", "amount": 2}
const LOSE_POP := {"op": "lose_pop", "amount": 1}
const POP := {"start": 3, "food_upkeep": 0, "vp_per_pop": 0}


## A card "x" of type with effects.
func card_x(type: String, effects: Array) -> Dictionary:
	return {"id": "x", "name": "X", "type": type, "effects": effects}


## A game on TEST_CARDS plus extra with config overrides; territory_deck holds hills and grassland.
func engine_with(extra: Array, overrides := {}) -> GameEngine:
	var r := fixture_load(extra)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var o := {"territory_deck": {"hills": 1, "grassland": 1}}
	o.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}, o), resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## Plays a new action x with effects in e; returns whether it was played.
func play_x(e: GameEngine) -> bool:
	var uid := put_in_hand(e, "x")
	var ok: bool = e.play_card(uid)
	check(ok, "play x: %s" % e.play_error(uid))
	return ok


# --- AC1: lose ---

func test_lose_takes_the_resource() -> void:
	var e: GameEngine = engine_with([card_x("action", [LOSE_FOOD])])
	e.resources.food = 5
	play_x(e)
	eq(e.resources.food, 3, "5 - 2")


func test_lose_never_goes_below_zero() -> void:
	var e: GameEngine = engine_with([card_x("action", [LOSE_FOOD])])
	e.resources.food = 1
	play_x(e)
	eq(e.resources.food, 0, "1 - 2 stops at 0")


func test_lose_works_for_wealth() -> void:
	var e: GameEngine = engine_with([card_x("action", [{"op": "lose", "resource": "wealth", "amount": 3}])])
	e.resources.wealth = 4
	play_x(e)
	eq(e.resources.wealth, 1, "4 - 3")


func test_a_drawn_event_with_lose_takes_food() -> void:
	var drought := {"id": "drought", "name": "Drought", "type": "event", "effects": [LOSE_FOOD]}
	var e: GameEngine = engine_with([drought], {"event_deck": {"drought": 1}})
	e.resources.food = 5
	var upkeep: int = e.upkeep_forecast().get("food", 0)
	e.end_turn()  # drawn as turn 2 starts, after upkeep (237)
	eq(card_ids(e.zone("active_events")), ["drought"] as Array[String], "Drought drawn")
	eq(e.resources.food, 5 + upkeep - 2, "5, then upkeep, then − 2 when drawn")


# --- AC2: loader ---

func test_lose_and_lose_pop_load_on_a_building() -> void:
	var r := fixture_load([card_x("building", [LOSE_FOOD, LOSE_POP])])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_lose_and_lose_pop_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["lose unknown resource", [card_x("action", [{"op": "lose", "resource": "gold", "amount": 1}])], prefix + "'resource' must be one of"],
		["lose missing resource", [card_x("action", [{"op": "lose", "amount": 1}])], prefix + "missing 'resource'"],
		["lose amount 0", [card_x("action", [{"op": "lose", "resource": "food", "amount": 0}])], prefix + "'amount' must be an integer >= 1"],
		["lose amount 1.5", [card_x("action", [{"op": "lose", "resource": "food", "amount": 1.5}])], prefix + "'amount' must be an integer >= 1"],
		["lose_pop amount 0", [card_x("action", [{"op": "lose_pop", "amount": 0}])], prefix + "'amount' must be an integer >= 1"],
		["lose_pop missing amount", [card_x("action", [{"op": "lose_pop"}])], prefix + "missing 'amount'"],
	], func(extra): return fixture_load(extra).errors)


# --- AC3: lose_pop ---

## A population game with the Homeland at home_pop and Hills settled at hills_pop; returns [engine, hills uid].
func lose_pop_engine(home_pop: int, hills_pop: int) -> Array:
	var e: GameEngine = engine_with([card_x("action", [LOSE_POP])], {"population": POP})
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	e.zone("tableau").find(home_uid(e)).pop = home_pop
	e.zone("tableau").find(hills).pop = hills_pop
	return [e, hills]


func test_lose_pop_takes_from_the_territory_with_the_most_pop() -> void:
	var p := lose_pop_engine(3, 1)
	var e: GameEngine = p[0]
	play_x(e)
	eq(e.pop(home_uid(e)), 2, "Homeland 3 - 1")
	eq(e.pop(p[1]), 1, "Hills unchanged")


func test_lose_pop_tie_takes_from_the_first_in_tableau_order() -> void:
	var p := lose_pop_engine(2, 2)
	var e: GameEngine = p[0]
	play_x(e)
	eq(e.pop(home_uid(e)), 1, "Homeland comes first in the tableau")
	eq(e.pop(p[1]), 2, "Hills unchanged")


func test_lose_pop_with_no_pop_does_nothing() -> void:
	var p := lose_pop_engine(0, 0)
	var e: GameEngine = p[0]
	play_x(e)
	eq(e.pop(home_uid(e)), 0, "Homeland stays at 0")
	eq(e.pop(p[1]), 0, "Hills stays at 0")


# --- AC4: upkeep ---

func test_upkeep_lose_is_in_the_forecast_and_applies() -> void:
	var hut := {"id": "hut", "name": "Hut", "type": "building", "effects": [
		{"op": "lose", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
	var e: GameEngine = engine_with([hut])
	build_on(e, home_uid(e), ["hut"])
	e.resources.food = 0
	eq(e.upkeep_forecast().food, 1, "Capital +2, Hut -1")
	e.end_turn()
	eq(e.resources.food, 1, "the next upkeep: 0 + 2 - 1")


func test_upkeep_lose_pop_applies_and_the_forecast_leaves_pop_alone() -> void:
	var hut := {"id": "hut", "name": "Hut", "type": "building", "effects": [
		{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]}
	var e: GameEngine = engine_with([hut], {"population": POP})
	build_on(e, home_uid(e), ["hut"])
	e.upkeep_forecast()
	eq(e.pop(home_uid(e)), 3, "the forecast changes no pop")
	e.end_turn()
	eq(e.pop(home_uid(e)), 2, "the next upkeep takes 1 pop")


# --- AC5: text and log ---

func test_lose_and_lose_pop_card_text() -> void:
	var r := fixture_load([card_x("action", [LOSE_FOOD]), {"id": "y", "name": "Y", "type": "action", "effects": [LOSE_POP]}])
	if not (r.cards.has("x") and r.cards.has("y")):
		check(false, "x and y should load: %s" % [r.errors])
		return
	eq(r.cards.x.rules_text(r.cards), "−2 food", "lose text")
	eq(r.cards.y.rules_text(r.cards), "−1 pop (largest territory)", "lose_pop text")


func test_the_log_names_the_source_card() -> void:
	var e: GameEngine = engine_with([card_x("action", [LOSE_FOOD])])
	e.resources.food = 5
	play_x(e)
	check(e.log_lines.any(func(l): return "X" in l and "−2 food" in l), "a log line names X and −2 food: %s" % [e.log_lines.slice(-3)])
