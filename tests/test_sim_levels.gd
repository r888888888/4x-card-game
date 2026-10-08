extends "res://tests/lib/test_case.gd"
## Sim levels (backlog 378): SimLevels.run_args reads scripts/sim.sh's arguments, --level 1-4 among them, into the
## seeds, strategy and civilization a run (or a comparison) plays, and the games SimStats.job_list makes of them.


## A parsed config listing Tribe and Nomads (TEST_CIVS) with Nomads as starting.civilization (baseline), 2 turns.
func level_config(baseline := "nomads") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(level_raw_config(baseline), resources(), civ_db(errors, warnings), "test",
		errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return config


## The raw config level_config parses.
func level_raw_config(baseline: String) -> Dictionary:
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"}
	if baseline != "":
		starting["civilization"] = baseline
	return raw_config({"shrine": 10}, {"civilizations": ["tribe", "nomads"], "turn_limit": 2, "starting": starting,
		"keywords": keywords()})


## SimLevels.run_args(args, config): {seeds, strategy, civ, turns, errors, …}.
func run_args(args: Array, config := {}) -> Dictionary:
	return SimLevels.run_args(PackedStringArray(args), config if not config.is_empty() else level_config())


## The games a run with these arguments plays: SimStats.job_list of run_args' seeds, strategy and civ.
func level_jobs(args: Array, config := {}) -> Array:
	var c := config if not config.is_empty() else level_config()
	var a := run_args(args, c)
	return SimStats.job_list(c, a.get("seeds", 0), a.get("strategy", ""), a.get("civ", ""))


## Runs SimStats.run_files on the fixture data (written to user://) with run_args' choices; returns its lines.
func level_run_lines(args: Array) -> Array:
	var cards_path := "user://sim_378_cards.json"
	var config_path := "user://sim_378_config.json"
	var cards: Array = TEST_CARDS.cards + TEST_CIVS
	for pair in [[cards_path, {"cards": cards}], [config_path, level_raw_config("nomads")]]:
		var f := FileAccess.open(pair[0], FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1]))
		f.close()
	var a := run_args(args)
	var out: Dictionary = SimStats.run_files(cards_path, config_path, a.get("seeds", 0), a.get("strategy", ""),
		{"civ": a.get("civ", "")})
	eq(out.get("code"), 0, "the run plays: %s" % [out.get("lines")])
	return out.get("lines", [])


# --- AC1: level 1 ---

func test_level_1_is_one_game_of_the_baseline_strategy_as_the_baseline_civ() -> void:
	eq(level_jobs(["--level", "1"]), [[1, GenericBot.STRATEGY, "nomads"]], "seed 1, generic, starting.civilization")


func test_a_level_1_run_prints_one_table() -> void:
	var lines := level_run_lines(["--level", "1"])
	check(not lines.any(func(l): return l.begins_with("== ")), "no block per strategy: %s" % [lines])
	check(lines.any(func(l): return l.begins_with("score ") and l.contains("mean")), "a score line: %s" % [lines])


# --- AC2: level 2 ---

func test_level_2_is_seed_1_of_every_strategy_as_the_baseline_civ() -> void:
	var expected := GenericBot.STRATEGIES.map(func(s): return [1, s, "nomads"])
	eq(level_jobs(["--level", "2"]), expected, "one game per strategy, in strategy order")


func test_a_level_2_run_names_the_baseline_civ_in_each_strategy_block() -> void:
	var lines := level_run_lines(["--level", "2"])
	eq(lines.filter(func(l): return l.begins_with("== ")).size(), GenericBot.STRATEGIES.size(), "a block per strategy")
	var scores := lines.filter(func(l): return l.begins_with("score by civilization: "))
	eq(scores.size(), GenericBot.STRATEGIES.size(), "a score line per block: %s" % [lines])
	check(scores.all(func(l): return l.begins_with("score by civilization: nomads ")), "named nomads: %s" % [scores])


# --- AC3: levels 3 and 4 ---

func test_level_3_is_seed_1_of_every_strategy_as_every_civ() -> void:
	var expected := []
	for s in GenericBot.STRATEGIES:
		for civ in ["tribe", "nomads"]:
			expected.append([1, s, civ])
	eq(level_jobs(["--level", "3"]), expected, "strategy, then civ; 3 x 2 games")


func test_level_4_is_seeds_1_to_10_of_every_strategy_as_every_civ() -> void:
	var expected := []
	for s in GenericBot.STRATEGIES:
		for civ in ["tribe", "nomads"]:
			for seed in range(1, 11):
				expected.append([seed, s, civ])
	eq(level_jobs(["--level", "4"]), expected, "10 x 3 x 2 games")


# --- AC4: --civ and --turns with a level ---

func test_civ_replaces_the_baseline_civ_at_levels_1_and_2() -> void:
	eq(level_jobs(["--level", "1", "--civ", "tribe"]), [[1, GenericBot.STRATEGY, "tribe"]], "level 1 as tribe")
	var two := level_jobs(["--level", "2", "--civ", "tribe"])
	eq(two.map(func(j): return j[2]), GenericBot.STRATEGIES.map(func(_s): return "tribe"), "level 2 as tribe")


func test_civ_is_refused_at_levels_3_and_4() -> void:
	for level in ["3", "4"]:
		var a := run_args(["--level", level, "--civ", "tribe"])
		var errors: Array[String] = []
		errors.assign(a.get("errors", []))
		has_msg(errors, "every civilization")


func test_turns_work_with_a_level() -> void:
	var a := run_args(["--level", "2", "--turns", "7"])
	eq(a.get("turns"), 7, "turn limit")
	eq(a.get("errors"), [], "no errors")


# --- AC5: bad levels ---

func test_a_level_other_than_1_to_4_is_refused() -> void:
	for value in ["0", "5", "x"]:
		var errors: Array[String] = []
		errors.assign(run_args(["--level", value]).get("errors", []))
		has_msg(errors, "--level '%s'" % value)
		has_msg(errors, "1, 2, 3 or 4")
	var missing: Array[String] = []
	missing.assign(run_args(["--level"]).get("errors", []))
	has_msg(missing, "--level needs a value")


func test_a_level_with_a_seed_count_or_strategy_is_refused() -> void:
	for args in [["20", "--level", "2"], ["--level", "2", "wide"]]:
		var errors: Array[String] = []
		errors.assign(run_args(args).get("errors", []))
		has_msg(errors, "--level replaces")


# --- AC6: --compare with a level ---

func test_a_compared_level_gets_its_seed_count_as_the_most_a_cell_plays() -> void:
	var config := level_config()
	var two := run_args(["--level", "2"], config)
	eq(two.get("seeds"), 1, "level 2: at most 1 seed a cell")
	var cells := SimStats.job_list(config, 1, two.get("strategy", ""), two.get("civ", ""))
	eq(cells.size(), GenericBot.STRATEGIES.size(), "level 2: a cell per strategy as nomads: %s" % [cells])
	for level in ["1", "3"]:
		eq(run_args(["--level", level], config).get("seeds"), 1, "level %s: at most 1 seed a cell" % level)
	eq(run_args(["--level", "4"], config).get("seeds"), 10, "level 4: at most 10 seeds a cell")


# --- AC7: no baseline civ ---

func test_levels_1_and_2_need_a_baseline_civ() -> void:
	var config := level_config("")
	for level in ["1", "2"]:
		var errors: Array[String] = []
		errors.assign(run_args(["--level", level], config).get("errors", []))
		has_msg(errors, "starting.civilization")
	eq(run_args(["--level", "2", "--civ", "tribe"], config).get("errors"), [], "--civ gives it one")


# --- no level: as before ---

func test_without_a_level_the_seed_count_and_strategy_are_positional() -> void:
	var a := run_args(["5", "wide", "--civ", "tribe"])
	eq([a.get("seeds"), a.get("strategy"), a.get("civ")], [5, "wide", "tribe"], "as given")
	var defaults := run_args([])
	eq([defaults.get("seeds"), defaults.get("strategy"), defaults.get("civ")], [20, "all", ""], "the defaults")
