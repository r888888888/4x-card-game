extends "res://tests/lib/test_case.gd"
## Buildings occupy territory slots: free_slots, building targets, placement (backlog 004).
## The Capital starts on Grassland (2 slots); hands are all Farms (cost 2).


## A game with the Capital on Grassland, a hand of Farms and plenty of food. settled: extra
## territories put straight into the tableau; frontier: territories put in the frontier.
func slots_engine(settled: Array[String] = [], frontier: Array[String] = []) -> GameEngine:
	var counts := {}
	for id in settled + frontier:
		counts[id] = counts.get(id, 0) + 1
	var e := make_engine({"farm": 10}, {
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "grassland"},
		"territory_deck": counts,
	})
	settle(e, settled)
	to_frontier(e, frontier)
	e.resources.food = 20
	return e


## Plays two Farms onto Grassland (the only territory at that point).
func fill_grassland(e: GameEngine) -> void:
	for i in 2:
		check(e.play_card(first_in_hand(e)), "fill Grassland: Farm %d" % (i + 1))


# --- AC1: one territory with room ---

func test_building_goes_on_only_territory_with_room() -> void:
	var e := slots_engine()
	var grassland := uid_of(e.zone("tableau"), "grassland")
	eq(e.free_slots(grassland), 2, "free slots before (the Capital uses none)")
	var farm := first_in_hand(e)
	check(e.play_card(farm), "play Farm")
	var placed := e.zone("tableau").find(farm)
	check(placed != null, "Farm in tableau")
	if placed != null:
		check(e.territory_of(placed) != null and e.territory_of(placed).uid == grassland, "Farm on Grassland")
	eq(e.free_slots(grassland), 1, "free slots after")


# --- AC2: no room anywhere ---

func test_building_with_no_free_slot_fails() -> void:
	var e := slots_engine()
	fill_grassland(e)
	var farm := first_in_hand(e)
	var food: int = e.resources.food
	eq(e.play_error(farm), "No territory with a free slot.", "play_error")
	check(not e.play_card(farm), "play fails")
	check(e.zone("hand").find(farm) != null, "Farm stays in hand")
	eq(e.resources.food, food, "food unchanged")


# --- AC3: several territories with room ---

func test_building_needs_a_choice_with_several_territories() -> void:
	var e := slots_engine(["hills"])
	var farm := first_in_hand(e)
	eq(e.play_error(farm), "Choose a territory for Farm.", "play_error")
	check(not e.play_card(farm), "play without target fails")


func test_building_placed_on_chosen_territory() -> void:
	var e := slots_engine(["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	var farm := first_in_hand(e)
	check(e.play_card(farm, hills), "play Farm on Hills")
	var placed := e.zone("tableau").find(farm)
	check(placed != null and placed.territory_uid == hills, "Farm on Hills")
	eq(e.free_slots(hills), 2, "Hills 3 - 1")


# --- AC4: full territories aren't targets ---

func test_full_territory_is_not_a_target() -> void:
	var e := slots_engine(["hills"])
	var grassland := uid_of(e.zone("tableau"), "grassland")
	var hills := uid_of(e.zone("tableau"), "hills")
	for i in 2:
		check(e.play_card(first_in_hand(e), grassland), "fill Grassland: Farm %d" % (i + 1))
	var farm := first_in_hand(e)
	eq(e.valid_targets(farm), [hills] as Array[int], "valid_targets")
	eq(e.play_error(farm, grassland), "That target isn't valid.", "full Grassland")
	check(e.play_card(farm), "play with no target")
	var placed := e.zone("tableau").find(farm)
	check(placed != null and placed.territory_uid == hills, "auto-placed on Hills")


# --- AC5: frontier territories aren't targets ---

func test_frontier_territory_is_not_a_target() -> void:
	var e := slots_engine([], ["hills"])
	var farm := first_in_hand(e)
	var grassland := uid_of(e.zone("tableau"), "grassland")
	var hills := uid_of(e.zone("frontier"), "hills")
	eq(e.valid_targets(farm), [grassland] as Array[int], "valid_targets")
	eq(e.play_error(farm, hills), "That target isn't valid.", "frontier Hills")


# --- Design note: the outcome's target ---

func test_building_outcome_target_is_its_territory() -> void:
	var e := slots_engine()
	var grassland := uid_of(e.zone("tableau"), "grassland")
	var outcomes := []
	e.card_played.connect(func(o): outcomes.append(o))
	e.play_card(first_in_hand(e))
	eq(outcomes.size(), 1, "one outcome")
	if outcomes.size() == 1:
		eq(outcomes[0].get("target"), grassland, "target")


# --- 030: a city with slots adds them to its territory (the Capital gives +4) ---

## Like slots_engine, but the starting city is a Citadel (+4 slots) on Grassland (2 slots).
func citadel_engine(settled: Array[String] = []) -> GameEngine:
	var counts := {}
	for id in settled:
		counts[id] = counts.get(id, 0) + 1
	var e := make_engine({"farm": 10}, {
		"starting": {"resources": {"food": 2}, "tableau": ["citadel"], "territory": "grassland"},
		"territory_deck": counts,
	})
	for c in e.zone("territory_deck").take_all():
		e.zone("tableau").add(c)
	e.resources.food = 30
	return e


## Plays n Farms onto territory, drawing more when the hand runs out.
func farms_onto(e: GameEngine, territory: int, n: int) -> void:
	for i in n:
		if e.zone("hand").is_empty():
			e.draw(5)
		check(e.play_card(first_in_hand(e), territory), "Farm %d placed" % (i + 1))


func test_city_slots_add_to_its_territory() -> void:
	var e := citadel_engine()
	var grassland := uid_of(e.zone("tableau"), "grassland")
	eq(e.total_slots(grassland), 6, "2 + 4")
	eq(e.free_slots(grassland), 6, "free before any building")


func test_city_slots_are_usable_up_to_the_total() -> void:
	var e := citadel_engine()
	var grassland := uid_of(e.zone("tableau"), "grassland")
	farms_onto(e, grassland, 5)
	eq(e.free_slots(grassland), 1, "6 - 5")
	farms_onto(e, grassland, 1)
	eq(e.free_slots(grassland), 0, "full at 6")
	if e.zone("hand").is_empty():
		e.draw(5)
	eq(e.play_error(first_in_hand(e)), "No territory with a free slot.", "seventh Farm refused")


func test_city_slots_apply_only_to_its_own_territory() -> void:
	var e := citadel_engine(["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	var city: CardInstance = e.zone("tableau").cards.filter(func(c): return c.def.id == "citadel")[0]
	eq(city.territory_uid, uid_of(e.zone("tableau"), "grassland"), "Citadel sits on Grassland")
	eq(e.total_slots(hills), 3, "Hills keeps its own 3")
	eq(e.total_slots(uid_of(e.zone("tableau"), "grassland")), 6, "Grassland gets the bonus")


func test_city_slots_do_not_change_housing() -> void:
	var e := citadel_engine()
	var grassland := uid_of(e.zone("tableau"), "grassland")
	eq(e.housing(grassland), 4, "Grassland housing stays slots 2 + 2")


func test_total_slots_of_a_non_territory_is_0() -> void:
	var e := citadel_engine()
	eq(e.total_slots(uid_of(e.zone("tableau"), "citadel")), 0, "a city isn't a territory")
