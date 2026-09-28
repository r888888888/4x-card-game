extends "res://tests/lib/test_case.gd"
## Research (backlog 025): tech cards, the research deck, and the reveal-2 buy-or-decline action.
## Techs live here (not in TEST_CARDS) so existing tests don't load a card type they don't use.

const TECHS := [
	{"id": "pottery", "name": "Pottery", "type": "tech", "cost": {"wealth": 2}, "vp": 1,
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "writing", "name": "Writing", "type": "tech", "cost": {"wealth": 3},
	 "effects": [{"op": "score", "amount": 2}]},
	{"id": "bronze", "name": "Bronze Working", "type": "tech", "cost": {"wealth": 5}},
]


# --- Helpers ---
# Engine helpers return Object, not GameEngine: GDScript rejects a call to a method the typed class
# lacks at parse time, which would hide these tests behind a parse error until the API exists.

func tech_db(errors: Array[String] = []) -> Dictionary:
	var warnings: Array[String] = []
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TECHS}, resources(), "test", errors, warnings, keywords())


## A game with the given main deck and a research deck holding order_top_first (top first),
## starting with 2 food and 10 wealth.
func tech_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}) -> Object:
	var counts := {}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {
		"research_deck": counts,
		"starting": {"resources": {"food": 2, "wealth": 10}, "tableau": ["capital"], "territory": "homeland"},
	}
	config.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db(errors)
	var parsed := DataLoader.parse_config(raw_config(deck, config), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, parsed)
	e.new_game(1)
	if not order_top_first.is_empty():  # otherwise keep the config's shuffled deck
		arrange(e.zone("research_deck"), order_top_first)
	return e


## Reorders a zone so ids are top first (the top is the last element).
func arrange(z: Zone, ids_top_first: Array) -> void:
	var ordered: Array[CardInstance] = []
	for i in range(ids_top_first.size() - 1, -1, -1):
		for c in z.cards:
			if c.def.id == ids_top_first[i] and not ordered.has(c):
				ordered.append(c)
				break
	z.cards.assign(ordered)
	var top_first := card_ids(z)
	top_first.reverse()
	eq(top_first, ids_top_first, "zone arranged")


func uid_of(z: Zone, id: String) -> int:
	for c in z.cards:
		if c.def.id == id:
			return c.uid
	return -1


func sorted(a: Array) -> Array:
	var out := a.duplicate()
	out.sort()
	return out


## An engine with the research deck [pottery, writing, bronze] and the first two revealed.
func open_engine() -> Object:
	var e := tech_engine(["pottery", "writing", "bronze"])
	check(e.research(), "research should open: %s" % e.research_error())
	return e


## Loads a card 'x' of the given type/cost/effects next to a city; returns {cards, errors}.
func load_x(type: String, cost: Variant, effects: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "effects": effects}
	if cost != null:
		x["cost"] = cost
	var raw := {"cards": [{"id": "city", "name": "City", "type": "city"}, x]}
	var cards := DataLoader.parse_cards(raw, resources(), "cards.json", errors, warnings, keywords())
	return {"cards": cards, "errors": errors}


func config_errors(overrides: Dictionary, deck := {"farm": 1}) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db(errors)
	check(errors.is_empty(), "fixture cards should load: %s" % [errors])
	DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "config.json", errors, warnings)
	return errors


# --- AC1: tech cards load ---

func test_tech_with_a_wealth_cost_loads() -> void:
	var r := load_x("tech", {"wealth": 2})
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.type, "tech", "type")
		eq(r.cards.x.is_permanent(), true, "techs are permanent")


func test_tech_food_cost_is_an_error() -> void:
	has_msg(load_x("tech", {"food": 1}).errors, "cards.json: card 'x': cost")


func test_tech_zero_wealth_cost_is_an_error() -> void:
	has_msg(load_x("tech", {"wealth": 0}).errors, "cards.json: card 'x': cost")


func test_tech_mixed_cost_is_an_error() -> void:
	has_msg(load_x("tech", {"wealth": 2, "food": 1}).errors, "cards.json: card 'x': cost")


func test_tech_without_a_cost_is_an_error() -> void:
	has_msg(load_x("tech", null).errors, "cards.json: card 'x': cost")


func test_tech_keyword_effect_is_an_error() -> void:
	var r := load_x("tech", {"wealth": 2}, [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "mountain"}])
	has_msg(r.errors, "cards.json: card 'x': effects[0]")


func test_tech_targeting_effect_is_an_error() -> void:
	var r := load_x("tech", {"wealth": 2}, [{"op": "settle", "card": "city"}])
	has_msg(r.errors, "cards.json: card 'x': effects[0]")


# --- AC2: research_deck config ---

func test_research_deck_is_normalized() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {"research_deck": {"pottery": 2.0, "writing": 1}}),
		resources(), tech_db(), "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(config.get("research_deck"), {"pottery": 2, "writing": 1}, "research_deck")


func test_research_deck_defaults_to_empty() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), tech_db(), "config.json", errors, warnings)
	eq(config.get("research_deck"), {}, "research_deck default")


func test_research_deck_unknown_card_is_error() -> void:
	has_msg(config_errors({"research_deck": {"dragon": 1}}), "config.json: research_deck: unknown card 'dragon'")


func test_research_deck_non_tech_is_error() -> void:
	has_msg(config_errors({"research_deck": {"farm": 1}}), "config.json: research_deck: 'farm' is not a tech")


func test_research_deck_count_below_1_is_error() -> void:
	has_msg(config_errors({"research_deck": {"pottery": 0}}), "config.json: research_deck: count for 'pottery'")


func test_tech_in_the_main_deck_is_error() -> void:
	has_msg(config_errors({}, {"pottery": 1}), "config.json: deck: 'pottery' is a tech")


# --- AC3: setup ---

func test_new_game_shuffles_the_research_deck_by_seed() -> void:
	var big := {"research_deck": {"pottery": 5, "writing": 5, "bronze": 5}}
	var a := tech_engine([], {"farm": 10}, big)
	var b := tech_engine([], {"farm": 10}, big)
	eq(a.zone("research_deck").size(), 15, "research deck size")
	eq(card_ids(a.zone("research_deck")), card_ids(b.zone("research_deck")), "same seed, same order")
	var sorted_ids := card_ids(a.zone("research_deck"))
	sorted_ids.sort()
	check(card_ids(a.zone("research_deck")) != sorted_ids, "the deck should be shuffled, not sorted")


func test_new_game_starts_with_one_charge_and_nothing_researched() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	eq(sorted(card_ids(e.zone("research_deck"))), ["bronze", "pottery", "writing"], "research deck")
	eq(e.zone("researched").size(), 0, "researched")
	eq(e.research_left(), 1, "research_left")
	eq(e.research_options(), [] as Array[int], "no options open")


func test_no_research_deck_means_nothing_to_research() -> void:
	var e := make_engine({"farm": 10})
	eq(e.zone("research_deck").size(), 0, "research deck")
	eq(e.research_error(), "The research deck is empty.", "research_error")


# --- AC4: reveal ---

func test_research_reveals_the_top_two() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	var changes := []
	e.changed.connect(func(): changes.append(1))
	check(e.research(), "research should succeed")
	var options = e.research_options()
	eq(options, [uid_of(e.zone("research_reveal"), "pottery"), uid_of(e.zone("research_reveal"), "writing")] as Array[int], "options, top first")
	eq(card_ids(e.zone("research_deck")), ["bronze"], "research deck")
	eq(e.research_left(), 0, "charge spent")
	eq(changes.size(), 1, "changed emitted once")


func test_open_options_block_play_grow_discard_end_turn_and_research() -> void:
	var pop := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}
	var e := tech_engine(["pottery", "writing", "bronze"], {"farm": 10}, pop)
	check(e.research(), "research should succeed")
	var hand_uid := first_in_hand(e)
	var food: int = e.resources.food
	eq(e.play_error(hand_uid), "Buy a tech or decline first.", "play_error")
	check(not e.play_card(hand_uid), "play_card should fail")
	eq(e.grow_error(home_uid(e)), "Buy a tech or decline first.", "grow_error")
	check(not e.grow(home_uid(e)), "grow should fail")
	check(not e.discard_card(hand_uid), "discard_card should fail")
	e.end_turn()
	eq(e.turn, 1, "still turn 1")
	check(not e.research(), "a second research should fail")
	eq(e.zone("hand").size(), 5, "hand unchanged")
	eq(e.resources.food, food, "food unchanged")
	eq(e.research_options().size(), 2, "options still open")


# --- AC5: buy ---

func test_buying_a_tech_pays_for_it_and_moves_it_to_researched() -> void:
	var e := open_engine()
	var pottery := uid_of(e.zone("research_reveal"), "pottery")
	check(e.buy_tech(pottery), "buy should succeed: %s" % e.buy_tech_error(pottery))
	eq(e.resources.wealth, 8, "wealth 10 - 2")
	eq(card_ids(e.zone("researched")), ["pottery"], "researched")
	eq(e.research_options(), [] as Array[int], "options closed")
	eq(e.zone("research_reveal").size(), 0, "nothing left revealed")


func test_buying_shuffles_the_other_techs_back_into_the_deck() -> void:
	var e := open_engine()
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "pottery")), "buy")
	eq(sorted(card_ids(e.zone("research_deck"))), ["bronze", "writing"], "research deck")


func test_play_and_end_turn_work_again_after_buying() -> void:
	var e := open_engine()
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "pottery")), "buy")
	eq(e.play_error(first_in_hand(e)), "", "play_error")
	e.end_turn()
	eq(e.turn, 2, "turn advanced")


func test_cannot_afford_a_tech() -> void:
	var e := open_engine()
	e.resources.wealth = 1
	var writing := uid_of(e.zone("research_reveal"), "writing")
	eq(e.buy_tech_error(writing), "Writing needs 3 wealth (you have 1).", "buy_tech_error")
	check(not e.buy_tech(writing), "buy should fail")
	eq(e.resources.wealth, 1, "wealth unchanged")
	eq(e.research_options().size(), 2, "options still open")
	eq(e.zone("researched").size(), 0, "nothing researched")


func test_cannot_buy_a_tech_that_was_not_revealed() -> void:
	var e := open_engine()
	var not_options := [uid_of(e.zone("research_deck"), "bronze"), uid_of(e.zone("tableau"), "capital"), -1]
	for uid in not_options:
		check(not e.buy_tech(uid), "buy_tech(%d) should fail" % uid)
	eq(e.resources.wealth, 10, "wealth unchanged")
	eq(e.research_options().size(), 2, "options still open")


func test_tech_cost_is_the_printed_wealth_cost() -> void:
	var e := open_engine()
	eq(e.tech_cost(uid_of(e.zone("research_reveal"), "pottery")), 2, "Pottery")
	eq(e.tech_cost(uid_of(e.zone("research_reveal"), "writing")), 3, "Writing")


# --- AC6: techs count like buildings ---

func test_buying_a_tech_resolves_its_play_effects() -> void:
	var e := open_engine()
	var before: int = e.score()
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "writing")), "buy Writing")
	eq(e.score(), before + 2, "score: Writing's +2 VP")


func test_a_tech_scores_its_vp_and_works_at_upkeep() -> void:
	var e := open_engine()
	var before: int = e.score()
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "pottery")), "buy Pottery")
	eq(e.score(), before + 1, "score: Pottery's printed VP")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, food + 3, "upkeep: Capital 2 + Pottery 1")


# --- AC7: decline ---

func test_declining_returns_both_techs_and_spends_nothing() -> void:
	var e := open_engine()
	check(e.decline_research(), "decline should succeed")
	eq(sorted(card_ids(e.zone("research_deck"))), ["bronze", "pottery", "writing"], "research deck")
	eq(e.zone("research_reveal").size(), 0, "nothing left revealed")
	eq(e.resources.wealth, 10, "wealth unchanged")
	eq(e.research_left(), 0, "the charge stays spent")
	eq(e.research_options(), [] as Array[int], "options closed")


func test_decline_does_nothing_without_open_options() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	check(not e.decline_research(), "decline should fail")
	eq(e.zone("research_deck").size(), 3, "research deck unchanged")
	eq(e.research_left(), 1, "charge unchanged")


# --- AC8: can't research ---

func test_research_error_when_the_game_is_over() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	e.is_over = true
	eq(e.research_error(), "The game is over.", "research_error")
	check(not e.research(), "research should fail")


func test_research_error_while_an_explore_choice_is_pending() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	e.pending_choice = {"options": [1], "source": e.zone("tableau").cards[0]}
	eq(e.research_error(), "Choose a territory first.", "research_error")
	check(not e.research(), "research should fail")


func test_research_error_while_a_discard_is_pending() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"], {"scout": 10})
	for i in 3:
		check(e.play_card(first_in_hand(e)), "play scout %d" % i)
	e.end_turn()
	eq(e.discard_needed(), 1, "a discard is pending")
	eq(e.research_error(), "Discard down to 7 cards first.", "research_error")
	check(not e.research(), "research should fail")


func test_research_error_with_no_charge_left() -> void:
	var e := open_engine()
	check(e.decline_research(), "decline")
	eq(e.research_error(), "No research left this turn.", "research_error")
	check(not e.research(), "research should fail")
	eq(e.zone("research_deck").size(), 3, "research deck unchanged")


func test_research_error_with_an_empty_research_deck() -> void:
	var e := tech_engine([])
	eq(e.research_error(), "The research deck is empty.", "research_error")
	check(not e.research(), "research should fail")
	eq(e.research_left(), 1, "charge not spent")


func test_researching_with_one_tech_left_reveals_just_that_one() -> void:
	var e := tech_engine(["writing"])
	check(e.research(), "research should succeed")
	eq(e.research_options().size(), 1, "one option")
	check(e.buy_tech(e.research_options()[0]), "buy it")
	eq(card_ids(e.zone("researched")), ["writing"], "researched")
	eq(e.zone("research_deck").size(), 0, "research deck empty")


# --- AC9: charges reset ---

func test_each_turn_starts_with_one_charge() -> void:
	var e := open_engine()
	check(e.decline_research(), "decline")
	eq(e.research_left(), 0, "spent")
	e.end_turn()
	eq(e.research_left(), 1, "turn 2 has 1")


func test_unused_charges_do_not_carry_over() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	e.end_turn()
	eq(e.research_left(), 1, "turn 2 has 1, not 2")
