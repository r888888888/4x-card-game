extends "res://tests/lib/test_case.gd"
## The gain_per_keyword op (backlog 081): gains amount × the settled territories (tableau) that have any of the listed
## keywords, printed or rolled. Fixtures are local (not in TEST_CARDS) so other tests load while the op is missing.
## TEST_CARDS territories: homeland (no keywords), hills [mountain], river [fresh_water, flood_plain].

const HUNT := {"op": "gain_per_keyword", "resource": "food", "amount": 1, "keywords": ["mountain", "fresh_water"]}


## An action "x" with effect.
func action(effect: Dictionary) -> Dictionary:
	return {"id": "x", "name": "X", "type": "action", "effects": [effect]}


## TEST_CARDS plus extra, parsed with the fixture keywords and resource keyword gold; returns {cards, errors, warnings}.
func load_with(extra: Array) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var gold: Array[String] = ["gold"]
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + extra}, resources(), "cards.json", errors, warnings,
		keywords(), gold)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## Loader result for one action x with effect.
func load_action(effect: Dictionary) -> Dictionary:
	return load_with([action(effect)])


## HUNT with key set to value (or removed when value is null).
func hunt_with(key: String, value: Variant) -> Dictionary:
	var effect := HUNT.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


## A game on TEST_CARDS plus extra, with territory_deck hills and river, a deck of farms, and 0 food.
func engine_with(extra: Array) -> GameEngine:
	var r := load_with(extra)
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


## Plays a new copy of action x (effect) in a game with territories settled; returns the engine.
func play_x(effect: Dictionary, settled: Array) -> Object:
	var e: Object = engine_with([action(effect)])
	settle(e, settled)
	e.resources.food = 0
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "play x: %s" % e.play_error(uid))
	return e


# --- AC1: count ---

func test_gains_amount_per_settled_territory_with_a_keyword() -> void:
	eq(play_x(HUNT, ["hills", "river"]).resources.food, 2, "hills (mountain) + river (fresh_water), 1 each")
	eq(play_x(hunt_with("amount", 2), ["hills", "river"]).resources.food, 4, "2 territories × 2")


func test_count_territories_with_query() -> void:
	var e: Object = engine_with([])
	settle(e, ["hills", "river"])
	eq(e.count_territories_with(["mountain", "fresh_water"] as Array[String]), 2, "hills and river")
	eq(e.count_territories_with(["flood_plain"] as Array[String]), 1, "river")
	eq(e.count_territories_with(["desert"] as Array[String]), 0, "none")


# --- AC2: any-of, once each ---

func test_a_territory_with_several_listed_keywords_counts_once() -> void:
	var e := play_x(hunt_with("keywords", ["fresh_water", "flood_plain"]), ["river"])
	eq(e.resources.food, 1, "river has both keywords, counted once")


# --- AC3: only settled territories ---

func test_frontier_territories_do_not_count() -> void:
	var e: Object = engine_with([action(HUNT)])
	to_frontier(e, ["hills"])
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "the play succeeds with nothing to count: %s" % e.play_error(uid))
	eq(e.resources.food, 0, "hills in the frontier doesn't count; homeland has no keywords")
	check(e.zone("discard").find(uid) != null, "x went to the discard")


# --- AC4: rolled resource keywords ---

func test_rolled_resource_keywords_count() -> void:
	var e: Object = engine_with([action(hunt_with("keywords", ["gold"]))])
	settle(e, ["hills"])
	var hills: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "hills"))
	hills.keywords.append("gold")  # as if rolled at setup
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "play x: %s" % e.play_error(uid))
	eq(e.resources.food, 1, "hills with rolled gold")


# --- AC5: upkeep ---

func test_upkeep_gain_per_keyword_is_forecast_and_given() -> void:
	var upkeep := {"op": "gain_per_keyword", "resource": "wealth", "amount": 1, "keywords": ["mountain"], "trigger": "upkeep"}
	var hut := {"id": "hut", "name": "Hut", "type": "building", "effects": [upkeep]}
	var e: Object = engine_with([hut])
	settle(e, ["hills"])
	build_on(e, home_uid(e), ["hut"])
	eq(e.upkeep_forecast().wealth, 1, "forecast: 1 mountain territory")
	e.end_turn()
	eq(e.resources.wealth, 1, "the next upkeep gives it")


# --- AC6: loader and card text ---

func test_gain_per_keyword_loads() -> void:
	var r := load_action(HUNT)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	var no_amount := load_action(hunt_with("amount", null))
	eq(no_amount.errors, [] as Array[String], "amount is optional")
	if no_amount.cards.has("x"):
		eq(no_amount.cards.x.effects[0].get("amount"), 1, "amount defaults to 1")
	eq(load_action(hunt_with("keywords", ["gold"])).errors, [] as Array[String], "a resource keyword is known")


func test_gain_per_keyword_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["missing keywords", hunt_with("keywords", null), prefix + "'keywords'"],
		["empty keywords", hunt_with("keywords", []), prefix + "'keywords'"],
		["keywords not a list", hunt_with("keywords", "mountain"), prefix + "'keywords'"],
		["unknown keyword", hunt_with("keywords", ["mountain", "swamp"]), [prefix, "unknown keyword 'swamp' in 'keywords'"]],
		["missing resource", hunt_with("resource", null), prefix + "missing 'resource'"],
		["amount 0", hunt_with("amount", 0), prefix + "'amount' must be an integer >= 1"],
		["amount not an integer", hunt_with("amount", 1.5), prefix + "'amount' must be an integer >= 1"],
	], func(effect): return load_action(effect).errors)


func test_gain_per_keyword_may_trigger_on_upkeep() -> void:
	var upkeep := HUNT.duplicate(true)
	upkeep["trigger"] = "upkeep"
	var r := load_with([{"id": "hut", "name": "Hut", "type": "building", "effects": [upkeep]}])
	eq(r.errors, [] as Array[String], "errors")


func test_gain_per_keyword_card_text() -> void:
	var cards: Dictionary = load_action(HUNT).cards
	if not cards.has("x"):
		check(false, "x should load")
		return
	eq(cards.x.rules_text(cards), "+1 food per mountain or fresh water territory", "rules_text")
	eq(cards.x.rules_tooltip(cards), "+1 food for each settled territory with Mountain or Fresh Water", "rules_tooltip")
