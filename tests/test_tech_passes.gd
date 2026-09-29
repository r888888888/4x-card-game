extends "res://tests/lib/tech_case.gd"
## Tech passes and discounts (backlog 026): a tech passed by a purchase gets cheaper, a third pass
## removes it, and owning its prerequisite lowers its price. Nothing here blocks a purchase.


## Loads fixture techs plus a card 'x' (type tech unless given) with fields; returns {cards, errors, warnings}.
func load_x(fields: Dictionary, type := "tech") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "cost": {"wealth": 2}}
	x.merge(fields, true)
	var cards := tech_db([x], errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## [bronze + loom, dye, salt]: a tech to pass and three cheap ones to buy instead.
func passing_engine() -> Object:
	return tech_engine(["bronze", "loom", "dye", "salt"])


# --- AC1: loader ---

func test_prereq_and_default_discount_load() -> void:
	var r := load_x({"prereq": "bronze"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if r.cards.has("x"):
		eq(r.cards.x.prereq, "bronze", "prereq")
		eq(r.cards.x.prereq_discount, 2, "default prereq_discount")


func test_prereq_discount_loads() -> void:
	var r := load_x({"prereq": "bronze", "prereq_discount": 3})
	eq(r.errors, [] as Array[String], "errors")
	if r.cards.has("x"):
		eq(r.cards.x.prereq_discount, 3, "prereq_discount")


func test_prereq_validation() -> void:
	check_cases([
		["unknown card", [{"prereq": "dragon"}, "tech"], "cards.json: card 'x': prereq"],
		["not a tech", [{"prereq": "farm"}, "tech"], "cards.json: card 'x': prereq"],
		["itself", [{"prereq": "x"}, "tech"], "cards.json: card 'x': prereq"],
		["discount 0", [{"prereq": "bronze", "prereq_discount": 0}, "tech"], "cards.json: card 'x': prereq_discount"],
		["discount not an int", [{"prereq": "bronze", "prereq_discount": "two"}, "tech"], "cards.json: card 'x': prereq_discount"],
		["discount without prereq", [{"prereq_discount": 3}, "tech"], "cards.json: card 'x': 'prereq_discount' needs 'prereq'",
			"warning_only"],
		["prereq on a building", [{"prereq": "bronze", "prereq_discount": 3}, "building"],
			["cards.json: card 'x': 'prereq' only applies to techs", "cards.json: card 'x': 'prereq_discount' only applies to techs"],
			"warning_only"],
	], func(args): return load_x(args[0], args[1]))


func test_prereq_on_a_card_that_is_not_a_tech_is_ignored() -> void:
	var r := load_x({"prereq": "bronze", "prereq_discount": 3}, "building")
	check(r.cards.has("x"), "the building loads")
	if r.cards.has("x"):
		eq(r.cards.x.prereq, "", "ignored")


# --- AC2 / AC3: only a purchase passes the other tech ---

func test_buying_passes_the_other_tech() -> void:
	var e := tech_engine(["pottery", "bronze"])
	check(play_research(e), "research")
	var bronze := uid_of(e.zone("research_reveal"), "bronze")
	var pottery := uid_of(e.zone("research_reveal"), "pottery")
	check(e.buy_tech(pottery), "buy Pottery")
	eq(e.tech_passes(bronze), 1, "Bronze Working passes")
	eq(e.tech_cost(bronze), 4, "Bronze Working cost 5 - 1")
	check(e.zone("research_deck").find(bronze) != null, "Bronze Working is back in the research deck")
	eq(e.tech_passes(pottery), 0, "Pottery passes")


func test_declining_passes_nothing() -> void:
	var e := tech_engine(["pottery", "bronze"])
	check(play_research(e), "research")
	var bronze := uid_of(e.zone("research_reveal"), "bronze")
	var pottery := uid_of(e.zone("research_reveal"), "pottery")
	check(e.decline_research(), "decline")
	eq([e.tech_passes(pottery), e.tech_passes(bronze)], [0, 0], "passes")
	eq([e.tech_cost(pottery), e.tech_cost(bronze)], [2, 5], "costs")


# --- AC4: discount stacks ---

func test_the_discount_stacks_and_is_paid() -> void:
	var e := passing_engine()
	var bronze := uid_of(e.zone("research_deck"), "bronze")
	pass_tech(e, "bronze", "loom")
	pass_tech(e, "bronze", "dye")
	eq(e.tech_passes(bronze), 2, "passes")
	eq(e.tech_cost(bronze), 3, "cost 5 - 2")
	arrange(e.zone("research_deck"), ["bronze", "salt"])
	check(play_research(e), "research")
	var wealth: int = e.resources.wealth
	check(e.buy_tech(bronze), "buy Bronze Working")
	eq(e.resources.wealth, wealth - 3, "wealth paid")


# --- AC5: the third pass removes ---

func test_the_third_pass_sends_the_tech_to_lost_techs() -> void:
	var e := passing_engine()
	var bronze := uid_of(e.zone("research_deck"), "bronze")
	pass_tech(e, "bronze", "loom")
	pass_tech(e, "bronze", "dye")
	check(e.zone("lost_techs").find(bronze) == null, "not lost after two passes")
	pass_tech(e, "bronze", "salt")
	check(e.zone("lost_techs").find(bronze) != null, "lost after the third pass")
	eq(card_ids(e.zone("lost_techs")), ["bronze"], "lost_techs")
	check(not card_ids(e.zone("research_deck")).has("bronze"), "gone from the research deck")
	check(not card_ids(e.zone("researched")).has("bronze"), "not researched either")


# --- AC6: prerequisite discount ---

func test_prerequisite_discounts_only_when_owned() -> void:
	var e := tech_engine(["iron", "bronze"])
	var iron := uid_of(e.zone("research_deck"), "iron")
	eq(e.tech_cost(iron), 6, "without Bronze Working")
	var bronze: CardInstance = e.zone("research_deck").find(uid_of(e.zone("research_deck"), "bronze"))
	e.zone("research_deck").remove(bronze)
	e.zone("researched").add(bronze)
	eq(e.tech_cost(iron), 4, "with Bronze Working: 6 - 2")


func test_prerequisite_and_passes_stack() -> void:
	var e := tech_engine(["iron", "bronze"])
	var iron := uid_of(e.zone("research_deck"), "iron")
	var bronze: CardInstance = e.zone("research_deck").find(uid_of(e.zone("research_deck"), "bronze"))
	e.zone("research_deck").remove(bronze)
	e.zone("researched").add(bronze)
	var card = e.zone("research_deck").find(iron)
	card.passes = 1
	eq(e.tech_cost(iron), 3, "6 - 1 pass - 2 prerequisite")


func test_a_tech_can_be_bought_without_its_prerequisite() -> void:
	var e := tech_engine(["iron", "pottery"])
	check(play_research(e), "research")
	var iron := uid_of(e.zone("research_reveal"), "iron")
	check(e.buy_tech(iron), "buy Iron Working: %s" % e.buy_tech_error(iron))
	eq(e.resources.wealth, 14, "wealth 20 - 6")


# --- AC7: minimum cost 1 ---

func test_a_big_prerequisite_discount_stops_at_1() -> void:
	var e := tech_engine(["steel", "iron"])
	var iron: CardInstance = e.zone("research_deck").find(uid_of(e.zone("research_deck"), "iron"))
	e.zone("research_deck").remove(iron)
	e.zone("researched").add(iron)
	eq(e.tech_cost(uid_of(e.zone("research_deck"), "steel")), 1, "3 - 5, raised to 1")


func test_passes_cannot_take_a_tech_below_1() -> void:
	var e := tech_engine(["pottery", "writing"])
	var pottery := uid_of(e.zone("research_deck"), "pottery")
	var card = e.zone("research_deck").find(pottery)
	card.passes = 2
	eq(e.tech_cost(pottery), 1, "2 - 2, raised to 1")
	check(play_research(e), "research")
	check(e.buy_tech(pottery), "buy Pottery")
	eq(e.resources.wealth, 19, "paid tech_cost 1")


# --- AC8: card text ---

func test_prerequisite_card_text() -> void:
	var db := tech_db()
	eq(db.iron.rules_text(db), "-2 wealth with Bronze Working", "short text")
	eq(db.iron.rules_tooltip(db), "Costs 2 less wealth if you have Bronze Working.", "tooltip")
