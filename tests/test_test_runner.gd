extends "res://tests/lib/test_case.gd"
## The test runner itself (223): frames run without the headless sleep on a fixed time step, and the test files split
## into shards for parallel processes (tests/lib/test_shards.gd); a test_* method that takes arguments is reported
## instead of called (284, tests/lib/test_methods.gd).

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
