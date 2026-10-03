extends "res://tests/lib/test_case.gd"
## The test runner itself (223): frames run without the headless sleep on a fixed time step, and the test files split
## into shards for parallel processes (tests/lib/test_shards.gd).

const SHARDS_PATH := "res://tests/lib/test_shards.gd"


# --- AC1, AC2: frames ---

func test_frames_run_without_the_headless_sleep() -> void:
	eq(OS.low_processor_usage_mode_sleep_usec, 0, "no sleep between frames")


func test_a_quarter_second_timer_takes_thirty_frames() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var timer := tree.create_timer(0.25)
	var frames := 0
	while timer.time_left > 0.0 and frames < 1000:
		await tree.process_frame
		frames += 1
	check(absi(frames - 30) <= 1, "0.25 s at a fixed 1/120 s per frame is 30 frames, took %d" % frames)


# --- AC3: shards ---

func test_shards_take_every_nth_file() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["a", "b", "c", "d", "e", "f", "g"]
	eq(shards.pick(files, 0, 3), ["a", "d", "g"] as Array[String], "shard 0 of 3")
	eq(shards.pick(files, 1, 3), ["b", "e"] as Array[String], "shard 1 of 3")
	eq(shards.pick(files, 2, 3), ["c", "f"] as Array[String], "shard 2 of 3")
	eq(shards.pick(files, 3, 8), [] as Array[String], "a shard past the last file gets none")


func test_one_shard_takes_every_file() -> void:
	var shards: Object = load(SHARDS_PATH)
	var files: Array[String] = ["a", "b", "c"]
	eq(shards.pick(files, 0, 1), files, "one shard: every file")
