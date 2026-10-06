extends "res://tests/lib/test_case.gd"
## Balance sim strategies (backlog 134): SimStats runs a named strategy (GenericBot's since 314) per civilization. The
## strategies themselves are tested in test_generic_bot.gd.

var STATS: Variant = load("res://sim/sim_stats.gd")


## A population block where nobody eats unless food_upkeep says so.
func pop_block(food_upkeep := 0, start := 1) -> Dictionary:
	return {"start": start, "food_upkeep": food_upkeep, "vp_per_pop": 1, "famine": FAMINE}


# --- AC6: stats per strategy and civilization ---

## TEST_CARDS + TEST_CIVS and a config listing Tribe and Nomads, with this deck and overrides.
func civ_sim_data(deck: Dictionary, overrides := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := civ_db(errors, warnings)
	var o := {"civilizations": ["tribe", "nomads"]}
	var config := DataLoader.parse_config(raw_config(deck, o.merged(overrides, true)), resources(), cards, "test",
		errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	return {"cards": cards, "config": config}


func test_sim_stats_runs_a_strategy() -> void:
	var d := civ_sim_data({"shrine": 10}, {"turn_limit": 2, "population": pop_block(),
		"starting": {"resources": {"food": 30}, "tableau": ["capital"], "territory": "homeland"}})
	var generic: Dictionary = STATS.run(d.cards, d.config, [1], "generic")
	var wide: Dictionary = STATS.run(d.cards, d.config, [1], "wide")
	for stats in [generic, wide]:
		eq(stats.get("pop", {}).get("min"), 1, "pop stats, and no strategy grows pop itself (260): %s" % [stats.get("pop")])


func test_sim_stats_plays_as_a_civilization() -> void:
	var d := civ_sim_data({"shrine": 10}, {"turn_limit": 3})
	var plain: Dictionary = STATS.run(d.cards, d.config, [1], "generic", "")
	var nomads: Dictionary = STATS.run(d.cards, d.config, [1], "generic", "nomads")
	# Nomads: vp 1 and +1 score each upkeep (3 turns).
	eq(nomads.get("score", {}).get("min", 0) - plain.get("score", {}).get("min", 0), 4, "Nomads' score over no civ")
