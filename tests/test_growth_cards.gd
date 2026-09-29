extends "res://tests/lib/test_case.gd"
## Growth cards (backlog 013): the grow op adds pop "here" (the card's territory) or in "each" settled
## territory, capped by housing and free of food.


## Population on (no food upkeep, no pop VP), Homeland pop start, 50 food. settled: extra territory ids moved
## straight to the tableau with pop 1 each.
func cards_engine(start: int, deck: Dictionary, settled: Array[String] = [], population := true) -> GameEngine:
	var counts := {}
	for id in settled:
		counts[id] = counts.get(id, 0) + 1
	var o := {"territory_deck": counts}
	if population:
		o["population"] = {"start": start, "food_upkeep": 0, "vp_per_pop": 0}
	var e := make_engine(deck, o)
	settle(e, settled)
	for c in e.zone("tableau").cards:
		if c.def.type == "territory" and c.uid != home_uid(e):
			c.pop = 1 if population else 0
	e.resources.food = 50
	return e


# --- AC2: "here" on a building grows its own territory at upkeep ---

func test_granary_grows_its_territory_at_upkeep() -> void:
	var e := cards_engine(2, {"granary": 10}, ["grassland"])
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e), home), "Granary on Homeland")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.pop(home), 3, "Homeland pop 2 + 1")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 1, "other territory unchanged")
	eq(e.resources.food, food + 2, "no food spent (only the Capital's +2)")


# --- AC3: "each" on an action grows every settled territory ---

func test_festival_grows_each_settled_territory() -> void:
	var e := cards_engine(2, {"festival": 10}, ["grassland"])
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 3, "Homeland 2 + 1")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 2, "Grassland 1 + 1")
	eq(e.resources.food, 50, "no food spent")


# --- AC4: capped by housing; "here" with no territory does nothing ---

func test_card_growth_stops_at_housing() -> void:
	var e := cards_engine(7, {"festival": 10}, ["grassland"])  # Homeland housing 7
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 7, "Homeland stays at housing")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 2, "Grassland still grows")


func test_granary_at_housing_adds_nothing() -> void:
	var e := cards_engine(7, {"granary": 10})
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e), home), "Granary on Homeland")
	e.end_turn()
	eq(e.pop(home), 7, "Homeland stays at housing 7")


func test_grow_here_without_a_territory_does_nothing() -> void:
	var e := cards_engine(2, {"rally": 10})
	check(e.play_card(first_in_hand(e)), "play Rally (an action: no territory)")
	eq(e.total_pop(), 2, "total pop unchanged")


# --- AC5: population off ---

func test_grow_does_nothing_without_population() -> void:
	var e := cards_engine(2, {"festival": 10}, ["grassland"], false)
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home_uid(e)), 0, "Homeland pop")
	eq(e.pop(uid_of(e.zone("tableau"), "grassland")), 0, "Grassland pop")
	eq(e.total_pop(), 0, "total pop")
