extends "res://tests/lib/test_case.gd"
## Workers gate buildings (backlog 012): a building needs a free worker (pop) on its territory, and a
## territory with more buildings than pop leaves the newest ones idle at upkeep.


## Population on with Homeland pop start (vp_per_pop 0 so score is printed VP + effect VP), plenty of food.
func workers_engine(start: int, deck := {"farm": 10}, food_upkeep := 0, overrides := {}) -> GameEngine:
	var e := make_engine(deck, {"population": {"start": start, "food_upkeep": food_upkeep, "vp_per_pop": 0}}.merged(overrides))
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
	eq(e.play_error(farm), "No free worker.", "play_error (347)")
	var hand_size := e.zone("hand").size()
	check(not e.play_card(farm, home), "play refused")
	eq(e.zone("hand").size(), hand_size, "Farm still in hand")
	eq(e.resources.food, 48, "food: 50 - 2 for the first Farm only")


# --- AC2: a free worker allows placement ---

# --- 347: why no free worker ---

const WHY := "Each building and unit needs a worker: one pop on its territory."


func test_no_free_worker_on_the_target_is_short_with_a_detail() -> void:
	var e := workers_engine(2, {"farm": 10}, 0, {"build_menu": {"farm": {}}})
	place(e, 2)
	var home := home_uid(e)
	check(e.free_slots(home) > 0, "a free slot left")
	var farm := first_in_hand(e)
	eq(e.play_error(farm, home), "No free worker.", "played on Homeland")
	eq(e.build_error("farm", home), "No free worker.", "built on Homeland")
	eq(e.play_error_detail(farm, home), WHY + " Homeland's pop is all at work.", "the play detail")
	eq(e.build_error_detail("farm", home), WHY + " Homeland's pop is all at work.", "the build detail")


func test_the_detail_names_the_city_name() -> void:
	var e := workers_engine(2)
	place(e, 2)
	var home := home_uid(e)
	check(e.rename_territory(home, "Memphis"), "renamed")
	eq(e.play_error_detail(first_in_hand(e), home), WHY + " Memphis's pop is all at work.", "the city name")


func test_with_no_territory_free_the_detail_says_every_pop_is_at_work() -> void:
	var e := workers_engine(1)
	place(e, 1)
	var farm := first_in_hand(e)
	eq(e.play_error(farm), "No free worker.", "no target given")
	eq(e.play_error_detail(farm), WHY + " Every territory's pop is at work.", "the detail")


func test_other_refusals_and_legal_plays_have_no_detail() -> void:
	var e := workers_engine(7, {"farm": 10}, 0, {"build_menu": {"farm": {}}})
	var home := home_uid(e)
	var farm := first_in_hand(e)
	eq([e.play_error(farm, home), e.play_error_detail(farm, home), e.build_error_detail("farm", home)], ["", "", ""],
		"legal: no detail")
	var fill: Array = []
	fill.resize(e.free_slots(home))
	fill.fill("farm")
	build_on(e, home, fill)
	eq(e.free_slots(home), 0, "no free slot")
	check(e.free_workers(home) > 0, "workers to spare")
	eq(e.play_error(farm, home), "That target isn't valid.", "no free slot: unchanged")
	eq([e.play_error_detail(farm, home), e.build_error_detail("farm", home)], ["", ""], "no detail")


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



# --- 123: a territory's status and tooltip ---

func test_territory_status_reports_free_slots_pop_housing_and_free_workers() -> void:
	var e: GameEngine = workers_engine(2)
	var home := home_uid(e)
	eq(e.territory_status(home), {"free_slots": e.free_slots(home), "total_slots": e.total_slots(home), "pop": 2,
		"housing": e.housing(home), "free_workers": 2}, "Homeland with pop 2 and nothing built")
	var slots_before: int = e.free_slots(home)
	place(e, 1)
	var after: Dictionary = e.territory_status(home)
	eq([after.get("free_slots"), after.get("free_workers")], [slots_before - 1, 1], "a Farm takes a slot and a worker")
	eq(e.territory_status(uid_of(e.zone("tableau"), "capital")), {}, "a city: {}")
	eq(e.territory_status(first_in_hand(e)), {}, "a hand card: {}")


func test_territory_tooltip_spells_out_slots_pop_and_workers() -> void:
	var e: GameEngine = workers_engine(2)
	var home := home_uid(e)
	eq(e.territory_tooltip(home), "Building slots: %d free of %d\nPop 2, housing %d\nFree workers: 2 (each building or unit needs one)\nDefence 0: units 0, walls 0, cities 0, terrain 0" % [
		e.free_slots(home), e.total_slots(home), e.housing(home)], "Homeland: no keywords")
	var with_river: GameEngine = make_engine({"farm": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"river": 1}})
	settle(with_river, ["river"])
	var river := uid_of(with_river.zone("tableau"), "river")
	check(str(with_river.territory_tooltip(river)).ends_with("\nKeywords: Fresh Water, Flood Plain"),
		"keywords last: %s" % with_river.territory_tooltip(river))


func test_territory_tooltip_without_population_names_slots_and_defence() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var home := home_uid(e)
	eq(e.territory_tooltip(home), "Building slots: %d free of %d\nDefence 0: units 0, walls 0, cities 0, terrain 0" % [
		e.free_slots(home), e.total_slots(home)], "slots and defence (161)")
