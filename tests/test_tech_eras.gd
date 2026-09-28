extends "res://tests/lib/tech_case.gd"
## Tech eras and extra research (backlog 027): the add_era and research ops, era-2 techs waiting in
## future_techs, the empty research deck adding the next era, and the Library.

const ERA_CARDS := [
	{"id": "philosophy", "name": "Philosophy", "type": "tech", "cost": {"wealth": 3},
	 "effects": [{"op": "add_era", "era": 2}]},
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"wealth": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"wealth": 5}, "era": 2},
	{"id": "academy", "name": "Academy", "type": "building", "cost": {"food": 1},
	 "effects": [{"op": "add_era", "era": 2}]},
	{"id": "library", "name": "Library", "type": "building", "cost": {"food": 1},
	 "effects": [{"op": "research", "amount": 1, "trigger": "upkeep"}]},
	{"id": "study", "name": "Study", "type": "action", "effects": [{"op": "research", "amount": 1}]},
]
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}


## Loads fixture cards plus a card 'x' with fields and effects; returns {cards, errors, warnings}.
func load_x(fields: Dictionary, type := "tech", effects: Array = []) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "effects": effects}
	if type == "tech":
		x["cost"] = {"wealth": 2}
	x.merge(fields, true)
	var cards := tech_db([x], errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## A game whose research deck starts with the era-1 techs in order_top_first (top first) and whose
## era-2 techs (optics, astronomy) wait in future_techs. deck is the main deck.
func era_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}) -> Object:
	var counts := {"optics": 1, "astronomy": 1}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {"research_deck": counts}
	config.merge(overrides, true)
	return tech_engine(order_top_first, deck, config, ERA_CARDS)


# --- AC1: loader and card text ---

func test_era_defaults_to_1_and_loads() -> void:
	eq(load_x({}).cards.x.era, 1, "default era")
	var r := load_x({"era": 2})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.cards.x.era, 2, "era")


func test_era_below_1_is_an_error() -> void:
	has_msg(load_x({"era": 0}).errors, "cards.json: card 'x': era")


func test_era_on_a_card_that_is_not_a_tech_is_a_warning() -> void:
	var r := load_x({"era": 2}, "building")
	eq(r.errors, [] as Array[String], "errors")
	has_msg(r.warnings, "cards.json: card 'x': 'era' only applies to techs")


func test_add_era_loads() -> void:
	var r := load_x({}, "tech", [{"op": "add_era", "era": 2}])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_add_era_needs_an_era() -> void:
	has_msg(load_x({}, "tech", [{"op": "add_era"}]).errors, "cards.json: card 'x': effects[0]: missing 'era'")


func test_add_era_1_is_an_error() -> void:
	has_msg(load_x({}, "tech", [{"op": "add_era", "era": 1}]).errors, "cards.json: card 'x': effects[0]: 'era' must be an integer >= 2")


func test_research_op_loads_with_a_default_amount() -> void:
	var r := load_x({}, "building", [{"op": "research", "trigger": "upkeep"}])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_research_amount_below_1_is_an_error() -> void:
	var r := load_x({}, "building", [{"op": "research", "amount": 0}])
	has_msg(r.errors, "cards.json: card 'x': effects[0]: 'amount' must be an integer >= 1")


func test_era_and_research_card_text() -> void:
	var db := tech_db(ERA_CARDS)
	eq(db.philosophy.rules_text(db), "Adds era 2 techs", "add_era short")
	eq(db.library.rules_text(db), "⟳ +1 research", "research short")
	eq(db.library.rules_tooltip(db), "Each upkeep: +1 research", "research tooltip")
	var two := load_x({}, "building", [{"op": "research", "amount": 2, "trigger": "upkeep"}])
	eq(two.cards.x.rules_text(two.cards), "⟳ +2 research", "amount 2")


# --- AC2: setup ---

func test_only_era_1_techs_start_in_the_research_deck() -> void:
	var e := era_engine(["philosophy", "pottery"])
	var deck := card_ids(e.zone("research_deck"))
	deck.sort()
	eq(deck, ["philosophy", "pottery"], "research deck")
	var future := card_ids(e.zone("future_techs"))
	future.sort()
	eq(future, ["astronomy", "optics"], "future_techs")
	eq(e.era(), 1, "era")


# --- AC3: add an era, once ---

func test_buying_an_era_tech_adds_the_next_era() -> void:
	var e := era_engine(["philosophy", "pottery"])
	check(e.research(), "research")
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "philosophy")), "buy Philosophy")
	var deck := card_ids(e.zone("research_deck"))
	deck.sort()
	eq(deck, ["astronomy", "optics", "pottery"], "research deck")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")
	eq(e.era(), 2, "era")


func test_an_era_is_only_added_once() -> void:
	var e := era_engine(["philosophy", "pottery"], {"academy": 10})
	check(e.research(), "research")
	check(e.buy_tech(uid_of(e.zone("research_reveal"), "philosophy")), "buy Philosophy")
	var size: int = e.zone("research_deck").size()
	check(e.play_card(first_in_hand(e)), "play Academy")
	eq(e.zone("research_deck").size(), size, "research deck unchanged")
	eq(e.era(), 2, "era")


func test_a_building_can_add_an_era() -> void:
	var e := era_engine(["philosophy", "pottery"], {"academy": 10})
	check(e.play_card(first_in_hand(e)), "play Academy")
	eq(e.zone("research_deck").size(), 4, "2 era-1 + 2 era-2 techs")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")
	eq(e.era(), 2, "era")


# --- AC4: an empty research deck adds the next era ---

func test_an_empty_research_deck_adds_the_next_era() -> void:
	var e := era_engine(["pottery"])
	e.zone("research_deck").take_all()
	eq(e.research_error(), "", "research_error")
	check(e.research(), "research should succeed")
	eq(e.era(), 2, "era")
	eq(e.research_options().size(), 2, "two era-2 techs revealed")
	eq(e.zone("future_techs").size(), 0, "future_techs emptied")


func test_an_empty_research_deck_with_no_eras_left_is_an_error() -> void:
	var e := tech_engine(["pottery"])
	e.zone("research_deck").take_all()
	eq(e.research_error(), "The research deck is empty.", "research_error")
	check(not e.research(), "research should fail")


# --- AC5: era techs can't be lost ---

func test_an_era_tech_is_never_lost() -> void:
	var e := era_engine(["philosophy", "loom", "dye", "salt"])
	var philosophy := uid_of(e.zone("research_deck"), "philosophy")
	pass_tech(e, "philosophy", "loom")
	pass_tech(e, "philosophy", "dye")
	pass_tech(e, "philosophy", "salt")
	check(e.zone("research_deck").find(philosophy) != null, "Philosophy is back in the research deck")
	eq(e.zone("lost_techs").size(), 0, "nothing lost")
	eq(e.tech_passes(philosophy), 2, "passes stop at 2")
	eq(e.tech_cost(philosophy), 1, "cost 3 - 2")


# --- AC6: Library ---

func library_engine() -> Object:
	return era_engine(["pottery", "writing"], {"library": 10}, POP)


func test_a_staffed_library_gives_a_second_research() -> void:
	var e := library_engine()
	check(e.play_card(first_in_hand(e)), "play Library")
	e.end_turn()
	eq(e.research_left(), 2, "research_left on turn 2")
	check(e.research(), "first research")
	check(e.decline_research(), "decline")
	eq(e.research_left(), 1, "one left")
	check(e.research(), "second research")
	eq(e.research_left(), 0, "none left")


func test_an_idle_library_gives_nothing() -> void:
	var e := library_engine()
	check(e.play_card(first_in_hand(e)), "play Library")
	e.zone("tableau").find(home_uid(e)).pop = 0
	e.end_turn()
	eq(e.research_left(), 1, "the idle Library adds no research")


func test_a_library_adds_nothing_until_the_next_upkeep() -> void:
	var e := library_engine()
	eq(e.research_left(), 1, "before")
	check(e.play_card(first_in_hand(e)), "play Library")
	eq(e.research_left(), 1, "the turn it is built")


func test_extra_research_does_not_carry_over() -> void:
	var e := library_engine()
	check(e.play_card(first_in_hand(e)), "play Library")
	e.end_turn()
	eq(e.research_left(), 2, "turn 2")
	e.end_turn()
	eq(e.research_left(), 2, "turn 3: 2, not 4")


# --- AC7: research op outside upkeep ---

func test_a_played_research_card_adds_a_charge_at_once() -> void:
	var e := era_engine(["pottery", "writing"], {"study": 10})
	check(e.research(), "research")
	check(e.decline_research(), "decline")
	eq(e.research_left(), 0, "spent")
	check(e.play_card(first_in_hand(e)), "play Study")
	eq(e.research_left(), 1, "research_left")
	check(e.research(), "research again")


func test_a_research_card_adds_to_the_charges_left() -> void:
	var e := era_engine(["pottery", "writing"], {"study": 10})
	check(e.play_card(first_in_hand(e)), "play Study")
	eq(e.research_left(), 2, "1 + 1")
