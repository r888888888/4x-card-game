extends "res://tests/lib/tech_case.gd"
## Research (backlog 025; an open tree since 140): tech cards, the research deck, and learning any tech whose
## prerequisite is researched with insight, at any time, with no card or action. Fixture techs and tech_engine come
## from tests/lib/tech_case.gd: Pottery 2, Writing 3, Bronze Working 5, Iron Working 6 (prereq Bronze), Steel 3
## (prereq Iron), Loom, Dye, Salt 4.

# --- Helpers ---

const OPTICS := {"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}
const ASTRONOMY := {"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2}


## GameEngine.<name>, read by name so this file parses before the constant exists (red phase); "<missing>" if absent.
func engine_const(name: String) -> Variant:
	return (GameEngine as Script).get_script_constant_map().get(name, "<missing>")


## A game with the research deck order_top_first and the given starting insight (and 20 wealth).
func insight_engine(order_top_first: Array, insight: int, overrides := {}, extra: Array = []) -> GameEngine:
	var o := {"starting": {"resources": {"food": 2, "wealth": 20, "insight": insight}, "tableau": ["capital"],
		"territory": "homeland"}}
	o.merge(overrides, true)
	return tech_engine(order_top_first, {"farm": 10}, o, extra)


## The uid of tech id in the research deck (-1 if it isn't there).
func deck_tech(e: GameEngine, id: String) -> int:
	return uid_of(e.zone("research_deck"), id)


## Learns tech id from the research deck; returns buy_tech's result.
func learn(e: GameEngine, id: String) -> bool:
	return e.buy_tech(deck_tech(e, id))


## The tech_tree() entry for id ({} if missing).
func entry(e: GameEngine, id: String) -> Dictionary:
	for t in e.tech_tree():
		if t.id == id:
			return t
	return {}


## Loads a card 'x' of the given type/cost/effects next to the fixture cards; returns {cards, errors, warnings}.
func load_x(type: String, cost: Variant, effects: Array = [], fields := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "effects": effects}
	if cost != null:
		x["cost"] = cost
	x.merge(fields, true)
	var cards := tech_db([x], errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## What buy_tech changes: [insight, researched ids, research deck ids sorted].
func snapshot(e: GameEngine) -> Array:
	return [e.resources.get("insight"), card_ids(e.zone("researched")), sorted(card_ids(e.zone("research_deck")))]


# --- Tech cards load ---

func test_tech_with_an_insight_cost_loads() -> void:
	var r := load_x("tech", {"insight": 2})
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.type, "tech", "type")
		eq(r.cards.x.is_permanent(), true, "techs are permanent")


func test_tech_card_validation() -> void:
	check_cases([
		["food cost", [{"food": 1}, []], "cards.json: card 'x': cost"],
		["zero insight cost", [{"insight": 0}, []], "cards.json: card 'x': cost"],
		["mixed cost", [{"insight": 2, "food": 1}, []], "cards.json: card 'x': cost"],
		["no cost", [null, []], "cards.json: card 'x': cost"],
		["keyword effect", [{"insight": 2}, [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "mountain"}]],
			"cards.json: card 'x': effects[0]"],
		["targeting effect", [{"insight": 2}, [{"op": "settle", "card": "city"}]], "cards.json: card 'x': effects[0]"],
	], func(cost_and_effects): return load_x("tech", cost_and_effects[0], cost_and_effects[1]).errors)


# --- Prerequisites load (backlog 026) ---

func test_prereq_loads() -> void:
	var r := load_x("tech", {"insight": 2}, [], {"prereq": "bronze"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if r.cards.has("x"):
		eq(r.cards.x.prereq, "bronze", "prereq")


func test_prereq_validation() -> void:
	check_cases([
		["unknown card", [{"prereq": "dragon"}, "tech"], "cards.json: card 'x': prereq"],
		["not a tech", [{"prereq": "farm"}, "tech"], "cards.json: card 'x': prereq"],
		["itself", [{"prereq": "x"}, "tech"], "cards.json: card 'x': prereq"],
		["prereq on a building", [{"prereq": "bronze"}, "building"], "cards.json: card 'x': 'prereq' only applies to techs",
			"warning_only"],
	], func(args): return load_x(args[1], {"insight": 2} if args[1] == "tech" else {"wealth": 2}, [], args[0]))


## A tech id with prereq (none when "").
func tech(id: String, prereq := "") -> Dictionary:
	var t := {"id": id, "name": id.capitalize(), "type": "tech", "cost": {"insight": 2}}
	if prereq != "":
		t["prereq"] = prereq
	return t


## 174: techs that need each other are one load error, on the cycle's first tech in card order.
func test_a_prereq_cycle_is_one_load_error() -> void:
	check_cases([
		["two techs", [tech("a", "b"), tech("b", "a")], "cards.json: card 'a': prereq: cycle a → b → a", "one_error"],
		["three techs", [tech("a", "b"), tech("b", "c"), tech("c", "a")],
			"cards.json: card 'a': prereq: cycle a → b → c → a", "one_error"],
		["a tail into a cycle", [tech("t", "b"), tech("a", "b"), tech("b", "a")],
			"cards.json: card 'a': prereq: cycle a → b → a", "one_error"],
		["its own prereq", [tech("a", "a")], "cards.json: card 'a': prereq: a tech can't be its own prerequisite",
			"one_error"],
	], func(extra): return fixture_load(extra, [TECHS]))
	eq(fixture_load([tech("a"), tech("b", "a"), tech("c", "b")], [TECHS]).errors, [] as Array[String], "a chain loads")


func test_prereq_on_a_card_that_is_not_a_tech_is_ignored() -> void:
	var r := load_x("building", {"wealth": 2}, [], {"prereq": "bronze"})
	check(r.cards.has("x"), "the building loads")
	if r.cards.has("x"):
		eq(r.cards.x.prereq, "", "ignored")


func test_prerequisite_card_text() -> void:
	var db := tech_db()
	eq(db.iron.rules_text(db), "Needs Bronze Working", "short text")
	eq(db.iron.rules_tooltip(db), "Needs Bronze Working researched first.", "tooltip")


# --- research_deck config ---

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
	], func(overrides_and_deck): return config_errors(overrides_and_deck[0], [TECHS], overrides_and_deck[1]))


# --- Setup ---

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
	eq(e.pending(), {}, "nothing owed")


# --- AC1 (140): learn any time, no card, no action ---

func test_learning_a_tech_needs_no_card_and_no_action() -> void:
	var o := {"starting": {"resources": {"food": 2, "insight": 2}, "tableau": ["capital"], "territory": "homeland",
		"government": "band"}}
	var e := tech_engine(["pottery", "writing"], {"farm": 10}, o, TEST_GOVS)
	eq(e.actions_left(), 2, "Band: 2 actions")
	var pottery := deck_tech(e, "pottery")
	check(e.buy_tech(pottery), "learn Pottery: %s" % e.buy_tech_error(pottery))
	eq(card_ids(e.zone("researched")), ["pottery"], "researched")
	eq(e.resources.get("insight"), 0, "insight 2 − 2")
	eq(card_ids(e.zone("research_deck")), ["writing"], "Writing still in the research deck")
	eq(e.actions_left(), 2, "no action used")
	eq(e.zone("discard").size(), 0, "no card played")


func test_learning_a_tech_resolves_its_play_effects() -> void:
	var e := insight_engine(["writing", "pottery"], 20)
	var before: int = e.score()
	check(learn(e, "writing"), "learn Writing")
	eq(e.score(), before + 2, "score: Writing's +2 VP")


func test_a_tech_scores_its_vp_and_works_at_upkeep() -> void:
	var e := insight_engine(["pottery", "writing"], 20)
	var before: int = e.score()
	check(learn(e, "pottery"), "learn Pottery")
	eq(e.score(), before + 1, "score: Pottery's printed VP")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, food + 3, "upkeep: Capital 2 + Pottery 1")


func test_several_techs_can_be_learned_in_one_turn() -> void:
	var e := insight_engine(["pottery", "writing", "bronze"], 20)
	check(learn(e, "pottery"), "learn Pottery")
	check(learn(e, "writing"), "learn Writing")
	eq(e.resources.get("insight"), 15, "20 − 2 − 3")
	eq(card_ids(e.zone("researched")), ["pottery", "writing"], "researched")


func test_tech_cost_is_the_printed_insight_cost() -> void:
	var e := insight_engine(["pottery", "writing"], 20)
	eq(e.tech_cost(deck_tech(e, "pottery")), 2, "Pottery")
	eq(e.tech_cost(deck_tech(e, "writing")), 3, "Writing")


# --- AC2 (140): prerequisites are hard ---

func test_a_tech_whose_prereq_isnt_researched_is_locked() -> void:
	var e := insight_engine(["iron", "bronze"], 20)
	eq(entry(e, "iron").get("state"), engine_const("TECH_LOCKED"), "Iron Working is locked")
	eq(entry(e, "bronze").get("state"), GameEngine.TECH_AVAILABLE, "Bronze Working is available")
	var iron := deck_tech(e, "iron")
	eq(e.buy_tech_error(iron), "Iron Working needs Bronze Working first.", "buy_tech_error")
	var before := snapshot(e)
	check(not e.buy_tech(iron), "buy_tech refuses")
	eq(snapshot(e), before, "nothing changed")


func test_learning_the_prereq_unlocks_the_tech() -> void:
	var e := insight_engine(["iron", "bronze"], 20)
	check(learn(e, "bronze"), "learn Bronze Working")
	eq(entry(e, "iron").get("state"), GameEngine.TECH_AVAILABLE, "Iron Working is available")
	check(learn(e, "iron"), "learn Iron Working: %s" % e.buy_tech_error(deck_tech(e, "iron")))
	eq(card_ids(e.zone("researched")), ["bronze", "iron"], "researched")


# --- AC3 (140): when learning is refused ---

func test_a_tech_not_in_the_research_deck_isnt_on_offer() -> void:
	var e := insight_engine(["pottery", "writing"], 20,
		{"research_deck": {"pottery": 1, "writing": 1, "optics": 1}}, [OPTICS])
	check(learn(e, "pottery"), "learn Pottery")
	var researched := uid_of(e.zone("researched"), "pottery")
	var future := uid_of(e.zone("future_techs"), "optics")
	for row in [["researched Pottery", researched], ["era 2 Optics", future], ["the Capital", home_uid(e)], ["no card", -1]]:
		eq(e.buy_tech_error(row[1]), "That tech isn't on offer.", "%s: buy_tech_error" % row[0])
		var before := snapshot(e)
		check(not e.buy_tech(row[1]), "%s: buy_tech refuses" % row[0])
		eq(snapshot(e), before, "%s: nothing changed" % row[0])


func test_a_tech_needs_enough_insight() -> void:
	var e := insight_engine(["pottery", "writing"], 1)
	var pottery := deck_tech(e, "pottery")
	eq(e.buy_tech_error(pottery), "Pottery needs 2 insight (you have 1).", "buy_tech_error")
	var before := snapshot(e)
	check(not e.buy_tech(pottery), "buy_tech refuses")
	eq(snapshot(e), before, "nothing changed")


func test_no_learning_after_the_game_is_over() -> void:
	var e := insight_engine(["pottery", "writing"], 20, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	var pottery := deck_tech(e, "pottery")
	eq(e.buy_tech_error(pottery), "The game is over.", "buy_tech_error")
	var before := snapshot(e)
	check(not e.buy_tech(pottery), "buy_tech refuses")
	eq(snapshot(e), before, "nothing changed")


func test_no_learning_during_an_explore_choice() -> void:
	var e := insight_engine(["pottery", "writing"], 20, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	var pottery := deck_tech(e, "pottery")
	eq(e.buy_tech_error(pottery), "Choose a territory first.", "buy_tech_error")
	var before := snapshot(e)
	check(not e.buy_tech(pottery), "buy_tech refuses")
	eq(snapshot(e), before, "nothing changed")


func test_learning_is_allowed_while_a_discard_is_owed() -> void:
	var e := insight_engine(["pottery", "writing"], 20)
	for i in 3:
		check(e.play_card(put_in_hand(e, "scout")), "play Scout %d" % i)
	e.end_turn()
	check(e.discard_needed() > 0, "a discard is owed")
	var pottery := deck_tech(e, "pottery")
	eq(e.buy_tech_error(pottery), "", "buy_tech_error")
	check(e.buy_tech(pottery), "learn Pottery")


# --- AC4 (140): the last tech of an era brings the next ---

func test_learning_the_last_tech_adds_the_next_era() -> void:
	var e := insight_engine(["pottery"], 20,
		{"research_deck": {"pottery": 1, "optics": 1, "astronomy": 1}}, [OPTICS, ASTRONOMY])
	eq(sorted(card_ids(e.zone("future_techs"))), ["astronomy", "optics"], "era 2 waits")
	check(learn(e, "pottery"), "learn Pottery")
	eq(e.era(), 2, "era 2")
	eq(sorted(card_ids(e.zone("research_deck"))), ["astronomy", "optics"], "era 2 techs in the research deck")


# --- AC5 (140): the reveal is gone ---

func test_the_research_op_is_unknown() -> void:
	var r := load_x("action", null, [{"op": "research"}])
	check(has_message(r.errors, "unknown op 'research'"), "errors: %s" % [r.errors])


func test_prereq_discount_is_an_unknown_field() -> void:
	var r := load_x("tech", {"insight": 2}, [], {"prereq": "bronze", "prereq_discount": 3})
	eq(r.errors, [] as Array[String], "errors")
	check(has_message(r.warnings, "unknown field 'prereq_discount'"), "warnings: %s" % [r.warnings])


func test_the_engine_has_no_reveal_passes_or_lost_techs() -> void:
	var e := insight_engine(["pottery", "writing"], 20)
	for zone_name in ["research_reveal", "lost_techs"]:
		check(not GameEngine.ZONES.has(zone_name), "no %s zone" % zone_name)
	for constant in ["PENDING_RESEARCH", "TECH_LOST", "MAX_PASSES"]:
		check(not (GameEngine as Script).get_script_constant_map().has(constant), "no GameEngine.%s" % constant)
	var card: CardInstance = e.zone("research_deck").cards[0]
	check(not "passes" in card, "a tech has no passes")


func test_tech_tree_entries_carry_a_uid_and_no_passes() -> void:
	var e := insight_engine(["pottery", "writing"], 20,
		{"research_deck": {"pottery": 1, "writing": 1, "optics": 1}}, [OPTICS])
	eq(entry(e, "pottery").get("uid"), deck_tech(e, "pottery"), "Pottery's uid")
	eq(entry(e, "optics").get("uid"), -1, "a future tech has uid -1")
	for t in e.tech_tree():
		check(not t.has("passes"), "%s: no passes" % t.id)


func test_learning_never_leaves_a_choice_pending() -> void:
	var e := insight_engine(["pottery", "writing"], 20)
	check(e.play_card(put_in_hand(e, "study")), "play a Research card")
	eq(e.pending(), {}, "playing Research opens nothing")
	check(learn(e, "pottery"), "learn Pottery")
	eq(e.pending(), {}, "learning opens nothing")


func test_the_research_card_gains_insight() -> void:
	var e := insight_engine(["pottery", "writing"], 0)
	check(e.play_card(put_in_hand(e, "study")), "play a Research card")
	eq(e.resources.get("insight"), 3, "+3 insight")


# --- Backlog 092: the research card's name, for the UI's hints (140: the first card that gains insight) ---

## A second research card, to tell deck order from supply order.
const SEEK := {"id": "seek", "name": "Seek", "type": "action", "effects": [{"op": "gain", "resource": "insight", "amount": 1}]}


func test_research_card_name_is_the_research_card_in_the_deck() -> void:
	var e: GameEngine = tech_engine(["pottery"], {"farm": 5, "study": 1})
	eq(e.research_card_name(), "Research", "Research is in the deck")


func test_research_card_name_is_empty_without_a_research_card() -> void:
	var e: GameEngine = tech_engine(["pottery"], {"farm": 5})
	eq(e.research_card_name(), "", "no research card in the deck or supply")


func test_research_card_name_looks_in_the_deck_then_the_supply_in_order() -> void:
	var pile := {"price": 1, "count": 1}
	var e: GameEngine = tech_engine(["pottery"], {"farm": 5}, {"supply": {"seek": pile, "study": pile}}, [SEEK])
	eq(e.research_card_name(), "Seek", "first supply pile that gains insight")
	e = tech_engine(["pottery"], {"farm": 5, "study": 1}, {"supply": {"seek": pile}}, [SEEK])
	eq(e.research_card_name(), "Research", "the deck comes before the supply")
