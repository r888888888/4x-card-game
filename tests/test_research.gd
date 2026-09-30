extends "res://tests/lib/tech_case.gd"
## Research (backlog 025): tech cards, the research deck, and the reveal-2 buy-or-decline action.
## Fixture techs and tech_engine come from tests/lib/tech_case.gd.

# --- Helpers ---

const TEN_WEALTH := {"starting": {"resources": {"food": 2, "wealth": 10}, "tableau": ["capital"], "territory": "homeland"}}


## An engine with the research deck [pottery, writing, bronze], 10 wealth, and the first two revealed.
func open_engine() -> Object:
	var e := tech_engine(["pottery", "writing", "bronze"], {"farm": 10}, TEN_WEALTH)
	check(play_research(e), "research should open")
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
	return config_errors_for(tech_db(), overrides, deck)


# --- AC1: tech cards load ---

func test_tech_with_a_wealth_cost_loads() -> void:
	var r := load_x("tech", {"wealth": 2})
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.type, "tech", "type")
		eq(r.cards.x.is_permanent(), true, "techs are permanent")


func test_tech_card_validation() -> void:
	check_cases([
		["food cost", [{"food": 1}, []], "cards.json: card 'x': cost"],
		["zero wealth cost", [{"wealth": 0}, []], "cards.json: card 'x': cost"],
		["mixed cost", [{"wealth": 2, "food": 1}, []], "cards.json: card 'x': cost"],
		["no cost", [null, []], "cards.json: card 'x': cost"],
		["keyword effect", [{"wealth": 2}, [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "mountain"}]],
			"cards.json: card 'x': effects[0]"],
		["targeting effect", [{"wealth": 2}, [{"op": "settle", "card": "city"}]], "cards.json: card 'x': effects[0]"],
	], func(cost_and_effects): return load_x("tech", cost_and_effects[0], cost_and_effects[1]).errors)


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


func test_research_deck_validation() -> void:
	check_cases([
		["unknown card", [{"research_deck": {"dragon": 1}}, {"farm": 1}], "config.json: research_deck: unknown card 'dragon'"],
		["not a tech", [{"research_deck": {"farm": 1}}, {"farm": 1}], "config.json: research_deck: 'farm' is not a tech"],
		["count below 1", [{"research_deck": {"pottery": 0}}, {"farm": 1}], "config.json: research_deck: count for 'pottery'"],
		["tech in the main deck", [{}, {"pottery": 1}], "config.json: deck: 'pottery' is a tech"],
	], func(overrides_and_deck): return config_errors(overrides_and_deck[0], overrides_and_deck[1]))


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


func test_new_game_starts_with_nothing_researched() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	eq(sorted(card_ids(e.zone("research_deck"))), ["bronze", "pottery", "writing"], "research deck")
	eq(e.zone("researched").size(), 0, "researched")
	eq(e.research_options(), [] as Array[int], "no options open")


# --- AC4: reveal (backlog 034: playing a Research card reveals) ---

func test_playing_a_research_card_reveals_the_top_two() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	var changes := []
	e.changed.connect(func(): changes.append(1))
	check(play_research(e), "playing Research should succeed")
	eq(card_ids(e.zone("discard")), ["study"], "Research is in the discard")
	var options = e.research_options()
	eq(options, [uid_of(e.zone("research_reveal"), "pottery"), uid_of(e.zone("research_reveal"), "writing")] as Array[int], "options, top first")
	eq(card_ids(e.zone("research_deck")), ["bronze"], "research deck")
	check(changes.size() >= 1, "changed emitted")


func test_open_options_block_play_grow_discard_end_turn_and_research() -> void:
	var pop := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}
	var e := tech_engine(["pottery", "writing", "bronze"], {"farm": 10}, pop)
	check(play_research(e), "research should succeed")
	var hand_uid := first_in_hand(e)
	var food: int = e.resources.food
	eq(e.play_error(hand_uid), "Buy a tech or decline first.", "play_error")
	check(not e.play_card(hand_uid), "play_card should fail")
	eq(e.grow_error(home_uid(e)), "Buy a tech or decline first.", "grow_error")
	check(not e.grow(home_uid(e)), "grow should fail")
	check(not e.discard_card(hand_uid), "discard_card should fail")
	e.end_turn()
	eq(e.turn, 1, "still turn 1")
	check(not play_research(e), "a second Research card can't be played")
	e.zone("hand").remove(e.zone("hand").cards[-1])  # the unplayed Research card
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
	eq(e.research_options(), [] as Array[int], "options closed")


func test_decline_does_nothing_without_open_options() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	check(not e.decline_research(), "decline should fail")
	eq(e.zone("research_deck").size(), 3, "research deck unchanged")


# --- AC8: can't research (backlog 034 AC5) ---

func test_a_research_card_cannot_be_played_with_nothing_to_research() -> void:
	var e := tech_engine([])
	var card := put_in_hand(e, "study")
	eq(e.play_error(card), "The tech deck is empty.", "play_error")
	check(not e.play_card(card), "play_card should fail")
	check(e.zone("hand").find(card) != null, "the card stays in hand")
	check(e.discard_card(card), "it can still be discarded")


func test_researching_with_one_tech_left_reveals_just_that_one() -> void:
	var e := tech_engine(["writing"])
	check(play_research(e), "research should succeed")
	eq(e.research_options().size(), 1, "one option")
	check(e.buy_tech(e.research_options()[0]), "buy it")
	eq(card_ids(e.zone("researched")), ["writing"], "researched")
	eq(e.zone("research_deck").size(), 0, "research deck empty")


# --- Backlog 034 AC3/AC4: no free research, no limit per turn ---

func test_there_are_no_research_charges() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	for method in ["research", "research_left", "research_error"]:
		check(not e.has_method(method), "the engine has no %s()" % method)
	e.end_turn()
	eq(e.research_options(), [] as Array[int], "a new turn opens no tech options")
	eq(e.zone("research_deck").size(), 3, "research deck untouched")


func test_two_research_cards_can_be_played_in_one_turn() -> void:
	var e := tech_engine(["pottery", "writing", "bronze"])
	check(play_research(e), "first Research")
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "pottery")), "buy Pottery")
	check(play_research(e), "second Research")
	eq(e.research_options().size(), 2, "two techs revealed again")


# --- Backlog 092: the research card's name, for the UI's hints ---

## A second research card, to tell deck order from supply order.
const SEEK := {"id": "seek", "name": "Seek", "type": "action", "effects": [{"op": "research"}]}


func test_research_card_name_is_the_research_card_in_the_deck() -> void:
	var e: Object = make_engine({"farm": 5, "study": 1})
	eq(e.research_card_name(), "Research", "Research is in the deck")


func test_research_card_name_is_empty_without_a_research_card() -> void:
	var e: Object = make_engine({"farm": 5})
	eq(e.research_card_name(), "", "no research card in the deck or supply")


func test_research_card_name_looks_in_the_deck_then_the_supply_in_order() -> void:
	var pile := {"price": 1, "count": 1}
	var e: Object = tech_engine(["pottery"], {"farm": 5}, {"supply": {"seek": pile, "study": pile}}, [SEEK])
	eq(e.research_card_name(), "Seek", "first supply pile with a research effect")
	e = tech_engine(["pottery"], {"farm": 5, "study": 1}, {"supply": {"seek": pile}}, [SEEK])
	eq(e.research_card_name(), "Research", "the deck comes before the supply")
