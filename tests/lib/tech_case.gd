extends "res://tests/lib/test_case.gd"
## Base class for tech tests (backlog 026 on): fixture techs and helpers to build a game with a
## research deck. Engine helpers return Object, not GameEngine: GDScript rejects a call to a method
## the typed class lacks at parse time, which would hide new tests behind a parse error in the red phase.

const TECHS := [
	{"id": "pottery", "name": "Pottery", "type": "tech", "cost": {"insight": 2}, "vp": 1,
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "writing", "name": "Writing", "type": "tech", "cost": {"insight": 3},
	 "effects": [{"op": "score", "amount": 2}]},
	{"id": "bronze", "name": "Bronze Working", "type": "tech", "cost": {"insight": 5}},
	{"id": "iron", "name": "Iron Working", "type": "tech", "cost": {"insight": 6}, "prereq": "bronze"},
	{"id": "steel", "name": "Steel", "type": "tech", "cost": {"insight": 3}, "prereq": "iron"},
	{"id": "loom", "name": "Loom", "type": "tech", "cost": {"insight": 4}},
	{"id": "dye", "name": "Dye", "type": "tech", "cost": {"insight": 4}},
	{"id": "salt", "name": "Salt", "type": "tech", "cost": {"insight": 4}},
]


func tech_db(extra: Array = [], errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TECHS + extra}, resources(), "cards.json", errors, warnings, keywords())


## A game with the given main deck and a research deck holding the ids in order_top_first (top first),
## starting with 2 food, 20 wealth and 20 insight. extra is more fixture cards to load.
func tech_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}, extra: Array = []) -> Object:
	var counts := {}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {
		"research_deck": counts,
		"starting": {"resources": {"food": 2, "wealth": 20, "insight": 20}, "tableau": ["capital"], "territory": "homeland"},
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

