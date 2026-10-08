extends "res://tests/lib/anarchy_case.gd"
## Sim metrics for Anarchy, governments and famine (backlog 158): per game, anarchies, revolts, gov_changes,
## famine_turns, trashed, and <id>_turns per government a game can have (384 dropped restored, with buying order, and
## anarchy_turns, always anarchy_turns × anarchies). Counted from the engine's changed signal and its revolted signal. Fixture games from tests/lib/anarchy_case.gd plus
## Charter (an action tagged order that creates Glory into the government deck and gains 1 food, so the generic bot plays it,
## 314), Glory (government, ⟳ +3 VP, limit 5), which the bot's rollouts prefer to Chiefs, and Husk (worthless, renewed).
## The real-data parallel run is in tests/balance/test_sim_anarchy_report.gd.

const GLORY := {"id": "glory", "name": "Glory", "type": "government", "unrest_limit": 5,
	"effects": [{"op": "score", "amount": 3, "trigger": "upkeep"}]}
const CHARTER := {"id": "charter", "name": "Charter", "type": "action", "tags": ["order"],
	"effects": [{"op": "create", "card": "glory", "zone": "discard"}, {"op": "gain", "resource": "food", "amount": 1}]}
## Husk: an action of no worth, which the bot renews (385: renewal is optional).
const HUSK := {"id": "husk", "name": "Husk", "type": "action"}
const NEW_METRICS := ["anarchies", "revolts", "gov_changes", "famine_turns", "trashed"]


## SimStats.run on one seed of a game with a deck of Charters, block merged into the unrest block, starting resources
## starting (food, wealth and insight 10 unless given) and overrides: {metric: value}.
func sim_game(block := {}, starting := {}, overrides := {}) -> Dictionary:
	var stats := sim_stats(block, starting, overrides, [1])
	var out := {}
	for m in stats:
		out[m] = stats[m].min
	return out


## SimStats.run on seeds of sim_game's game: {metric: {mean, min, max}}.
func sim_stats(block: Dictionary, starting: Dictionary, overrides: Dictionary, seeds: Array) -> Dictionary:
	var cards := anarchy_db([GLORY, CHARTER, HUSK])
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
	return SimStats.run(cards, config, seeds)


# --- AC1, AC2: the metric names ---

func test_the_new_metrics_and_one_per_government_in_order() -> void:
	var cards := anarchy_db([GLORY, CHARTER])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(anarchy_raw(), RESOURCES, cards, "config.json", errors, warnings)
	var names := SimStats.metric_names(cards, config)
	for m in NEW_METRICS:
		check(names.has(m), "%s in %s" % [m, names])
	check(not names.has("restored") and not names.has("anarchy_turns"), "no restored or anarchy_turns (384)")
	var govs := names.filter(func(n): return n.ends_with("_turns") and not n in ["famine_turns", "lookahead_turns"])
	eq(govs, ["chiefs_turns", "glory_turns"], "the starting government, then those a card creates; no Anarchy")


# --- AC3: a known script ---

func test_a_forced_anarchy_of_3_turns_then_glory() -> void:
	var m := sim_game({}, {"unrest": 5})
	eq([m.get("anarchies"), m.get("revolts")], [1, 0], "turn 1 starts at the limit: Anarchy for turns 1 to 3 (384)")
	eq([m.get("gov_changes"), m.get("glory_turns"), m.get("chiefs_turns")], [1, 2, 0],
		"Glory chosen at the end of turn 3 rules turns 4 and 5; Chiefs never started a turn")


func test_a_revolution_counts_as_a_revolt_and_an_anarchy() -> void:
	var revolt := GenericBot.REVOLT_EVERY
	var last := revolt + GenericBot.ROLLOUT_TURNS
	var m := sim_game({}, {"unrest": 1}, {"turn_limit": last})
	eq([m.get("revolts"), m.get("anarchies")], [1, 1],
		"Charter makes Glory on turn 1, the bot revolts at the end of turn %d; Anarchy for turns %d–%d" % [revolt,
		revolt + 1, revolt + 3])
	eq([m.get("chiefs_turns"), m.get("glory_turns"), m.get("gov_changes")], [revolt, last - revolt - 3, 1],
		"Chiefs turns 1–%d, Glory %d–%d" % [revolt, revolt + 4, last])


# --- 294: lookahead_turns ---

func test_lookahead_turns_counts_each_game_on_its_own() -> void:
	var stats := sim_stats({}, {"unrest": 1}, {"turn_limit": GenericBot.REVOLT_EVERY + GenericBot.ROLLOUT_TURNS}, [1, 1])
	var turns: Dictionary = stats.get("lookahead_turns", {})
	check(turns.get("min", 0) > 0, "the bot weighed a revolution: %s" % [turns])
	eq(turns.get("max"), turns.get("min"), "the same game twice counts the same: the count restarts each game")


func test_trashed_and_famine_turns() -> void:
	var renewal := sim_game({"renewal": 1}, {"unrest": 5}, {"deck": {"charter": 9, "husk": 1}})
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

