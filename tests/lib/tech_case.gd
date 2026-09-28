extends "res://tests/lib/test_case.gd"
## Base class for tech tests (backlog 026 on): fixture techs and helpers to build a game with a
## research deck. Engine helpers return Object, not GameEngine: GDScript rejects a call to a method
## the typed class lacks at parse time, which would hide new tests behind a parse error in the red phase.

const TECHS := [
	{"id": "pottery", "name": "Pottery", "type": "tech", "cost": {"wealth": 2}, "vp": 1,
	 "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
	{"id": "writing", "name": "Writing", "type": "tech", "cost": {"wealth": 3}},
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
## starting with 2 food and 20 wealth.
func tech_engine(order_top_first: Array, deck := {"farm": 10}, overrides := {}) -> Object:
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
	var cards := tech_db([], errors, warnings)
	var parsed := DataLoader.parse_config(raw_config(deck, config), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, parsed)
	e.new_game(1)
	arrange(e.zone("research_deck"), order_top_first)
	return e


## Puts the cards with these ids on top of zone z, top first, keeping the rest below them.
func arrange(z: Zone, ids_top_first: Array) -> void:
	var top: Array[CardInstance] = []
	for id in ids_top_first:
		for c in z.cards:
			if c.def.id == id and not top.has(c):
				top.append(c)
				break
	var rest: Array[CardInstance] = []
	for c in z.cards:
		if not top.has(c):
			rest.append(c)
	top.reverse()  # the top is the last element
	z.cards.assign(rest + top)
	var got := card_ids(z)
	got.reverse()
	eq(got.slice(0, ids_top_first.size()), ids_top_first, "zone arranged")


func uid_of(z: Zone, id: String) -> int:
	for c in z.cards:
		if c.def.id == id:
			return c.uid
	return -1


## Researches with [tech_id, buy_id] on top and buys buy_id, so tech_id is passed once.
func pass_tech(e: Object, tech_id: String, buy_id: String) -> void:
	arrange(e.zone("research_deck"), [tech_id, buy_id])
	e._research_left = 1
	check(e.research(), "research should open: %s" % e.research_error())
	check(e.buy_tech(uid_of(e.zone("research_reveal"), buy_id)), "buy %s" % buy_id)
