extends "res://tests/lib/tech_case.gd"
## The tech tree (backlog 059): tech_tree() lists every tech in research_deck with its state, cost now, uid (140) and
## what it gives; era_name(n) names eras from config era_names.

const ERA_2 := [
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2},
]
const GUILDS := {"id": "guilds", "name": "Guilds", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "create", "card": "guildhall", "zone": "discard"}, {"op": "unlock", "card": "guildhall"}]}


## era_2 techs (optics, astronomy) come first in the config, then order_top_first (era 1, top first).
func tree_engine(order_top_first: Array, overrides := {}, extra: Array = []) -> GameEngine:
	var counts := {"optics": 1, "astronomy": 1}
	for id in order_top_first:
		counts[id] = counts.get(id, 0) + 1
	var config := {"research_deck": counts}
	config.merge(overrides, true)
	return tech_engine(order_top_first, {"farm": 10}, config, ERA_2 + extra)


## The tree entry for tech id, or {}.
func entry(e: GameEngine, id: String) -> Dictionary:
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


# --- 278 AC1: a tech's links in the tree ---

## Techs a, b (prereq a), c and d (both prereq b), in config order; no other tech is in the research deck.
func links_engine() -> Object:
	var chain := [
		{"id": "a", "name": "A", "type": "tech", "cost": {"insight": 1}},
		{"id": "b", "name": "B", "type": "tech", "cost": {"insight": 1}, "prereq": "a"},
		{"id": "c", "name": "C", "type": "tech", "cost": {"insight": 1}, "prereq": "b"},
		{"id": "d", "name": "D", "type": "tech", "cost": {"insight": 1}, "prereq": "b"},
	]
	return tech_engine(["a", "b", "c", "d"], {"farm": 10}, {"research_deck": {"a": 1, "b": 1, "c": 1, "d": 1}}, chain)


func test_tech_links_name_the_prerequisite_and_the_techs_it_opens_in_tree_order() -> void:
	var e: Object = links_engine()
	var links: Dictionary = e.tech_links("b")
	eq(links.get("prereq"), "a", "b's prerequisite")
	eq(links.get("unlocks"), ["c", "d"] as Array[String], "b opens c and d")


func test_tech_links_of_a_tech_with_no_prerequisite_have_none() -> void:
	var links: Dictionary = (links_engine() as Object).tech_links("a")
	eq(links.get("prereq"), "", "a has no prerequisite")
	eq(links.get("unlocks"), ["b"] as Array[String], "a opens b")


func test_tech_links_of_an_unknown_id_are_empty() -> void:
	var links: Dictionary = (links_engine() as Object).tech_links("nothing")
	eq(links.get("prereq"), "", "no prerequisite")
	eq(links.get("unlocks"), [] as Array[String], "opens nothing")


# --- Backlog 325: affordable ---

## tree_engine(["writing", "pottery", "iron", "bronze"]) with insight set to n: Writing costs 3, Iron Working is locked.
func afford_engine(n: int, overrides := {}) -> GameEngine:
	var e := tree_engine(["writing", "pottery", "iron", "bronze"], overrides)
	e.resources[GameEngine.INSIGHT] = n
	return e


func test_an_available_tech_the_insight_covers_is_affordable() -> void:
	var e := afford_engine(3)
	eq(entry(e, "writing").get("cost"), 3, "precondition: Writing costs 3")
	eq(entry(e, "writing").get("affordable"), true, "3 insight covers 3")


func test_an_available_tech_short_of_insight_isnt_affordable_until_the_insight_comes() -> void:
	var e := afford_engine(2)
	eq(entry(e, "writing").get("affordable"), false, "2 insight is short of 3")
	e.resources[GameEngine.INSIGHT] = 3
	eq(entry(e, "writing").get("affordable"), true, "one more insight covers it")


func test_researched_locked_and_later_era_techs_are_never_affordable() -> void:
	var e := afford_engine(50)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "pottery")), "learn Pottery")
	eq(entry(e, "pottery").get("affordable"), false, "researched")
	eq(entry(e, "iron").get("state"), GameEngine.TECH_LOCKED, "precondition: Iron Working is locked")
	eq(entry(e, "iron").get("affordable"), false, "locked")
	eq(entry(e, "optics").get("state"), GameEngine.TECH_FUTURE, "precondition: Optics is a later era's")
	eq(entry(e, "optics").get("affordable"), false, "later era")


func test_affordable_is_about_insight_only_while_a_choice_is_owed() -> void:
	var e := afford_engine(3, {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}})
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	eq(e.pending().get("kind", ""), GameEngine.PENDING_EXPLORE, "precondition: an explore choice is owed")
	eq(entry(e, "writing").get("affordable"), true, "still affordable")
	check(e.buy_tech_error(uid_of(e.zone("research_deck"), "writing")) != "", "but it can't be bought yet")
