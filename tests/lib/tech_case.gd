extends "res://tests/lib/test_case.gd"
## Base class for tech tests (backlog 026 on): fixture techs and helpers to build a game with a
## research deck. Engine helpers return Object, not GameEngine: GDScript rejects a call to a method
## the typed class lacks at parse time, which would hide new tests behind a parse error in the red phase.

const TECHS := [
	{"id": "pottery", "name": "Pottery", "type": "tech", "cost": {"wealth": 2}, "vp": 1,
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "writing", "name": "Writing", "type": "tech", "cost": {"wealth": 3},
	 "effects": [{"op": "score", "amount": 2}]},
	{"id": "bronze", "name": "Bronze Working", "type": "tech", "cost": {"wealth": 5}},
	{"id": "iron", "name": "Iron Working", "type": "tech", "cost": {"wealth": 6}, "prereq": "bronze"},
	{"id": "steel", "name": "Steel", "type": "tech", "cost": {"wealth": 3}, "prereq": "iron", "prereq_discount": 5},
	{"id": "loom", "name": "Loom", "type": "tech", "cost": {"wealth": 4}},
	{"id": "dye", "name": "Dye", "type": "tech", "cost": {"wealth": 4}},
	{"id": "salt", "name": "Salt", "type": "tech", "cost": {"wealth": 4}},
]


func tech_db(extra: Array = [], errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TECHS + extra}, resources(), "cards.json", errors, warnings, keywords())


## A game with the given main deck and a research deck holding the ids in order_top_first (top first),
## starting with 2 food and 20 wealth. extra is more fixture cards to load.
func tech_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}, extra: Array = []) -> Object:
	var counts := {}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {
		"research_deck": counts,
		"starting": {"resources": {"food": 2, "wealth": 20}, "tableau": ["capital"], "territory": "homeland"},
	}
	config.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db(extra, errors, warnings)
	var parsed := DataLoader.parse_config(raw_config(deck, config), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, parsed)
	e.new_game(1)
	arrange(e.zone("research_deck"), order_top_first)
	return e


## Researches with [tech_id, buy_id] on top and buys buy_id, so tech_id is passed once.
func pass_tech(e: Object, tech_id: String, buy_id: String) -> void:
	arrange(e.zone("research_deck"), [tech_id, buy_id])
	check(play_research(e), "research should open")
	check(e.buy_tech(uid_of(e.zone("research_reveal"), buy_id)), "buy %s" % buy_id)
