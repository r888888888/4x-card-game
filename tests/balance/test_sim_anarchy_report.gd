extends "res://tests/lib/test_case.gd"
## Balance suite: the Anarchy, government and famine metrics (backlog 158) on the real data, through a parallel run.

const NEW_METRICS := ["anarchies", "revolts", "gov_changes", "famine_turns", "trashed"]


# --- 158 AC4: a parallel run ---

func test_the_metrics_come_through_a_parallel_run() -> void:
	var o := {"civ": "sumer", "turns": 6, "seed": -1}
	var one: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "generic",
		o.merged({"procs": 1}))
	var two: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "generic",
		o.merged({"procs": 2}))
	for m in NEW_METRICS + ["chiefdom_turns"]:
		check(one.get("lines", []).any(func(l): return l.begins_with(m + " ")), "%s in the report" % m)
	eq(two.get("lines"), one.get("lines"), "the same report on 2 processes")
