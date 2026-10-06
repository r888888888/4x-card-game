extends "res://tests/lib/tech_case.gd"
## The balance simulator (backlog 042): the sim bot (GenericBot since 314, sim/generic_bot.gd) and per-seed stats
## (sim/sim_stats.gd).

const METRICS := ["anarchies", "anarchy_turns", "bought", "cities", "era", "explored", "famine_turns", "gov_changes",
	"lookahead_turns", "pop", "restored", "revolts", "score", "techs", "trashed"]  # sorted (158 added the Anarchy and
	# famine ones, 294 lookahead_turns)


## TEST_CARDS and a config with this deck and overrides, parsed; returns {cards, config}.
func sim_data(deck: Dictionary, overrides := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return {"cards": cards, "config": config}


# --- AC1: the sim bot ---

func test_bot_plays_a_game_to_the_end() -> void:
	var e := make_engine({"shrine": 10}, {"turn_limit": 3})
	check(GenericBot.play(e), "play returns true when the game ended")
	check(e.is_over, "game over")
	eq(e.score(), 17, "Capital 2 + 5 Shrines x 3 turns")


func test_bug_058_bot_ends_the_turn_when_a_free_card_only_redraws_itself() -> void:
	# Two free Scouts (draw 2) and nothing else: each play reshuffles the discard, which holds only the other Scout,
	# and draws it back, forever.
	var e := make_engine({"scout": 2}, {"turn_limit": 2})
	check(GenericBot.play(e), "the game ends within the bot's step limit")
	check(e.is_over, "game over")


## Backlog 151: the bot picks a tech without building tech_tree(). Fixture techs for the tie-break and the timing.
const ERA_2_SCRIBE := {"id": "scribe", "name": "Scribe", "type": "tech", "cost": {"insight": 3}, "era": 2}


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


func test_a_game_with_nothing_to_weigh_reports_no_lookahead_turns() -> void:
	var d := sim_data({"shrine": 10}, {"turn_limit": 3 * GenericBot.REVOLT_EVERY})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("lookahead_turns"), {"mean": 0.0, "min": 0, "max": 0}, "no government deck, no choice events (294)")


# --- 318 AC1: a game reports each turn as it starts (a parallel worker's progress) ---

func test_bug_318_a_game_reports_each_turn_and_plays_the_same() -> void:
	var stats: Object = SimStats.new()
	var d := sim_data({"shrine": 10}, {"turn_limit": 3})
	var names := SimStats.metric_names(d.cards, d.config)
	var turns := []
	var watched: Dictionary = stats.play_game(d.cards, d.config, [1, "generic", ""], names, func(t): turns.append(t))
	var plain: Dictionary = stats.play_game(d.cards, d.config, [1, "generic", ""], names)
	eq(turns, [1, 2, 3], "each turn once, as it starts")
	eq(watched, plain, "the same game with or without the callback")

func test_sim_stats_counts_founded_cities() -> void:
	var d := sim_data({"settler": 10}, {"turn_limit": 2,
		"starting": {"resources": {"food": 30}, "tableau": ["capital"], "territory": "homeland"}})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("cities", {}).get("min"), 10, "10 Settlers played with 30 food + upkeep over 2 turns")


## Backlog 066: explored is how many turns the territory deck lasted: the turn it ran out, or the last turn played.
func test_sim_stats_reports_how_long_the_territory_deck_lasted() -> void:
	var d := sim_data({"pathfinder": 10}, {"turn_limit": 5, "territory_deck": {"hills": 1, "grassland": 1}})
	var stats: Dictionary = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("explored", {}).get("min"), 1, "two Pathfinders (explore, +1 food) on turn 1 empty a 2-card territory deck")
	d = sim_data({"shrine": 10}, {"turn_limit": 5, "territory_deck": {"hills": 1, "grassland": 1}})
	stats = SimStats.run(d.cards, d.config, [1])
	eq(stats.get("explored", {}).get("min"), 5, "never explored: it lasted all 5 turns")


## Backlog 143: when each era with techs opens and runs out. Fixture: Pottery (2) and Writing (3) in era 1, Optics (era 2,
## 4 insight) and a 3-turn game; insight as given, with no income.
const OPTICS := {"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}


func tempo_stats(insight: int, era_1 := {"pottery": 1, "writing": 1}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([OPTICS], errors, warnings)
	var deck := era_1.duplicate()
	deck["optics"] = 1
	var config := DataLoader.parse_config(raw_config({"shrine": 10}, {"turn_limit": 3, "research_deck": deck,
		"starting": {"resources": {"food": 2, "insight": insight}, "tableau": ["capital"], "territory": "homeland"}}),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return SimStats.run(cards, config, [1])


func test_sim_stats_report_when_each_era_opens_and_runs_out() -> void:
	var stats := tempo_stats(5)
	eq(stats.get("era_1_open"), {"mean": 1.0, "min": 1, "max": 1}, "era 1 is open from turn 1")
	eq(stats.get("era_1_done", {}).get("min"), 1, "Pottery and Writing both learned on turn 1")
	eq(stats.get("era_2_open", {}).get("min"), 1, "the empty deck adds era 2 on turn 1")
	eq(stats.get("era_2_done", {}).get("min"), 3, "Optics (4) never afforded: the turn limit")


func test_an_era_never_finished_reports_the_turn_limit() -> void:
	var stats := tempo_stats(0, {"pottery": 1, "bronze": 1})
	eq(stats.get("era_1_done", {}).get("min"), 3, "never afforded: the turn limit")
	eq(stats.get("era_2_open", {}).get("min"), 3, "never opened: the turn limit")


func test_sim_stats_have_no_era_metrics_without_techs() -> void:
	var stats: Dictionary = SimStats.run(sim_data({"shrine": 10}, {"turn_limit": 2}).cards,
		sim_data({"shrine": 10}, {"turn_limit": 2}).config, [1])
	check(not stats.keys().any(func(k): return k.begins_with("era_")), "no era_ metrics: %s" % [stats.keys()])


# --- AC3: the command-line entry point ---

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
