extends "res://tests/lib/test_case.gd"
## Growth cards (backlog 013): the grow op adds pop "here" (the card's territory) or in "each" settled
## territory, capped by housing and free of food.


## Population on (no food upkeep, no pop VP, settlement tiers when tiers isn't empty), Homeland pop start, 50 food.
## settled: extra territory ids moved straight to the tableau with pop 1 each.
func cards_engine(start: int, deck: Dictionary, settled: Array[String] = [], population := true, extra := [], tiers := []) -> GameEngine:
	var counts := {}
	for id in settled:
		counts[id] = counts.get(id, 0) + 1
	var o := {"territory_deck": counts}
	if population:
		o["population"] = {"start": start, "food_upkeep": 0, "vp_per_pop": 0}
		if not tiers.is_empty():
			o.population["tiers"] = tiers
	var e := make_engine(deck, o, 1, extra)
	settle(e, settled)
	for c in e.zone("tableau").cards:
		if c.def.type == "territory" and c.uid != home_uid(e):
			c.pop = 1 if population else 0
	e.resources.food = 50
	return e


# --- AC2: "here" on a building grows its own territory at upkeep ---

func test_granary_grows_its_territory_at_upkeep() -> void:
	var e := cards_engine(2, {"granary": 10}, ["grassland"])
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e), home), "Granary on Homeland")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.pop(home), 3, "Homeland pop 2 + 1")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 1, "other territory unchanged")
	eq(e.resources.food, food + 2, "no food spent (only the Capital's +2)")


# --- AC3: "each" on an action grows every settled territory ---

func test_festival_grows_each_settled_territory() -> void:
	var e := cards_engine(2, {"festival": 10}, ["grassland"])
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 3, "Homeland 2 + 1")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 2, "Grassland 1 + 1")
	eq(e.resources.food, 50, "no food spent")


# --- AC4: capped by housing; "here" with no territory does nothing ---

func test_card_growth_stops_at_housing() -> void:
	var e := cards_engine(7, {"festival": 10}, ["grassland"])  # Homeland housing 7
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 7, "Homeland stays at housing")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 2, "Grassland still grows")


func test_granary_at_housing_adds_nothing() -> void:
	var e := cards_engine(7, {"granary": 10})
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e), home), "Granary on Homeland")
	e.end_turn()
	eq(e.pop(home), 7, "Homeland stays at housing 7")


func test_grow_here_without_a_territory_does_nothing() -> void:
	var e := cards_engine(2, {"rally": 10})
	check(e.play_card(first_in_hand(e)), "play Rally (an action: no territory)")
	eq(e.total_pop(), 2, "total pop unchanged")


# --- AC5: population off ---

func test_grow_does_nothing_without_population() -> void:
	var e := cards_engine(2, {"festival": 10}, ["grassland"], false)
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 0, "Homeland pop")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 0, "Grassland pop")
	eq(e.total_pop(), 0, "total pop")


# --- Loader: the grow op ---

func grow_card_errors(effect: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": [{"id": "x", "name": "X", "type": "action", "effects": [effect]}]},
		resources(), "cards.json", errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


func test_grow_op_loads() -> void:
	var r := grow_card_errors({"op": "grow", "amount": 2, "where": "each"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_grow_where_defaults_to_here() -> void:
	var r := grow_card_errors({"op": "grow", "amount": 1})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.cards.x.rules_text(r.cards), "+1 pop here", "text")


func test_grow_validation() -> void:
	check_cases([
		["bad where", {"op": "grow", "amount": 1, "where": "everywhere"}, "cards.json: card 'x': effects[0]: 'where' must be one of"],
		["amount 0", {"op": "grow", "amount": 0}, "cards.json: card 'x': effects[0]: 'amount' must be an integer >= 1"],
		["missing amount", {"op": "grow"}, "cards.json: card 'x': effects[0]: missing 'amount'"],
	], grow_card_errors)


func test_grow_text() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "t", errors, warnings, keywords())
	eq(cards.granary.rules_tooltip(cards), "Each upkeep: +1 pop here", "Granary")
	eq(cards.festival.rules_tooltip(cards), "+1 pop in each territory", "Festival")
	eq(grow_card_errors({"op": "grow", "amount": 2, "where": "each"}).cards.x.rules_tooltip({}), "+2 pop in each territory", "amount 2")


# --- 261: where "best" and count ---

## Growth cards for 261's tests (not in TEST_CARDS).
const GROW_CARDS := [
	{"id": "bread", "name": "Bread", "type": "action", "effects": [{"op": "grow", "amount": 1, "where": "best"}]},
	{"id": "banquet", "name": "Banquet", "type": "action", "effects": [{"op": "grow", "amount": 2, "where": "best"}]},
	{"id": "grants", "name": "Grants", "type": "action",
	 "effects": [{"op": "grow", "amount": 1, "where": "each", "count": 3}]},
	{"id": "harvest_feast", "name": "Harvest Feast", "type": "action",
	 "effects": [{"op": "grow", "amount": 1, "where": "best"}, {"op": "gain", "resource": "food", "amount": 1}]},
]

## cards_engine with the Homeland first and Grassland, Hills (and the rest of settled) after it, at these pops in
## tableau order, and these stalls (buildings with no housing) on each; settlement tiers when tiers isn't empty.
func best_engine(pops: Array, stalls: Array, settled: Array[String] = ["grassland", "hills"], population := true, tiers := []) -> GameEngine:
	var e := cards_engine(2, {"farm": 10}, settled, population, GROW_CARDS, tiers)
	var lands := territories(e)
	for i in lands.size():
		if population:
			lands[i].pop = pops[i]
		for n in stalls[i]:
			build_on(e, lands[i].uid, ["stall"])
	return e


func territories(e: GameEngine) -> Array:
	return e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY)


func pops(e: GameEngine) -> Array:
	return territories(e).map(func(c): return c.pop)


func play(e: GameEngine, id: String) -> void:
	check(e.play_card(put_in_hand(e, id)), "play %s" % id)


func test_best_grows_the_territory_with_idle_buildings() -> void:
	var e := best_engine([3, 1], [2, 2], ["grassland"])  # Grassland: 2 buildings, 1 pop: one idle
	play(e, "bread")
	eq(pops(e), [3, 2], "Grassland grows, Homeland stays")


func test_best_without_idle_buildings_grows_the_lowest_pop() -> void:
	var e := best_engine([3, 1, 2], [0, 0, 0])
	play(e, "bread")
	eq(pops(e), [3, 2, 2], "Grassland (lowest pop) grows")


func test_best_breaks_a_tie_in_tableau_order() -> void:
	var e := best_engine([3, 2, 2], [0, 0, 0])
	play(e, "bread")
	eq(pops(e), [3, 3, 2], "Grassland (first of the tied) grows")


func test_best_among_idle_territories_picks_the_lowest_pop() -> void:
	var e := best_engine([3, 2, 1], [4, 3, 0])  # Homeland and Grassland idle; Hills lowest but not idle
	play(e, "bread")
	eq(pops(e), [3, 3, 1], "Grassland: lowest pop among those with idle buildings")
	var tie := best_engine([3, 2, 2], [0, 3, 3])
	play(tie, "bread")
	eq(pops(tie), [3, 3, 2], "tie among idle: tableau order")


func test_best_skips_full_territories() -> void:
	var e := best_engine([3, 4], [0, 5], ["grassland"])  # Grassland 4 of 4 with an idle building
	play(e, "bread")
	eq(pops(e), [4, 4], "Homeland grows")


func test_best_does_nothing_without_population() -> void:  # full and Famine: blocked instead (276)
	var off := best_engine([0, 0, 0], [0, 0, 0], ["grassland", "hills"], false)
	play(off, "bread")
	eq(pops(off), [0, 0, 0], "population off")


func test_best_adds_the_whole_amount_to_one_territory_capped_by_housing() -> void:
	var e := best_engine([3, 1, 2], [0, 0, 0])
	play(e, "banquet")
	eq(pops(e), [3, 3, 2], "+2 on Grassland")
	var capped := best_engine([5, 3], [0, 0], ["grassland"])  # Grassland housing 4
	play(capped, "banquet")
	eq(pops(capped), [5, 4], "capped at Grassland's housing")


func test_each_with_count_grows_the_smallest_territories_with_room() -> void:
	var e := best_engine([3, 1, 2, 2], [0, 0, 0, 0], ["grassland", "hills", "jungle"])
	play(e, "grants")
	eq(pops(e), [3, 2, 3, 3], "pop 1, 2, 2 grow; 3 doesn't")
	var tie := best_engine([2, 1, 2, 2], [0, 0, 0, 0], ["grassland", "hills", "jungle"])
	play(tie, "grants")
	eq(pops(tie), [3, 2, 3, 2], "ties in tableau order: Homeland and Hills before Jungle")


func test_each_with_count_skips_full_territories() -> void:
	var e := best_engine([7, 4, 2, 1], [0, 0, 0, 0], ["grassland", "hills", "jungle"])
	play(e, "grants")
	eq(pops(e), [7, 4, 3, 2], "only the two with room grow")


func test_each_without_count_still_grows_every_territory() -> void:
	var e := best_engine([3, 1, 2, 2], [0, 0, 0, 0], ["grassland", "hills", "jungle"])
	play(e, "festival")
	eq(pops(e), [4, 2, 3, 3], "all four grow")



# --- 283: "best" prefers a territory one pop short of its next tier ---

## 281's tiers: Village at 4, Town at 8, Metropolis at 13.
const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
	{"id": "metropolis", "name": "Metropolis", "pop": 13, "slots": 3},
]


func test_best_grows_a_territory_one_short_of_its_next_tier() -> void:
	var e := best_engine([2, 1, 3], [0, 0, 0], ["grassland", "hills"], true, TIERS)
	play(e, "bread")
	eq(pops(e), [2, 1, 4], "Hills (3, one short of a Village) grows, not Grassland (smallest)")


func test_best_grows_idle_buildings_before_one_short_of_a_tier() -> void:
	var e := best_engine([2, 1, 3], [0, 2, 0], ["grassland", "hills"], true, TIERS)  # Grassland: 2 stalls, 1 pop
	play(e, "bread")
	eq(pops(e), [2, 2, 3], "Grassland (an idle building) grows, Hills stays")


func test_best_among_several_one_short_grows_the_smallest_then_tableau_order() -> void:
	var e := best_engine([7, 1, 3], [0, 0, 0], ["grassland", "hills"], true, TIERS)
	build_on(e, home_uid(e), ["silo"])  # Homeland housing 8: 7 is one short of a Town, with room
	play(e, "bread")
	eq(pops(e), [7, 1, 4], "Hills (3) grows before the Homeland (7)")
	var tie := best_engine([2, 3, 3], [0, 0, 0], ["grassland", "hills"], true, TIERS)
	play(tie, "bread")
	eq(pops(tie), [2, 4, 3], "Grassland and Hills both at 3: the first in tableau order")


func test_best_ignores_one_short_of_a_tier_without_room() -> void:
	var e := best_engine([2, 1, 2, 3], [0, 0, 0, 0], ["grassland", "hills", "jungle"], true, TIERS)  # Jungle 3 of 3
	play(e, "bread")
	eq(pops(e), [2, 2, 2, 3], "Grassland (smallest) grows; Jungle is full")


func test_best_without_tiers_grows_the_smallest() -> void:
	var e := best_engine([2, 1, 3], [0, 0, 0])
	play(e, "bread")
	eq(pops(e), [2, 2, 3], "no tiers: Grassland (smallest) grows")


func test_a_metropolis_is_never_one_short() -> void:
	var e := best_engine([13, 1], [0, 0], ["grassland"], true, TIERS)
	for c in territories(e):
		if c.uid == home_uid(e):
			build_on(e, c.uid, ["silo", "silo", "silo", "silo", "silo", "silo", "silo"])  # Homeland housing 14
	play(e, "bread")
	eq(pops(e), [13, 2], "Grassland (smallest) grows, not the Metropolis at 13")


func grow_on(type: String, effect: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "effects": [effect]}
	if type == CardDef.UNIT:
		x["strength"] = 1
	if type == CardDef.TECH:
		x["cost"] = {"insight": 2}
	var cards := DataLoader.parse_cards({"cards": [x]}, resources(), "cards.json", errors, warnings, keywords())
	return {"cards": cards, "errors": errors, "warnings": warnings}


func test_best_loads_on_any_card_type() -> void:
	for type in [CardDef.ACTION, CardDef.BUILDING, CardDef.UNIT, CardDef.EVENT, CardDef.TECH]:
		var r := grow_on(type, {"op": "grow", "amount": 1, "where": "best"})
		eq(r.errors, [] as Array[String], "%s: errors" % type)


func test_count_loads_with_each() -> void:
	var r := grow_card_errors({"op": "grow", "amount": 1, "where": "each", "count": 3})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_count_validation() -> void:
	check_cases([
		["count 0", {"op": "grow", "amount": 1, "where": "each", "count": 0},
			"cards.json: card 'x': effects[0]: 'count' must be an integer >= 1"],
		["count not an integer", {"op": "grow", "amount": 1, "where": "each", "count": "three"},
			"cards.json: card 'x': effects[0]: 'count' must be an integer >= 1"],
		["count with best", {"op": "grow", "amount": 1, "where": "best", "count": 2},
			["cards.json: card 'x': effects[0]", "'count'", "each"]],
		["count with here", {"op": "grow", "amount": 1, "where": "here", "count": 2},
			["cards.json: card 'x': effects[0]", "'count'", "each"]],
	], grow_card_errors)


## The grow effect's short and long text on an action, or "<not loaded>".
func grow_texts(effect: Dictionary) -> Array:
	var cards: Dictionary = grow_card_errors(effect).cards
	if not cards.has("x"):
		return ["<not loaded>", "<not loaded>"]
	return [cards.x.rules_text(cards), cards.x.rules_tooltip(cards)]


func test_best_and_count_text() -> void:
	eq(grow_texts({"op": "grow", "amount": 1, "where": "best"}),
		["+1 pop", "+1 pop where it's needed most"], "best: short, long")
	eq(grow_texts({"op": "grow", "amount": 1, "where": "each", "count": 3}),
		["+1 pop on 3 territories", "+1 pop on each of your 3 smallest territories with room"], "count: short, long")


# --- 262: growth cards replace automatic growth ---

func test_pop_never_grows_by_itself() -> void:
	var e := make_engine({"scout": 10},
		{"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1, "growth_surplus": 1}})
	build_on(e, home_uid(e), ["farm", "farm", "farm"])  # Capital 2 + 3 Farms: net +5
	var before := e.total_pop()
	var recorded := record_messages(e)
	e.end_turn()
	eq(e.turn, 2, "the next turn started")
	eq(e.total_pop(), before, "no territory grew")
	eq(notices_in(recorded).filter(func(n): return n.contains("grew to")), [], "no growth notice")


func test_growth_surplus_is_an_unknown_population_field() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config({"farm": 1})
	raw.population = {"start": 2, "growth_surplus": 2, "famine": FAMINE}
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw, resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	has_msg(warnings, "population: unknown field 'growth_surplus'")
	check(not config.population.has("growth_surplus"), "the normalized block has no growth_surplus: %s" % [config.population])


func test_manual_growth_is_gone() -> void:
	var e := cards_engine(2, {"scout": 10})
	for method in ["grow", "grow_error", "grow_cost"]:
		check(not e.has_method(method), "GameEngine.%s is gone" % method)
	var view_vars: Array = (load("res://ui/territory_view.gd") as Script).get_script_property_list().map(
		func(p): return p.name)
	check(not view_vars.has("grow_button"), "the territory view has no Grow button")


func test_the_grow_op_still_adds_pop() -> void:
	var e := make_engine({"festival": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}})
	var home := home_uid(e)
	var before := e.pop(home)
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home), before + 1, "Festival's +1 pop")


# --- 276: a growth card can't be played when it would add no pop ---

## Plays id from the hand of e and checks it's refused with an error containing want, leaving the hand, food and
## actions as they were.
func check_grow_blocked(e: GameEngine, id: String, want: String, label: String) -> void:
	var uid := put_in_hand(e, id)
	var food: int = e.resources.food
	var actions: int = e.actions_left()
	var before := pops(e)
	var err: String = e.play_error(uid)
	check(err.contains(want), "%s: play_error names '%s': '%s'" % [label, want, err])
	check(not e.play_card(uid), "%s: play_card refuses" % label)
	check(e.zone("hand").find(uid) != null, "%s: the card stays in hand" % label)
	eq(e.resources.food, food, "%s: food unchanged" % label)
	eq(e.actions_left(), actions, "%s: no action spent" % label)
	eq(pops(e), before, "%s: pop unchanged" % label)


func test_bug_276_best_is_blocked_when_every_territory_is_full() -> void:
	check_grow_blocked(best_engine([7, 4, 5], [0, 0, 0]), "bread", "room", "every territory at housing")


func test_bug_276_each_is_blocked_when_every_territory_is_full() -> void:
	check_grow_blocked(best_engine([7, 4, 5], [0, 0, 0]), "grants", "room", "each with count")
	check_grow_blocked(best_engine([7, 4, 5], [0, 0, 0]), "festival", "room", "each without count")


func test_bug_276_growth_is_blocked_during_a_famine() -> void:
	for id in ["bread", "grants", "festival"]:
		var e := best_engine([3, 1, 2], [0, 0, 0])
		put_in(e, "famine", "active_events")
		check_grow_blocked(e, id, Famine.growth_error(e), "%s during a Famine" % id)
		check(Famine.growth_error(e) != "", "the Famine blocks growth")


func test_bug_276_growth_plays_when_one_territory_has_room() -> void:
	for id in ["bread", "grants", "festival"]:
		var e := best_engine([7, 3, 5], [0, 0, 0])  # Grassland 3 of 4
		eq(e.play_error(put_in_hand(e, id)), "", "%s: playable" % id)
		play(e, id)
		eq(pops(e), [7, 4, 5], "%s: Grassland grows" % id)


func test_bug_276_a_card_with_another_effect_still_plays_with_no_room() -> void:
	var e := best_engine([7, 4, 5], [0, 0, 0])
	play(e, "harvest_feast")
	eq(e.resources.food, 51, "the food gain still happens")
	eq(pops(e), [7, 4, 5], "no pop added")
