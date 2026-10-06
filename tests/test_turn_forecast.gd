extends "res://tests/lib/raid_case.gd"
## turn_forecast (309): what starting the next turn changes, without the draw or the new event: upkeep's resources and
## score, pop starved by feeding, and the announced raids that strike. An arriving era's unrest: test_anarchy.gd.
## Raid games from tests/lib/raid_case.gd.

## Population on, eating 1 food per pop and scoring 1 VP per pop.
const POP_ON := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}
## raid_engine's population, scoring 1 VP per pop.
const RAID_POP := {"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 1}}


## A raid_engine game (VP per pop on) at turn 3, with Raiders announced on turn 2 to strike at the turn-4 start.
## before_strike runs on turn 2, after the raid is drawn.
func raid_turn_3(before_strike := func(_e): pass) -> GameEngine:
	var e: GameEngine = raid_engine(["raiders", "omen", "omen"], {"raiders": 1, "horde": 1, "omen": 3}, RAID_POP)
	if e == null:
		return null
	e.end_turn()
	before_strike.call(e)
	e.end_turn()
	check(e.raid_turns_left(active_uid(e, "raiders")) == 1, "Raiders strike at the next turn's start")
	return e


# --- AC1: upkeep's score and resources ---

func test_the_forecast_counts_upkeep_score_and_resources_like_upkeep_forecast() -> void:
	var e := make_engine({"farm": 10}, POP_ON)
	build_on(e, home_uid(e), ["temple"])
	var upkeep := e.upkeep_forecast()
	var f := e.turn_forecast()
	eq(f.get("score"), 1, "Temple ⟳ +1 score")
	for r in resources():
		eq(f.get(r), upkeep.get(r), "%s as upkeep_forecast" % r)
	eq(f.get("pop"), 0, "no pop change")
	eq(f.get("starve"), 0, "no starving")


# --- AC2: starving pop no longer scores ---

func test_pop_starved_by_feeding_is_lost_from_pop_and_score() -> void:
	var e := make_engine({"farm": 10}, POP_ON)
	e.zone("tableau").find(home_uid(e)).pop = 3
	e.resources.food = 0
	eq(e.upkeep_forecast().get("starve"), 1, "Capital's 2 food feed 2 of 3 pop")
	var f := e.turn_forecast()
	eq(f.get("starve"), 1, "1 starves")
	eq(f.get("pop"), -1, "pop −1")
	eq(f.get("score"), -1, "1 VP per pop lost")


# --- AC3: raids that strike ---

func test_a_raid_short_of_defence_counts_its_pillage() -> void:
	var e := raid_turn_3()
	if e == null:
		return
	var raid: Dictionary = e.raid_forecast()[0]
	check(raid.defense < raid.strength, "Hills is short: %s" % [raid])
	var upkeep := e.upkeep_forecast()
	var f := e.turn_forecast()
	eq(f.get("pop"), -1, "Hills loses 1 pop")
	eq(f.get("score"), -1, "1 VP per pop lost")
	eq(f.get("food"), upkeep.food - 2, "pillage −2 food")
	eq(f.get("unrest"), upkeep.unrest + 1, "pillage +1 unrest")


func test_a_raid_meeting_enough_defence_counts_its_repel() -> void:
	var e := raid_turn_3(func(g: GameEngine):
		build_on(g, hills_of(g), ["town"])
		recruit(g, hills_of(g)))
	if e == null:
		return
	var raid: Dictionary = e.raid_forecast()[0]
	check(raid.defense >= raid.strength, "Hills holds: %s" % [raid])
	var upkeep := e.upkeep_forecast()
	var f := e.turn_forecast()
	eq(f.get("pop"), 0, "no pop lost")
	eq(f.get("score"), 0, "no score lost")
	eq(f.get("wealth"), upkeep.wealth + 2, "repel +2 wealth")
	eq(f.get("unrest"), upkeep.unrest - 1, "repel −1 unrest")


# --- AC5: nothing changes ---

func test_the_forecast_changes_nothing_in_the_game() -> void:
	var e := raid_turn_3()
	if e == null:
		return
	var zones := {}
	for name in GameEngine.ZONES:
		zones[name] = e.zone(name).cards.map(func(c): return [c.uid, c.def.id, c.pop])
	var resources_before: Dictionary = e.resources.duplicate()
	var pending: Dictionary = e.pending()
	var turn := e.turn
	var log_size: int = e.log_lines.size()
	var twin := e.fork()
	var emitted := []
	for s in ["changed", "logged", "noticed", "raid_resolved", "milestone", "event_drawn"]:
		e.connect(s, func(_a = null, _b = null): emitted.append(s))
	var first := e.turn_forecast()
	var second := e.turn_forecast()
	eq(second, first, "two calls agree")
	for name in GameEngine.ZONES:
		eq(e.zone(name).cards.map(func(c): return [c.uid, c.def.id, c.pop]), zones[name], "zone %s" % name)
	eq(e.resources, resources_before, "resources")
	eq(e.pending(), pending, "pending")
	eq(e.turn, turn, "turn")
	eq(e.log_lines.size(), log_size, "log")
	eq(emitted, [], "no signals")
	var a := range(20)
	var b := range(20)
	e.rng.shuffle(a)
	twin.rng.shuffle(b)
	eq(a, b, "the game's rng draws as it would have")


# --- AC6: no next turn ---

func test_no_forecast_on_the_last_turn_or_after_game_over() -> void:
	eq(make_engine({"farm": 10}, {"turn_limit": 1}).turn_forecast(), {}, "turn 1 of 1")
	eq(over_engine().turn_forecast(), {}, "game over")


# --- 336: what the forecast reads ---

## Tally (building, ⟳ +1 food per farm in the discard) and Scribe (creates a Farm in the discard).
const TALLY := {"id": "tally", "name": "Tally", "type": "building",
	"effects": [{"op": "gain_per_tag", "resource": "food", "amount": 1, "tag": "farm", "zone": "discard",
		"trigger": "upkeep"}]}
const SCRIBE := {"id": "scribe", "name": "Scribe", "type": "action",
	"effects": [{"op": "create", "card": "farm", "zone": "discard"}]}
## The zones every turn forecast reads: the board and the always-on zones.
const BOARD_ZONES: Array[String] = ["tableau", "researched", "civilization", "government", "active_events"]


## The first effect of card id in a make_engine game with extra cards.
func effect_of(id: String, extra := []) -> Effect:
	return make_engine({"farm": 10}, {}, 1, extra).card_db[id].effects[0]


func test_a_gain_per_tag_reads_the_zone_it_counts() -> void:
	var tally := effect_of("tally", [TALLY])
	eq(tally.reads_zones(), ["discard"] as Array[String], "Tally counts farms in the discard")


func test_a_create_into_the_discard_reads_no_zone() -> void:
	var scribe := effect_of("scribe", [SCRIBE])
	eq(scribe.reads_zones(), [] as Array[String], "Scribe puts a card there; it counts none")


func test_every_other_op_reads_no_zone() -> void:
	for op in EffectRegistry.OPS:
		if op == "gain_per_tag":
			continue
		var effect: Effect = EffectRegistry.OPS[op].new()
		eq(effect.reads_zones(), [] as Array[String], op)


func test_the_forecast_reads_the_board_plus_the_zones_effects_count() -> void:
	var plain := make_engine({"farm": 10}, {}, 1, [SCRIBE])
	eq(plain.forecast_zones(), BOARD_ZONES, "Scribe's discard isn't read")
	var counting := make_engine({"farm": 10}, {}, 1, [TALLY])
	eq(counting.forecast_zones(), BOARD_ZONES + (["discard"] as Array[String]), "Tally's discard is")
