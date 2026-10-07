extends "res://tests/lib/tech_case.gd"
## The balance simulator (backlog 042): the sim bot (GenericBot since 314, sim/generic_bot.gd) and per-seed stats
## (sim/sim_stats.gd).

const METRICS := ["anarchies", "anarchy_turns", "bought", "cities", "era", "explored", "famine_turns", "gov_changes",
	"lookahead_turns", "pop", "raid_food_lost", "raid_pop_lost", "raid_strength_max", "raid_units_lost",
	"raid_wealth_lost", "raids", "raids_repelled", "restored", "revolts", "score", "techs", "trashed"]  # sorted (158
	# added the Anarchy and famine ones, 294 lookahead_turns, 375 the raid ones)


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


# --- 375: raids and what they cost ---

## The raid metrics (375), in report order.
const RAID_METRICS := ["raids", "raids_repelled", "raid_strength_max", "raid_pop_lost", "raid_units_lost",
	"raid_food_lost", "raid_wealth_lost"]
## Siege: a raid of strength 99 on any territory, so the bot never repels it; pillaged −1 food.
const SIEGE := {"id": "siege", "name": "Siege", "type": "event", "raid": {"strength": 99},
	"effects": [{"op": "lose", "resource": "food", "amount": 1, "trigger": "pillage"}]}


## A raid_resolved outcome with these fields; the rest as a pillage that took nothing.
func fixture_outcome(fields: Dictionary) -> Dictionary:
	var o := {"uid": 1, "id": "siege", "target": 1, "strength": 2, "defense": 0, "repelled": false,
		"units_lost": [] as Array[int], "pop_lost": 0, "gained": {}, "lost": {}, "vp": 0}
	o.merge(fields, true)
	return o


func test_375_metric_names_add_the_raid_metrics_after_the_others() -> void:
	var d := sim_data({"shrine": 10}, {"turn_limit": 3})
	var names := SimStats.metric_names(d.cards, d.config)
	var at := names.find("lookahead_turns") + 1
	eq(names.slice(at, at + RAID_METRICS.size()), RAID_METRICS, "after lookahead_turns, in order")


func test_375_raid_metrics_count_strikes_and_sum_what_pillages_took() -> void:
	var stats: Object = SimStats.new()
	var outcomes := [
		fixture_outcome({"strength": 2, "repelled": true, "defense": 3, "lost": {"food": 9}, "gained": {"wealth": 2}}),
		fixture_outcome({"strength": 5, "pop_lost": 1, "units_lost": [7] as Array[int], "lost": {"food": 4}}),
		fixture_outcome({"strength": 3, "pop_lost": 2, "lost": {"food": 2, "wealth": 3, "unrest": 1}}),
	]
	eq(stats.raid_metrics(outcomes), {"raids": 3, "raids_repelled": 1, "raid_strength_max": 5, "raid_pop_lost": 3,
		"raid_units_lost": 1, "raid_food_lost": 6, "raid_wealth_lost": 3}, "a repel adds to raids and repelled only")


func test_375_with_no_raid_struck_the_raid_metrics_are_0() -> void:
	var stats: Object = SimStats.new()
	var zero := {}
	for m in RAID_METRICS:
		zero[m] = 0
	eq(stats.raid_metrics([]), zero, "raid_metrics([])")
	var d := sim_data({"shrine": 10}, {"turn_limit": 3})
	var game: Dictionary = SimStats.run(d.cards, d.config, [1])
	for m in RAID_METRICS:
		eq(game.get(m), {"mean": 0.0, "min": 0, "max": 0}, "%s with no event deck" % m)


func test_375_a_sim_game_counts_the_raids_that_struck() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + [SIEGE]}, resources(), "test", errors, warnings,
		keywords())
	var config := DataLoader.parse_config(raw_config({"shrine": 10}, {"turn_limit": 7, "event_deck": {"siege": 1}}),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var game: Dictionary = SimStats.run(cards, config, [1])
	var got := {}
	for m in ["raids", "raids_repelled", "raid_strength_max"]:
		got[m] = game.get(m, {}).get("min")
	# Drawn on turn 2, it strikes as turn 4 starts, is drawn again then and strikes on turn 6; drawn again on turn 6,
	# the game ends before it strikes.
	eq(got, {"raids": 2, "raids_repelled": 0, "raid_strength_max": 99}, "two strikes at 99, none repelled")


func test_375_raids_by_civilization_line() -> void:
	var stats: Object = SimStats.new()
	var per_civ := [
		["sumer", {"raids": [4, 4], "raids_repelled": [1, 2], "raid_pop_lost": [2, 3]}],
		["", {"raids": [3], "raids_repelled": [3], "raid_pop_lost": [0]}],
	]
	eq(stats.raids_by_civilization(per_civ),
		"raids by civilization: sumer 4.0 (1.5 repelled, 2.5 pop lost), default 3.0 (3.0 repelled, 0.0 pop lost)",
		"means to 1 decimal, in the given order; the default civ named default")
