extends "res://tests/lib/test_case.gd"
## The sim's report on the real data (backlogs 042, 134, 135), moved out of the main suite: these play real-data
## ScriptedBot games, so they run only with scripts/test.sh --balance. The fixture tests of the bot and SimStats stay
## in tests/test_sim.gd, tests/test_sim_strategies.gd and tests/test_launch_options.gd.

const METRICS := ["bought", "cities", "era", "explored", "pop", "score", "techs"]
const STRATEGIES := ["baseline", "growth", "wealth", "wide", "tall"]


func test_sim_run_files_prints_one_line_per_metric() -> void:
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 5)
	eq(out.get("code"), 0, "exit code")
	var lines: Array = out.get("lines", [])
	for m in METRICS:
		var matching := lines.filter(func(l): return l.begins_with(m + " "))
		eq(matching.size(), 1, "one line for %s in %s" % [m, lines])


func test_sim_run_files_reports_every_strategy_and_civilization() -> void:
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 1, "all")
	eq(out.get("code"), 0, "exit code")
	var text := "\n".join(out.get("lines", []))
	for strategy in STRATEGIES:
		check(strategy in text, "the report names %s" % strategy)
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	for civ in r.config.civilizations:
		check(civ in text, "the report names %s" % civ)


func test_sim_uses_the_turn_limit_option() -> void:
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		{"civ": "", "turns": 5, "seed": -1})
	eq(out.get("code"), 0, "exit code")
	var explored: Array = out.get("lines", []).filter(func(l): return l.begins_with("explored "))
	check(not explored.is_empty() and explored[0].ends_with("max   5"), "games last 5 turns: %s" % [explored])


func test_sim_plays_only_the_civ_option() -> void:
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 1, "all",
		{"civ": "sumer", "turns": 3, "seed": -1})
	eq(out.get("code"), 0, "exit code")
	var text := "\n".join(out.get("lines", []))
	check("sumer" in text, "the report names Sumer")
	check(not "egypt" in text, "and no other civilization: %s" % text)


func test_sim_plays_a_single_strategy_as_the_civ_option() -> void:
	var r := DataLoader.load_all("res://data/cards.json", "res://data/config.json")
	var config: Dictionary = r.config.duplicate(true)
	config.turn_limit = 4
	var expected: Dictionary = SimStats.run(r.cards, config, [1, 2], "baseline", "sumer")
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		{"civ": "sumer", "turns": 4, "seed": -1})
	var score: Array = out.get("lines", []).filter(func(l): return l.begins_with("score "))
	check(not score.is_empty() and ("mean %6.2f" % expected.score.mean) in score[0],
		"score line %s matches Sumer's %s" % [score, expected.score])
