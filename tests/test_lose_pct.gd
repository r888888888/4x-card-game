extends "res://tests/lib/test_case.gd"
## The lose_pct op (backlog 268): takes pct% of the stored resource, rounded up (as Anarchy's drain does), never below
## 0. May trigger on upkeep. Fixtures are local, not in TEST_CARDS, so other tests load while the op is missing.

const FIRE := {"op": "lose_pct", "resource": "food", "pct": 25}


## A card "x" of type with effects.
func card_x(type: String, effects: Array) -> Dictionary:
	return {"id": "x", "name": "X", "type": type, "effects": effects}


## Loader result for one action x with effect.
func load_action(effect: Dictionary) -> Dictionary:
	return fixture_load([card_x("action", [effect])])


## FIRE with key set to value (or removed when value is null).
func fire_with(key: String, value: Variant) -> Dictionary:
	var effect := FIRE.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


## A game on TEST_CARDS plus extra, with a deck of farms.
func engine_with(extra: Array) -> GameEngine:
	var r := fixture_load(extra)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {}), resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	return e


## Plays a new action x (effect) with food on hand; returns [engine, card_played outcomes].
func play_with_food(effect: Dictionary, food: int) -> Array:
	var outcomes: Array[Dictionary] = []
	var e: GameEngine = engine_with([card_x("action", [effect])])
	e.resources.food = food
	e.card_played.connect(func(o: Dictionary): outcomes.append(o))
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "play x: %s" % e.play_error(uid))
	eq(outcomes.size(), 1, "card_played once")
	return [e, outcomes]


# --- AC1: a share, rounded up ---

func test_lose_pct_takes_a_share_of_the_store_rounded_up() -> void:
	var played := play_with_food(FIRE, 7)
	eq(played[0].resources.food, 5, "25% of 7 is 1.75, rounded up to 2")
	if played[1].size() == 1:
		eq(played[1][0].lost, {"food": 2}, "lost reports 2 food")


func test_lose_pct_of_an_empty_store_takes_nothing() -> void:
	var played := play_with_food(FIRE, 0)
	eq(played[0].resources.food, 0, "still 0")
	if played[1].size() == 1:
		eq(played[1][0].lost, {}, "nothing lost")


# --- AC2: upkeep ---

func test_upkeep_lose_pct_is_forecast_and_taken() -> void:
	var upkeep := {"op": "lose_pct", "resource": "wealth", "pct": 50, "trigger": "upkeep"}
	var rot := {"id": "rot", "name": "Rot", "type": "event", "discard": {"turns": 2}, "effects": [upkeep]}
	var r := fixture_load([rot])
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"event_deck": {"rot": 1}}), resources(), r.cards,
		"config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	e.end_turn()  # Rot drawn as turn 2 starts
	eq(card_ids(e.zone("active_events")), ["rot"] as Array[String], "Rot active")
	e.resources.wealth = 6
	eq(e.upkeep_forecast().get("wealth", 0), -3, "forecast: half of 6 (the Capital makes only food)")
	e.end_turn()
	eq(e.resources.wealth, 3, "the next upkeep takes 3")


# --- AC4, AC5: loader and card text ---

func test_lose_pct_loads_and_may_trigger_on_upkeep() -> void:
	var r := load_action(FIRE)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	var upkeep := FIRE.duplicate(true)
	upkeep["trigger"] = "upkeep"
	eq(fixture_load([card_x("building", [upkeep])]).errors, [] as Array[String], "on upkeep")
	eq(load_action(fire_with("pct", 100)).errors, [] as Array[String], "100% is allowed")


func test_lose_pct_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["missing pct", fire_with("pct", null), prefix + "missing 'pct'"],
		["pct 0", fire_with("pct", 0), prefix + "'pct' must be an integer from 1 to 100"],
		["pct 101", fire_with("pct", 101), prefix + "'pct' must be an integer from 1 to 100"],
		["missing resource", fire_with("resource", null), prefix + "missing 'resource'"],
		["unknown resource", fire_with("resource", "gold"), prefix + "'resource'"],
	], func(effect): return load_action(effect).errors)


func test_lose_pct_card_text() -> void:
	var cards: Dictionary = load_action(FIRE).cards
	if not cards.has("x"):
		check(false, "x should load")
		return
	eq(cards.x.rules_text(cards), "−25% food", "rules_text")
	eq(cards.x.rules_tooltip(cards), "Lose 25% of stored food (rounded up)", "rules_tooltip")
