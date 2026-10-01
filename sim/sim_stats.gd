class_name SimStats
extends RefCounted
## Plays one ScriptedBot game per seed and summarizes the results (backlog 042); per strategy and civilization (134). Used by sim/run.gd
## (scripts/sim.sh) and the balance skill.

const METRICS: Array[String] = ["score", "cities", "pop", "techs", "bought", "era", "explored"]


## Plays one game per seed with strategy (a ScriptedBot.STRATEGIES name, 134) as civ ("" for the default) and returns
## {metric: {mean: float, min: int, max: int}} for each of METRICS. explored is how many turns the territory deck lasted:
## the turn it ran out, or the last turn played if it never did. For each era with techs in the research deck (143),
## era_<n>_open is the turn it was added (1 for era 1) and era_<n>_done the turn its last tech was researched; either
## is the last turn played when it never happened.
static func run(cards: Dictionary, config: Dictionary, seeds: Array, strategy := "baseline", civ := "") -> Dictionary:
	return _summaries(_values(cards, config, seeds, strategy, civ))


## {metric: [one value per seed]} for games with strategy as civ.
static func _values(cards: Dictionary, config: Dictionary, seeds: Array, strategy: String, civ: String) -> Dictionary:
	var values := {}
	var era_techs := _techs_per_era(cards, config)
	var names := METRICS.duplicate()
	for n in era_techs:
		names.append_array(["era_%d_open" % n, "era_%d_done" % n])
	for m in names:
		values[m] = []
	for s in seeds:
		var engine := GameEngine.new(cards, config)
		engine.new_game(s, civ)
		var seen := {}  # the turn things first happened: "explored" (the territory deck ran out, 066), "era_<n>_…" (143)
		var on_changed := func():
			if not seen.has("explored") and engine.zone("territory_deck").is_empty():
				seen.explored = engine.turn
			for n in era_techs:
				if not seen.has("era_%d_open" % n) and engine.era() >= n:
					seen["era_%d_open" % n] = engine.turn
				var learned := engine.zone("researched").cards.filter(func(c): return c.def.era == n).size()
				if not seen.has("era_%d_done" % n) and learned >= era_techs[n]:
					seen["era_%d_done" % n] = engine.turn
		engine.changed.connect(on_changed)
		on_changed.call()  # an empty territory deck from the start, era 1 open
		ScriptedBot.play(engine, strategy)
		engine.changed.disconnect(on_changed)  # on_changed holds engine: break the cycle so it is freed
		var game := game_metrics(engine, config)
		for m in names:
			values[m].append(game[m] if game.has(m) else seen.get(m, engine.turn))
	return values


## How many techs each era has in config research_deck: {era: count}, by era.
static func _techs_per_era(cards: Dictionary, config: Dictionary) -> Dictionary:
	var out := {}
	for id in config.get("research_deck", {}):
		var era: int = cards[id].era
		out[era] = out.get(era, 0) + config.research_deck[id]
	var sorted := {}
	var eras := out.keys()
	eras.sort()
	for n in eras:
		sorted[n] = out[n]
	return sorted


static func _summaries(values: Dictionary) -> Dictionary:
	var stats := {}
	for m in values:
		stats[m] = _summary(values[m])
	return stats


## The metrics of one finished game.
static func game_metrics(engine: GameEngine, config: Dictionary) -> Dictionary:
	var bought := 0
	var supply: Dictionary = config.get("supply", {})
	for id in supply:
		bought += supply[id].count - engine.supply_left(id)
	return {
		"score": engine.score(),
		"cities": _count_type(engine.zone("tableau").cards, "city") - _starting_cities(engine, config),
		"pop": engine.total_pop(),
		"techs": engine.zone("researched").size(),
		"bought": bought,
		"era": engine.era(),
	}


## Loads the data files and runs seeds 1..seed_count with strategy. Returns {code, lines}: code 0 and one line per
## metric; with strategy "all", a block per strategy: its mean score per listed civilization, then its metrics over all
## of them. Code 1 and the loader errors (or an unknown strategy). options (LaunchOptions.parse, 135): turns replaces
## the turn limit, civ plays only that civilization.
static func run_files(cards_path: String, config_path: String, seed_count: int, strategy := "baseline",
		options := {}) -> Dictionary:
	var data := DataLoader.load_all(cards_path, config_path)
	if not data.errors.is_empty():
		return {"code": 1, "lines": data.errors}
	if options.get("turns", 0) > 0:
		data.config.turn_limit = options.turns
	var only_civ: String = options.get("civ", "")
	if strategy != "all" and not ScriptedBot.STRATEGIES.has(strategy):
		return {"code": 1, "lines": ["unknown strategy '%s' (one of %s, or all)" % [strategy, ScriptedBot.STRATEGIES]]}
	var seeds := range(1, seed_count + 1)
	var lines: Array[String] = ["%d seeds (1-%d)" % [seed_count, seed_count]]
	if strategy != "all":
		lines.append_array(_metric_lines(run(data.cards, data.config, seeds, strategy, only_civ)))
		return {"code": 0, "lines": lines}
	var civs: Array = [only_civ] if only_civ != "" else data.config.get("civilizations", [])
	if civs.is_empty():
		civs = [""]
	for s in ScriptedBot.STRATEGIES:
		lines.append("== %s" % s)
		var all := {}
		var scores: PackedStringArray = []
		for civ in civs:
			var values := _values(data.cards, data.config, seeds, s, civ)
			scores.append("%s %.1f" % [civ if civ != "" else "default", _summary(values.score).mean])
			for m in values:
				all[m] = all.get(m, []) + values[m]
		lines.append("score by civilization: " + ", ".join(scores))
		lines.append_array(_metric_lines(_summaries(all)))
	return {"code": 0, "lines": lines}


static func _metric_lines(stats: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for m in stats:  # METRICS, then the era metrics by era
		lines.append("%-10s mean %6.2f  min %3d  max %3d" % [m, stats[m].mean, stats[m].min, stats[m].max])
	return lines


static func _summary(values: Array) -> Dictionary:
	var total := 0
	for v in values:
		total += v
	return {"mean": float(total) / values.size(), "min": values.min(), "max": values.max()}


static func _count_type(cards: Array, type: String) -> int:
	return cards.filter(func(c): return c.def.type == type).size()


static func _starting_cities(engine: GameEngine, config: Dictionary) -> int:
	var n := 0
	for id in config.starting.tableau:
		if engine.card_db[id].type == "city":
			n += 1
	return n
