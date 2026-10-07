extends "res://tests/lib/test_case.gd"
## GameEngine's split (backlog 249): the read queries live in EngineQueries, between EngineCore and GameEngine; the
## actions, their *_error queries and the internals stay in GameEngine. The territory queries moved down into
## TerritoryQueries, between EngineCore and EngineQueries (281).
## In detail (from docs/testing.md, 331): GameEngine's split (249, 281): `EngineCore` → `TerritoryQueries` (the
## territory queries) → `EngineQueries` (the other read queries) → `GameEngine` (fork, actions and their error queries,
## internals); every method still on a `GameEngine`; each file under 500 lines

const QUERIES_PATH := "res://engine/engine_queries.gd"
const ENGINE_PATH := "res://engine/game_engine.gd"
const TERRITORY_PATH := "res://engine/territory_queries.gd"
## The queries TerritoryQueries took from EngineQueries (281), plus the tier queries it added.
const TERRITORY_QUERIES: Array[String] = ["pop", "housing", "territory_keywords", "count_territories_with", "total_pop",
	"total_slots", "free_slots", "free_workers", "tier", "tier_name", "next_tier_pop", "is_idle", "territory_name",
	"territory_of", "territory_groups", "territory_summary", "territory_status", "territory_tooltip"]
## The read queries GameEngine had under "# --- Queries ---" when 249 was specced.
const QUERIES: Array[String] = ["turn_limit", "score", "civilization", "government", "event_counters",
	"famine_counters", "population_on", "unrest_on", "pop", "housing", "territory_keywords", "count_territories_with",
	"famine_relief", "outcome_summary", "total_pop", "pending", "research_card_name", "era",
	"upkeep_forecast", "event_turns_left", "era_unlocks", "upcoming_era_unlocks", "tech_eras", "tech_tree", "era_name",
	"tech_cost", "supply", "supply_left", "open_supply_piles", "supply_locked", "buy_price", "supply_play_cost",
	"count_tag", "actions_per_turn", "unrest_limit", "anarchy_id", "anarchy", "order_relief", "anarchy_counters",
	"revolt_forecast", "at_unrest_limit", "anarchy_ahead", "hand_size", "modifier", "actions_left", "play_cost",
	"play_shortfall", "playable_error", "valid_targets", "total_slots", "free_slots", "free_workers", "is_idle",
	"unit_station", "units_at", "needs_target_choice", "needs_target", "def_details", "card_details", "territory_name",
	"territory_of", "territory_groups", "territory_summary", "territory_status", "territory_tooltip", "zone_of",
	"hand_limit", "research_on", "hand_input_error", "discard_needed", "supply_error", "build_preview", "turn_forecast",
	"would_need_target", "would_target", "legal_actions"]  # 309, 310, 312
## Some of what stays in GameEngine: fork, actions with their error queries, internals.
const STAYS: Array[String] = ["fork", "sample_fork", "new_game", "play_card", "play_error", "end_turn", "end_turn_error",
	"_blocked_error", "_owed_error"]


func declared(path: String) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(path):
		return out
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("func "):
			out.append(line.trim_prefix("func ").get_slice("(", 0))
	return out


func lines_in(path: String) -> int:
	return FileAccess.get_file_as_string(path).split("\n").size() if FileAccess.file_exists(path) else 0


# --- AC1: the chain ---

func test_game_engine_extends_engine_queries_which_extends_engine_core() -> void:
	check(ResourceLoader.exists(QUERIES_PATH), "engine_queries.gd exists")
	if not ResourceLoader.exists(QUERIES_PATH):
		return
	var queries: Script = load(QUERIES_PATH)
	eq(queries.get_global_name(), &"EngineQueries", "class_name")
	eq(queries.get_base_script(), load(TERRITORY_PATH), "EngineQueries extends TerritoryQueries (281)")
	eq((load(TERRITORY_PATH) as Script).get_base_script(), load("res://engine/engine_core.gd"),
		"TerritoryQueries extends EngineCore")
	eq((load(ENGINE_PATH) as Script).get_base_script(), queries, "GameEngine extends EngineQueries")


func test_every_query_and_action_is_still_on_a_game_engine() -> void:
	var e := make_engine({"farm": 10})
	for name in QUERIES + TERRITORY_QUERIES + STAYS:
		check(e.has_method(name), "GameEngine.%s" % name)  # scaffolding-ok: checks the engine's surface after a split


# --- AC2: where each method is declared ---

func test_queries_are_declared_in_engine_queries_only() -> void:
	var in_queries := declared(QUERIES_PATH)
	var in_territory := declared(TERRITORY_PATH)
	var in_engine := declared(ENGINE_PATH)
	for name in QUERIES:
		if TERRITORY_QUERIES.has(name):
			continue
		check(in_queries.has(name), "%s in engine_queries.gd" % name)
		check(not in_engine.has(name), "%s not in game_engine.gd" % name)
	for name in TERRITORY_QUERIES:
		check(in_territory.has(name), "%s in territory_queries.gd" % name)
		check(not in_queries.has(name) and not in_engine.has(name), "%s only in territory_queries.gd" % name)
	for name in STAYS:
		check(in_engine.has(name), "%s stays in game_engine.gd" % name)


# --- AC3: sizes ---

func test_both_files_are_under_the_soft_limit() -> void:
	check(lines_in(QUERIES_PATH) > 0, "engine_queries.gd has lines")
	check(lines_in(QUERIES_PATH) <= 500, "engine_queries.gd: %d lines" % lines_in(QUERIES_PATH))
	check(lines_in(ENGINE_PATH) <= 500, "game_engine.gd: %d lines" % lines_in(ENGINE_PATH))
	check(lines_in(TERRITORY_PATH) <= 500, "territory_queries.gd: %d lines" % lines_in(TERRITORY_PATH))


# --- 394: no forwards to a module that has an area ---

const CORE_PATH := "res://engine/engine_core.gd"


## The class names of the engine's areas: GameEngine's properties typed as a class (engine.military: Military).
func area_modules() -> Array[String]:
	var out: Array[String] = []
	for p in (GameEngine as Script).get_script_property_list():
		if p.type == TYPE_OBJECT and p.class_name != &"" and String(p.name) == String(p.class_name).to_snake_case():
			out.append(String(p.class_name))
	return out


## The public methods in path whose whole body is one `return <module>.x(self…` for a module in modules.
func forwards_in(path: String, modules: Array[String]) -> Array[String]:
	var found: Array[String] = []
	var lines := FileAccess.get_file_as_string(path).split("\n")
	for i in lines.size():
		if not lines[i].begins_with("func ") or lines[i].begins_with("func _"):
			continue
		var body: Array[String] = []
		for j in range(i + 1, lines.size()):
			if lines[j].begins_with("func ") or lines[j].begins_with("##") or lines[j].begins_with("# ---"):
				break
			if lines[j].strip_edges() != "" and not lines[j].strip_edges().begins_with("#"):
				body.append(lines[j].strip_edges())
		for module in modules:
			if body.size() == 1 and body[0].begins_with("return %s." % module) and body[0].contains("(self"):
				found.append("%s: %s" % [path.get_file(), lines[i].trim_prefix("func ").get_slice("(", 0)])
	return found


func test_no_engine_method_forwards_to_an_area() -> void:
	var modules := area_modules()
	eq(modules, ["Military"] as Array[String], "the engine's areas")
	var found: Array[String] = []
	for path in [ENGINE_PATH, QUERIES_PATH, TERRITORY_PATH]:
		found.append_array(forwards_in(path, ["Military"] as Array[String] if modules.is_empty() else modules))
	eq(found, [] as Array[String], "forwards to an area's module: call engine.<area>.x instead")
