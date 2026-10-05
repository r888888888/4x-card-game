extends "res://tests/lib/test_case.gd"
## Comparing two checkouts game by game on the real data (backlog 293): SimStats.compare plays each [seed, strategy,
## civ] on both sides in rounds of 5 seeds until cell_done, and reports the change per cell. Both sides here are this
## checkout; a side's config copy varies the data. Short games.

const CARDS := "res://data/cards.json"
const CONFIG := "res://data/config.json"


func temp_dir() -> String:
	return OS.get_temp_dir().path_join("test-293-%d" % OS.get_process_id())


## A side of this checkout with config (a path).
func side(config := CONFIG) -> Dictionary:
	return {"root": ProjectSettings.globalize_path("res://"), "cards": CARDS, "config": config}


## A copy of the real config with turn_limit turns (no other change, unless broken: not JSON).
func config_with(turns: int, broken := false) -> String:
	var source := FileAccess.get_file_as_string(CONFIG)
	check(source.contains("\"turn_limit\": 100"), "the config has turn_limit 100")
	source = source.replace("\"turn_limit\": 100", "\"turn_limit\": %d" % turns)
	if broken:
		source = source.substr(0, source.length() / 2)
	DirAccess.make_dir_recursive_absolute(temp_dir())
	var path := temp_dir().path_join("config-%d%s.json" % [turns, "-broken" if broken else ""])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(source)
	f.close()
	return path


func compare(main: Dictionary, this: Dictionary, max_seeds: int, strategy: String, options := {}) -> Dictionary:
	var stats: Object = SimStats.new()
	var o := {"civ": "sumer", "turns": 0, "seed": -1, "procs": 1}
	o.merge(options, true)
	return stats.compare(main, this, max_seeds, strategy, o)


# --- AC2: the same code and data ---

func test_identical_sides_stop_every_cell_after_5_seeds_with_no_change() -> void:
	var out := compare(side(), side(), 20, "all", {"turns": 5})
	eq(out.get("code"), 0, "exit code: %s" % [out.get("lines")])
	var cells: Array = out.get("cells", [])
	eq(cells.size(), ScriptedBot.STRATEGIES.size(), "a cell per strategy (sumer only)")
	for cell in cells:
		eq([cell.seeds, cell.delta, cell.half_width], [5, 0.0, 0.0], "%s: seeds, Δ, half-width" % cell.strategy)
	var lines: Array = out.get("lines", [])
	for s in ScriptedBot.STRATEGIES:
		var at := lines.find("== %s" % s)
		check(at != -1, "a block for %s" % s)
		if at == -1:
			continue
		check(lines[at + 1].begins_with("sumer  main "), "%s: its civ line" % s)
		check(at + 2 == lines.size() or lines[at + 2].begins_with("== "), "%s: no metric moved" % s)


# --- AC3, AC4: a change, paired by seed ---

func test_a_changed_side_is_compared_seed_by_seed() -> void:
	var a := config_with(5)
	var b := config_with(6)
	var out := compare(side(a), side(b), 10, "baseline")
	eq(out.get("code"), 0, "exit code: %s" % [out.get("lines")])
	var cells: Array = out.get("cells", [{}])
	var n: int = cells[0].get("seeds", 0)
	check(n in [5, 10], "5 or 10 seeds, got %d" % n)
	if n == 0:
		remove_tree(temp_dir())
		return
	var seeds := range(1, n + 1)
	var main_data := DataLoader.load_all(CARDS, a)
	var this_data := DataLoader.load_all(CARDS, b)
	var main_mean: float = SimStats.run(main_data.cards, main_data.config, seeds, "baseline", "sumer").score.mean
	var this_mean: float = SimStats.run(this_data.cards, this_data.config, seeds, "baseline", "sumer").score.mean
	remove_tree(temp_dir())
	check(absf(cells[0].get("delta", -999.0) - (this_mean - main_mean)) < 0.001,
		"Δ %s is the mean of this − main over seeds 1-%d (%s)" % [cells[0].get("delta"), n, this_mean - main_mean])
	eq(out.get("played"), 2 * n, "each seed played on both sides")
	var lines: Array = out.get("lines", [])
	var at := lines.find("== baseline")
	for line in lines.slice(at + 2):
		check(not " Δ +0.00" in line and not " Δ -0.00" in line, "a metric line only for a metric that moved: %s" % line)


# --- AC5: errors ---

func test_a_side_that_is_not_a_checkout_fails() -> void:
	var nowhere := temp_dir().path_join("nowhere")
	var out := compare({"root": nowhere, "cards": CARDS, "config": CONFIG}, side(), 5, "baseline")
	eq(out.get("code"), 1, "exit code")
	eq(out.get("lines"), ["not a checkout: %s" % nowhere], "the message")
	eq(out.get("played", 0), 0, "nothing played")


func test_a_side_whose_data_does_not_load_fails_with_its_errors() -> void:
	var broken := config_with(5, true)
	var out := compare(side(), side(broken), 5, "baseline")
	remove_tree(temp_dir())
	eq(out.get("code"), 1, "exit code")
	var lines: Array = out.get("lines", [])
	check(not lines.is_empty() and lines.all(func(l): return l.begins_with("this: ")), "this side's errors: %s" % [lines])


func test_an_unknown_strategy_fails() -> void:
	var out := compare(side(), side(), 5, "nope")
	eq(out.get("code"), 1, "exit code")
	check(out.get("lines", [""])[0].contains("unknown strategy 'nope'"), "the message: %s" % [out.get("lines")])


# --- AC6: the cache ---

func test_a_second_comparison_reads_every_game_from_the_cache() -> void:
	var cache := temp_dir().path_join("cache")
	var options := {"turns": 4, "cache_dir": cache}
	var first := compare(side(), side(config_with(5)), 10, "baseline", options)
	var second := compare(side(), side(config_with(5)), 10, "baseline", options)
	remove_tree(temp_dir())
	eq(first.get("code"), 0, "exit code: %s" % [first.get("lines")])
	check(first.get("played", 0) > 0, "the first comparison played")
	eq(second.get("played"), 0, "the second played nothing")
	eq(second.get("lines"), first.get("lines"), "the same report")
