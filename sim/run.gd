extends SceneTree
## Balance simulator entry point (backlog 042). Use scripts/sim.sh [seeds] [strategy] [--civ id] [--turns n] (135): plays seeds 1..N (default 20)
## with ScriptedBot on data/*.json and prints mean, min and max per metric; with no strategy (or "all"), a block per
## strategy with its score per civilization (134). Exits 1 on loader errors or an unknown strategy. Plays the games on
## SIM_PROCS processes (152; default the CPU count, SIM_PROCS=1 for this one only).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var child := _child_args(args)
	var cards_path: String = child.get("cards", "res://data/cards.json")
	var config_path: String = child.get("config", "res://data/config.json")
	var data := DataLoader.load_all(cards_path, config_path)
	var civs: Array = data.config.get("civilizations", []) if data.errors.is_empty() else []
	var options := LaunchOptions.parse(args.slice(0, args.size() - child.size()), civs)
	var positional: Array = options.positional
	var seed_count := int(positional[0]) if not positional.is_empty() and positional[0].is_valid_int() else 20
	var strategy: String = positional[1] if positional.size() > 1 else "all"
	if child.has("shard"):  # a child process of a parallel run (152): play one shard, print nothing
		var shard: PackedStringArray = child.shard.split("/")
		quit(SimStats.play_shard(cards_path, config_path, seed_count, strategy, options, int(shard[0]), int(shard[1]),
			child.out))
		return
	var procs := OS.get_environment("SIM_PROCS")
	options["procs"] = int(procs) if procs.is_valid_int() else OS.get_processor_count()
	var out := {"code": 1, "lines": options.errors} if not options.errors.is_empty() \
		else SimStats.run_files(cards_path, config_path, seed_count, strategy, options)
	for line in out.lines:
		if out.code == 0:
			print(line)
		else:
			printerr(line)
	quit(out.code)


## The key=value arguments a parallel run passes its children at the end of their args (cards, config, shard, out):
## {key: value}, {} for a run started by hand.
func _child_args(args: PackedStringArray) -> Dictionary:
	var out := {}
	for i in range(args.size() - 1, -1, -1):
		var kv := args[i].split("=", true, 1)
		if kv.size() != 2 or not kv[0] in ["cards", "config", "shard", "out"]:
			break
		out[kv[0]] = kv[1]
	return out
