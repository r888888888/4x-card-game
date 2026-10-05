class_name SimStats
extends RefCounted
## Plays one ScriptedBot game per seed and summarizes the results (backlog 042); per strategy and civilization (134). Used by sim/run.gd
## (scripts/sim.sh) and the balance skill. run_files can spread the games over child processes (152): each claims the next
## unplayed game from one queue until none is left (play_claimed, 291) and writes its games to a file, which the parent
## reads back (read_workers). A parallel run given a lock_path runs only while no other run holds that lock (291).

const METRICS: Array[String] = ["score", "cities", "pop", "techs", "bought", "era", "explored", "anarchies", "revolts",
	"anarchy_turns", "restored", "gov_changes", "famine_turns", "trashed", "lookahead_turns"]
## How long a parallel run waits for its child processes before killing them (their shards then fail the run).
const CHILD_TIMEOUT_MSEC := 60 * 60 * 1000
## The file in a parallel run's directory listing its jobs (293), so a worker plays exactly the parent's list.
const JOBS_FILE := "jobs.json"


## Plays one game per seed with strategy (a ScriptedBot.STRATEGIES name, 134) as civ ("" for the default) and returns
## {metric: {mean: float, min: int, max: int}} for each of METRICS. explored is how many turns the territory deck lasted:
## the turn it ran out, or the last turn played if it never did. For each era with techs in the research deck (143),
## era_<n>_open is the turn it was added (1 for era 1) and era_<n>_done the turn its last tech was researched; either
## is the last turn played when it never happened. The Anarchy metrics (158): anarchies (times it began), revolts,
## anarchy_turns (turns that started under it), restored (times order was bought), gov_changes (times the ruling
## government's id changed, Anarchy not counted), famine_turns (turns that started with a Famine), trashed (cards
## trashed by the end), and <id>_turns per government (see _governments): turns that started with it ruling.
## lookahead_turns (294) is the turns the bot's lookahead forks played (ScriptedBot.lookahead_turns).
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
	ScriptedBot.lookahead_turns = 0
	ScriptedBot.play(engine, job[1])
	engine.changed.disconnect(on_changed)  # the callables hold engine: break the cycle so it is freed
	engine.changed.disconnect(on_state)
	engine.revolted.disconnect(on_revolted)
	engine.order_restored.disconnect(on_restored)
	var game := game_metrics(engine, config)
	game.merge(tally)
	game.lookahead_turns = ScriptedBot.lookahead_turns
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
static func run_files(cards_path: String, config_path: String, seed_count: int, strategy := "baseline",
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
	if data.errors.is_empty() and strategy != "all" and not ScriptedBot.STRATEGIES.has(strategy):
		data.errors.append("unknown strategy '%s' (one of %s, or all)" % [strategy, ScriptedBot.STRATEGIES])
	if data.errors.is_empty() and options.get("turns", 0) > 0:
		data.config.turn_limit = options.turns
	return data


## Every game a run plays, [seed, strategy, civ] each, in report order: by strategy, then civilization, then seed.
## Also the cells a comparison plays (293), with seed_count 1.
## A single strategy plays only_civ ("" for the default); "all" plays each listed civilization, or only_civ.
static func job_list(config: Dictionary, seed_count: int, strategy: String, only_civ: String) -> Array:
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
## worker_path(dir, worker) as JSON {job index: {metric: value}} after each one, {} when none was left. Returns 0, or 1
## when the data doesn't load (no file). sim/run.gd calls it in a child process.
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
	for i in jobs.size():
		if DirAccess.make_dir_absolute(claim_path(dir, i)) != OK:  # another worker has it
			continue
		games[str(i)] = _play_one(data.cards, data.config, jobs[i], names)
		_write_json(worker_path(dir, worker), games)
	return 0


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
## with no result ("game 2 of 4 has no result"; only those in expected, when given), and how many games each worker
## wrote.
static func read_workers(dir: String, count: int, job_count: int, names: Array[String], expected := []) -> Dictionary:
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
	var errors: Array[String] = []
	for i in job_count:
		if games[i] == null and (expected.is_empty() or i in expected):
			errors.append("game %d of %d has no result" % [i + 1, job_count])
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
			games[i] = _play_one(data.cards, data.config, jobs[i], names)
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
## front, and the workers claim the rest from one queue. Returns read_workers' {games, errors, per_proc}. A child still
## running after CHILD_TIMEOUT_MSEC is killed.
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
	var deadline := Time.get_ticks_msec() + CHILD_TIMEOUT_MSEC
	for pid in pids:
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			OS.delay_msec(20)
		if OS.is_process_running(pid):
			OS.kill(pid)
	return read_workers(dir, procs, jobs.size(), names, todo)


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
