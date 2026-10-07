class_name SimLevels
extends RefCounted
## Sim levels (backlog 378): scripts/sim.sh --level 1-4 picks a run's seeds, strategies and civilizations in place of
## its positional seed count and strategy. 1: seed 1, GenericBot.STRATEGY, the baseline civ (config
## starting.civilization, or --civ); 2: seed 1, every strategy, the baseline civ; 3: seed 1, every strategy and listed
## civilization; 4: seeds 1-10, every strategy and civilization. With --compare, the seeds are the most a cell gets.

## [seeds, every strategy, every civilization] per level, 1-4.
const LEVELS := {"1": [1, false, false], "2": [1, true, false], "3": [1, true, true], "4": [10, true, true]}
## Seeds a run plays with no level and no seed count.
const DEFAULT_SEEDS := 20


## Reads scripts/sim.sh's arguments (the --compare pair already taken out) against config (parsed; {} when it doesn't
## load). Returns LaunchOptions.parse's dictionary (civ, turns, seed, positional, errors) plus seeds and strategy
## ("all" for every one): from --level when given, else the positional seed count (default 20) and strategy (default
## "all"). civ is the one civilization the run plays, "" for every listed one (or, with one strategy, the default).
static func run_args(args: PackedStringArray, config: Dictionary) -> Dictionary:
	var level := ""
	var errors: Array[String] = []
	var rest := PackedStringArray()
	var i := 0
	while i < args.size():
		if args[i] != "--level":
			rest.append(args[i])
		elif i + 1 >= args.size():
			errors.append("--level needs a value")
		else:
			i += 1
			level = args[i]
		i += 1
	var out := LaunchOptions.parse(rest, config.get("civilizations", []))
	out.errors.append_array(errors)
	var positional: Array = out.positional
	out["seeds"] = int(positional[0]) if not positional.is_empty() and positional[0].is_valid_int() else DEFAULT_SEEDS
	out["strategy"] = positional[1] if positional.size() > 1 else "all"
	if level == "":
		return out
	if not LEVELS.has(level):
		out.errors.append("--level '%s' must be 1, 2, 3 or 4" % level)
		return out
	if not positional.is_empty():
		out.errors.append("--level replaces the seed count and strategy: %s" % " ".join(positional))
	var shape: Array = LEVELS[level]
	out.seeds = shape[0]
	out.strategy = "all" if shape[1] else GenericBot.STRATEGY
	if shape[2]:
		if out.civ != "":
			out.errors.append("--civ: level %s plays every civilization" % level)
	elif out.civ == "":
		out.civ = config.get("starting", {}).get("civilization", "")
		if out.civ == "":
			out.errors.append("level %s plays one civilization: set starting.civilization in the config, or --civ" % level)
	return out
