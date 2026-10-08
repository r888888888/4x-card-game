extends "res://tests/lib/test_case.gd"
## The test runner itself (223): frames run without the headless sleep on a fixed time step, and the test files split
## into shards for parallel processes (tests/lib/test_shards.gd; 335: the slow files dealt first); a test_* method that takes arguments is reported
## instead of called (284, tests/lib/test_methods.gd).
## In detail (from docs/testing.md, 331): The runner itself (223): no frame sleep, a fixed 1/120 s step per frame even
## when a frame is slow, and the shard split (`tests/lib/test_shards.gd`): every n-th file, disjoint, one shard takes
## all; the warning when the player's settings file changes during a run (196, `tests/lib/settings_watch.gd`); a
## `test_*` method with arguments reported as a failure, not called (284, `tests/lib/test_methods.gd`, fixture
## `tests/lib/fixtures/runner_fixture.gd`)

const SHARDS_PATH := "res://tests/lib/test_shards.gd"
const WATCH_PATH := "res://tests/lib/settings_watch.gd"
const METHODS_PATH := "res://tests/lib/test_methods.gd"
const FIXTURE_PATH := "res://tests/lib/fixtures/runner_fixture.gd"


# --- AC1, AC2: frames ---

func test_frames_run_without_the_headless_sleep() -> void:
	eq(OS.low_processor_usage_mode_sleep_usec, 0, "no sleep between frames")


func test_each_frame_is_a_120th_of_a_second_whatever_the_wall_clock_does() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var deltas: Array[float] = []
	for i in 5:
		if i == 2:
			OS.delay_msec(50)  # a slow frame: six 120ths of real time
		await tree.process_frame
		deltas.append(tree.root.get_process_delta_time())
	for d in deltas:
		check(absf(d - 1.0 / 120.0) < 0.0001, "each frame advances 1/120 s of game time: %s" % [deltas])


# --- AC3: shards ---

func test_shards_take_every_nth_file() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["a", "b", "c", "d", "e", "f", "g"]
	eq(shards.pick(files, 0, 3), ["a", "d", "g"] as Array[String], "shard 0 of 3")
	eq(shards.pick(files, 1, 3), ["b", "e"] as Array[String], "shard 1 of 3")
	eq(shards.pick(files, 2, 3), ["c", "f"] as Array[String], "shard 2 of 3")
	eq(shards.pick(files, 7, 8), [] as Array[String], "a shard past the last file gets none")


func test_one_shard_takes_every_file() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["a", "b", "c"]
	eq(shards.pick(files, 0, 1), files, "one shard: every file")



# --- 335: slow files dealt first ---

func test_slow_files_are_dealt_first_one_per_shard_then_the_rest_round_robin() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["c", "a", "d", "b", "e"]
	var dealt: Array[String] = shards.slow_first(files, ["a", "b"] as Array[String])
	eq(dealt, ["a", "b", "c", "d", "e"] as Array[String], "the slow files first, in the slow list's order")
	eq(shards.pick(dealt, 0, 2), ["a", "c", "e"] as Array[String], "shard 0 of 2")
	eq(shards.pick(dealt, 1, 2), ["b", "d"] as Array[String], "shard 1 of 2")


func test_slow_files_match_by_file_name_and_a_missing_one_is_skipped() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["res://tests/test_c.gd", "res://tests/test_a.gd"]
	eq(shards.slow_first(files, ["test_a.gd", "test_gone.gd"] as Array[String]),
		["res://tests/test_a.gd", "res://tests/test_c.gd"] as Array[String], "test_a first; test_gone isn't there")


func test_the_slow_list_names_test_files_that_exist() -> void:
	var shards: Object = load(SHARDS_PATH)
	var slow: Array = shards.get("SLOW") if shards.get("SLOW") != null else []
	check(slow.size() >= 3, "at least three slow files: %s" % [slow])
	for file in slow:
		check(FileAccess.file_exists("res://tests/" + file), "%s exists" % file)


func test_every_file_runs_exactly_once_for_1_to_12_shards() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = []
	for file in DirAccess.get_files_at("res://tests"):
		if file.begins_with("test_") and file.ends_with(".gd"):
			files.append("res://tests/" + file)
	var dealt: Array[String] = shards.slow_first(files, shards.SLOW)
	for n in range(1, 13):
		var seen: Array[String] = []
		for i in n:
			seen.append_array(shards.pick(dealt, i, n))
		seen.sort()
		var want := files.duplicate()
		want.sort()
		eq(seen, want, "%d shards: every file once" % n)


func test_the_runner_deals_the_slow_files_first() -> void:
	var runner := FileAccess.get_file_as_string("res://tests/run_tests.gd")
	check(runner.contains("TestShards.slow_first("), "run_tests.gd orders the files with TestShards.slow_first")

# --- 196: the player's settings file changing is a warning ---

func test_bug_196_different_settings_bytes_warn_naming_the_file() -> void:
	var watch: Object = load(WATCH_PATH)
	var warning: String = watch.settings_change_warning("a=1".to_utf8_buffer(), "a=2".to_utf8_buffer())
	check("user://settings.cfg" in warning, "the warning names the file: '%s'" % warning)
	check("test" in warning and "game" in warning, "it says a test or a running game changed it: '%s'" % warning)


func test_bug_196_a_file_that_appears_or_vanishes_warns() -> void:
	var watch: Object = load(WATCH_PATH)
	check(watch.settings_change_warning(null, "a=1".to_utf8_buffer()) != "", "no file, then a file")
	check(watch.settings_change_warning("a=1".to_utf8_buffer(), null) != "", "a file, then none")


func test_bug_196_same_settings_bytes_give_no_warning() -> void:
	var watch: Object = load(WATCH_PATH)
	eq(watch.settings_change_warning("a=1".to_utf8_buffer(), "a=1".to_utf8_buffer()), "", "same bytes")
	eq(watch.settings_change_warning(null, null), "", "no file both times")


# --- 284: a test_* method that takes arguments is reported, not called ---

func test_bug_284_a_test_method_with_arguments_is_reported_not_run() -> void:
	var methods: Object = load(METHODS_PATH)
	var picked: Dictionary = methods.select(load(FIXTURE_PATH), "runner_fixture", "")
	eq(picked.run, ["test_plain"] as Array[String], "only the method without arguments runs")
	eq(picked.failures, ["runner_fixture::test_helper: test methods take no arguments; rename the helper"] as Array[String],
			"the helper is reported by file::method")


func test_bug_284_a_filtered_out_method_with_arguments_is_not_reported() -> void:
	var methods: Object = load(METHODS_PATH)
	var picked: Dictionary = methods.select(load(FIXTURE_PATH), "runner_fixture", "test_plain")
	eq(picked.run, ["test_plain"] as Array[String], "the filter keeps test_plain")
	eq(picked.failures, [] as Array[String], "test_helper is left out by the filter, so not reported")


func test_bug_284_methods_not_named_test_are_ignored() -> void:
	var methods: Object = load(METHODS_PATH)
	var picked: Dictionary = methods.select(load(FIXTURE_PATH), "runner_fixture", "")
	for name: String in ["helper", "plain"]:
		check(not picked.run.has(name), "%s doesn't run" % name)
		check(not picked.failures.any(func(f: String): return f.get_slice(":", 2) == name), "%s isn't reported" % name)
