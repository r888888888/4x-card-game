extends "res://tests/lib/anarchy_case.gd"
## A new government's honeymoon (backlog 399): with config unrest.honeymoon_turns, the government chosen when Anarchy
## ends is protected for that many turns (honeymoon_left()): unrest can't rise (every source: effects, upkeep, a new
## era) though it can fall, no revolution can be declared, and Anarchy doesn't fall; the forecasts know it. None at a
## new game's start, none without the config. The sidebar shows the turns left. Fixtures: tests/lib/anarchy_case.gd
## (Chiefs, limit 5; Kings, limit 7; Feast, −2 unrest; Dawn, adds era 2; anarchy_turns 3), plus Rouse (an action, +2
## unrest), Riot (a building, ⟳ +1 unrest) and Mob (a building, unrest limit −10).

const HONEYMOON := {"honeymoon_turns": 3}
const ROUSE := {"id": "rouse", "name": "Rouse", "type": "action", "effects": [{"op": "gain", "resource": "unrest", "amount": 2}]}
const RIOT := {"id": "riot", "name": "Riot", "type": "building",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const MOB := {"id": "mob", "name": "Mob", "type": "building", "modifiers": {"unrest_limit": -10}}
const NO_REVOLT := "The people back the new government (%s)."


## An anarchy game (block merged into the unrest block) that fell into Anarchy at turn 2's start and chose Kings when
## it ended, at the end of turn 4: turn 5 has started under Kings.
func chosen_engine(block := HONEYMOON) -> GameEngine:
	var e := anarchy_engine(block, {}, [ROUSE, RIOT, MOB])
	choose_kings_after_anarchy(e)
	return e


## Plays e (a new anarchy game) into Anarchy at turn 2's start and chooses Kings when it ends, at the end of turn 4.
func choose_kings_after_anarchy(e: GameEngine) -> void:
	e.resources["unrest"] = 5
	e.end_turn()
	e.create_card("kings", "discard", null)  # into the government deck (154)
	outlast_anarchy(e)
	check(e.choose_government(uid_of(e.zone("governments"), "kings")), "choose Kings")
	eq([e.turn, ruling(e), e.resources.unrest], [5, "kings", 0], "precondition: turn 5 under Kings, unrest 0")


## Plays a new Rouse (+2 unrest) from the hand.
func rouse(e: GameEngine) -> void:
	var uid := put_in_hand(e, "rouse")
	check(e.play_card(uid), "Rouse: %s" % e.play_error(uid))


# --- AC1: unrest can't rise ---

func test_the_honeymoon_counts_down_its_turns() -> void:
	var e := chosen_engine()
	for row in [[5, 3], [6, 2], [7, 1], [8, 0]]:
		eq([e.turn, e.honeymoon_left()], row, "turn %d" % row[0])
		e.end_turn()


func test_during_the_honeymoon_no_source_raises_unrest() -> void:
	var e := chosen_engine()
	build_on(e, home_uid(e), ["riot"])
	for turn in [5, 6, 7]:
		eq(e.turn, turn, "turn")
		rouse(e)
		eq(e.resources.unrest, 0, "turn %d: Rouse's +2 doesn't land" % turn)
		e.gain("unrest", 2, e.zone("tableau").cards[0])
		eq(e.resources.unrest, 0, "turn %d: a gain effect doesn't land" % turn)
		if turn < 7:
			e.end_turn()
			eq(e.resources.unrest, 0, "turn %d's upkeep: Riot's +1 doesn't land" % (turn + 1))
	check(e.play_card(put_in_hand(e, "dawn")), "Dawn: a new era")
	eq(e.resources.unrest, 0, "a new era stirs no unrest")


func test_after_the_honeymoon_unrest_rises_as_usual() -> void:
	var e := chosen_engine()
	build_on(e, home_uid(e), ["riot"])
	for i in 3:
		e.end_turn()
	eq([e.turn, e.honeymoon_left()], [8, 0], "turn 8: over")
	eq(e.resources.unrest, 1, "turn 8's upkeep: Riot's +1")
	rouse(e)
	eq(e.resources.unrest, 3, "Rouse's +2")
	check(e.play_card(put_in_hand(e, "dawn")), "Dawn: a new era")
	eq(e.resources.unrest, 6, "era 2 stirs 3")


# --- AC2: lowering still works ---

func test_during_the_honeymoon_unrest_still_falls_to_0() -> void:
	var e := chosen_engine()
	e.resources["unrest"] = 2
	var feast := put_in_hand(e, "feast")
	check(e.play_card(feast), "Feast: %s" % e.play_error(feast))
	eq(e.resources.unrest, 0, "2 − 2")
	check(e.play_card(put_in_hand(e, "feast")), "a second Feast")
	eq(e.resources.unrest, 0, "never below 0")


# --- AC3: no revolution ---

func test_no_revolution_during_the_honeymoon() -> void:
	var e := chosen_engine()
	for n in ["3 turns", "2 turns", "1 turn"]:
		eq(e.revolt_error(), NO_REVOLT % n, "turn %d" % e.turn)
		var before := e.state.copy()
		check(not e.revolt(), "revolt refuses")
		eq(state_diff(e.state, before), "", "and changes nothing")
		check(not e.legal_actions().has(["revolt"]), "no revolt in legal_actions")
		e.end_turn()
	eq(e.turn, 8, "turn 8")
	eq(e.revolt_error(), "", "a revolution can be declared")
	check(e.legal_actions().has(["revolt"]), "revolt is legal")


# --- AC4: no fall ---

func test_anarchy_doesnt_fall_during_the_honeymoon() -> void:
	var e := chosen_engine()
	build_on(e, home_uid(e), ["mob"])
	eq(e.unrest_limit(), 0, "precondition: Kings' 7 − 10, never below 0")
	check(e.at_unrest_limit(), "precondition: at the limit")
	e.end_turn()
	eq([e.turn, e.anarchy()], [6, -1], "no fall at turn 6's start")
	e.end_turn()
	eq([e.turn, e.anarchy()], [7, -1], "nor at turn 7's")
	e.end_turn()
	check(e.anarchy() != -1, "at turn 8's start, the honeymoon over, it falls")


# --- AC5: the forecasts know it ---

func test_the_forecasts_count_no_unrest_during_the_honeymoon() -> void:
	var e := chosen_engine()
	build_on(e, home_uid(e), ["riot"])
	for turn in [5, 6]:
		e.resources["unrest"] = 6  # one below Kings' 7
		eq(e.upkeep_forecast().get("unrest", 0), 0, "turn %d: upkeep_forecast" % turn)
		eq(e.turn_forecast().get("unrest", 0), 0, "turn %d: turn_forecast" % turn)
		check(not e.anarchy_ahead(), "turn %d: no Anarchy ahead" % turn)
		e.end_turn()
	eq(e.turn, 7, "the honeymoon's last turn")
	e.resources["unrest"] = 6
	eq(e.upkeep_forecast().get("unrest", 0), 1, "turn 7: turn 8's upkeep brings Riot's +1")
	eq(e.turn_forecast().get("unrest", 0), 1, "turn 7: turn_forecast too")
	check(e.anarchy_ahead(), "turn 7: Anarchy ahead")


# --- AC6: only after Anarchy, and off without config ---

func test_a_new_game_has_no_honeymoon() -> void:
	var e := anarchy_engine(HONEYMOON, {}, [ROUSE])
	eq(e.honeymoon_left(), 0, "turn 1")
	rouse(e)
	eq(e.resources.unrest, 2, "unrest rises")


func test_without_honeymoon_turns_there_is_none() -> void:
	var e := chosen_engine({})
	eq(e.honeymoon_left(), 0, "turn 5, no honeymoon_turns")
	rouse(e)
	eq(e.resources.unrest, 2, "unrest rises")
	eq(e.revolt_error(), "", "a revolution can be declared")


func test_honeymoon_turns_loads_and_is_validated() -> void:
	check_loads([
		["honeymoon_turns 3", anarchy_raw(HONEYMOON), {"config.unrest.honeymoon_turns": 3}],
		["absent", anarchy_raw(), {}],
	], raw_config_load)
	check_cases([
		["0", anarchy_raw({"honeymoon_turns": 0}), ["config.json: unrest.honeymoon_turns", ">= 1"]],
		["a fraction", anarchy_raw({"honeymoon_turns": 2.5}), ["config.json: unrest.honeymoon_turns"]],
		["a string", anarchy_raw({"honeymoon_turns": "3"}), ["config.json: unrest.honeymoon_turns"]],
	], raw_config_load)


func test_a_copy_keeps_the_honeymoon() -> void:
	var e := chosen_engine()
	var f := e.fork()
	eq(f.honeymoon_left(), 3, "the fork's honeymoon")
	f.end_turn()
	eq([f.honeymoon_left(), e.honeymoon_left()], [2, 3], "each counts on its own")


# --- UI: the sidebar shows it ---

func test_the_sidebar_shows_the_honeymoon_turns_left() -> void:
	await with_main(anarchy_engine(HONEYMOON, {}, [ROUSE, RIOT, MOB]), func(main: Node):
		var e := Game.engine
		choose_kings_after_anarchy(e)  # with_main started a new game
		var line := MainProbe.honeymoon_line(main)
		await wait_frames()
		check(line != null and line.is_visible_in_tree(), "shown under the government")
		if line == null:
			return
		eq(line.text, "Honeymoon: 3 turns", "the turns left")
		e.end_turn()
		e.end_turn()
		await wait_frames()
		eq(line.text, "Honeymoon: 1 turn", "one left")
		e.end_turn()
		await wait_frames()
		check(not line.is_visible_in_tree(), "hidden on turn 8"))
