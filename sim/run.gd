extends SceneTree
## Balance simulator entry point (backlog 042). Use scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n] (135): plays seeds 1..N (default 20)
## with ScriptedBot on data/*.json and prints mean, min and max per metric; with no strategy (or "all"), a block per
## strategy with its score per civilization (134). Exits 1 on loader errors or an unknown strategy. Plays the games on
## SIM_PROCS processes (152; default the performance cores but one, 291: SimStats.procs_from_env; SIM_PROCS=1 for this
## one only). A parallel run fails at once while another one, from any checkout, holds the lock (291). Each game's
## result is cached under CACHE_DIR by the code and data that played it (292). With --compare <checkout> (293) it
## compares that checkout ("main") with this one game by game instead: the seed count is the most a cell gets.

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
	var civs: Array = data.config.get("civilizations", []) if data.errors.is_empty() else []
	var own := _without_compare(args.slice(0, args.size() - child.size()))  # the game's launch options don't know it
	var against := _compare_path(args.slice(0, args.size() - child.size()))
	var options := LaunchOptions.parse(own, civs)
	var positional: Array = options.positional
	var seed_count := int(positional[0]) if not positional.is_empty() and positional[0].is_valid_int() else 20
	var strategy: String = positional[1] if positional.size() > 1 else "all"
	if child.has("worker"):  # a child process of a parallel run (152): play from its queue (291), print nothing
		quit(SimStats.play_claimed(cards_path, config_path, seed_count, strategy, options, child.dir, int(child.worker)))
		return
	var env := {}
	for key in ["SIM_PROCS", "SIM_PERF_CORES"]:
		env[key] = OS.get_environment(key)
	options["procs"] = SimStats.procs_from_env(env, OS.get_processor_count())
	options["lock_path"] = OS.get_temp_dir().path_join(LOCK_NAME)
	options["cache_dir"] = CACHE_DIR
	options["cache"] = OS.get_environment("SIM_CACHE") != "0"
	var out := {"code": 1, "lines": options.errors}
	if not options.errors.is_empty():
		pass
	elif against != "":
		var main_side := {"root": against, "cards": "res://data/cards.json", "config": "res://data/config.json"}
		out = SimStats.compare(main_side, SimStats.here(cards_path, config_path), seed_count, strategy, options)
	else:
		out = SimStats.run_files(cards_path, config_path, seed_count, strategy, options)
	for line in out.lines:
		if out.code == 0:
			print(line)
		else:
			printerr(line)
	quit(out.code)


## The checkout after --compare in args (293), absolute (a relative one is from SIM_CWD, where scripts/sim.sh was
## started), "" without one.
func _compare_path(args: PackedStringArray) -> String:
	var at := args.find("--compare")
	if at == -1 or at + 1 >= args.size():
		return ""
	var path := args[at + 1]
	if path.is_relative_path():
		path = OS.get_environment("SIM_CWD").path_join(path)
	return path.simplify_path().trim_suffix("/")


## args without --compare and its checkout.
func _without_compare(args: PackedStringArray) -> PackedStringArray:
	var at := args.find("--compare")
	return args if at == -1 else args.slice(0, at) + args.slice(at + 2)


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
