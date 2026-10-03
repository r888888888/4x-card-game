extends SceneTree
## Minimal test runner (no addon needed). Finds every tests/**/test_*.gd file and
## runs each test_* method on a fresh instance. Use scripts/test.sh rather than
## calling this directly; it also re-imports new classes and catches script errors.
##   godot --headless --fixed-fps 120 --path . --script res://tests/run_tests.gd [-- [--balance] <filter>]
## <filter> is a substring of "file::method", e.g. "rules" or "test_create_card".
## tests/balance/ (real-data sim runs) is left out; --balance runs only it.
## TEST_SHARD=i/n in the environment runs only shard i of n of the files (TestShards.pick, 223); scripts/test.sh runs
## the shards in parallel and sums their counts, so a shard where nothing matched the filter isn't a failure by itself.
## Frames don't sleep and --fixed-fps gives each one 1/120 s of game time (223): animation waits cost a fixed number
## of frames and run as fast as the CPU allows.
## A test fails if an assertion fails, it makes no assertions, or it raises any
## engine/script error (GDScript has no exceptions, so errors are caught by a Logger).
## Exits with code 1 if any test fails, a test file fails to load, or nothing ran.

const TEST_ROOT := "res://tests"
const BALANCE_ROOT := "res://tests/balance"
const PLAYER_SETTINGS := "user://settings.cfg"
const RUN_SETTINGS := "user://test_run_settings.cfg"  # the settings every test starts on (195)
const TestShards := preload("res://tests/lib/test_shards.gd")


## Collects errors (not warnings) logged while a test runs.
class ErrorCollector extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])


func _initialize() -> void:
	OS.low_processor_usage_mode_sleep_usec = 0  # headless can't draw, so Godot would sleep 6.9 ms every frame (223)
	# Autoloads (Game, Settings) join the tree and run _ready only after the first frame; UI tests need them.
	await process_frame
	var args := Array(OS.get_cmdline_user_args())
	var balance := args.has("--balance")
	args.erase("--balance")
	var shard := [0, 1]  # index, count: TEST_SHARD=i/n, an environment variable so the game's LaunchOptions don't see it
	if OS.has_environment("TEST_SHARD"):
		var parts := OS.get_environment("TEST_SHARD").split("/")
		shard = [int(parts[0]), int(parts[1])]
	var filter: String = args[0] if not args.is_empty() else ""
	var failures: Array[String] = []
	var count := 0
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var kept := root.get_children()  # the autoloads; anything else a test leaves behind is freed after it
	# The player's settings (Day mode, Reduce motion) must not change a result, nor a run change them (195): every test
	# starts on a fresh store with both off, and the player's file is compared before and after.
	var player_settings: Variant = _read(PLAYER_SETTINGS)
	var settings: Node = root.get_node("Settings")
	settings.store = SettingsStore.new(RUN_SETTINGS)
	settings.changed.emit()  # the palette follows the fresh store: Night

	for path in TestShards.pick(_find_test_files(BALANCE_ROOT if balance else TEST_ROOT), shard[0], shard[1]):
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append("%s: failed to load (parse error? see output above)" % path)
			continue
		var file_label := path.get_file().get_basename()
		for m in script.get_script_method_list():
			var method_name: String = m.name
			var test_name := "%s::%s" % [file_label, method_name]
			if not method_name.begins_with("test_") or not (filter.is_empty() or filter in test_name):
				continue
			count += 1
			var t: Object = script.new()
			t.test_name = test_name
			t.failures = failures
			collector.errors.clear()
			await t.call(method_name)  # a test may await frames (for layout); a plain one returns at once
			for e in collector.errors:
				if not t.expected_errors.any(func(fragment: String): return fragment in e):
					failures.append("%s: error: %s" % [test_name, e])
			for fragment: String in t.expected_errors:
				if not collector.errors.any(func(e: String): return fragment in e):
					failures.append("%s: expected an error containing '%s'" % [test_name, fragment])
			if t.assertions == 0:
				failures.append("%s: made no assertions (empty, or crashed before the first check)" % test_name)
			for node in root.get_children():  # a test that crashed before close_main leaves its scene in the tree
				if not kept.has(node):
					root.remove_child(node)
					node.free()

	if FileAccess.file_exists(RUN_SETTINGS):
		DirAccess.remove_absolute(RUN_SETTINGS)
	if _read(PLAYER_SETTINGS) != player_settings:
		failures.append("the run changed the player's %s (tests must use a temp settings store)" % PLAYER_SETTINGS)

	for f in failures:
		printerr("FAIL ", f)
	var whole_run: bool = shard[1] == 1
	if count == 0 and whole_run:
		printerr("No tests matched filter '%s'." % filter)
	print("%d tests, %d failures" % [count, failures.size()])
	quit(1 if not failures.is_empty() or (count == 0 and whole_run) else 0)


func _find_test_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		var sub_path := dir_path.path_join(sub)
		if sub == "lib" or sub_path == BALANCE_ROOT:  # helpers; the balance suite runs alone (--balance)
			continue
		found.append_array(_find_test_files(sub_path))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found


## The bytes of the file at path, or null when there is none.
func _read(path: String) -> Variant:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
