extends SceneTree
## Minimal test runner (no addon needed). Finds every tests/**/test_*.gd file and
## runs each test_* method on a fresh instance. Use scripts/test.sh rather than
## calling this directly; it also re-imports new classes and catches script errors.
##   godot --headless --path . --script res://tests/run_tests.gd [-- <filter>]
## <filter> is a substring of "file::method", e.g. "rules" or "test_create_card".
## A test fails if an assertion fails, it makes no assertions, or it raises any
## engine/script error (GDScript has no exceptions, so errors are caught by a Logger).
## Exits with code 1 if any test fails, a test file fails to load, or nothing ran.

const TEST_ROOT := "res://tests"


## Collects errors (not warnings) logged while a test runs.
class ErrorCollector extends Logger:
	var errors: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors.append("%s (%s:%d)" % [rationale if rationale != "" else code, file, line])


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var filter: String = args[0] if not args.is_empty() else ""
	var failures: Array[String] = []
	var count := 0
	var collector := ErrorCollector.new()
	OS.add_logger(collector)

	for path in _find_test_files(TEST_ROOT):
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
			t.call(method_name)
			for e in collector.errors:
				failures.append("%s: error: %s" % [test_name, e])
			if t.assertions == 0:
				failures.append("%s: made no assertions (empty, or crashed before the first check)" % test_name)

	for f in failures:
		printerr("FAIL ", f)
	if count == 0:
		printerr("No tests matched filter '%s'." % filter)
	print("%d tests, %d failures" % [count, failures.size()])
	quit(1 if not failures.is_empty() or count == 0 else 0)


func _find_test_files(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		if sub == "lib":  # helpers, not tests
			continue
		found.append_array(_find_test_files(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.begins_with("test_") and file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	found.sort()
	return found
