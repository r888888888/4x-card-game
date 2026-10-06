extends "res://tests/lib/test_case.gd"
## A parallel sim run's guard against a stalled or dead worker (backlog 318): what read_workers says about a game a
## worker claimed and never finished, the stall limit from the environment and the progress line. Hand-written run
## directories, no games (the runs that spawn workers are in tests/balance/test_parallel_sim.gd).

const CIVS := ["egypt", "sumer", "phoenicia", "babylon", "greece", "persia"]


## A run directory for this test: jobs.json with seed 1 of each strategy × CIVS (18 jobs, wide greece is index 10), and
## job 10 claimed.
func fixture_run(name: String) -> String:
	var dir := OS.get_temp_dir().path_join("test-318-%s-%d" % [name, OS.get_process_id()])
	DirAccess.make_dir_recursive_absolute(dir.path_join("claims").path_join("10"))
	var jobs := []
	for s in ["generic", "wide", "tall"]:
		for civ in CIVS:
			jobs.append([1, s, civ])
	var file := FileAccess.open(dir.path_join("jobs.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(jobs))
	file.close()
	return dir


func fixture_names() -> Array[String]:
	return ["score"] as Array[String]


# --- AC3: a dead worker's game ---

func test_bug_318_a_dead_workers_game_is_named_with_its_turn() -> void:
	var stats: Object = SimStats.new()
	var dir := fixture_run("dead")
	stats.write_progress(dir, 3, 10, 57)
	var read: Dictionary = stats.read_workers(dir, 4, 18, fixture_names(), [10, 11])
	eq(read.get("errors"), ["worker 3 stopped during game 11 of 18 (seed 1, wide, greece) at turn 57",
		"game 12 of 18 has no result"], "the claimed game named with its worker and turn; the unclaimed one as before")
	check(not DirAccess.dir_exists_absolute(dir), "the results directory is removed")


# --- AC2: a stalled worker's game (the message; the run itself is in the balance suite) ---

func test_bug_318_a_stalled_workers_game_names_the_stall_limit() -> void:
	var stats: Object = SimStats.new()
	var dir := fixture_run("stalled")
	stats.write_progress(dir, 3, 10, 57)
	var read: Dictionary = stats.read_workers(dir, 4, 18, fixture_names(), [10], {3: 600})
	eq(read.get("errors"), ["worker 3 stalled during game 11 of 18 (seed 1, wide, greece) at turn 57: no turn finished "
		+ "in 600 s"], "the stalled game")


func test_bug_318_a_worker_stalled_between_games_is_named() -> void:
	var stats: Object = SimStats.new()
	var dir := fixture_run("between")
	stats.write_progress(dir, 2, -1, 0)
	var read: Dictionary = stats.read_workers(dir, 4, 18, fixture_names(), [], {2: 30})
	eq(read.get("errors", []).filter(func(e): return e.begins_with("worker")),
		["worker 2 stalled with no game in play: no turn finished in 30 s"], "the worker with no game in play")


# --- AC1: the progress file ---

func test_bug_318_progress_reads_back_what_was_written() -> void:
	var stats: Object = SimStats.new()
	var dir := fixture_run("progress")
	var before := Time.get_unix_time_from_system()
	stats.write_progress(dir, 1, 10, 57)
	var p: Dictionary = stats.read_progress(dir, 1)
	var none: Dictionary = stats.read_progress(dir, 2)
	remove_tree(dir)
	eq(p.get("job"), 10, "the job index")
	eq(p.get("turn"), 57, "the turn reached")
	check(p.get("at", 0.0) >= before - 1.0 and p.get("at", 0.0) <= Time.get_unix_time_from_system() + 1.0,
		"written now: %s" % [p.get("at")])
	eq(none, {}, "no progress file: {}")


# --- AC4: the stall limit ---

func test_bug_318_the_stall_limit_defaults_to_10_minutes() -> void:
	var stats: Object = SimStats.new()
	eq(stats.stall_sec_from_env({}), 600, "no SIM_STALL_SEC")
	eq(stats.stall_sec_from_env({"SIM_STALL_SEC": ""}), 600, "empty")


func test_bug_318_sim_stall_sec_sets_the_stall_limit() -> void:
	var stats: Object = SimStats.new()
	eq(stats.stall_sec_from_env({"SIM_STALL_SEC": "30"}), 30, "30")
	eq(stats.stall_sec_from_env({"SIM_STALL_SEC": "1"}), 1, "the least")


func test_bug_318_an_invalid_sim_stall_sec_is_ignored() -> void:
	var stats: Object = SimStats.new()
	for bad in ["0", "-5", "abc", "1.5"]:
		eq(stats.stall_sec_from_env({"SIM_STALL_SEC": bad}), 600, "'%s'" % bad)


# --- AC5: the progress line ---

func test_bug_318_the_progress_line_names_each_game_in_play() -> void:
	var stats: Object = SimStats.new()
	eq(stats.progress_line(17, 18, [[[1, "wide", "greece"], 63, 9.6]]),
		"sim: 17 of 18 games done; playing seed 1 wide greece (turn 63, 9 min)", "one game")
	eq(stats.progress_line(3, 18, [[[2, "generic", ""], 4, 0.2], [[1, "tall", "sumer"], 12, 1.0]]),
		"sim: 3 of 18 games done; playing seed 2 generic default (turn 4, 0 min), seed 1 tall sumer (turn 12, 1 min)",
		"two games; no civ is the default")
	eq(stats.progress_line(18, 18, []), "sim: 18 of 18 games done", "none in play")
