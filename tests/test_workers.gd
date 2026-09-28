extends "res://tests/lib/test_case.gd"
## Workers gate buildings (backlog 012): a building needs a free worker (pop) on its territory, and a
## territory with more buildings than pop leaves the newest ones idle at upkeep.


## Population on with Homeland pop start (vp_per_pop 0 so score is printed VP + effect VP), plenty of food.
func workers_engine(start: int, deck := {"farm": 10}, food_upkeep := 0) -> GameEngine:
	var e := make_engine(deck, {"population": {"start": start, "food_upkeep": food_upkeep, "vp_per_pop": 0}})
	e.resources.food = 50
	return e


## Plays n hand cards onto Homeland, highest uid first, so placement order is the reverse of uid order.
## Returns the played uids in placement order.
func place(e: GameEngine, n: int) -> Array[int]:
	var uids: Array[int] = []
	for c in e.zone("hand").cards:
		uids.append(c.uid)
	uids.sort()
	uids.reverse()
	var placed: Array[int] = []
	for i in n:
		check(e.play_card(uids[i], home_uid(e)), "place building %d" % (i + 1))
		placed.append(uids[i])
	return placed


# --- AC1: no free worker, no placement ---

func test_building_needs_a_free_worker() -> void:
	var e := workers_engine(1)
	place(e, 1)
	var home := home_uid(e)
	eq(e.free_slots(home), 4, "Homeland still has 4 free slots")
	eq(e.free_workers(home), 0, "pop 1 - 1 building")
	var farm := first_in_hand(e)
	eq(e.valid_targets(farm), [] as Array[int], "no valid target")
	eq(e.play_error(farm), "No territory with a free worker.", "play_error")
	var hand_size := e.zone("hand").size()
	check(not e.play_card(farm, home), "play refused")
	eq(e.zone("hand").size(), hand_size, "Farm still in hand")
	eq(e.resources.food, 48, "food: 50 - 2 for the first Farm only")


# --- AC2: a free worker allows placement ---

func test_building_placed_with_a_free_worker() -> void:
	var e := workers_engine(2)
	place(e, 1)
	var home := home_uid(e)
	eq(e.free_workers(home), 1, "pop 2 - 1 building")
	var farm := first_in_hand(e)
	eq(e.valid_targets(farm), [home] as Array[int], "Homeland is a valid target")
	check(e.play_card(farm, home), "second Farm placed")
	eq(e.free_workers(home), 0, "pop 2 - 2 buildings")


# --- AC3: extra buildings go idle, newest first ---

func test_newest_buildings_go_idle_when_pop_drops() -> void:
	var e := workers_engine(3, {"temple": 10})  # Temple: 1 VP printed, upkeep +1 VP
	var placed := place(e, 3)
	e.zone("tableau").find(home_uid(e)).pop = 2
	check(not e.is_idle(placed[0]) and not e.is_idle(placed[1]), "two placed first are working")
	check(e.is_idle(placed[2]), "placed last is idle (even though it has the lowest uid)")
	var bonus := e.bonus_score
	e.end_turn()
	eq(e.bonus_score - bonus, 2, "only 2 Temples score at upkeep")
	check(e.zone("tableau").find(placed[2]) != null, "idle Temple stays on the tableau")
	eq(e.score(), 2 + 3 + e.bonus_score, "Capital 2 + 3 printed Temple VP (idle included) + effect VP")


func test_cities_never_idle() -> void:
	var e := workers_engine(1)
	e.zone("tableau").find(home_uid(e)).pop = 0
	var capital := -1
	for c in e.zone("tableau").cards:
		if c.def.id == "capital":
			capital = c.uid
	check(not e.is_idle(capital), "Capital uses no worker")
	e.end_turn()
	eq(e.resources.food, 52, "Capital still produces 2 at pop 0")


# --- AC4: idle buildings work again when pop grows back ---

func test_idle_buildings_work_again_when_pop_returns() -> void:
	var e := workers_engine(3, {"temple": 10})
	var placed := place(e, 3)
	var home := e.zone("tableau").find(home_uid(e))
	home.pop = 2
	e.end_turn()
	home.pop = 3
	check(not e.is_idle(placed[2]), "no longer idle")
	var bonus := e.bonus_score
	e.end_turn()
	eq(e.bonus_score - bonus, 3, "all 3 Temples score")


# --- AC5: idleness is decided before pop eats ---

func test_starvation_during_upkeep_does_not_idle_a_building_that_turn() -> void:
	var e := workers_engine(3, {"temple": 10}, 1)
	var placed := place(e, 3)
	e.resources.food = 0
	var bonus := e.bonus_score
	e.end_turn()  # Capital +2, pop 3 eats 3: 1 starves after the Temples have scored
	eq(e.pop(home_uid(e)), 2, "1 pop starved")
	eq(e.bonus_score - bonus, 3, "all 3 Temples scored this upkeep")
	check(e.is_idle(placed[2]), "newest is idle from now on")


# --- AC6: population off ---

func test_without_population_workers_are_ignored() -> void:
	var e := make_engine({"temple": 10})
	e.resources.food = 50
	var placed := place(e, 3)
	for uid in placed:
		check(not e.is_idle(uid), "never idle")
	var bonus := e.bonus_score
	e.end_turn()
	eq(e.bonus_score - bonus, 3, "all 3 Temples score")
