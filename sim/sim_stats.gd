class_name SimStats
extends RefCounted
## Plays one ScriptedBot game per seed and summarizes the results (backlog 042); per strategy and civilization (134). Used by sim/run.gd
## (scripts/sim.sh) and the balance skill. run_files can spread the games over child processes (152): each plays one
## shard of the job list (play_shard) and writes its games to a file, which the parent reads back (read_shards).

const METRICS: Array[String] = ["score", "cities", "pop", "techs", "bought", "era", "explored", "anarchies", "revolts",
	"anarchy_turns", "restored", "gov_changes", "famine_turns", "trashed"]
## How long a parallel run waits for its child processes before killing them (their shards then fail the run).
const CHILD_TIMEOUT_MSEC := 60 * 60 * 1000


## Plays one game per seed with strategy (a ScriptedBot.STRATEGIES name, 134) as civ ("" for the default) and returns
## {metric: {mean: float, min: int, max: int}} for each of METRICS. explored is how many turns the territory deck lasted:
## the turn it ran out, or the last turn played if it never did. For each era with techs in the research deck (143),
## era_<n>_open is the turn it was added (1 for era 1) and era_<n>_done the turn its last tech was researched; either
## is the last turn played when it never happened. The Anarchy metrics (158): anarchies (times it began), revolts,
## anarchy_turns (turns that started under it), restored (times order was bought), gov_changes (times the ruling
## government's id changed, Anarchy not counted), famine_turns (turns that started with a Famine), trashed (cards
## trashed by the end), and <id>_turns per government (see _governments): turns that started with it ruling.
static func run(cards: Dictionary, config: Dictionary, seeds: Array, strategy := "baseline", civ := "") -> Dictionary:
	return _summaries(_values(cards, config, seeds, strategy, civ))


## {metric: [one value per seed]} for games with strategy as civ.
static func _values(cards: Dictionary, config: Dictionary, seeds: Array, strategy: String, civ: String) -> Dictionary:
	var names := metric_names(cards, config)
	return _collect(seeds.map(func(seed): return _play_one(cards, config, [seed, strategy, civ], names)), names)


## {metric: [one value per game]} for names, from games' metrics.
static func _collect(games: Array, names: Array[String]) -> Dictionary:
	var values := {}
	for m in names:
		values[m] = games.map(func(g): return g[m])
	return values


## The metrics a game reports, in report order: METRICS, <id>_turns for each of _governments, then era_<n>_open and
## era_<n>_done for each era with techs.
static func metric_names(cards: Dictionary, config: Dictionary) -> Array[String]:
	var names := METRICS.duplicate()
	for id in _governments(cards, config):
		names.append("%s_turns" % id)
	for n in _techs_per_era(cards, config):
		names.append_array(["era_%d_open" % n, "era_%d_done" % n])
	return names


## Plays job ([seed, strategy, civ]) and returns its metrics, {name: int} for names.
static func _play_one(cards: Dictionary, config: Dictionary, job: Array, names: Array[String]) -> Dictionary:
	var era_techs := _techs_per_era(cards, config)
	var engine := GameEngine.new(cards, config)
	engine.new_game(job[0], job[2])
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
	var tally := {"anarchies": 0, "revolts": 0, "anarchy_turns": 0, "restored": 0, "gov_changes": 0, "famine_turns": 0}
	for id in _governments(cards, config):
		tally["%s_turns" % id] = 0
	var last := {"turn": 0, "anarchy": false, "government": config.starting.get("government", "")}
	var on_state := func():  # Anarchy and government changes, and what each turn started with (158)
		var in_anarchy := engine.anarchy() != -1
		if in_anarchy and not last.anarchy:
			tally.anarchies += 1
		last.anarchy = in_anarchy
		var gov := engine.zone("government")
		var ruling: String = "" if gov.is_empty() or in_anarchy else gov.cards[0].def.id
		if ruling != "":
			if last.government != "" and ruling != last.government:
				tally.gov_changes += 1
			last.government = ruling
		if engine.turn > last.turn:
			last.turn = engine.turn
			tally.anarchy_turns += 1 if in_anarchy else 0
			tally.famine_turns += 1 if engine.famine_counters() > 0 else 0
			if tally.has("%s_turns" % ruling):
				tally["%s_turns" % ruling] += 1
	var on_revolted := func(): tally.revolts += 1
	var on_restored := func(): tally.restored += 1
	engine.changed.connect(on_changed)
	engine.changed.connect(on_state)
	engine.revolted.connect(on_revolted)
	engine.order_restored.connect(on_restored)
	on_changed.call()  # an empty territory deck from the start, era 1 open
	on_state.call()  # turn 1 as it started
	ScriptedBot.play(engine, job[1])
	engine.changed.disconnect(on_changed)  # the callables hold engine: break the cycle so it is freed
	engine.changed.disconnect(on_state)
	engine.revolted.disconnect(on_revolted)
	engine.order_restored.disconnect(on_restored)
	var game := game_metrics(engine, config)
	game.merge(tally)
	var out := {}
	for m in names:
		out[m] = game[m] if game.has(m) else seen.get(m, engine.turn)
	return out


## The governments a game can have, in config order (158): starting.government, then each one a card creates, in
## card order; never the unrest.anarchy card.
static func _governments(cards: Dictionary, config: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var anarchy: String = config.get("unrest", {}).get("anarchy", "")
	var ids: Array[String] = [config.starting.get("government", "")]
	for id in cards:
		for effect in cards[id].effects:
			if effect.op == "create":
				ids.append_array(effect.referenced_cards().filter(func(c): return cards[c].type == CardDef.GOVERNMENT))
	for id in ids:
		if id != "" and id != anarchy and not out.has(id):
			out.append(id)
	return out


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
		"trashed": engine.zone("trashed").size(),
	}


## Loads the data files and runs seeds 1..seed_count with strategy. Returns {code, lines, procs}: code 0 and one line
## per metric; with strategy "all", a block per strategy: its mean score per listed civilization, then its metrics over
## all of them. Code 1 and the loader errors (or an unknown strategy, or the shards that wrote no results). options
## (LaunchOptions.parse, 135): turns replaces the turn limit, civ plays only that civilization; procs (152, default 1)
## is how many processes play the games, never more than there are games. procs in the result is how many did.
static func run_files(cards_path: String, config_path: String, seed_count: int, strategy := "baseline",
		options := {}) -> Dictionary:
	var data := _load(cards_path, config_path, strategy, options)
	if not data.errors.is_empty():
		return {"code": 1, "lines": data.errors, "procs": 1}
	var jobs := _jobs(data.config, seed_count, strategy, options.get("civ", ""))
	var names := metric_names(data.cards, data.config)
	var procs := clampi(options.get("procs", 1), 1, jobs.size())
	var games: Variant = jobs.map(func(job): return _play_one(data.cards, data.config, job, names)) if procs == 1 \
		else _play_children(cards_path, config_path, seed_count, strategy, options, procs, jobs.size(), names)
	if games is Dictionary:  # read_shards' errors
		return {"code": 1, "lines": games.errors, "procs": procs}
	var lines: Array[String] = ["%d seeds (1-%d)" % [seed_count, seed_count]]
	if strategy != "all":
		lines.append_array(_metric_lines(_summaries(_collect(games, names))))
		return {"code": 0, "lines": lines, "procs": procs}
	var per_civ: int = jobs.size() / ScriptedBot.STRATEGIES.size() / seed_count
	var next := 0
	for s in ScriptedBot.STRATEGIES:
		lines.append("== %s" % s)
		var all := {}
		var scores: PackedStringArray = []
		for i in per_civ:
			var civ: String = jobs[next][2]
			var values := _collect(games.slice(next, next + seed_count), names)
			next += seed_count
			scores.append("%s %.1f" % [civ if civ != "" else "default", _summary(values.score).mean])
			for m in values:
				all[m] = all.get(m, []) + values[m]
		lines.append("score by civilization: " + ", ".join(scores))
		lines.append_array(_metric_lines(_summaries(all)))
	return {"code": 0, "lines": lines, "procs": procs}


## The data files loaded with options' turn limit applied: {cards, config, errors}; errors also name an unknown
## strategy.
static func _load(cards_path: String, config_path: String, strategy: String, options: Dictionary) -> Dictionary:
	var data := DataLoader.load_all(cards_path, config_path)
	if data.errors.is_empty() and strategy != "all" and not ScriptedBot.STRATEGIES.has(strategy):
		data.errors.append("unknown strategy '%s' (one of %s, or all)" % [strategy, ScriptedBot.STRATEGIES])
	if data.errors.is_empty() and options.get("turns", 0) > 0:
		data.config.turn_limit = options.turns
	return data


## Every game a run plays, [seed, strategy, civ] each, in report order: by strategy, then civilization, then seed.
## A single strategy plays only_civ ("" for the default); "all" plays each listed civilization, or only_civ.
static func _jobs(config: Dictionary, seed_count: int, strategy: String, only_civ: String) -> Array:
	var strategies: Array = ScriptedBot.STRATEGIES if strategy == "all" else [strategy]
	var civs: Array = [only_civ] if only_civ != "" or strategy != "all" else config.get("civilizations", [])
	if civs.is_empty():
		civs = [""]
	var jobs := []
	for s in strategies:
		for civ in civs:
			for seed in range(1, seed_count + 1):
				jobs.append([seed, s, civ])
	return jobs


## Plays shard index of count (jobs index, index + count, …) of the run run_files would make, and writes their
## metrics to out_path as JSON {job index: {metric: value}}. Returns 0, or 1 when the data doesn't load (no file).
## sim/run.gd calls it in a child process.
static func play_shard(cards_path: String, config_path: String, seed_count: int, strategy: String, options: Dictionary,
		index: int, count: int, out_path: String) -> int:
	var data := _load(cards_path, config_path, strategy, options)
	if not data.errors.is_empty():
		return 1
	var jobs := _jobs(data.config, seed_count, strategy, options.get("civ", ""))
	var names := metric_names(data.cards, data.config)
	var games := {}
	for i in range(index, jobs.size(), count):
		games[str(i)] = _play_one(data.cards, data.config, jobs[i], names)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		return 1
	file.store_string(JSON.stringify(games))
	return 0


## Where shard index writes its games in dir.
static func shard_path(dir: String, index: int) -> String:
	return dir.path_join("%d.json" % index)


## Reads the count shards' files in dir back into one list of job_count games ({metric: int} for names, in names'
## order; null for a game no shard wrote), then removes the files and dir. Returns {games, errors}: an error per
## shard with no readable file ("shard 2 of 4 wrote no results").
static func read_shards(dir: String, count: int, job_count: int, names: Array[String]) -> Dictionary:
	var games := []
	games.resize(job_count)
	var errors: Array[String] = []
	for i in count:
		var path := shard_path(dir, i)
		var part: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not part is Dictionary:
			errors.append("shard %d of %d wrote no results" % [i + 1, count])
			continue
		for k in part:
			var game := {}
			for m in names:  # JSON sorts keys: back in report order
				game[m] = int(part[k][m])
			games[int(k)] = game
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)
	return {"games": games, "errors": errors}


## Plays the run on procs child processes (sim/run.gd with a shard=i/procs argument each) and returns its games in job
## order, or {errors} when a shard wrote no results. A child still running after CHILD_TIMEOUT_MSEC is killed.
static func _play_children(cards_path: String, config_path: String, seed_count: int, strategy: String,
		options: Dictionary, procs: int, job_count: int, names: Array[String]) -> Variant:
	var dir := OS.get_temp_dir().path_join("sim-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	DirAccess.make_dir_recursive_absolute(dir)
	var base := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
		"res://sim/run.gd", "--", str(seed_count), strategy])
	if options.get("civ", "") != "":
		base.append_array(["--civ", options.civ])
	if options.get("turns", 0) > 0:
		base.append_array(["--turns", str(options.turns)])
	base.append_array(["cards=" + cards_path, "config=" + config_path])
	var pids := []
	for i in procs:
		var args := base.duplicate()
		args.append_array(["shard=%d/%d" % [i, procs], "out=" + shard_path(dir, i)])
		pids.append(OS.create_process(OS.get_executable_path(), args))
	var deadline := Time.get_ticks_msec() + CHILD_TIMEOUT_MSEC
	for pid in pids:
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			OS.delay_msec(20)
		if OS.is_process_running(pid):
			OS.kill(pid)
	var read := read_shards(dir, procs, job_count, names)
	return read.games if read.errors.is_empty() else {"errors": read.errors}


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
