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
	var pool := e.zone("territory_deck").take_all()
	for pair in [[settled, "tableau"], [frontier, "frontier"]]:
		for id in pair[0]:
			for c in pool:
				if c.def.id == id:
					pool.erase(c)
					e.zone(pair[1]).add(c)
					break
	e.resources.food = 20
	return e


func uid_of(zone: Zone, id: String) -> int:
	for c in zone.cards:
		if c.def.id == id:
			return c.uid
	return -1


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
