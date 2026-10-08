class_name SimStats
extends RefCounted
## Plays one GenericBot game per seed and summarizes the results (backlog 042); per strategy and civilization (134). Used by sim/run.gd
## (scripts/sim.sh) and the balance skill. run_files can spread the games over child processes (152): each claims the next
## unplayed game from one queue until none is left (play_claimed, 291) and writes its games to a file, which the parent
## reads back (read_workers). A parallel run given a lock_path runs only while no other run holds that lock (291).

const METRICS: Array[String] = ["score", "settlements", "pop", "techs", "bought", "era", "explored", "anarchies", "revolts",
	"gov_changes", "famine_turns", "trashed", "deck_end", "lookahead_turns", "raids",
	"raids_repelled", "raid_strength_max", "raid_pop_lost", "raid_units_lost", "raid_food_lost", "raid_wealth_lost"]
## How long a parallel run's worker may go without finishing a turn before it is stopped and the run fails (318).
## SIM_STALL_SEC overrides it (stall_sec_from_env).
const DEFAULT_STALL_SEC := 600
## How often a parallel run still waiting on its workers prints a progress line (318), in seconds.
const PROGRESS_EVERY_SEC := 60.0
## The file in a parallel run's directory listing its jobs (293), so a worker plays exactly the parent's list.
const JOBS_FILE := "jobs.json"
## A game samples TREND_RESOURCES held every TREND_EVERY turns (379): <resource>_t<n> as turn n starts.
const TREND_EVERY := 10
const TREND_RESOURCES: Array[String] = [GameEngine.FOOD, GameEngine.WEALTH]


## Plays one game per seed with strategy (a GenericBot.STRATEGIES name, 134, 314) as civ ("" for the default) and returns
## {metric: {mean: float, min: int, max: int}} for each of METRICS. explored is how many turns the territory deck lasted:
## the turn it ran out, or the last turn played if it never did. For each era with techs in the research deck (143),
## era_<n>_open is the turn it was added (1 for era 1) and era_<n>_done the turn its last tech was researched; either
## is the last turn played when it never happened. The Anarchy metrics (158): anarchies (times it began), revolts,
## gov_changes (times the ruling
## government's id changed, Anarchy not counted), famine_turns (turns that started with a Famine), trashed (cards
## trashed by the end), deck_end (the cards in the deck, hand and discard at the end, 376), and <id>_turns per government (see _governments): turns that started with it ruling.
## lookahead_turns (294) is the turns the bot's rollouts played (GenericBot.lookahead_turns). The raid metrics (375)
## add up the game's raid_resolved outcomes (raid_metrics).
static func run(cards: Dictionary, config: Dictionary, seeds: Array, strategy := GenericBot.STRATEGY, civ := "") -> Dictionary:
	return _summaries(_values(cards, config, seeds, strategy, civ))


## {metric: [one value per seed]} for games with strategy as civ.
static func _values(cards: Dictionary, config: Dictionary, seeds: Array, strategy: String, civ: String) -> Dictionary:
	var names := metric_names(cards, config)
	return _collect(seeds.map(func(seed): return play_game(cards, config, [seed, strategy, civ], names)), names)


## {metric: [one value per game]} for names, from games' metrics.
static func _collect(games: Array, names: Array[String]) -> Dictionary:
	var values := {}
	for m in names:
		values[m] = games.map(func(g): return g[m])
	return values


## The metrics a game reports, in report order: METRICS, <id>_turns for each of _governments, era_<n>_open and
## era_<n>_done for each era with techs, then tier_<id> for each settlement tier (328, see _tiers), then the trend
## samples (379): <resource>_t<n> for each of TREND_RESOURCES, then each n of TREND_EVERY, 2 × TREND_EVERY, … up to
## the turn limit.
static func metric_names(cards: Dictionary, config: Dictionary) -> Array[String]:
	var names := METRICS.duplicate()
	for id in _governments(cards, config):
		names.append("%s_turns" % id)
	for n in _techs_per_era(cards, config):
		names.append_array(["era_%d_open" % n, "era_%d_done" % n])
	for t in _tiers(config):
		names.append("tier_%s" % t.id)
	for r in TREND_RESOURCES:
		for n in range(TREND_EVERY, config.get("turn_limit", 0) + 1, TREND_EVERY):
			names.append("%s_t%d" % [r, n])
	return names


## The turns of resource's trend samples (379) among names (metric names, or the keys of {metric: mean}), in order.
static func trend_turns(resource: String, names: Array) -> Array[int]:
	var turns: Array[int] = []
	for m in names:
		var n: String = m.trim_prefix(resource + "_t")
		if m.begins_with(resource + "_t") and n.is_valid_int():
			turns.append(int(n))
	turns.sort()
	return turns


## Whether metric m is a trend sample (379), reported by trend_line instead of a line of its own.
static func is_trend_metric(m: String) -> bool:
	return TREND_RESOURCES.any(func(r): return not trend_turns(r, [m]).is_empty())


## "food by turn: 10 12.0, 20 22.5" (379): the mean of each of resource's trend samples in means ({metric: mean}),
## by turn; "" when it has none.
static func trend_line(resource: String, means: Dictionary) -> String:
	var parts: PackedStringArray = []
	for n in trend_turns(resource, means.keys()):
		parts.append("%d %.1f" % [n, means["%s_t%d" % [resource, n]]])
	return "%s by turn: %s" % [resource, ", ".join(parts)] if not parts.is_empty() else ""


## The config's settlement tiers (281), lowest first; [] with population or tiers off.
static func _tiers(config: Dictionary) -> Array:
	return config.get("population", {}).get("tiers", [])


## Plays job ([seed, strategy, civ]) and returns its metrics, {name: int} for names. Calls on_turn (when valid) with
## each turn as it starts (318: a parallel worker's progress); it changes nothing in the game.
static func play_game(cards: Dictionary, config: Dictionary, job: Array, names: Array[String],
		on_turn := Callable()) -> Dictionary:
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
	var tally := {"anarchies": 0, "revolts": 0, "gov_changes": 0, "famine_turns": 0}
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
			if on_turn.is_valid():
				on_turn.call(engine.turn)
			tally.famine_turns += 1 if engine.famine_counters() > 0 else 0
			if tally.has("%s_turns" % ruling):
				tally["%s_turns" % ruling] += 1
			if engine.turn % TREND_EVERY == 0:  # what is held as the turn starts (379)
				for r in TREND_RESOURCES:
					tally["%s_t%d" % [r, engine.turn]] = engine.resources.get(r, 0)
	var on_revolted := func(): tally.revolts += 1
	var raids: Array[Dictionary] = []
	var on_raid := func(outcome: Dictionary): raids.append(outcome)
	engine.changed.connect(on_changed)
	engine.changed.connect(on_state)
	engine.revolted.connect(on_revolted)
	engine.raid_resolved.connect(on_raid)
	on_changed.call()  # an empty territory deck from the start, era 1 open
	on_state.call()  # turn 1 as it started
	GenericBot.lookahead_turns = 0
	GenericBot.play(engine, job[1])
	engine.changed.disconnect(on_changed)  # the callables hold engine: break the cycle so it is freed
	engine.changed.disconnect(on_state)
	engine.revolted.disconnect(on_revolted)
	engine.raid_resolved.disconnect(on_raid)
	var game := game_metrics(engine, config)
	game.merge(tally)
	game.merge(raid_metrics(raids))
	game.lookahead_turns = GenericBot.lookahead_turns
	var out := {}
	for m in names:
		out[m] = game[m] if game.has(m) else seen.get(m, engine.turn)
	return out


## The raid metrics (375) of a game's raid_resolved outcomes: raids (strikes), raids_repelled, raid_strength_max, and
## what the pillages took: raid_pop_lost, raid_units_lost, raid_food_lost, raid_wealth_lost. A repelled raid's own
## losses don't count.
static func raid_metrics(outcomes: Array) -> Dictionary:
	var out := {"raids": outcomes.size(), "raids_repelled": 0, "raid_strength_max": 0, "raid_pop_lost": 0,
		"raid_units_lost": 0, "raid_food_lost": 0, "raid_wealth_lost": 0}
	for o in outcomes:
		out.raid_strength_max = maxi(out.raid_strength_max, o.strength)
		if o.repelled:
			out.raids_repelled += 1
			continue
		out.raid_pop_lost += o.pop_lost
		out.raid_units_lost += o.units_lost.size()
		out.raid_food_lost += o.lost.get(GameEngine.FOOD, 0)
		out.raid_wealth_lost += o.lost.get(GameEngine.WEALTH, 0)
	return out


## "raids by civilization: sumer 4.0 (1.5 repelled, 2.5 pop lost), …" (375) from per_civ, [[civ ("" for the default),
## {metric: [one value per game]}], …] in report order.
static func raids_by_civilization(per_civ: Array) -> String:
	var parts: PackedStringArray = []
	for row in per_civ:
		var values: Dictionary = row[1]
		parts.append("%s %.1f (%.1f repelled, %.1f pop lost)" % [row[0] if row[0] != "" else "default",
			_summary(values.raids).mean, _summary(values.raids_repelled).mean, _summary(values.raid_pop_lost).mean])
	return "raids by civilization: " + ", ".join(parts)


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


## The metrics of one finished game. settlements counts the cities founded, the starting ones not counted;
## tier_<id> (328) how many settled territories, the home one included, ended in each tier.
static func game_metrics(engine: GameEngine, config: Dictionary) -> Dictionary:
	var bought := 0
	var supply: Dictionary = config.get("supply", {})
	for id in supply:
		bought += supply[id].count - engine.supply_left(id)
	var out := {
		"score": engine.score(),
		"settlements": _count_type(engine.zone("tableau").cards, "city") - _starting_cities(engine, config),
		"pop": engine.total_pop(),
		"techs": engine.zone("researched").size(),
		"bought": bought,
		"era": engine.era(),
		"trashed": engine.zone("trashed").size(),
		"deck_end": engine.zone("deck").size() + engine.zone("hand").size() + engine.zone("discard").size(),
	}
	var tiers := _tiers(config)
	for t in tiers:
		out["tier_%s" % t.id] = 0
	for c in engine.zone("tableau").cards:
		if c.def.type == CardDef.TERRITORY and not tiers.is_empty():
			out["tier_%s" % tiers[Population.tier(engine, c.uid)].id] += 1
	return out


## Loads the data files and runs seeds 1..seed_count with strategy. Returns {code, lines, procs, games_per_proc, played,
## cached}: code 0 and one line
## per metric; with strategy "all", a block per strategy: its mean score per listed civilization, then its metrics over
## all of them. Code 1 and the loader errors (or an unknown strategy, or the shards that wrote no results). options
## (LaunchOptions.parse, 135): turns replaces the turn limit, civ plays only that civilization; procs (152, default 1)
## is how many processes play the games, never more than there are games. procs in the result is how many did, and
## games_per_proc how many games each played. lock_path (291): with procs 2+, the run takes that lock first and fails
## at once (code 1, playing nothing) while another live run holds it; "" or absent for no lock. cache_dir (292): reads
## each game a run with the same code (source_hash), data bytes, seed, strategy, civ and turn limit played before, and
## writes each game it plays; "" or absent (or cache false) for no cache. played and cached count the games each way;
## the header names the cached ones.
static func run_files(cards_path: String, config_path: String, seed_count: int, strategy := GenericBot.STRATEGY,
		options := {}) -> Dictionary:
	var data := _load(cards_path, config_path, strategy, options)
	if not data.errors.is_empty():
		return {"code": 1, "lines": data.errors, "procs": 1}
	var jobs := job_list(data.config, seed_count, strategy, options.get("civ", ""))
	var names := metric_names(data.cards, data.config)
	var refused := take_run_lock(options)
	if refused != "":
		return {"code": 1, "lines": [refused], "procs": options.get("procs", 1), "games_per_proc": []}
	var played := play_side(here(cards_path, config_path), data, jobs, names, options)
	release_run_lock(options)
	var out := {"code": 1, "lines": played.errors, "procs": played.procs, "games_per_proc": played.per_proc,
		"played": played.played, "cached": played.cached}
	if not played.errors.is_empty():
		return out
	var games: Array = played.games
	var lines: Array[String] = ["%d seeds (1-%d)" % [seed_count, seed_count]]
	if out.cached > 0:
		lines[0] += ", %d of %d games cached" % [out.cached, jobs.size()]
	out.code = 0
	out.lines = lines
	if strategy != "all":
		lines.append_array(_metric_lines(_summaries(_collect(games, names))))
		return out
	var per_civ: int = jobs.size() / GenericBot.STRATEGIES.size() / seed_count
	var next := 0
	for s in GenericBot.STRATEGIES:
		lines.append("== %s" % s)
		var all := {}
		var scores: PackedStringArray = []
		var civ_values := []
		for i in per_civ:
			var civ: String = jobs[next][2]
			var values := _collect(games.slice(next, next + seed_count), names)
			next += seed_count
			scores.append("%s %.1f" % [civ if civ != "" else "default", _summary(values.score).mean])
			civ_values.append([civ, values])
			for m in values:
				all[m] = all.get(m, []) + values[m]
		lines.append("score by civilization: " + ", ".join(scores))
		lines.append(raids_by_civilization(civ_values))
		lines.append_array(_metric_lines(_summaries(all)))
	return out


## Compares two checkouts game by game, adding seeds where the change isn't clear yet (293): see SimCompare.run.
static func compare(main_side: Dictionary, this_side: Dictionary, max_seeds: int, strategy: String,
		options: Dictionary) -> Dictionary:
	return SimCompare.run(main_side, this_side, max_seeds, strategy, options)


## Whether a compared cell needs no more seeds (293): see SimCompare.cell_done.
static func cell_done(deltas: Array, main_mean: float, max_seeds: int) -> bool:
	return SimCompare.cell_done(deltas, main_mean, max_seeds)


## A compared cell's report line (293): see SimCompare.cell_line.
static func cell_line(cell: Dictionary) -> String:
	return SimCompare.cell_line(cell)


## The data files loaded with options' turn limit applied: {cards, config, errors}; errors also name an unknown
## strategy.
static func _load(cards_path: String, config_path: String, strategy: String, options: Dictionary) -> Dictionary:
	var data := DataLoader.load_all(cards_path, config_path)
	if data.errors.is_empty() and strategy != "all" and not GenericBot.STRATEGIES.has(strategy):
		data.errors.append("unknown strategy '%s' (one of %s, or all)" % [strategy, GenericBot.STRATEGIES])
	if data.errors.is_empty() and options.get("turns", 0) > 0:
		data.config.turn_limit = options.turns
	return data


## Every game a run plays, [seed, strategy, civ] each, in report order: by strategy, then civilization, then seed.
## Also the cells a comparison plays (293), with seed_count 1.
## A single strategy plays only_civ ("" for the default); "all" plays each listed civilization, or only_civ.
static func job_list(config: Dictionary, seed_count: int, strategy: String, only_civ: String) -> Array:
	var strategies: Array = GenericBot.STRATEGIES if strategy == "all" else [strategy]
	var civs: Array = [only_civ] if only_civ != "" or strategy != "all" else config.get("civilizations", [])
	if civs.is_empty():
		civs = [""]
	var jobs := []
	for s in strategies:
		for civ in civs:
			for seed in range(1, seed_count + 1):
				jobs.append([seed, s, civ])
	return jobs


## How many processes a run uses (291), from env's SIM_PROCS (a whole number of at least 1), else SIM_PERF_CORES (the
## performance cores, which scripts/sim.sh reads from sysctl) but one, else cpu_count but one; never fewer than 1.
static func procs_from_env(env: Dictionary, cpu_count: int) -> int:
	var procs: String = env.get("SIM_PROCS", "")
	if procs.is_valid_int() and int(procs) >= 1:
		return int(procs)
	var perf: String = env.get("SIM_PERF_CORES", "")
	var cores := int(perf) if perf.is_valid_int() and int(perf) >= 1 else cpu_count
	return maxi(1, cores - 1)


## Plays, as worker, every job in dir's jobs.json (293; else of the run run_files would make) that no worker has claimed
## in dir yet, one at a time: a
## job is claimed by making its claim_path, which only one worker can do. Writes the games it played to
## worker_path(dir, worker) as JSON {job index: {metric: value}} after each one, {} when none was left, and its progress
## (write_progress, 318) when it starts, claims a game, starts each turn and finishes a game. Returns 0, or 1 when the
## data doesn't load (no file). sim/run.gd calls it in a child process.
static func play_claimed(cards_path: String, config_path: String, seed_count: int, strategy: String,
		options: Dictionary, dir: String, worker: int) -> int:
	var data := _load(cards_path, config_path, strategy, options)
	if not data.errors.is_empty():
		return 1
	var jobs := _jobs_in(dir) if FileAccess.file_exists(dir.path_join(JOBS_FILE)) \
		else job_list(data.config, seed_count, strategy, options.get("civ", ""))
	var names := metric_names(data.cards, data.config)
	DirAccess.make_dir_recursive_absolute(claim_path(dir, 0).get_base_dir())
	var games := {}
	if not _write_json(worker_path(dir, worker), games):
		return 1
	write_progress(dir, worker, -1, 0)
	var turn := [0]
	for i in jobs.size():
		if DirAccess.make_dir_absolute(claim_path(dir, i)) != OK:  # another worker has it
			continue
		var since := Time.get_unix_time_from_system()
		write_progress(dir, worker, i, 0, since)
		var on_turn := func(t: int):
			turn[0] = t
			write_progress(dir, worker, i, t, since)
		games[str(i)] = play_game(data.cards, data.config, jobs[i], names, on_turn)
		_write_json(worker_path(dir, worker), games)
		write_progress(dir, worker, -1, turn[0])
	return 0


## Writes worker's progress in dir (318): {job (its index, -1 for none in play), turn (the last reached), at (now, in
## Unix seconds), since (when the game in play was claimed; now when not given)}. Written whole by a rename, so a
## reader never sees half of it.
static func write_progress(dir: String, worker: int, job: int, turn: int, since := 0.0) -> void:
	var now := Time.get_unix_time_from_system()
	var path := progress_path(dir, worker)
	if _write_json(path + ".tmp", {"job": job, "turn": turn, "at": now, "since": since if since > 0.0 else now}):
		DirAccess.rename_absolute(path + ".tmp", path)


## worker's progress in dir as write_progress wrote it ({job, turn, at, since}), {} when it has none.
static func read_progress(dir: String, worker: int) -> Dictionary:
	var path := progress_path(dir, worker)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if not raw is Dictionary or not raw.has_all(["job", "turn", "at", "since"]):
		return {}
	return {"job": int(raw.job), "turn": int(raw.turn), "at": float(raw.at), "since": float(raw.since)}


## Where worker writes its progress in dir (318).
static func progress_path(dir: String, worker: int) -> String:
	return dir.path_join("%d.progress.json" % worker)


## The stall limit in seconds (318) from env's SIM_STALL_SEC (a whole number of at least 1), else DEFAULT_STALL_SEC.
static func stall_sec_from_env(env: Dictionary) -> int:
	var sec: String = env.get("SIM_STALL_SEC", "")
	return int(sec) if sec.is_valid_int() and int(sec) >= 1 else DEFAULT_STALL_SEC


## A parallel run's progress line (318): games done of total, then each game in playing ([job ([seed, strategy, civ]),
## turn, minutes so far]).
static func progress_line(done: int, total: int, playing: Array) -> String:
	var line := "sim: %d of %d games done" % [done, total]
	var games := PackedStringArray()
	for p in playing:
		games.append("seed %d %s %s (turn %d, %d min)" % [p[0][0], p[0][1], p[0][2] if p[0][2] != "" else "default",
			p[1], floori(p[2])])
	return line + ("; playing " + ", ".join(games) if not games.is_empty() else "")


## The jobs a parent wrote to dir's jobs.json ([seed, strategy, civ] each).
static func _jobs_in(dir: String) -> Array:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(JOBS_FILE)))
	return (raw if raw is Array else []).map(func(j): return [int(j[0]), j[1], j[2]])


## The directory whose making claims job index of the run in dir (291).
static func claim_path(dir: String, index: int) -> String:
	return dir.path_join("claims").path_join(str(index))


## Where worker writes its games in dir.
static func worker_path(dir: String, worker: int) -> String:
	return dir.path_join("%d.json" % worker)


## Reads the count workers' files in dir back into one list of job_count games ({metric: int} for names, in names'
## order; null for a game no worker wrote), then removes dir. Returns {games, errors, per_proc}: an error per game
## with no result (only those in expected, when given), and how many games each worker wrote. A game a worker's
## progress says it was playing names that worker, the game (with its seed, strategy and civ from dir's jobs.json) and
## the turn it reached (318): "stalled" for a worker in stalled ({worker: the stall limit it broke, in seconds}),
## else "stopped" (it died); any other is "game 2 of 4 has no result". A stalled worker with no game in play gets its
## own error.
static func read_workers(dir: String, count: int, job_count: int, names: Array[String], expected := [],
		stalled := {}) -> Dictionary:
	var games := []
	games.resize(job_count)
	var per_proc := []
	for i in count:
		var path := worker_path(dir, i)
		var part: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not part is Dictionary:
			per_proc.append(0)
			continue
		per_proc.append(part.size())
		for k in part:
			var game := {}
			for m in names:  # JSON sorts keys: back in report order
				game[m] = int(part[k][m])
			games[int(k)] = game
	var jobs := _jobs_in(dir) if FileAccess.file_exists(dir.path_join(JOBS_FILE)) else []
	var in_play := {}  # job index → that worker's progress
	for w in count:
		var p := read_progress(dir, w)
		if p.get("job", -1) >= 0:
			p.worker = w
			in_play[p.job] = p
	var errors: Array[String] = []
	for i in job_count:
		if games[i] != null or not (expected.is_empty() or i in expected):
			continue
		if not in_play.has(i):
			errors.append("game %d of %d has no result" % [i + 1, job_count])
			continue
		var p: Dictionary = in_play[i]
		var game := "game %d of %d" % [i + 1, job_count]
		if i < jobs.size():
			game += " (seed %d, %s, %s)" % [jobs[i][0], jobs[i][1], jobs[i][2] if jobs[i][2] != "" else "default"]
		if stalled.has(p.worker):
			errors.append("worker %d stalled during %s at turn %d: no turn finished in %d s" % [p.worker, game, p.turn,
				stalled[p.worker]])
		else:
			errors.append("worker %d stopped during %s at turn %d" % [p.worker, game, p.turn])
	for w in stalled:
		if not in_play.values().any(func(p): return p.worker == w):
			errors.append("worker %d stalled with no game in play: no turn finished in %d s" % [w, stalled[w]])
	_remove_tree(dir)
	return {"games": games, "errors": errors, "per_proc": per_proc}


## Takes the lock at path for this process (291): a directory holding its pid, made atomically. A lock whose process
## isn't running is taken over. Returns "", or why not (another live run holds it).
static func take_lock(path: String) -> String:
	for attempt in 2:
		if DirAccess.make_dir_absolute(path) == OK:
			_write_text(path.path_join("pid"), str(OS.get_process_id()))
			return ""
		var pid := _lock_pid(path)
		if pid == 0:  # just made, its pid not written yet: look once more
			OS.delay_msec(200)
			pid = _lock_pid(path)
		if pid > 0 and _running(pid):
			return "another sim run is using the CPU (pid %d); try again when it ends" % pid
		release_lock(path)
	return "could not take the sim lock %s" % path


## Releases the lock at path (take_lock).
static func release_lock(path: String) -> void:
	DirAccess.remove_absolute(path.path_join("pid"))
	DirAccess.remove_absolute(path)


## The pid in the lock at path, 0 when there is none.
static func _lock_pid(path: String) -> int:
	var text := FileAccess.get_file_as_string(path.path_join("pid")).strip_edges()
	return int(text) if text.is_valid_int() else 0


## Whether process pid is running (any process, not only this one's children).
static func _running(pid: int) -> bool:
	return OS.execute("kill", ["-0", str(pid)]) == 0


## A side of a run (293): this project with these data files. A side is {root, cards, config}: a checkout's absolute
## root and its data files (res:// paths are that checkout's).
static func here(cards_path: String, config_path: String) -> Dictionary:
	return {"root": project_root(), "cards": cards_path, "config": config_path}


## This project's absolute root, with no trailing slash.
static func project_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


## Whether root (an absolute path, with or without a trailing slash) is this project's.
static func is_this_project(root: String) -> bool:
	return root.simplify_path().trim_suffix("/") == project_root()


## path of side as this process can open it: a res:// path of another checkout under its root.
static func side_path(side: Dictionary, path: String) -> String:
	if path.begins_with("res://") and not is_this_project(side.root):
		return side.root.path_join(path.trim_prefix("res://"))
	return path


## side's data files loaded with options' turn limit applied: {cards, config, errors} (see _load).
static func load_side(side: Dictionary, strategy: String, options: Dictionary) -> Dictionary:
	return _load(side_path(side, side.cards), side_path(side, side.config), strategy, options)


## Plays jobs ([seed, strategy, civ] each) on side with its loaded data, reading and writing options' cache (292), on
## options' procs: in this process for procs 1 (this project only), else on child processes running side's own code.
## Returns {games (one per job, null where none came back), errors, procs, per_proc, played, cached}.
static func play_side(side: Dictionary, data: Dictionary, jobs: Array, names: Array[String], options: Dictionary) -> Dictionary:
	var cache := _cache_folder(side, data.config, options)
	var games := []
	games.resize(jobs.size())
	var todo := []  # the job indices no cache entry has
	for i in jobs.size():
		games[i] = _cache_read(cache, jobs[i], names)
		if games[i] == null:
			todo.append(i)
	var procs := clampi(options.get("procs", 1), 1, maxi(todo.size(), 1))
	var out := {"games": games, "errors": [], "procs": procs, "per_proc": [], "played": todo.size(),
		"cached": jobs.size() - todo.size()}
	if todo.is_empty():
		return out
	if procs == 1:
		for i in todo:
			games[i] = play_game(data.cards, data.config, jobs[i], names)
		out.per_proc = [todo.size()]
	else:
		var read := _play_children(side, options, procs, jobs, names, todo)
		out.errors = read.errors
		out.per_proc = read.per_proc
		for i in todo:
			games[i] = read.games[i]
	if out.errors.is_empty():
		for i in todo:
			_cache_write(cache, jobs[i], games[i])
	return out


## Takes options' lock_path when the run is parallel (procs 2+, 291). Returns "", or why another run holds it.
static func take_run_lock(options: Dictionary) -> String:
	if options.get("lock_path", "") == "" or options.get("procs", 1) < 2:
		return ""
	return take_lock(options.lock_path)


## Releases what take_run_lock took.
static func release_run_lock(options: Dictionary) -> void:
	if options.get("lock_path", "") != "" and options.get("procs", 1) >= 2:
		release_lock(options.lock_path)


## Plays the todo indices of jobs on procs child processes running side's code (sim/run.gd with --path side's root,
## and worker=i and dir= arguments): the parent writes jobs to the run directory's jobs.json and claims the others up
## front, and the workers claim the rest from one queue. Returns read_workers' {games, errors, per_proc}. A worker that
## finishes no turn for options' stall_sec (default DEFAULT_STALL_SEC, counted from its last progress, else from its
## start) is killed and named as stalled (318); there is no limit on the run as a whole. Every PROGRESS_EVERY_SEC while
## waiting, prints progress_line to stderr.
static func _play_children(side: Dictionary, options: Dictionary, procs: int, jobs: Array, names: Array[String],
		todo: Array) -> Dictionary:
	var dir := OS.get_temp_dir().path_join("sim-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	for i in jobs.size():
		if not i in todo:
			DirAccess.make_dir_recursive_absolute(claim_path(dir, i))
	DirAccess.make_dir_recursive_absolute(dir)
	_write_json(dir.path_join(JOBS_FILE), jobs)
	var base := PackedStringArray(["--headless", "--path", side.root, "--script", "res://sim/run.gd", "--", "1", "all"])
	if options.get("turns", 0) > 0:
		base.append_array(["--turns", str(options.turns)])
	base.append_array(["cards=" + side.cards, "config=" + side.config, "dir=" + dir])
	var pids := []
	for i in procs:
		var args := base.duplicate()
		args.append("worker=%d" % i)
		pids.append(OS.create_process(OS.get_executable_path(), args))
	var stalled := _watch(dir, pids, options.get("stall_sec", DEFAULT_STALL_SEC), jobs, todo.size())
	return read_workers(dir, procs, jobs.size(), names, todo, stalled)


## Waits for the worker processes pids (worker i is pids[i]) of the run in dir to exit, killing each that finishes no
## turn for stall_sec seconds, and prints progress_line every PROGRESS_EVERY_SEC (318). Returns {worker: stall_sec}
## for the workers it killed.
static func _watch(dir: String, pids: Array, stall_sec: int, jobs: Array, total: int) -> Dictionary:
	var started := Time.get_unix_time_from_system()
	var last_line := started
	var running := {}
	for i in pids.size():
		running[i] = pids[i]
	var stalled := {}
	while not running.is_empty():
		var now := Time.get_unix_time_from_system()
		for i in running.keys():
			if not OS.is_process_running(running[i]):
				running.erase(i)
			elif now - read_progress(dir, i).get("at", started) >= stall_sec:
				OS.kill(running[i])  # and reaps it
				stalled[i] = stall_sec
				running.erase(i)
		if now - last_line >= PROGRESS_EVERY_SEC and not running.is_empty():
			printerr(_progress_now(dir, pids.size(), jobs, total, now))
			last_line = now
		OS.delay_msec(20)
	return stalled


## progress_line for the run in dir now: the games its count workers have written of total, and the games in play.
static func _progress_now(dir: String, count: int, jobs: Array, total: int, now: float) -> String:
	var done := 0
	var playing := []
	for w in count:
		var path := worker_path(dir, w)
		var part: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		done += part.size() if part is Dictionary else 0
		var p := read_progress(dir, w)
		if p.get("job", -1) >= 0:
			playing.append([jobs[p.job], p.turn, (now - p.since) / 60.0])
	return progress_line(done, total, playing)


## A hash of the code that plays a game (292): every .gd script under root's engine/, sim/ and autoload/ (paths and
## contents, in path order) and the Godot version.
static func source_hash(root: String) -> String:
	var paths: Array[String] = []
	for folder in ["engine", "sim", "autoload"]:
		_scripts_under(root, folder, paths)
	paths.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(Engine.get_version_info().string.to_utf8_buffer())
	for path in paths:
		ctx.update(("\n%s\n" % path).to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(root.path_join(path)))
	return ctx.finish().hex_encode()


## Appends to out the .gd scripts under root/folder, as paths relative to root.
static func _scripts_under(root: String, folder: String, out: Array[String]) -> void:
	var dir := root.path_join(folder)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(folder.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		_scripts_under(root, folder.path_join(sub), out)


## The cache folder for side's code and data files' bytes under options' cache_dir, "" for no cache.
static func _cache_folder(side: Dictionary, config: Dictionary, options: Dictionary) -> String:
	var base: String = options.get("cache_dir", "")
	if base == "" or not options.get("cache", true):
		return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in [side.cards, side.config]:
		ctx.update(FileAccess.get_file_as_bytes(side_path(side, path)))
		ctx.update("\n".to_utf8_buffer())
	var code := source_hash(side.root)
	return base.path_join("%s-%s" % [code.left(16), ctx.finish().hex_encode().left(16)]).path_join(
		"turns-%d" % config.get("turn_limit", 0))


## The cache entry of job ([seed, strategy, civ]) in folder.
static func _cache_entry(folder: String, job: Array) -> String:
	return folder.path_join("%s-%s-%d.json" % [job[1], job[2] if job[2] != "" else "default", job[0]])


## job's metrics from the cache folder ({metric: int} for names, in names' order), null when it has no entry, the entry
## isn't JSON or lacks one of names.
static func _cache_read(folder: String, job: Array, names: Array[String]) -> Variant:
	if folder == "" or not FileAccess.file_exists(_cache_entry(folder, job)):
		return null
	var json := JSON.new()  # parse(), unlike parse_string, logs no error for a bad entry
	var entry: Variant = json.data if json.parse(FileAccess.get_file_as_string(_cache_entry(folder, job))) == OK else null
	if not entry is Dictionary or names.any(func(m): return not entry.has(m)):
		return null
	var game := {}
	for m in names:
		game[m] = int(entry[m])
	return game


## Writes job's metrics (game) to the cache folder, through a temp file so a reader never sees half an entry.
static func _cache_write(folder: String, job: Array, game: Dictionary) -> void:
	if folder == "":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	var path := _cache_entry(folder, job)
	var temp := "%s.%d.tmp" % [path, OS.get_process_id()]
	if _write_json(temp, game):
		DirAccess.rename_absolute(temp, path)


## Writes value to path as JSON; whether it could.
static func _write_json(path: String, value: Variant) -> bool:
	return _write_text(path, JSON.stringify(value))


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	return true


## Removes dir and everything in it.
static func _remove_tree(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


## A line per metric in stats ({metric: {mean, min, max}}), then a trend_line per resource in place of the trend
## samples' own lines (379).
static func _metric_lines(stats: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var means := {}
	for m in stats:  # METRICS, then the era metrics by era
		means[m] = stats[m].mean
		if not is_trend_metric(m):
			lines.append("%-10s mean %6.2f  min %3d  max %3d" % [m, stats[m].mean, stats[m].min, stats[m].max])
	for r in TREND_RESOURCES:
		var line := trend_line(r, means)
		if line != "":
			lines.append(line)
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
