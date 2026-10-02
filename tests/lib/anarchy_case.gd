extends "res://tests/lib/test_case.gd"
## Base class for Anarchy tests (backlogs 145, 146): fixture governments and cards, a config with the unrest block, and
## games that start or have fallen into Anarchy. Fixtures, with TEST_CARDS and TEST_GOVS: Chiefs (government, limit 5),
## Kings (limit 7), Anarchy (government, 1 action, ⟳ −1 pop), Feast (order, −2 unrest), Calm (building, ⟳ −1 unrest),
## Dawn (adds era 2), Lore (a tech) and Altar (building, unrest limit +1). The unrest block's relief is 6 wealth.

const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
const CHIEFS := {"id": "chiefs", "name": "Chiefs", "type": "government", "unrest_limit": 5}
const KINGS := {"id": "kings", "name": "Kings", "type": "government", "unrest_limit": 7}
const ANARCHY := {"id": "anarchy", "name": "Anarchy", "type": "government", "actions": 1,
	"effects": [{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]}
const FEAST := {"id": "feast", "name": "Feast", "type": "action", "tags": ["order"],
	"effects": [{"op": "lose", "resource": "unrest", "amount": 2}]}
const CALM := {"id": "calm", "name": "Calm", "type": "building",
	"effects": [{"op": "lose", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const DAWN := {"id": "dawn", "name": "Dawn", "type": "action", "effects": [{"op": "add_era", "era": 2}]}
const LORE := {"id": "lore", "name": "Lore", "type": "tech", "cost": {"insight": 1}}
const ALTAR := {"id": "altar", "name": "Altar", "type": "building", "modifiers": {"unrest_limit": 1}}
const FIXTURES := [CHIEFS, KINGS, ANARCHY, FEAST, CALM, DAWN, LORE, ALTAR]
const UNREST_BLOCK := {"anarchy": "anarchy", "max_counters": 4, "era_unrest": 3,
	"allowed_tag": "order", "relief": {"wealth": 6}}
const POP := {"start": 6, "food_upkeep": 0, "vp_per_pop": 0, "famine": FAMINE}
const ONLY_ORDER := "Anarchy: only a government or an order card can be played."
const NOTHING_BUILT := "Anarchy: nothing can be grown, bought or researched."


## TEST_CARDS, TEST_GOVS, FIXTURES and extra, parsed with unrest a resource.
func anarchy_db(extra := []) -> Dictionary:
	return fixture_db(extra, [TEST_GOVS, FIXTURES], RESOURCES)


## The raw config for an anarchy game: Chiefs ruling, unrest listed, the unrest block (merged with unrest), population
## on (home pop 6), 10 food, wealth and insight, Lore in the research deck and Farms in the supply; overrides last (a
## null value, in unrest or overrides, drops that key).
func anarchy_raw(unrest := {}, overrides := {}) -> Dictionary:
	var o := {"resources": RESOURCES, "population": POP, "unrest": UNREST_BLOCK.merged(unrest, true),
		"research_deck": {"lore": 1}, "supply": {"farm": {"price": 1, "count": 3}},
		"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": "chiefs"}}
	o.merge(overrides, true)
	var raw := raw_config({"farm": 10}, o)
	for key in overrides:
		if overrides[key] == null:
			raw.erase(key)
	if raw.get("unrest") is Dictionary:
		for key in unrest:
			if unrest[key] == null:
				raw.unrest.erase(key)
	return raw


## The errors from parsing the raw config raw against anarchy_db.
func raw_config_errors(raw: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var listed: Array[String] = []
	listed.assign(raw.resources)
	DataLoader.parse_config(raw, listed, anarchy_db(), "config.json", errors, warnings)
	return errors


## A new anarchy game (see anarchy_raw), with extra cards in the card db.
func anarchy_engine(unrest := {}, overrides := {}, extra := []) -> GameEngine:
	var cards := anarchy_db(extra)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := anarchy_raw(unrest, overrides)
	var listed: Array[String] = []
	listed.assign(raw.resources)
	var config := DataLoader.parse_config(raw, listed, cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	return e


## An anarchy game that fell into Anarchy at the start of turn 2 (unrest 5 of 5 at the end of turn 1).
func fallen_engine(unrest := {}) -> GameEngine:
	var e := anarchy_engine(unrest)
	e.resources["unrest"] = 5
	e.end_turn()
	return e


## The ruling government's card id ("" for none).
func ruling(e: GameEngine) -> String:
	return "" if e.zone("government").is_empty() else e.zone("government").cards[0].def.id
