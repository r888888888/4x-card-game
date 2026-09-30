extends "res://tests/lib/test_case.gd"
## Wealth, the second resource (backlog 021): mixed costs, gaining wealth, carry over, and wealth
## never standing in for food. Test cards: Guildhall (2 food + 2 wealth), Stall (upkeep +1 wealth),
## Bazaar (+2 wealth per city).


## Loads one card named 'x' with the given cost and effects; returns {cards, errors}.
func load_x(cost: Dictionary, effects: Array = [], type := "building") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := {"cards": [{"id": "city", "name": "City", "type": "city"},
		{"id": "x", "name": "X", "type": type, "cost": cost, "effects": effects}]}
	var cards := DataLoader.parse_cards(raw, resources(), "cards.json", errors, warnings, keywords())
	return {"cards": cards, "errors": errors}


## Population on with the given food upkeep; starting resources and tableau as given.
func pop_overrides(food_upkeep: int, start_resources: Dictionary, tableau: Array = ["capital"]) -> Dictionary:
	return {
		"population": {"start": 2, "food_upkeep": food_upkeep, "vp_per_pop": 1},
		"starting": {"resources": start_resources, "tableau": tableau, "territory": "homeland"},
	}


# --- AC1: loader and card text ---

func test_wealth_cost_and_gains_load() -> void:
	var r := load_x({"food": 2, "wealth": 2}, [
		{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"},
		{"op": "gain_per_tag", "resource": "wealth", "amount": 2, "tag": "city"}])
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.cost, {"food": 2, "wealth": 2}, "cost")


func test_unknown_resource_cost_is_still_an_error() -> void:
	var r := load_x({"gold": 1})
	has_msg(r.errors, "cards.json: card 'x': cost: unknown resource 'gold'")


func test_wealth_card_text() -> void:
	var up := load_x({}, [{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}])
	eq(up.cards.x.rules_text(up.cards) if up.cards.has("x") else "<not loaded>", "⟳ +1 wealth", "upkeep gain")
	var per := load_x({}, [{"op": "gain_per_tag", "resource": "wealth", "amount": 2, "tag": "city"}], "action")
	eq(per.cards.x.rules_text(per.cards) if per.cards.has("x") else "<not loaded>", "+2 wealth per city", "per tag")


# --- AC2: starting wealth ---

func test_wealth_starts_at_0_when_not_listed() -> void:
	var e := make_engine({"farm": 10})
	eq(e.resources.get("wealth", -1), 0, "wealth")
	eq(e.resources.food, 4, "food: 2 start + 2 Capital")


func test_starting_wealth_from_config() -> void:
	var start := {"resources": {"food": 2, "wealth": 3}, "tableau": ["capital"], "territory": "homeland"}
	var e := make_engine({"farm": 10}, {"starting": start})
	eq(e.resources.get("wealth", -1), 3, "wealth")


# --- AC3: mixed cost ---

func test_mixed_cost_pays_both_resources() -> void:
	var e := make_engine({"guildhall": 10})
	e.resources.food = 3
	e.resources.wealth = 2
	var uid := first_in_hand(e)
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	check(e.play_card(uid), "play should succeed: %s" % e.play_error(uid))
	eq(e.resources.food, 1, "food 3 - 2")
	eq(e.resources.wealth, 0, "wealth 2 - 2")
	eq(card_ids(e.zone("tableau")), ["homeland", "capital", "guildhall"], "tableau")
	eq(outcomes.size(), 1, "one outcome")
	if outcomes.size() == 1:
		eq(outcomes[0].paid, {"food": 2, "wealth": 2}, "paid")


# --- AC4: can't afford ---

func test_short_of_wealth_is_rejected() -> void:
	var e := make_engine({"guildhall": 10})
	e.resources.food = 5
	e.resources.wealth = 1
	var uid := first_in_hand(e)
	eq(e.play_error(uid), "Guildhall needs 2 wealth (you have 1).", "error")
	check(not e.play_card(uid), "play should fail")
	eq(e.resources.food, 5, "food unchanged")
	eq(e.resources.wealth, 1, "wealth unchanged")
	eq(e.zone("hand").size(), 5, "hand unchanged")
	eq(card_ids(e.zone("tableau")), ["homeland", "capital"], "tableau unchanged")


func test_short_of_food_names_food() -> void:
	var e := make_engine({"guildhall": 10})
	e.resources.food = 1
	e.resources.wealth = 5
	eq(e.play_error(first_in_hand(e)), "Guildhall needs 2 food (you have 1).", "error")


# --- AC5: gaining wealth, carry over ---

func test_upkeep_gains_wealth_and_it_carries_over() -> void:
	var e := make_engine({"stall": 10})
	check(e.play_card(first_in_hand(e)), "play Stall")
	e.resources.wealth = 3
	e.end_turn()
	eq(e.resources.wealth, 4, "3 carried over + 1 Stall")
	for i in 3:
		e.end_turn()
	eq(e.resources.wealth, 7, "4 + 3 turns of Stall, never reset")


func test_gain_wealth_per_city() -> void:
	var e := make_engine({"bazaar": 10})
	check(e.play_card(first_in_hand(e)), "play Bazaar")
	eq(e.resources.wealth, 2, "0 + 2 per city (1 city)")
	eq(e.resources.food, 4, "food unchanged")


# --- AC6: wealth is not food ---

func test_starvation_does_not_spend_wealth() -> void:
	# A Village produces nothing, so 2 pop with 0 food go hungry at the first upkeep: a Famine kills 1 (083).
	var e := make_engine({"farm": 10}, pop_overrides(1, {"food": 0, "wealth": 5}, ["village"]))
	eq(e.pop(home_uid(e)), 1, "a Famine killed 1: 2 needed, 0 food")
	eq(e.resources.wealth, 5, "wealth untouched")


func test_growth_needs_food_not_wealth() -> void:
	var e := make_engine({"farm": 10}, pop_overrides(0, {"food": 0, "wealth": 10}, ["village"]))
	var home := home_uid(e)
	check("food" in e.grow_error(home), "error names food: '%s'" % e.grow_error(home))
	check(not e.grow(home), "grow fails")
	eq(e.pop(home), 2, "pop unchanged")
	eq(e.resources.wealth, 10, "wealth unchanged")
