extends "res://tests/lib/test_case.gd"
## The sim on several processes (backlog 152): run_files' `procs` option spreads the games over child Godot processes
## (sim/run.gd playing one shard each) and merges them into the same report; a shard with no results fails the run.
## Real data with short games.

const CARDS := "res://data/cards.json"
const CONFIG := "res://data/config.json"


## run_files' result for seed_count seeds of strategy with these options merged over no civ and no seed.
func run_with(seed_count: int, strategy: String, options: Dictionary) -> Dictionary:
	var o := {"civ": "", "turns": 0, "seed": -1}
	o.merge(options, true)
	return SimStats.run_files(CARDS, CONFIG, seed_count, strategy, o)


## This process's result directories under the temp dir (named sim-<pid>-…).
func my_result_dirs() -> Array:
	var prefix := "sim-%d-" % OS.get_process_id()
	return Array(DirAccess.get_directories_at(OS.get_temp_dir())).filter(func(d): return d.begins_with(prefix))


# --- AC1, AC2, AC3: the same report on any number of processes ---

func test_the_report_is_the_same_on_1_2_and_4_processes() -> void:
	var one := run_with(3, "all", {"turns": 5, "procs": 1})
	eq(one.get("code"), 0, "exit code")
	check(one.get("lines", []).any(func(l): return l.begins_with("era_1_open")), "era metrics in the report")
	for n in [2, 4]:
		var out := run_with(3, "all", {"turns": 5, "procs": n})
		eq(out.get("procs"), n, "ran on %d processes" % n)
		eq(out.get("lines"), one.get("lines"), "the report on %d processes" % n)


func test_a_single_strategy_report_is_the_same_on_2_processes() -> void:
	var one := run_with(2, "baseline", {"civ": "sumer", "turns": 4, "procs": 1})
	var two := run_with(2, "baseline", {"civ": "sumer", "turns": 4, "procs": 2})
	eq(two.get("procs"), 2, "ran on 2 processes")
	eq(two.get("lines"), one.get("lines"), "the report")


func test_more_processes_than_games_runs_one_per_game() -> void:
	var one := run_with(3, "baseline", {"civ": "sumer", "turns": 4, "procs": 1})
	var eight := run_with(3, "baseline", {"civ": "sumer", "turns": 4, "procs": 8})
	eq(eight.get("procs"), 3, "3 games: 3 processes")
	eq(eight.get("lines"), one.get("lines"), "the report")


# --- AC4: in-process unless asked ---

func test_run_files_plays_in_this_process_by_default() -> void:
	var out := run_with(1, "baseline", {"turns": 2})
	eq(out.get("code"), 0, "exit code")
	eq(out.get("procs"), 1, "no child processes")


# --- AC5, AC6: a failed shard, and cleaning up ---

func test_a_shard_with_no_results_fails_the_run_and_its_directory_goes() -> void:
	var dir := OS.get_temp_dir().path_join("test-152-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(dir)
	var options := {"civ": "sumer", "turns": 2, "seed": -1}
	for i in [0, 2, 3]:  # shard 1 (the 2nd of 4) never writes
		eq(SimStats.play_shard(CARDS, CONFIG, 4, "baseline", options, i, 4, SimStats.shard_path(dir, i)), 0, "shard %d played" % i)
	var data := DataLoader.load_all(CARDS, CONFIG)
	var read: Dictionary = SimStats.read_shards(dir, 4, 4, SimStats.metric_names(data.cards, data.config))
	eq(read.get("errors"), ["shard 2 of 4 wrote no results"], "the missing shard named")
	eq(read.get("games", []).filter(func(g): return g != null).size(), 3, "the other 3 games read")
	check(not DirAccess.dir_exists_absolute(dir), "the results directory is removed")


func test_a_parallel_run_leaves_no_results_directory() -> void:
	var out := run_with(2, "baseline", {"turns": 2, "procs": 2})
	eq(out.get("code"), 0, "exit code")
	eq(out.get("procs"), 2, "ran on 2 processes")
	eq(my_result_dirs(), [], "no sim-%d-… directory left in %s" % [OS.get_process_id(), OS.get_temp_dir()])
