extends RefCounted
## Checks on the test helpers (334): a helper defined in tests/lib/ isn't copied into the test files.


## "name: file, file" for each function defined in two or more of test_texts (path -> source) whose name tests/lib/
## also defines (lib_texts, path -> source), sorted by name.
static func copies(_test_texts: Dictionary, _lib_texts: Dictionary) -> Array[String]:
	return []


## "path: name" for each function in names that texts (path -> source) define, sorted.
static func definitions(_texts: Dictionary, _names: Array) -> Array[String]:
	return []
