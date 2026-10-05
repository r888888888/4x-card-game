extends RefCounted
## Picks the methods of a test file the runner calls (284): every test_* method the filter matches. One that takes
## arguments is a helper misnamed as a test; calling it with none can hang the run, so it is reported instead.


## {"run": the test_* method names to call, "failures": one line per matched test_* method that takes arguments}.
## file_label and the method name make the "file::method" the filter is a substring of.
static func select(script: GDScript, file_label: String, filter: String) -> Dictionary:
	var run: Array[String] = []
	var failures: Array[String] = []
	for m in script.get_script_method_list():
		var method_name: String = m.name
		var test_name := "%s::%s" % [file_label, method_name]
		if not method_name.begins_with("test_") or not (filter.is_empty() or filter in test_name):
			continue
		if m.args.is_empty():
			run.append(method_name)
		else:
			failures.append("%s: test methods take no arguments; rename the helper" % test_name)
	return {"run": run, "failures": failures}
