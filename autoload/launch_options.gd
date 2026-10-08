class_name LaunchOptions
extends RefCounted
## Command-line options for testing (backlog 135), shared by the game (`godot --path . -- --civ sumer --turns 20`) and
## the sim (`scripts/sim.sh 20 all --civ sumer`): --civ <id>, --turns <n> and --seed <n>. Static functions.

const OPTIONS: Array[String] = ["--civ", "--turns", "--seed"]


## Reads args against the listed civilizations. Returns {civ: "" or an id, turns: 0 or the limit, seed: -1 or the
## seed, positional: the args that aren't options, errors}. A bad option is reported and keeps its default.
static func parse(args: PackedStringArray, civilizations: Array) -> Dictionary:
	var out := {"civ": "", "turns": 0, "seed": -1, "positional": [], "errors": [] as Array[String]}
	var i := 0
	while i < args.size():
		var arg := args[i]
		i += 1
		if not arg.begins_with("--"):
			out.positional.append(arg)
			continue
		if not OPTIONS.has(arg):
			out.errors.append("unknown option %s (options: %s)" % [arg, ", ".join(OPTIONS)])
			continue
		if i >= args.size():
			out.errors.append("%s needs a value" % arg)
			continue
		var value := args[i]
		i += 1
		match arg:
			"--civ":
				if civilizations.has(value):
					out.civ = value
				else:
					out.errors.append("--civ '%s' is not a listed civilization (one of %s)" % [value, ", ".join(civilizations)])
			"--turns":
				if value.is_valid_int() and int(value) >= 1:
					out.turns = int(value)
				else:
					out.errors.append("--turns '%s' must be a whole number of turns, at least 1" % value)
			"--seed":
				if value.is_valid_int() and int(value) >= 0:
					out.seed = int(value)
				else:
					out.errors.append("--seed '%s' must be a whole number, at least 0" % value)
	return out


## The game's options (378): parse(user_args, civilizations), or no options when engine_args (Godot's own) run a script
## (--script: the sim, the tests), whose arguments are that script's, not the game's.
static func for_game(engine_args: PackedStringArray, user_args: PackedStringArray, civilizations: Array) -> Dictionary:
	return parse(PackedStringArray() if engine_args.has("--script") else user_args, civilizations)


## Applies options to engine: a turns option replaces the config's turn limit for the games it starts.
static func apply(engine: GameEngine, options: Dictionary) -> void:
	if options.get("turns", 0) > 0:
		engine.config.turn_limit = options.turns


## Whether the game should start a game at launch instead of showing the title screen: a civ or a seed was given.
static func starts_game(options: Dictionary) -> bool:
	return options.get("civ", "") != "" or options.get("seed", -1) >= 0
