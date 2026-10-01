extends SceneTree
## Balance simulator entry point (backlog 042). Use scripts/sim.sh [seeds] [strategy]: plays seeds 1..N (default 20)
## with ScriptedBot on data/*.json and prints mean, min and max per metric; with no strategy (or "all"), a block per
## strategy with its score per civilization (134). Exits 1 on loader errors or an unknown strategy.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 20
	var strategy: String = args[1] if args.size() > 1 else "all"
	var out := SimStats.run_files("res://data/cards.json", "res://data/config.json", seed_count, strategy)
	for line in out.lines:
		if out.code == 0:
			print(line)
		else:
			printerr(line)
	quit(out.code)
