extends RefCounted
## Checks on the test helpers (334): a helper defined in tests/lib/ isn't copied into the test files.


## Each function texts (path -> source) define: {name: [paths]}.
static func _definers(texts: Dictionary) -> Dictionary:
	var re := RegEx.create_from_string("(?m)^(?:static )?func (\\w+)\\(")
	var out := {}
	for path in texts:
		for m in re.search_all(texts[path]):
			var name := m.get_string(1)
			if not out.has(name):
				out[name] = []
			if not out[name].has(path):
				out[name].append(path)
	return out


## "name: file, file" for each function defined in two or more of test_texts (path -> source) whose name tests/lib/
## also defines (lib_texts, path -> source), sorted by name.
static func copies(test_texts: Dictionary, lib_texts: Dictionary) -> Array[String]:
	var lib := _definers(lib_texts)
	var tests := _definers(test_texts)
	var out: Array[String] = []
	for name in tests:
		if lib.has(name) and tests[name].size() >= 2:
			var paths: Array = tests[name]
			paths.sort()
			out.append("%s: %s" % [name, ", ".join(paths)])
	out.sort()
	return out


## "path: name" for each function in names that texts (path -> source) define, sorted.
static func definitions(texts: Dictionary, names: Array) -> Array[String]:
	var defined := _definers(texts)
	var out: Array[String] = []
	for name in names:
		for path in defined.get(name, []):
			out.append("%s: %s" % [path, name])
	out.sort()
	return out
