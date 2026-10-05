extends "res://tests/lib/test_case.gd"
## The lose_per_keyword op (backlog 268): the mirror of gain_per_keyword. Takes amount × the settled territories with
## any of the keywords (printed or rolled), never below 0. May trigger on upkeep. Fixtures are local, not in
## TEST_CARDS, so other tests load while the op is missing.
## TEST_CARDS territories: homeland (no keywords), hills [mountain], river [fresh_water, flood_plain].

const STORM := {"op": "lose_per_keyword", "resource": "food", "amount": 1, "keywords": ["mountain"]}
const GOLD: Array[String] = ["gold"]  # the resource keyword the loader is given


## An action "x" with effect.
func action(effect: Dictionary) -> Dictionary:
	return {"id": "x", "name": "X", "type": "action", "effects": [effect]}


## Loader result for one action x with effect.
func load_action(effect: Dictionary) -> Dictionary:
	return fixture_load([action(effect)], [], [], GOLD)


## STORM with key set to value (or removed when value is null).
func storm_with(key: String, value: Variant) -> Dictionary:
	var effect := STORM.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


## A game on TEST_CARDS plus extra, with territory_deck hills and river, a deck of farms, and 0 food and wealth.
func storm_engine(extra: Array) -> GameEngine:
	var r := fixture_load(extra, [], [], GOLD)
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"territory_deck": {"hills": 1, "river": 1}}),
		resources(), r.cards, "config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	e.resources.food = 0
	e.resources.wealth = 0
	return e


## Hills and River settled, River with a rolled mountain keyword: 2 territories with mountain (one printed, one
## rolled) and Homeland with none. Plays a new copy of action x (effect) with food on hand; returns the engine.
func play_x(effect: Dictionary, food: int) -> GameEngine:
	var e: GameEngine = storm_engine([action(effect)])
	settle(e, ["hills", "river"])
	e.zone("tableau").find(uid_of(e.zone("tableau"), "river")).keywords.append("mountain")
	e.resources.food = food
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "play x: %s" % e.play_error(uid))
	return e


# --- AC3: count, floor and none ---

func test_lose_per_keyword_takes_amount_per_matching_territory() -> void:
	eq(play_x(STORM, 5).resources.food, 3, "hills (printed) and river (rolled): 5 − 2")
	eq(play_x(storm_with("amount", 2), 5).resources.food, 1, "2 territories × 2")


func test_lose_per_keyword_never_goes_below_zero() -> void:
	eq(play_x(STORM, 1).resources.food, 0, "1 − 2 stops at 0")


func test_lose_per_keyword_with_no_matching_territory_takes_nothing() -> void:
	eq(play_x(storm_with("keywords", ["gold"]), 5).resources.food, 5, "no territory has gold")


# --- upkeep ---

func test_upkeep_lose_per_keyword_is_forecast_and_taken() -> void:
	var upkeep := {"op": "lose_per_keyword", "resource": "wealth", "amount": 1, "keywords": ["mountain"], "trigger": "upkeep"}
	var hut := {"id": "hut", "name": "Hut", "type": "building", "effects": [upkeep]}
	var e: GameEngine = storm_engine([hut])
	settle(e, ["hills"])
	build_on(e, home_uid(e), ["hut"])
	e.resources.wealth = 4
	eq(e.upkeep_forecast().get("wealth", 0), -1, "forecast: 1 mountain territory")
	e.end_turn()
	eq(e.resources.wealth, 3, "the next upkeep takes it")


# --- AC4, AC5: loader and card text ---

func test_lose_per_keyword_loads_and_may_trigger_on_upkeep() -> void:
	var r := load_action(STORM)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	var upkeep := STORM.duplicate(true)
	upkeep["trigger"] = "upkeep"
	eq(fixture_load([{"id": "hut", "name": "Hut", "type": "building", "effects": [upkeep]}], [], [], GOLD).errors,
		[] as Array[String], "on upkeep")
	var no_amount := load_action(storm_with("amount", null))
	eq(no_amount.errors, [] as Array[String], "amount is optional")
	if no_amount.cards.has("x"):
		eq(no_amount.cards.x.effects[0].get("amount"), 1, "amount defaults to 1")


func test_lose_per_keyword_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["missing keywords", storm_with("keywords", null), prefix + "'keywords'"],
		["empty keywords", storm_with("keywords", []), prefix + "'keywords'"],
		["unknown keyword", storm_with("keywords", ["mountain", "swamp"]), [prefix, "unknown keyword 'swamp' in 'keywords'"]],
		["missing resource", storm_with("resource", null), prefix + "missing 'resource'"],
		["amount 0", storm_with("amount", 0), prefix + "'amount' must be an integer >= 1"],
	], func(effect): return load_action(effect).errors)


func test_lose_per_keyword_card_text() -> void:
	var cards: Dictionary = load_action(STORM).cards
	if not cards.has("x"):
		check(false, "x should load")
		return
	eq(cards.x.rules_text(cards), "−1 food per mountain territory", "rules_text")
	eq(cards.x.rules_tooltip(cards), "−1 food for each settled territory with Mountain", "rules_tooltip")
