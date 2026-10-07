extends SceneTree
## Balance simulator entry point (backlog 042). Use scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n] (135), or
## --level 1-4 in place of seeds and strategy (378, SimLevels): plays seeds 1..N (default 20)
## with GenericBot on data/*.json and prints mean, min and max per metric; with no strategy (or "all"), a block per
## strategy with its score per civilization (134). Exits 1 on loader errors or an unknown strategy. Plays the games on
## SIM_PROCS processes (152; default the performance cores but one, 291: SimStats.procs_from_env; SIM_PROCS=1 for this
## one only). A parallel worker that finishes no turn for SIM_STALL_SEC seconds (default 600) is stopped and fails the run,
## and a parallel run prints a progress line to stderr each minute (318). A parallel run fails at once while another one, from any checkout, holds the lock (291). Each game's
## result is cached under CACHE_DIR by the code and data that played it (292). With SIM_COMPARE set to a checkout's
## absolute root (293; scripts/sim.sh --compare <checkout> sets it) it compares that checkout ("main") with this one game
## by game instead: the seed count is the most a cell gets.

## The lock every checkout's parallel runs share, in the per-user temp directory (291).
const LOCK_NAME := "4x-card-game-sim.lock"
## Where games' results are cached (292): user:// is shared by every checkout of the project. SIM_CACHE=0 turns it off.
const CACHE_DIR := "user://sim-cache"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var child := _child_args(args)
	var cards_path: String = child.get("cards", "res://data/cards.json")
	var config_path: String = child.get("config", "res://data/config.json")
	var data := DataLoader.load_all(cards_path, config_path)
	var options := SimLevels.run_args(args.slice(0, args.size() - child.size()), data.config if data.errors.is_empty() else {})
	var seed_count: int = options.seeds
	var strategy: String = options.strategy
	if child.has("worker"):  # a child process of a parallel run (152): play from its queue (291), print nothing
		quit(SimStats.play_claimed(cards_path, config_path, seed_count, strategy, options, child.dir, int(child.worker)))
		return
	var env := {}
	for key in ["SIM_PROCS", "SIM_PERF_CORES", "SIM_STALL_SEC"]:
		env[key] = OS.get_environment(key)
	options["procs"] = SimStats.procs_from_env(env, OS.get_processor_count())
	options["stall_sec"] = SimStats.stall_sec_from_env(env)
	options["lock_path"] = OS.get_temp_dir().path_join(LOCK_NAME)
	options["cache_dir"] = CACHE_DIR
	options["cache"] = OS.get_environment("SIM_CACHE") != "0"
	var out := {"code": 1, "lines": options.errors}
	if not options.errors.is_empty():
		pass
	elif OS.get_environment("SIM_COMPARE") != "":
		var main_side := {"root": OS.get_environment("SIM_COMPARE").simplify_path().trim_suffix("/"), "cards": "res://data/cards.json", "config": "res://data/config.json"}
		out = SimStats.compare(main_side, SimStats.here(cards_path, config_path), seed_count, strategy, options)
	else:
		out = SimStats.run_files(cards_path, config_path, seed_count, strategy, options)
	for line in out.lines:
		if out.code == 0:
			print(line)
		else:
			printerr(line)
	quit(out.code)


## The key=value arguments a parallel run passes its children at the end of their args (cards, config, dir, worker):
## {key: value}, {} for a run started by hand.
func _child_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for i in range(args.size() - 1, -1, -1):
		var kv := args[i].split("=", true, 1)
		if kv.size() != 2 or not kv[0] in ["cards", "config", "dir", "worker"]:
			break
		out[kv[0]] = kv[1]
	return out
