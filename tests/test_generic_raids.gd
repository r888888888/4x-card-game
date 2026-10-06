extends "res://tests/lib/raid_case.gd"
## The generic bot meets raids (314, superseding 168) with no raid rule: turn_forecast (309) counts the raid that
## strikes at the next turn's start, so moving a unit onto a short target values more. Raid games from
## tests/lib/raid_case.gd: Raiders (strength 3) aimed at Hills; a Town on Hills gives defence 1, a Levy 2 more.


## raid_engine's game (1 VP per pop) at turn 3, Raiders striking at the next turn's start, a Town built on Hills and a
## Levy recruited on territory levy_on during turn 2.
func raid_turn_3(levy_on: String) -> GameEngine:
	var e: GameEngine = raid_engine(["raiders", "omen", "omen"], {"raiders": 1, "horde": 1, "omen": 3},
		{"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 1}})
	if e == null:
		return null
	e.end_turn()
	build_on(e, hills_of(e), ["town"])
	recruit(e, hills_of(e) if levy_on == "hills" else home_uid(e))
	e.end_turn()
	check(e.raid_turns_left(active_uid(e, "raiders")) == 1, "Raiders strike at the next turn's start")
	return e


func levy_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "levy")


func test_the_bot_moves_a_unit_onto_a_short_target() -> void:
	var e := raid_turn_3("home")
	if e == null:
		return
	var raid: Dictionary = e.raid_forecast()[0]
	check(raid.defense < raid.strength and raid.defense + e.unit_strength(levy_of(e)) >= raid.strength,
		"Hills is short, and the Levy would make up the shortfall: %s" % [raid])
	GenericBot.take_turn(e, "generic")
	eq(e.unit_station(levy_of(e)), hills_of(e), "the Levy moved onto Hills")


func test_the_bot_keeps_a_unit_on_a_raided_target_it_holds() -> void:
	var e := raid_turn_3("hills")
	if e == null:
		return
	var raid: Dictionary = e.raid_forecast()[0]
	check(raid.defense >= raid.strength, "Hills holds with the Levy: %s" % [raid])
	GenericBot.take_turn(e, "generic")
	eq(e.unit_station(levy_of(e)), hills_of(e), "the Levy stays on Hills")
