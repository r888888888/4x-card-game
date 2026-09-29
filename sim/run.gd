extends SceneTree
## Balance simulator entry point (backlog 042). Use scripts/sim.sh [seeds]: plays seeds 1..N (default 20)
## with ScriptedBot on data/*.json and prints mean, min and max per metric. Exits 1 on loader errors.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := int(args[0]) if not args.is_empty() and args[0].is_valid_int() else 20
	var out := SimStats.run_files("res://data/cards.json", "res://data/config.json", seed_count)
	for line in out.lines:
		if out.code == 0:
			print(line)
		else:
			printerr(line)
	quit(out.code)
