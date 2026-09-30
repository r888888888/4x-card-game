extends "res://tests/lib/test_case.gd"
## Script size limits (backlog 085): no script in engine/ or ui/ may pass 700 lines; past 500 the suite prints a
## warning. Crossing 700 means specing a split along a real boundary, not trimming lines to fit.

const HARD_LIMIT := 700
const SOFT_LIMIT := 500
const DIRS: Array[String] = ["res://engine", "res://ui"]


## Held as Object so the red phase fails on missing functions, not a parse error.
func sizes() -> Object:
	return load("res://tests/lib/script_sizes.gd")


# --- AC1: the limits' edges ---

func test_files_over_700_break_the_hard_limit_and_501_to_700_the_soft() -> void:
	var counts := {"a.gd": 701, "b.gd": 700, "c.gd": 501, "d.gd": 500}
	var result: Dictionary = sizes().classify(counts, HARD_LIMIT, SOFT_LIMIT)
	eq(result.get("hard"), ["a.gd"], "over the hard limit")
	eq(result.get("soft"), ["b.gd", "c.gd"], "over the soft limit only")


# --- AC2: the hard limit on the real scripts ---

func test_scripts_in_engine_and_ui_are_counted_including_subfolders() -> void:
	var counts: Dictionary = sizes().count_lines_in(DIRS)
	for path in ["res://engine/game_engine.gd", "res://engine/effects/draw_effect.gd", "res://ui/main.gd"]:
		check(counts.has(path), "%s is counted" % path)
	for path in counts:
		check(String(path).ends_with(".gd"), "%s is a script" % path)


func test_no_script_in_engine_or_ui_is_over_700_lines() -> void:
	var counts: Dictionary = sizes().count_lines_in(DIRS)
	var result: Dictionary = sizes().classify(counts, HARD_LIMIT, SOFT_LIMIT)
	var over: Array[String] = []
	for path in result.get("hard", []):
		over.append("%s (%d lines)" % [path, counts[path]])
	eq(over, [] as Array[String], "scripts over %d lines; spec a split" % HARD_LIMIT)
	for path in result.get("soft", []):
		print(sizes().warning(path, counts[path], SOFT_LIMIT))


# --- AC3: the warning line ---

func test_a_warning_names_the_file_its_lines_and_the_soft_limit() -> void:
	eq(sizes().warning("res://ui/card_view.gd", 674, SOFT_LIMIT), "WARN ui/card_view.gd: 674 lines (soft limit 500)")


# --- AC4: lines as wc -l counts them ---

func test_line_count_matches_wc() -> void:
	eq(sizes().line_count("a\nb\n"), 2, "two lines ending in a newline")
	eq(sizes().line_count("a\nb"), 1, "no final newline, like wc -l")
	eq(sizes().line_count(""), 0, "empty")
