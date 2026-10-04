extends "res://tests/lib/test_case.gd"
## Moving and disbanding units (backlog 163): move_unit changes only a unit's station, once a turn, for an action;
## disband, free, sends a unit to the discard and frees its worker on its home. move_unit_error and disband_error.

## Levy: a unit costing 1 food, strength 2, ⟳ −1 food.
const MOVE_UNITS := [
	{"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2,
	 "effects": [{"op": "lose", "resource": "food", "amount": 1, "trigger": "upkeep"}]},
]


## A game on TEST_CARDS + MOVE_UNITS with Levies in the deck, 50 food, Homeland at 2 pop, Hills settled at 1 pop and
## Grassland on the frontier, and a Levy recruited on Homeland. gov is the starting government from TEST_GOVS (Band:
## 2 actions a turn, 1 left after the Levy), none (unlimited actions) when "". null (after a failed check) when the
## data doesn't load.
func move_engine(gov := "") -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(fixture_load([], [TEST_GOVS, MOVE_UNITS]), errors, warnings)
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"hills": 1, "grassland": 1}, "starting": starting}
	var config := DataLoader.parse_config(raw_config({"levy": 10}, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	if not errors.is_empty():
		return null
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	e.resources.food = 50
	settle(e, ["hills"])
	to_frontier(e, ["grassland"])
	e.zone("tableau").find(hills_of(e)).pop = 1
	var levy := uid_of(e.zone("hand"), "levy")
	check(e.play_card(levy, home_uid(e)), "Levy recruited on Homeland: %s" % e.play_error(levy, home_uid(e)))
	return e


## Hills' uid in e's tableau.
func hills_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "hills")


## The recruited Levy's uid in e's tableau.
func levy_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "levy")


## Asserts that each case [label, error query, action] on e gives the expected error and that the action then returns
## false and changes nothing. Each case is [label, Callable returning the error, Callable doing the action, expected].
func check_refusals(e: GameEngine, cases: Array) -> void:
	for c in cases:
		var label: String = c[0]
		eq(c[1].call(), c[3], label)
		var before := e.state.copy()
		eq(c[2].call(), false, "%s: refused" % label)
		eq(state_diff(e.state, before), "", "%s: changes nothing; changed" % label)


# --- AC1: moving ---

func test_moving_a_unit_changes_its_station_for_an_action() -> void:
	var e: GameEngine = move_engine("band")
	if e == null:
		return
	var home := home_uid(e)
	var hills := hills_of(e)
	var levy := levy_of(e)
	var workers := [e.free_workers(home), e.free_workers(hills)]
	var defense := [e.defense(home), e.defense(hills)]
	var resources := e.resources.duplicate()
	eq(e.actions_left(), 1, "Band: 1 action left after the Levy")
	eq(e.move_unit_error(levy, hills), "", "the move is legal")
	check(e.move_unit(levy, hills), "Levy moved to Hills")
	eq(e.unit_station(levy), hills, "stationed on Hills")
	eq(e.zone("tableau").find(levy).territory_uid, home, "still homed on Homeland")
	eq([e.free_workers(home), e.free_workers(hills)], workers, "free workers unchanged")
	eq(e.defense(hills) - defense[1], 2, "Hills' defence +2")
	eq(defense[0] - e.defense(home), 2, "Homeland's defence −2")
	eq(e.actions_left(), 0, "one action used")
	eq(e.resources, resources, "no resource spent")


# --- AC2: once a turn ---

func test_a_unit_moves_once_a_turn() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var home := home_uid(e)
	var hills := hills_of(e)
	var levy := levy_of(e)
	check(e.move_unit(levy, hills), "first move")
	check_refusals(e, [["second move this turn", func(): return e.move_unit_error(levy, home),
		func(): return e.move_unit(levy, home), "Levy has already moved this turn."]])
	eq(e.unit_station(levy), hills, "still on Hills")
	e.end_turn()
	eq(e.move_unit_error(levy, home), "", "next turn it can move")
	check(e.move_unit(levy, home), "moved back")
	eq(e.unit_station(levy), home, "back on Homeland")


func test_moves_this_turn_survive_a_fork() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var levy := levy_of(e)
	check(e.move_unit(levy, hills_of(e)), "moved")
	var f: GameEngine = e.fork()
	eq(f.move_unit_error(levy, home_uid(e)), "Levy has already moved this turn.", "the fork knows it moved")


# --- AC3: move errors ---

func test_moving_needs_an_action_left() -> void:
	var e: GameEngine = move_engine("band")
	if e == null:
		return
	var levy := levy_of(e)
	var home := home_uid(e)
	check(e.move_unit(levy, hills_of(e)), "the last action moves the Levy")
	check_refusals(e, [
		["no action left", func(): return e.move_unit_error(levy, home), func(): return e.move_unit(levy, home),
			"No actions left this turn."],
		["no action left comes before the unit checks", func(): return e.move_unit_error(-1, -1),
			func(): return e.move_unit(-1, -1), "No actions left this turn."],
	])
	e.end_turn()
	eq(e.move_unit_error(levy, home), "", "a new turn's actions")


func test_move_unit_error_reasons() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var home := home_uid(e)
	var hills := hills_of(e)
	var levy := levy_of(e)
	var capital := uid_of(e.zone("tableau"), "capital")
	var in_hand := uid_of(e.zone("hand"), "levy")
	var frontier := uid_of(e.zone("frontier"), "grassland")
	var move := func(label: String, uid: int, to: int, expected: String) -> Array:
		return [label, func(): return e.move_unit_error(uid, to), func(): return e.move_unit(uid, to), expected]
	var not_unit := "That isn't a unit in your realm."
	var not_settled := "Units can only move to a settled territory."
	check_refusals(e, [
		move.call("an unknown uid", -1, hills, not_unit),
		move.call("a Levy in the hand", in_hand, hills, not_unit),
		move.call("the Capital", capital, hills, not_unit),
		move.call("a frontier territory", levy, frontier, not_settled),
		move.call("a city as the target", levy, capital, not_settled),
		move.call("no target", levy, -1, not_settled),
		move.call("its own station", levy, home, "Levy is already on %s." % e.zone("tableau").find(home).shown_name()),
	])
	set_home_pop(e, 0)
	check(e.is_idle(levy), "the Levy is idle")
	eq(e.move_unit_error(levy, hills), "", "an idle unit can move")
	set_home_pop(e, 2)
	e.state.pending = {"kind": GameEngine.PENDING_DISCARD, "count": 1}
	var owed := e.end_turn_error()
	check(owed != "", "a discard is owed")
	check_refusals(e, [move.call("a decision owed", levy, hills, owed)])
	e.state.pending = {}
	e.state.is_over = true
	check_refusals(e, [move.call("game over", levy, hills, "The game is over.")])


# --- AC4: disbanding ---

func test_disbanding_a_unit_frees_its_worker_and_its_strength() -> void:
	var e: GameEngine = move_engine("band")
	if e == null:
		return
	var home := home_uid(e)
	var hills := hills_of(e)
	var levy := levy_of(e)
	check(e.move_unit(levy, hills), "moved to Hills with the last action")
	var workers: int = e.free_workers(home)
	var hills_workers: int = e.free_workers(hills)
	var defense: int = e.defense(hills)
	var actions := e.state.actions_used
	eq(e.disband_error(levy), "", "the Levy can be disbanded with no action left")
	check(e.disband(levy), "disbanded")
	check(e.zone("tableau").find(levy) == null, "out of the tableau")
	check(e.zone("discard").find(levy) != null, "in the discard")
	eq(e.unit_station(levy), -1, "no station")
	eq(e.free_workers(home) - workers, 1, "a worker freed on its home")
	eq(e.free_workers(hills), hills_workers, "none on its station")
	eq(defense - e.defense(hills), 2, "its strength gone from Hills")
	eq(e.state.actions_used, actions, "no action used")


func test_disband_error_reasons() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var levy := levy_of(e)
	var disband := func(label: String, uid: int, expected: String) -> Array:
		return [label, func(): return e.disband_error(uid), func(): return e.disband(uid), expected]
	var not_unit := "That isn't a unit in your realm."
	check_refusals(e, [
		disband.call("an unknown uid", -1, not_unit),
		disband.call("a Levy in the hand", uid_of(e.zone("hand"), "levy"), not_unit),
		disband.call("the Capital", uid_of(e.zone("tableau"), "capital"), not_unit),
		disband.call("a territory", home_uid(e), not_unit),
	])
	e.state.pending = {"kind": GameEngine.PENDING_DISCARD, "count": 1}
	var owed := e.end_turn_error()
	check(owed != "", "a discard is owed")
	check_refusals(e, [disband.call("a decision owed", levy, owed)])
	e.state.pending = {}
	e.state.is_over = true
	check_refusals(e, [disband.call("game over", levy, "The game is over.")])


# --- AC6 (added at green, for the Manual check): what the details modal and the unit's face show ---

func test_move_targets_list_where_a_unit_can_go_now() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var levy := levy_of(e)
	var hills := hills_of(e)
	eq(e.move_targets(levy), [hills] as Array[int], "Hills: not its station, not the frontier")
	eq(e.move_targets(home_uid(e)), [] as Array[int], "not a unit")
	check(e.move_unit(levy, hills), "moved")
	eq(e.move_targets(levy), [] as Array[int], "moved this turn")


func test_unit_move_block_says_why_a_unit_cant_move_anywhere() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var levy := levy_of(e)
	eq(e.unit_move_block(levy), "", "it can move")
	eq(e.unit_move_block(home_uid(e)), "That isn't a unit in your realm.", "not a unit")
	check(e.move_unit(levy, hills_of(e)), "moved")
	eq(e.unit_move_block(levy), "Levy has already moved this turn.", "moved this turn")
	var band: GameEngine = move_engine("band")
	if band == null:
		return
	band.state.actions_used = 2
	eq(band.unit_move_block(levy_of(band)), "No actions left this turn.", "no action left")
	var alone: GameEngine = move_engine()
	alone.zone("tableau").remove(alone.zone("tableau").find(hills_of(alone)))
	eq(alone.unit_move_block(levy_of(alone)), "Levy has nowhere else to go.", "no other settled territory")


func test_unit_origin_names_the_home_of_a_unit_stationed_away() -> void:
	var e: GameEngine = move_engine()
	if e == null:
		return
	var levy := levy_of(e)
	eq(e.unit_origin(levy), "", "at home")
	check(e.move_unit(levy, hills_of(e)), "moved")
	eq(e.unit_origin(levy), "from %s" % e.territory_name(home_uid(e)), "away from home")
	eq(e.unit_origin(home_uid(e)), "", "not a unit")
