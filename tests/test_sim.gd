extends "res://tests/lib/test_case.gd"
## The balance simulator (backlog 042): the scripted bot (sim/bot.gd) and per-seed stats (sim/sim_stats.gd).

const METRICS := ["bought", "cities", "era", "pop", "score", "techs"]  # sorted


## TEST_CARDS and a config with this deck and overrides, parsed; returns {cards, config}.
func sim_data(deck: Dictionary, overrides := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return {"cards": cards, "config": config}


# --- AC1: the scripted bot ---

func test_bot_plays_a_game_to_the_end() -> void:
	var e := make_engine({"shrine": 10}, {"turn_limit": 3})
	check(ScriptedBot.play(e), "play returns true when the game ended")
	check(e.is_over, "game over")
	eq(e.score(), 17, "Capital 2 + 5 Shrines x 3 turns")


func test_bot_resolves_an_explore_choice_with_its_first_option() -> void:
	var e := make_engine({"explorer": 10}, {"turn_limit": 1, "territory_deck": {"hills": 1, "grassland": 1}})
	arrange(e.zone("territory_deck"), ["hills", "grassland"])
	ScriptedBot.play(e)
	# Explorer 1 reveals Hills then Grassland; options list the reveal zone top first, so the first option is
	# Grassland. The bot keeps it and puts Hills under; Explorer 2 then finds Hills.
	eq(card_ids(e.zone("frontier")), ["grassland", "hills"] as Array[String], "first option kept first")


# --- AC2: stats over seeds ---

func test_sim_stats_reports_mean_min_max_per_metric() -> void:
	var d := sim_data({"shrine": 10}, {"turn_limit": 3})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1, 2])
	eq(sorted(stats.keys()), METRICS, "metrics")
	eq(stats.get("score"), {"mean": 17.0, "min": 17, "max": 17}, "score: Capital 2 + 5 Shrines x 3 turns")
	eq(stats.get("cities"), {"mean": 0.0, "min": 0, "max": 0}, "cities (the Capital doesn't count)")
	eq(stats.get("techs"), {"mean": 0.0, "min": 0, "max": 0}, "techs")
	eq(stats.get("bought"), {"mean": 0.0, "min": 0, "max": 0}, "bought")
	eq(stats.get("era"), {"mean": 1.0, "min": 1, "max": 1}, "era")
	eq(stats.get("pop"), {"mean": 0.0, "min": 0, "max": 0}, "pop (no population block)")


func test_sim_stats_counts_founded_cities() -> void:
	var d := sim_data({"settler": 10}, {"turn_limit": 2,
		"starting": {"resources": {"food": 30}, "tableau": ["capital"], "territory": "homeland"}})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("cities", {}).get("min"), 10, "10 Settlers played with 30 food + upkeep over 2 turns")


# --- AC3: the command-line entry point ---

func test_sim_run_files_prints_one_line_per_metric() -> void:
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 5)
	eq(out.get("code"), 0, "exit code")
	var lines: Array = out.get("lines", [])
	for m in METRICS:
		var matching := lines.filter(func(l): return l.begins_with(m + " "))
		eq(matching.size(), 1, "one line for %s in %s" % [m, lines])


func test_sim_run_files_reports_loader_errors() -> void:
	var path := "user://sim_bad_cards.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"cards": [{"id": "x", "name": "X", "type": "action", "effects": [{"op": "explode"}]}]}')
	f.close()
	var out: Dictionary = SimStats.run_files(path, "res://data/config.json", 5)
	eq(out.get("code"), 1, "exit code")
	var lines: Array[String] = []
	lines.assign(out.get("lines", []))
	has_msg(lines, "unknown op 'explode'")
