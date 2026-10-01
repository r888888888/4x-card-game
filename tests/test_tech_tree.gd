extends "res://tests/lib/tech_case.gd"
## The tech tree (backlog 059): tech_tree() lists every tech in research_deck with its state, cost now, uid (140) and
## what it gives; era_name(n) names eras from config era_names. Engines are Object so this parses before the API.

const ERA_2 := [
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2},
]
const GUILDS := {"id": "guilds", "name": "Guilds", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "create", "card": "guildhall", "zone": "discard"}, {"op": "unlock", "card": "guildhall"}]}


## era_2 techs (optics, astronomy) come first in the config, then order_top_first (era 1, top first).
func tree_engine(order_top_first: Array, overrides := {}, extra: Array = []) -> Object:
	var counts := {"optics": 1, "astronomy": 1}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {"research_deck": counts}
	config.merge(overrides, true)
	return tech_engine(order_top_first, {"farm": 10}, config, ERA_2 + extra)


## The tree entry for tech id, or {}.
func entry(e: Object, id: String) -> Dictionary:
	for t in e.tech_tree():
		if t.id == id:
			return t
	return {}


## Parses a config with era_names; returns {config, errors}.
func era_names_config(era_names: Variant) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {"era_names": era_names}), resources(), cards,
		"config.json", errors, warnings)
	return {"config": config, "errors": errors, "warnings": warnings}


# --- AC1: a new game ---

func test_new_game_tree_has_era_1_available_and_era_2_future() -> void:
	var e := tree_engine(["pottery", "writing"])
	var ids: Array[String] = []
	for t in e.tech_tree():
		ids.append(t.id)
	eq(ids, ["pottery", "writing", "optics", "astronomy"] as Array[String], "by era, then config order")
	var pottery := entry(e, "pottery")
	eq(pottery.get("state"), GameEngine.TECH_AVAILABLE, "pottery state")
	eq(pottery.get("cost"), 2, "pottery printed cost")
	eq(pottery.get("era"), 1, "pottery era")
	eq(pottery.get("prereq"), "", "pottery prereq")
	eq(entry(e, "writing").get("state"), GameEngine.TECH_AVAILABLE, "writing state")
	for id in ["optics", "astronomy"]:
		eq(entry(e, id).get("state"), GameEngine.TECH_FUTURE, "%s state" % id)
		eq(entry(e, id).get("era"), 2, "%s era" % id)


# --- AC2: learning one (140: the other is untouched) ---

func test_a_learned_tech_is_researched_and_the_other_is_untouched() -> void:
	var e := tree_engine(["pottery", "writing"])
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	eq(entry(e, "pottery").get("state"), GameEngine.TECH_RESEARCHED, "pottery researched")
	var writing := entry(e, "writing")
	eq(writing.get("state"), GameEngine.TECH_AVAILABLE, "writing still available")
	eq(writing.get("cost"), 3, "writing at its printed cost")


# --- AC3 (140: a prerequisite gates, it no longer discounts) ---

func test_a_researched_prerequisite_no_longer_lowers_the_cost() -> void:
	var e := tree_engine(["iron", "bronze"])
	eq(entry(e, "iron").get("cost"), 6, "iron printed")
	eq(entry(e, "iron").get("prereq"), "bronze", "iron prereq")
	check(e.buy_tech(uid_of(e.zone("research_deck"), "bronze")), "learn Bronze Working")
	eq(entry(e, "iron").get("cost"), 6, "iron still 6 with Bronze Working")


# --- AC4: a new era ---

func test_adding_era_2_makes_its_techs_available() -> void:
	var e := tree_engine(["pottery", "writing"])
	e.add_era(2)
	for id in ["optics", "astronomy"]:
		eq(entry(e, id).get("state"), GameEngine.TECH_AVAILABLE, "%s after add_era(2)" % id)


# --- AC5: what a tech gives ---

func test_gives_merges_create_and_unlock() -> void:
	var e := tree_engine(["guilds", "pottery"], {"supply": {"guildhall": {"price": 2, "count": 2, "locked": true}}}, [GUILDS])
	eq(entry(e, "guilds").get("gives"), ["guildhall"] as Array[String], "guilds gives")
	eq(entry(e, "pottery").get("gives"), [] as Array[String], "pottery gives nothing")


# --- AC6: era names ---

func test_era_names_come_from_config_with_a_default() -> void:
	var e := tree_engine(["pottery"], {"era_names": {"1": "Stone Age", "2": "Bronze Age"}})
	eq(e.era_name(1), "Stone Age", "era 1")
	eq(e.era_name(2), "Bronze Age", "era 2")
	eq(e.era_name(3), "Era 3", "era 3 has no name")


func test_era_names_validation() -> void:
	var ok := era_names_config({"1": "Stone Age"})
	eq(ok.errors, [] as Array[String], "valid era_names")
	eq(ok.warnings, [] as Array[String], "no unknown-field warning")
	check_cases([
		["name not a string", {"1": 5}, "config.json: era_names: '1' must be a name"],
		["key zero", {"0": "Nothing"}, "config.json: era_names: '0' must be an era number >= 1"],
		["key not a number", {"first": "Stone Age"}, "config.json: era_names: 'first' must be an era number >= 1"],
		["not an object", ["Stone Age"], "config.json: 'era_names' must be an object"],
	], era_names_config)
