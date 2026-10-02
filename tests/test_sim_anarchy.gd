extends "res://tests/lib/anarchy_case.gd"
## Sim metrics for Anarchy, governments and famine (backlog 158): per game, anarchies, revolts, anarchy_turns, restored,
## gov_changes, famine_turns, trashed, and <id>_turns per government a game can have. Counted from the engine's
## changed signal and its revolted and order_restored signals. Fixture games from tests/lib/anarchy_case.gd plus
## Charter (an order card that creates Kings into the government deck).

const CHARTER := {"id": "charter", "name": "Charter", "type": "action", "tags": ["order"],
	"effects": [{"op": "create", "card": "kings", "zone": "discard"}]}
const NEW_METRICS := ["anarchies", "revolts", "anarchy_turns", "restored", "gov_changes", "famine_turns", "trashed"]


## SimStats.run on one seed of a game with a deck of Charters, block merged into the unrest block, starting resources
## starting (food, wealth and insight 10 unless given) and overrides: {metric: value}.
func sim_game(block := {}, starting := {}, overrides := {}) -> Dictionary:
	var cards := anarchy_db([CHARTER])
	var resources := {"food": 10, "wealth": 10, "insight": 10}
	resources.merge(starting, true)
	var o := {"deck": {"charter": 10}, "turn_limit": 5, "starting": {"resources": resources, "tableau": ["capital"],
		"territory": "homeland", "government": "chiefs"}}
	o.merge(overrides, true)
	var raw := anarchy_raw(block, o)
	raw.deck = o.deck
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var listed: Array[String] = []
	listed.assign(raw.resources)
	var config := DataLoader.parse_config(raw, listed, cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test config should load: %s" % [errors])
	var stats := SimStats.run(cards, config, [1])
	var out := {}
	for m in stats:
		out[m] = stats[m].min
	return out


# --- AC1, AC2: the metric names ---

func test_the_new_metrics_and_one_per_government_in_order() -> void:
	var cards := anarchy_db([CHARTER])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(anarchy_raw(), RESOURCES, cards, "config.json", errors, warnings)
	var names := SimStats.metric_names(cards, config)
	for m in NEW_METRICS:
		check(names.has(m), "%s in %s" % [m, names])
	var govs := names.filter(func(n): return n.ends_with("_turns") and n != "anarchy_turns" and n != "famine_turns")
	eq(govs, ["chiefs_turns", "kings_turns"], "the starting government, then those a card creates; no Anarchy")


# --- AC3: a known script ---

func test_a_forced_anarchy_of_2_turns_then_kings() -> void:
	var m := sim_game({"max_counters": 2}, {"unrest": 5})
	eq([m.get("anarchies"), m.get("anarchy_turns"), m.get("revolts"), m.get("restored")], [1, 2, 0, 0],
		"turn 1 starts at the limit: Anarchy for turns 1 and 2, burning out")
	eq([m.get("gov_changes"), m.get("kings_turns"), m.get("chiefs_turns")], [1, 3, 0],
		"Kings chosen at the end of turn 2 rules turns 3 to 5; Chiefs never started a turn")


func test_a_revolution_counts_as_a_revolt_and_an_anarchy() -> void:
	var m := sim_game({}, {"unrest": 1})
	eq([m.get("revolts"), m.get("anarchies"), m.get("anarchy_turns")], [1, 1, 1],
		"Charter makes Kings on turn 1, the bot revolts; a 1-turn Anarchy on turn 2")
	eq([m.get("chiefs_turns"), m.get("kings_turns"), m.get("gov_changes")], [1, 3, 1], "Chiefs turn 1, Kings 3 to 5")


func test_buying_order_counts_as_restored() -> void:
	var m := sim_game({}, {"unrest": 5, "wealth": 30})
	eq([m.get("restored"), m.get("anarchy_turns")], [1, 2], "the bot buys order on Anarchy's second turn")


func test_trashed_and_famine_turns() -> void:
	var renewal := sim_game({"renewal": 1, "max_counters": 2}, {"unrest": 5})
	check(renewal.get("trashed", 0) >= 1, "renewal trashed cards: %s" % renewal.get("trashed"))
	eq(sim_game().get("trashed"), 0, "nothing trashed")
	var hungry := sim_game({}, {"food": 0}, {"population": {"start": 6, "food_upkeep": 3, "vp_per_pop": 0,
		"famine": FAMINE}})
	check(hungry.get("famine_turns", 0) >= 1, "a hungry game has famine turns: %s" % hungry.get("famine_turns"))
	eq(sim_game().get("famine_turns"), 0, "a fed game has none")


# --- The signals the metrics count ---

func test_revolting_emits_revolted_once() -> void:
	var e := anarchy_engine()
	var count := [0]
	e.connect("revolted", func(): count[0] += 1)
	e.revolt()
	e.revolt()
	eq(count[0], 1, "one revolution, the refusal silent")


func test_restoring_order_emits_order_restored_once() -> void:
	var e := second_turn_engine(5, 30)
	var count := [0]
	e.connect("order_restored", func(): count[0] += 1)
	e.restore_order()
	e.restore_order()
	eq(count[0], 1, "once, the refusal silent")


# --- AC4: a parallel run ---

func test_the_metrics_come_through_a_parallel_run() -> void:
	var o := {"civ": "sumer", "turns": 6, "seed": -1}
	var one: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		o.merged({"procs": 1}))
	var two: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 2, "baseline",
		o.merged({"procs": 2}))
	for m in NEW_METRICS + ["chiefdom_turns"]:
		check(one.get("lines", []).any(func(l): return l.begins_with(m + " ")), "%s in the report" % m)
	eq(two.get("lines"), one.get("lines"), "the same report on 2 processes")
