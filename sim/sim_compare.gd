class_name SimCompare
extends RefCounted
## Compares two checkouts game by game (backlog 293): each [seed, strategy, civ] is played on both sides ("main", the
## baseline, and "this") and paired, so seed-to-seed noise cancels. Every strategy x civ cell starts with seeds 1-5 and
## gets the next ROUND seeds, on both sides, until cell_done. Reached through SimStats.compare, cell_done and cell_line;
## the games are played by SimStats.play_side (its cache and processes).

## Seeds a cell gets per round.
const ROUND := 5
## The share of main's mean score a cell's 95% interval must be within to stop.
const TOLERANCE := 0.05
## The fewest points that tolerance is.
const MIN_TOLERANCE := 1.0
## A cell whose score moved by more than this share of main's is flagged with "!".
const FLAG := 0.10
## Student's t at 95% (two-sided) by degrees of freedom, 1-30; 1.96 past that.
const T95: Array[float] = [0.0, 12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228, 2.201, 2.179,
	2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086, 2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048,
	2.045, 2.042]


## Compares main_side with this_side (SimStats.here's {root, cards, config}) for strategy ("all" for every one) as
## options' civ (every listed civilization when ""), up to max_seeds seeds a cell. options as SimStats.run_files: turns,
## procs (another checkout's games need 2+), lock_path (held for the whole comparison), cache_dir / cache. Returns
## {code, lines, cells, played, cached}: cells {strategy, civ, seeds, main_mean, this_mean, delta, half_width} in report
## order. Code 1 and the reasons when a side isn't a checkout or its data doesn't load (each line naming the side).
static func run(main_side: Dictionary, this_side: Dictionary, max_seeds: int, strategy: String,
		options: Dictionary) -> Dictionary:
	var sides := {"main": main_side, "this": this_side}
	var errors: Array[String] = []
	for name in sides:
		var root: String = sides[name].root
		if not FileAccess.file_exists(root.path_join("project.godot")):
			return _failed(["not a checkout: %s" % root])
		if not SimStats.is_this_project(root) and options.get("procs", 1) < 2:
			errors.append("%s: another checkout's games need 2 or more processes (SIM_PROCS)" % name)
	var data := {}
	var names := {}
	for name in sides:
		data[name] = SimStats.load_side(sides[name], strategy, options)
		errors.append_array(data[name].errors.map(func(e): return "%s: %s" % [name, e]))
		if data[name].errors.is_empty():
			names[name] = SimStats.metric_names(data[name].cards, data[name].config)
	if not errors.is_empty():
		return _failed(errors)
	var refused := SimStats.take_run_lock(options)
	if refused != "":
		return _failed([refused])
	var cells := []
	for job in SimStats.job_list(data.this.config, 1, strategy, options.get("civ", "")):
		cells.append({"strategy": job[1], "civ": job[2], "seeds": 0, "main": [], "this": [], "done": false})
	var out := {"code": 0, "lines": [], "cells": [], "played": 0, "cached": 0}
	while cells.any(func(c): return not c.done):
		var open := cells.filter(func(c): return not c.done)
		var jobs := []
		for c in open:
			for seed in range(c.seeds + 1, mini(c.seeds + ROUND, max_seeds) + 1):
				jobs.append([seed, c.strategy, c.civ])
		for name in sides:
			var played := SimStats.play_side(sides[name], data[name], jobs, names[name], options)
			if not played.errors.is_empty():
				SimStats.release_run_lock(options)
				return _failed(played.errors.map(func(e): return "%s: %s" % [name, e]))
			out.played += played.played
			out.cached += played.cached
			for k in jobs.size():
				open.filter(func(c): return c.strategy == jobs[k][1] and c.civ == jobs[k][2])[0][name].append(
					played.games[k])
		for c in open:
			c.seeds = c.main.size()
			c.done = cell_done(_deltas(c), _mean(_scores(c.main)), max_seeds)
	SimStats.release_run_lock(options)
	for c in cells:
		var deltas := _deltas(c)
		out.cells.append({"strategy": c.strategy, "civ": c.civ, "seeds": c.seeds, "main_mean": _mean(_scores(c.main)),
			"this_mean": _mean(_scores(c.this)), "delta": _mean(deltas), "half_width": _half_width(deltas)})
	out.lines = _report(main_side, this_side, max_seeds, cells, out.cells, names)
	return out


## Whether a cell whose paired score changes (this − main, one per seed) are deltas needs no more seeds: its 95%
## interval's half-width, t(n−1) × sd / √n, is at most TOLERANCE of main_mean (at least MIN_TOLERANCE points), or it
## has max_seeds seeds.
static func cell_done(deltas: Array, main_mean: float, max_seeds: int) -> bool:
	if deltas.size() >= max_seeds:
		return true
	return deltas.size() >= 2 and _half_width(deltas) <= maxf(TOLERANCE * absf(main_mean), MIN_TOLERANCE)


## A cell's report line: "sumer  main 249.0  this 262.4  Δ +13.4 ±4.1 (+5.4%)  seeds 10", ending " !" when the change
## is more than FLAG of main's mean. The default civilization is "default".
static func cell_line(cell: Dictionary) -> String:
	var share: float = cell.delta / cell.main_mean if cell.main_mean != 0.0 else 0.0
	var line := "%s  main %.1f  this %.1f  Δ %+.1f ±%.1f (%+.1f%%)  seeds %d" % [
		cell.civ if cell.civ != "" else "default", cell.main_mean, cell.this_mean, cell.delta, cell.half_width,
		share * 100.0, cell.seeds]
	return line + " !" if absf(share) > FLAG + 1e-9 else line


## The report: a header naming both sides, then per strategy its cells' lines, a line per other metric (in both
## sides' metric names) whose mean over the strategy's pairs changed, and a trend_change_line per resource (379) in
## place of its trend samples' lines.
static func _report(main_side: Dictionary, this_side: Dictionary, max_seeds: int, cells: Array, summaries: Array,
		names: Dictionary) -> Array[String]:
	var lines: Array[String] = ["main %s vs this %s: seeds in rounds of %d, up to %d" % [main_side.root, this_side.root,
		ROUND, max_seeds]]
	var metrics: Array = names.main.filter(func(m): return m != "score" and names.this.has(m))
	var strategy := ""
	for i in cells.size():
		if cells[i].strategy != strategy:
			strategy = cells[i].strategy
			lines.append("== %s" % strategy)
		lines.append(cell_line(summaries[i]))
		if i + 1 < cells.size() and cells[i + 1].strategy == strategy:
			continue
		var games := cells.filter(func(c): return c.strategy == strategy)
		var means := {"main": {}, "this": {}}
		for m in metrics:
			var before := _mean(_values(games, "main", m))
			var after := _mean(_values(games, "this", m))
			means.main[m] = before
			means.this[m] = after
			if absf(after - before) > 1e-9 and not SimStats.is_trend_metric(m):
				lines.append("%-10s main %.2f  this %.2f  Δ %+.2f" % [m, before, after, after - before])
		for r in SimStats.TREND_RESOURCES:
			var line := trend_change_line(r, means.main, means.this)
			if line != "":
				lines.append(line)
	return lines


## "wealth by turn  Δ 10 +0.0, 20 -2.5" (379): the change in the mean of each of resource's trend samples both
## main_means and this_means ({metric: mean}) have, by turn; "" when none of them moved.
static func trend_change_line(resource: String, main_means: Dictionary, this_means: Dictionary) -> String:
	var parts: PackedStringArray = []
	var moved := false
	for n in SimStats.trend_turns(resource, main_means.keys()):
		var m := "%s_t%d" % [resource, n]
		if this_means.has(m):
			var delta: float = this_means[m] - main_means[m]
			moved = moved or absf(delta) > 1e-9
			parts.append("%d %+.1f" % [n, delta])
	return "%s by turn  Δ %s" % [resource, ", ".join(parts)] if moved else ""


static func _failed(lines: Array) -> Dictionary:
	return {"code": 1, "lines": lines, "cells": [], "played": 0, "cached": 0}


## A cell's paired score changes, this − main, by seed.
static func _deltas(cell: Dictionary) -> Array:
	var out := []
	for i in cell.main.size():
		out.append(cell.this[i].score - cell.main[i].score)
	return out


static func _scores(games: Array) -> Array:
	return games.map(func(g): return g.score)


## Metric m of side's games over cells.
static func _values(cells: Array, side: String, m: String) -> Array:
	var out := []
	for c in cells:
		out.append_array(c[side].map(func(g): return g[m]))
	return out


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()


## The half-width of the 95% interval of values' mean: t(n−1) × sd / √n (0 for fewer than 2).
static func _half_width(values: Array) -> float:
	var n := values.size()
	if n < 2:
		return 0.0
	var mean := _mean(values)
	var squares := 0.0
	for v in values:
		squares += (v - mean) * (v - mean)
	var t: float = T95[n - 1] if n - 1 < T95.size() else 1.96
	return t * sqrt(squares / (n - 1)) / sqrt(n)
