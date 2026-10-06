extends "res://tests/lib/test_case.gd"
## Red-phase scaffolding stays out of the suite (backlog 333): no test file holds an engine typed Object, loads a script
## into an untyped Variant or calls has_method, unless the line says why (`# scaffolding-ok: <reason>`). The check
## lives in tests/lib/scaffolding_checks.gd; its fixtures below carry the comment so the suite check skips them.

const DocChecks := preload("res://tests/lib/doc_checks.gd")
const ScaffoldingChecks := preload("res://tests/lib/scaffolding_checks.gd")


func test_an_engine_typed_object_is_named() -> void:
	var text := "\n".join([
		"func test_a() -> void:",
		"	var e: Object = make_engine()",  # scaffolding-ok: fixture
		"	var links: Dictionary = (links_engine() as Object).tech_links(\"a\")",  # scaffolding-ok: fixture
		"	var screen: Object = main.new_game_screen",
		"func helper(engine: Object) -> void:",  # scaffolding-ok: fixture
	])
	eq(ScaffoldingChecks.problems({"tests/test_a.gd": text}), [
		"tests/test_a.gd:2: an engine typed Object",
		"tests/test_a.gd:3: an engine typed Object",
		"tests/test_a.gd:5: an engine typed Object",
	] as Array[String], "the engines, not the screen")


func test_a_script_loaded_untyped_is_named() -> void:
	var text := "\n".join([
		"const Bot := preload(\"res://sim/generic_bot.gd\")",
		"var BOT: Variant = load(\"res://sim/generic_bot.gd\")",  # scaffolding-ok: fixture
	])
	eq(ScaffoldingChecks.problems({"tests/test_b.gd": text}),
		["tests/test_b.gd:2: a script loaded into an untyped Variant"] as Array[String], "the load, not the preload")


func test_has_method_is_named() -> void:
	var text := "\n".join([
		"	if main.has_method(\"figure\"):",  # scaffolding-ok: fixture
		"	check(true, \"x\")",
	])
	eq(ScaffoldingChecks.problems({"tests/test_c.gd": text}),
		["tests/test_c.gd:1: has_method"] as Array[String], "has_method")


func test_a_reasoned_ok_comment_and_comment_lines_are_allowed() -> void:
	var text := "\n".join([
		"	check(GameEngine.new().has_method(\"x\"))  # scaffolding-ok: the engine's public surface",  # scaffolding-ok: fixture
		"	check(e.has_method(\"y\"))  # scaffolding-ok",  # scaffolding-ok: fixture
		"	check(e.has_method(\"z\"))  # scaffolding-ok:   ",  # scaffolding-ok: fixture
		"## Calls has_method( on nothing; var e: Object = make_engine()",  # scaffolding-ok: fixture
		"	# var e: Object = make_engine()",  # scaffolding-ok: fixture
	])
	eq(ScaffoldingChecks.problems({"tests/test_d.gd": text}),
		["tests/test_d.gd:2: has_method", "tests/test_d.gd:3: has_method"] as Array[String],
		"a reason excuses a line; a comment line is not code")


func test_problems_are_sorted_by_file_then_line() -> void:
	var texts := {"tests/test_z.gd": "x.has_method(\"a\")", "tests/test_y.gd": "\n\ny.has_method(\"b\")"}  # scaffolding-ok: fixture
	eq(ScaffoldingChecks.problems(texts),
		["tests/test_y.gd:3: has_method", "tests/test_z.gd:1: has_method"] as Array[String], "sorted")


func test_no_test_file_holds_red_phase_scaffolding() -> void:
	var texts := {}
	for path in DocChecks.suite_files():
		texts[path] = FileAccess.get_file_as_string("res://" + path)
	check(texts.has("tests/test_scaffolding.gd"), "the check reads the test files (%d)" % texts.size())
	eq(ScaffoldingChecks.problems(texts), [] as Array[String], "red-phase scaffolding left in tests/")
