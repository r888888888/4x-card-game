extends "res://tests/lib/test_case.gd"
## GameEngine's split (backlog 249): the read queries live in EngineQueries, between EngineCore and GameEngine; the
## actions, their *_error queries and the internals stay in GameEngine.

const QUERIES_PATH := "res://engine/engine_queries.gd"
const ENGINE_PATH := "res://engine/game_engine.gd"
## The read queries GameEngine had under "# --- Queries ---" when 249 was specced.
const QUERIES: Array[String] = ["turn_limit", "score", "civilization", "government", "event_counters",
	"famine_counters", "population_on", "unrest_on", "pop", "housing", "territory_keywords", "count_territories_with",
	"grow_cost", "famine_relief", "outcome_summary", "total_pop", "pending", "research_card_name", "era",
	"upkeep_forecast", "event_turns_left", "era_unlocks", "upcoming_era_unlocks", "tech_eras", "tech_tree", "era_name",
	"tech_cost", "supply", "supply_left", "open_supply_piles", "supply_locked", "buy_price", "supply_play_cost",
	"count_tag", "actions_per_turn", "unrest_limit", "anarchy_id", "anarchy", "order_relief", "anarchy_counters",
	"revolt_forecast", "at_unrest_limit", "anarchy_ahead", "hand_size", "modifier", "actions_left", "play_cost",
	"play_shortfall", "playable_error", "valid_targets", "total_slots", "free_slots", "free_workers", "is_idle",
	"unit_station", "units_at", "needs_target_choice", "needs_target", "def_details", "card_details", "territory_name",
	"territory_of", "territory_groups", "territory_summary", "territory_status", "territory_tooltip", "zone_of",
	"hand_limit", "research_on", "hand_input_error", "discard_needed", "supply_error"]
## Some of what stays in GameEngine: fork, actions with their error queries, internals.
const STAYS: Array[String] = ["fork", "new_game", "play_card", "play_error", "end_turn", "end_turn_error",
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
	eq(queries.get_base_script(), load("res://engine/engine_core.gd"), "EngineQueries extends EngineCore")
	eq((load(ENGINE_PATH) as Script).get_base_script(), queries, "GameEngine extends EngineQueries")


func test_every_query_and_action_is_still_on_a_game_engine() -> void:
	var e := make_engine({"farm": 10})
	for name in QUERIES + STAYS:
		check(e.has_method(name), "GameEngine.%s" % name)


# --- AC2: where each method is declared ---

func test_queries_are_declared_in_engine_queries_only() -> void:
	var in_queries := declared(QUERIES_PATH)
	var in_engine := declared(ENGINE_PATH)
	for name in QUERIES:
		check(in_queries.has(name), "%s in engine_queries.gd" % name)
		check(not in_engine.has(name), "%s not in game_engine.gd" % name)
	for name in STAYS:
		check(in_engine.has(name), "%s stays in game_engine.gd" % name)


# --- AC3: sizes ---

func test_both_files_are_under_the_soft_limit() -> void:
	check(lines_in(QUERIES_PATH) > 0, "engine_queries.gd has lines")
	check(lines_in(QUERIES_PATH) <= 500, "engine_queries.gd: %d lines" % lines_in(QUERIES_PATH))
	check(lines_in(ENGINE_PATH) <= 500, "game_engine.gd: %d lines" % lines_in(ENGINE_PATH))
