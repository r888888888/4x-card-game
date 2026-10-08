extends "res://tests/lib/test_case.gd"
## Command-line options (backlog 135): LaunchOptions parses --civ, --turns and --seed for the game and the sim. The
## sim runs on the real data (AC5) are in tests/balance/test_sim_reports.gd.

const CIVS := ["egypt", "sumer"]


## parse(args, CIVS) for check_cases: {errors, warnings}.
func parse_result(args: Array) -> Dictionary:
	var out: Dictionary = LaunchOptions.parse(PackedStringArray(args), CIVS)
	return {"errors": out.errors, "warnings": [] as Array[String]}


# --- AC1: parse ---

func test_parse_reads_civ_turns_seed_and_positional_args() -> void:
	var o: Dictionary = LaunchOptions.parse(PackedStringArray(["20", "--civ", "sumer", "--turns", "15", "--seed", "5"]), CIVS)
	eq(o.civ, "sumer", "civ")
	eq(o.turns, 15, "turns")
	eq(o.seed, 5, "seed")
	eq(o.positional, ["20"], "positional")
	eq(o.errors, [] as Array[String], "errors")


func test_parse_defaults_with_no_options() -> void:
	var o: Dictionary = LaunchOptions.parse(PackedStringArray(), CIVS)
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
	var o: Dictionary = LaunchOptions.parse(PackedStringArray(["--civ", "rome", "--turns", "abc", "--seed", "x"]), CIVS)
	eq([o.civ, o.turns, o.seed], ["", 0, -1], "defaults kept")


# --- AC3: the turn limit ---

func test_apply_sets_the_turn_limit() -> void:
	var e := make_engine({"shrine": 10})
	LaunchOptions.apply(e, {"civ": "", "turns": 7, "seed": -1})
	eq(e.turn_limit(), 7, "turn limit")
	e.new_game(1)
	for i in 10:
		if not e.is_over:
			e.end_turn()
	check(e.is_over, "the game ended")
	eq(e.turn, 7, "after turn 7")


func test_apply_without_turns_keeps_the_config_limit() -> void:
	var e := make_engine({"shrine": 10}, {"turn_limit": 12})
	LaunchOptions.apply(e, {"civ": "", "turns": 0, "seed": -1})
	eq(e.turn_limit(), 12, "config limit")


# --- AC4: starting straight away ---

func test_starts_game_with_a_civ_or_a_seed() -> void:
	eq(LaunchOptions.starts_game({"civ": "sumer", "turns": 0, "seed": -1}), true, "civ")
	eq(LaunchOptions.starts_game({"civ": "", "turns": 0, "seed": 4}), true, "seed")
	eq(LaunchOptions.starts_game({"civ": "", "turns": 20, "seed": -1}), false, "turns only")


# --- 378: a script's arguments aren't the game's ---

func test_378_the_game_reads_no_options_when_godot_runs_a_script() -> void:
	var sim := PackedStringArray(["--headless", "--path", ".", "--script", "res://sim/run.gd"])
	var under_sim: Dictionary = LaunchOptions.for_game(sim, PackedStringArray(["--level", "2", "--civ", "sumer"]), CIVS)
	eq(under_sim.get("errors"), [], "the sim's --level is not the game's unknown option")
	eq(under_sim.get("civ"), "", "nor does the game start as the sim's --civ")
	var game: Dictionary = LaunchOptions.for_game(PackedStringArray(["--path", "."]), PackedStringArray(["--civ", "sumer"]), CIVS)
	eq(game.get("civ"), "sumer", "the game itself reads its options")
	var bad: Dictionary = LaunchOptions.for_game(PackedStringArray(["--path", "."]), PackedStringArray(["--level", "2"]), CIVS)
	check(not bad.get("errors", []).is_empty(), "and still reports an unknown one")
