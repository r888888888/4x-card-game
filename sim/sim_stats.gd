class_name SimStats
extends RefCounted
## Plays one ScriptedBot game per seed and summarizes the results (backlog 042). Used by sim/run.gd
## (scripts/sim.sh) and the balance skill.

const METRICS: Array[String] = ["score", "cities", "pop", "techs", "bought", "era", "explored"]


## Plays one game per seed and returns {metric: {mean: float, min: int, max: int}} for each of METRICS. explored is how
## many turns the territory deck lasted: the turn it ran out, or the last turn played if it never did.
static func run(cards: Dictionary, config: Dictionary, seeds: Array) -> Dictionary:
	var values := {}
	for m in METRICS:
		values[m] = []
	for s in seeds:
		var engine := GameEngine.new(cards, config)
		engine.new_game(s)
		var explored := [0]  # the turn the territory deck ran out (066); 0 until it does
		var on_changed := func():
			if explored[0] == 0 and engine.zone("territory_deck").is_empty():
				explored[0] = engine.turn
		engine.changed.connect(on_changed)
		on_changed.call()  # an empty territory deck from the start
		ScriptedBot.play(engine)
		engine.changed.disconnect(on_changed)  # on_changed holds engine: break the cycle so it is freed
		var game := game_metrics(engine, config)
		game.explored = explored[0] if explored[0] > 0 else engine.turn
		for m in METRICS:
			values[m].append(game[m])
	var stats := {}
	for m in METRICS:
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


## Loads the data files and runs seeds 1..seed_count. Returns {code, lines}: code 0 and one line per metric,
## or code 1 and the loader errors.
static func run_files(cards_path: String, config_path: String, seed_count: int) -> Dictionary:
	var data := DataLoader.load_all(cards_path, config_path)
	if not data.errors.is_empty():
		return {"code": 1, "lines": data.errors}
	var seeds := range(1, seed_count + 1)
	var stats := run(data.cards, data.config, seeds)
	var lines: Array[String] = ["%d seeds (1-%d)" % [seed_count, seed_count]]
	for m in METRICS:
		lines.append("%-7s mean %6.2f  min %3d  max %3d" % [m, stats[m].mean, stats[m].min, stats[m].max])
	return {"code": 0, "lines": lines}


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
