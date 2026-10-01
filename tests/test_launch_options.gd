extends "res://tests/lib/test_case.gd"
## Command-line options (backlog 135): LaunchOptions parses --civ, --turns and --seed for the game and the sim.
## LaunchOptions and SimStats are loaded untyped so this file parses before the new API exists.

const PATH := "res://autoload/launch_options.gd"
const CIVS := ["egypt", "sumer"]
var LO: Variant = load(PATH) if ResourceLoader.exists(PATH) else null
var STATS: Variant = load("res://sim/sim_stats.gd")


## parse(args, CIVS) for check_cases: {errors, warnings}.
func parse_result(args: Array) -> Dictionary:
	var out: Dictionary = LO.parse(PackedStringArray(args), CIVS)
	return {"errors": out.errors, "warnings": [] as Array[String]}


# --- AC1: parse ---

func test_parse_reads_civ_turns_seed_and_positional_args() -> void:
	var o: Dictionary = LO.parse(PackedStringArray(["20", "--civ", "sumer", "--turns", "15", "--seed", "5"]), CIVS)
	eq(o.civ, "sumer", "civ")
	eq(o.turns, 15, "turns")
	eq(o.seed, 5, "seed")
	eq(o.positional, ["20"], "positional")
	eq(o.errors, [] as Array[String], "errors")


func test_parse_defaults_with_no_options() -> void:
	var o: Dictionary = LO.parse(PackedStringArray(), CIVS)
	eq([o.civ, o.turns, o.seed, o.positional, o.errors], ["", 0, -1, [], [] as Array[String]], "defaults")


# --- AC2: bad options ---

func test_parse_rejects_bad_options() -> void:
	check_cases([
		["unlisted civ", ["--civ", "rome"], ["--civ", "'rome'", "egypt", "sumer"], "one_error"],
		["zero turns", ["--turns", "0"], ["--turns", "'0'"], "one_error"],
		["turns not a number", ["--turns", "abc"], ["--turns", "'abc'"], "one_error"],
		["negative seed", ["--seed", "-3"], ["--seed", "'-3'"], "one_error"],
		["no value", ["--turns"], ["--turns"], "one_error"],
		["unknown option", ["--speed", "2"], ["--speed"], "one_error"],
	], parse_result)


func test_bad_options_keep_their_defaults() -> void:
	var o: Dictionary = LO.parse(PackedStringArray(["--civ", "rome", "--turns", "abc", "--seed", "x"]), CIVS)
	eq([o.civ, o.turns, o.seed], ["", 0, -1], "defaults kept")


# --- AC3: the turn limit ---

func test_apply_sets_the_turn_limit() -> void:
	var e := make_engine({"shrine": 10})
	LO.apply(e, {"civ": "", "turns": 7, "seed": -1})
	eq(e.turn_limit(), 7, "turn limit")
	e.new_game(1)
	for i in 10:
		if not e.is_over:
			e.end_turn()
	check(e.is_over, "the game ended")
	eq(e.turn, 7, "after turn 7")


func test_apply_without_turns_keeps_the_config_limit() -> void:
	var e := make_engine({"shrine": 10}, {"turn_limit": 12})
	LO.apply(e, {"civ": "", "turns": 0, "seed": -1})
	eq(e.turn_limit(), 12, "config limit")


# --- AC4: starting straight away ---

func test_starts_game_with_a_civ_or_a_seed() -> void:
	eq(LO.starts_game({"civ": "sumer", "turns": 0, "seed": -1}), true, "civ")
	eq(LO.starts_game({"civ": "", "turns": 0, "seed": 4}), true, "seed")
	eq(LO.starts_game({"civ": "", "turns": 20, "seed": -1}), false, "turns only")


# --- AC5: the sim ---

func test_sim_uses_the_turn_limit_option() -> void:
	var out: Dictionary = STATS.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		{"civ": "", "turns": 5, "seed": -1})
	eq(out.get("code"), 0, "exit code")
	var explored: Array = out.get("lines", []).filter(func(l): return l.begins_with("explored "))
	check(not explored.is_empty() and explored[0].ends_with("max   5"), "games last 5 turns: %s" % [explored])


func test_sim_plays_only_the_civ_option() -> void:
	var out: Dictionary = STATS.run_files("res://data/cards.json", "res://data/config.json", 1, "all",
		{"civ": "sumer", "turns": 3, "seed": -1})
	eq(out.get("code"), 0, "exit code")
	var text := "\n".join(out.get("lines", []))
	check("sumer" in text, "the report names Sumer")
	check(not "egypt" in text, "and no other civilization: %s" % text)


func test_sim_plays_a_single_strategy_as_the_civ_option() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	var config: Dictionary = r.config.duplicate(true)
	config.turn_limit = 4
	var expected: Dictionary = STATS.run(r.cards, config, [1, 2], "baseline", "sumer")
	var out: Dictionary = STATS.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		{"civ": "sumer", "turns": 4, "seed": -1})
	var score: Array = out.get("lines", []).filter(func(l): return l.begins_with("score "))
	check(not score.is_empty() and ("mean %6.2f" % expected.score.mean) in score[0],
		"score line %s matches Sumer's %s" % [score, expected.score])
