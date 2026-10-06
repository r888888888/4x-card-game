extends "res://tests/lib/test_case.gd"
## The sim on several processes (backlog 152): run_files' `procs` option spreads the games over child Godot processes
## and merges them into the same report; a game with no result fails the run. Since 291 the workers claim games from
## one queue (play_claimed), and a parallel run given a lock_path fails fast while another run holds it.
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
	var one := run_with(2, "generic", {"civ": "sumer", "turns": 4, "procs": 1})
	var two := run_with(2, "generic", {"civ": "sumer", "turns": 4, "procs": 2})
	eq(two.get("procs"), 2, "ran on 2 processes")
	eq(two.get("lines"), one.get("lines"), "the report")


func test_more_processes_than_games_runs_one_per_game() -> void:
	var one := run_with(3, "generic", {"civ": "sumer", "turns": 4, "procs": 1})
	var eight := run_with(3, "generic", {"civ": "sumer", "turns": 4, "procs": 8})
	eq(eight.get("procs"), 3, "3 games: 3 processes")
	eq(eight.get("lines"), one.get("lines"), "the report")


# --- AC4: in-process unless asked ---

func test_run_files_plays_in_this_process_by_default() -> void:
	var out := run_with(1, "generic", {"turns": 2})
	eq(out.get("code"), 0, "exit code")
	eq(out.get("procs"), 1, "no child processes")


# --- AC5, AC6: a game with no result, and cleaning up (since 291: a game claimed by a worker that died) ---

func test_a_game_with_no_result_fails_the_run_and_its_directory_goes() -> void:
	var stats: Object = SimStats.new()
	var dir := OS.get_temp_dir().path_join("test-152-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(stats.claim_path(dir, 1))  # game 2 of 4 claimed by a worker that never wrote it
	var options := {"civ": "sumer", "turns": 2, "seed": -1}
	eq(stats.play_claimed(CARDS, CONFIG, 4, "generic", options, dir, 0), 0, "worker 0 played")
	var data := DataLoader.load_all(CARDS, CONFIG)
	var read: Dictionary = stats.read_workers(dir, 1, 4, SimStats.metric_names(data.cards, data.config))
	eq(read.get("errors"), ["game 2 of 4 has no result"], "the missing game named")
	eq(read.get("games", []).filter(func(g): return g != null).size(), 3, "the other 3 games read")
	check(not DirAccess.dir_exists_absolute(dir), "the results directory is removed")


func test_a_parallel_run_leaves_no_results_directory() -> void:
	var out := run_with(2, "generic", {"turns": 2, "procs": 2})
	eq(out.get("code"), 0, "exit code")
	eq(out.get("procs"), 2, "ran on 2 processes")
	eq(my_result_dirs(), [], "no sim-%d-… directory left in %s" % [OS.get_process_id(), OS.get_temp_dir()])


# --- 291 AC2, AC3: the job queue ---

func test_a_worker_plays_only_the_unclaimed_games() -> void:
	var stats: Object = SimStats.new()
	var dir := OS.get_temp_dir().path_join("test-291-%d" % OS.get_process_id())
	for i in 4:  # games 1-4 of 6 already claimed
		DirAccess.make_dir_recursive_absolute(stats.claim_path(dir, i))
	var options := {"civ": "sumer", "turns": 2, "seed": -1}
	eq(stats.play_claimed(CARDS, CONFIG, 6, "generic", options, dir, 0), 0, "worker 0 played")
	eq(stats.play_claimed(CARDS, CONFIG, 6, "generic", options, dir, 1), 0, "worker 1 played")
	var first: Variant = JSON.parse_string(FileAccess.get_file_as_string(stats.worker_path(dir, 0)))
	var second: Variant = JSON.parse_string(FileAccess.get_file_as_string(stats.worker_path(dir, 1)))
	remove_tree(dir)
	eq(first.keys() if first is Dictionary else first, ["4", "5"], "worker 0 played games 5 and 6 (jobs 4, 5)")
	eq(second.keys() if second is Dictionary else second, [], "nothing left for worker 1")


func test_every_game_is_played_exactly_once_from_the_queue() -> void:
	var one := run_with(7, "generic", {"civ": "sumer", "turns": 3, "procs": 1})
	var two := run_with(7, "generic", {"civ": "sumer", "turns": 3, "procs": 2})
	eq(two.get("lines"), one.get("lines"), "the report on 2 processes")
	var per: Array = two.get("games_per_proc", [])
	eq(per.size(), 2, "2 workers")
	eq(per.reduce(func(a, b): return a + b, 0), 7, "7 games in all")


# --- 291 AC4, AC5, AC6: one parallel run at a time ---

func lock_path() -> String:
	return OS.get_temp_dir().path_join("test-291-lock-%d" % OS.get_process_id())


func test_a_parallel_run_fails_fast_while_another_holds_the_lock() -> void:
	var stats: Object = SimStats.new()
	var lock := lock_path()
	eq(stats.take_lock(lock), "", "the test holds the lock")
	var out := run_with(2, "generic", {"turns": 2, "procs": 2, "lock_path": lock})
	var held := DirAccess.dir_exists_absolute(lock)
	stats.release_lock(lock)
	eq(out.get("code"), 1, "exit code")
	eq(out.get("lines"), ["another sim run is using the CPU (pid %d); try again when it ends" % OS.get_process_id()],
		"the message")
	eq(out.get("games_per_proc", []), [], "no worker started")
	eq(my_result_dirs(), [], "no results directory")
	check(held, "the other run's lock is left in place")


func test_a_parallel_run_takes_over_a_dead_runs_lock_and_releases_it() -> void:
	var dead := OS.create_process("/usr/bin/true", [])
	while OS.is_process_running(dead):
		OS.delay_msec(10)
	var lock := lock_path()
	DirAccess.make_dir_recursive_absolute(lock)
	var file := FileAccess.open(lock.path_join("pid"), FileAccess.WRITE)
	file.store_string(str(dead))
	file.close()
	var out := run_with(2, "generic", {"turns": 2, "procs": 2, "lock_path": lock})
	var left := DirAccess.dir_exists_absolute(lock)
	remove_tree(lock)
	eq(out.get("code"), 0, "exit code: %s" % [out.get("lines")])
	check(not left, "the lock is released after the run")


func test_an_in_process_run_ignores_the_lock() -> void:
	var stats: Object = SimStats.new()
	var lock := lock_path()
	eq(stats.take_lock(lock), "", "the test holds the lock")
	var out := run_with(1, "generic", {"turns": 2, "procs": 1, "lock_path": lock})
	stats.release_lock(lock)
	eq(out.get("code"), 0, "exit code")
