extends "res://tests/lib/tech_case.gd"
## The balance simulator (backlog 042): the scripted bot (sim/bot.gd) and per-seed stats (sim/sim_stats.gd).

const METRICS := ["bought", "cities", "era", "explored", "pop", "score", "techs"]  # sorted


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


func test_bug_058_bot_ends_the_turn_when_a_free_card_only_redraws_itself() -> void:
	# Two free Scouts (draw 2) and nothing else: each play reshuffles the discard, which holds only the other Scout,
	# and draws it back, forever.
	var e := make_engine({"scout": 2}, {"turn_limit": 2})
	check(ScriptedBot.play(e), "the game ends within the bot's step limit")
	check(e.is_over, "game over")


## Backlog 140: the tree is open, so the bot learns the cheapest tech it can afford at the start of its turn.
func test_bot_learns_the_cheapest_tech_it_can_afford() -> void:
	var e: Object = tech_engine(["writing", "pottery", "bronze"], {"farm": 10},
		{"starting": {"resources": {"food": 2, "insight": 2}, "tableau": ["capital"], "territory": "homeland"}})
	ScriptedBot.take_turn(e, "baseline")
	eq(card_ids(e.zone("researched")), ["pottery"], "Pottery (2) learned; Writing (3) and Bronze (5) too dear")
	eq(e.resources.get("insight"), 0, "2 − 2")


## Backlog 084: before ending a turn the bot relieves a Famine it can pay for when the next upkeep would still starve.
func test_bot_relieves_a_famine_only_when_the_next_upkeep_would_starve() -> void:
	var famine: Dictionary = FAMINE.merged({"relief": {"wealth": 5}})
	var e: Object = make_engine({"shrine": 10}, {"turn_limit": 3,
		"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1, "famine": famine}})
	e.zone("tableau").find(home_uid(e)).pop = 4
	e.resources.food = 0
	e.resources.wealth = 20
	# Turn 2 starts short (Famine, 4 -> 3) and would starve again: relieved (20 -> 15). Turn 3 starts short again
	# (a new Famine, 3 -> 2), but it's the last turn: no next upkeep, so no relief.
	ScriptedBot.play(e)
	eq(e.resources.wealth, 15, "relieved once")


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


## Backlog 066: explored is how many turns the territory deck lasted: the turn it ran out, or the last turn played.
func test_sim_stats_reports_how_long_the_territory_deck_lasted() -> void:
	var d := sim_data({"explorer": 10}, {"turn_limit": 5, "territory_deck": {"hills": 1, "grassland": 1}})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("explored", {}).get("min"), 1, "two Explorers on turn 1 empty a 2-card territory deck")
	d = sim_data({"shrine": 10}, {"turn_limit": 5, "territory_deck": {"hills": 1, "grassland": 1}})
	stats = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("explored", {}).get("min"), 5, "never explored: it lasted all 5 turns")


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
