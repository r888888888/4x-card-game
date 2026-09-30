extends "res://tests/lib/tech_case.gd"
## Engine queries for rules the UI used to work out itself (backlog 049): playable_error, end_turn_error,
## supply_error, upcoming_era_unlocks and territory_groups. Engines are held as Object (see tech_case).


## A game on Grassland (2 slots) with plenty of food and a hand of Farms. With hills, Hills is settled too.
func grassland_engine(hills: bool) -> Object:
	var e: Object = make_engine({"farm": 10}, {
		"starting": {"resources": {"food": 20}, "tableau": ["capital"], "territory": "grassland"},
		"territory_deck": {"hills": 1},
	})
	if hills:
		settle(e, ["hills"])
	return e


## A game with an explore choice open (Hills and Grassland revealed).
func choice_engine() -> Object:
	var e: Object = make_engine({"farm": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	check(not e.pending_choice.is_empty(), "a choice is open")
	return e


## A game with pottery and writing revealed.
func research_engine() -> Object:
	var e: Object = tech_engine(["pottery", "writing"])
	check(play_research(e), "research should open")
	return e


## A game on turn 1 with 1 card to discard (hand 8, limit 7).
func discard_engine() -> Object:
	var e: Object = make_engine({"scout": 10})
	for i in 3:
		check(e.play_card(first_in_hand(e)), "play Scout %d" % i)
	e.end_turn()
	eq(e.discard_needed(), 1, "1 to discard")
	return e


## A finished game (turn limit 1).
func over_engine() -> Object:
	var e: Object = make_engine({"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	return e


# --- AC1: playable_error ---

func test_playable_error_ignores_the_choice_of_territory() -> void:
	var e := grassland_engine(true)
	var farm := first_in_hand(e)
	eq(e.play_error(farm), "Choose a territory for Farm.", "play_error without a target")
	eq(e.playable_error(farm), "", "playable_error")


func test_playable_error_reports_a_missing_cost() -> void:
	var e := grassland_engine(true)
	e.resources.food = 1
	eq(e.playable_error(first_in_hand(e)), "Farm needs 2 food (you have 1).", "playable_error")


func test_playable_error_reports_no_free_slot() -> void:
	var e := grassland_engine(false)
	for i in 2:
		check(e.play_card(first_in_hand(e)), "play Farm %d" % i)
	eq(e.playable_error(first_in_hand(e)), "No territory with a free slot.", "playable_error")


# --- AC2: end_turn_error ---

func test_end_turn_error_is_empty_normally() -> void:
	eq(make_engine({"farm": 10}).end_turn_error(), "", "end_turn_error")


func test_end_turn_error_names_what_blocks_it_and_end_turn_does_nothing() -> void:
	var cases := [
		["explore choice", choice_engine(), "Choose a territory first."],
		["research", research_engine(), "Buy a tech or decline first."],
		["discard owed", discard_engine(), "Discard down to 7 cards first."],
		["game over", over_engine(), "The game is over."],
	]
	for row in cases:
		var e: Object = row[1]
		eq(e.end_turn_error(), row[2], "%s: end_turn_error" % row[0])
		var turn: int = e.turn
		var hand := card_ids(e.zone("hand"))
		e.end_turn()
		eq(e.turn, turn, "%s: turn unchanged" % row[0])
		eq(card_ids(e.zone("hand")), hand, "%s: hand unchanged" % row[0])


# --- AC3: supply_error ---

func test_supply_error_allows_browsing_normally_and_while_discarding() -> void:
	eq(make_engine({"farm": 10}).supply_error(), "", "normally")
	eq(discard_engine().supply_error(), "", "while a discard is owed")


func test_supply_error_blocks_during_choices_and_after_the_game() -> void:
	eq(choice_engine().supply_error(), "Choose a territory first.", "explore choice")
	eq(research_engine().supply_error(), "Buy a tech or decline first.", "research")
	eq(over_engine().supply_error(), "The game is over.", "game over")


# --- AC4: upcoming_era_unlocks ---

func test_upcoming_era_unlocks_drops_eras_already_reached() -> void:
	var e: Object = make_engine({"farm": 10}, {"era_unlocks": {"2": {"pop": 8}, "3": {"wealth": 30}}})
	eq(e.upcoming_era_unlocks(), {2: {"pop": 8}, 3: {"wealth": 30}}, "at the start")
	e.add_era(2)
	eq(e.upcoming_era_unlocks(), {3: {"wealth": 30}}, "after era 2")


# --- AC5: territory_groups ---

## territory_groups as [[territory uid, [card uids]], ...] with plain arrays, for comparing.
func groups(e: Object) -> Array:
	return e.territory_groups().map(func(g): return [g.territory, Array(g.cards)])


func test_territory_groups_put_each_territory_first_with_its_cards() -> void:
	var e: Object = make_engine({"farm": 10}, {"territory_deck": {"river": 1}})
	e.resources.food = 10
	check(e.play_card(first_in_hand(e)), "play Farm on Homeland")
	to_frontier(e, ["river"])
	check(e.play_card(put_in_hand(e, "pioneer")), "Pioneer settles River")
	var t: Zone = e.zone("tableau")
	var home := uid_of(t, "homeland")
	var river := uid_of(t, "river")
	eq(groups(e), [
		[home, [home, uid_of(t, "capital"), uid_of(t, "farm")]],
		[river, [river, uid_of(t, "city")]],
	], "groups")


func test_territory_groups_put_cards_with_no_territory_last() -> void:
	var e: Object = make_engine({"farm": 10})
	e.resources.food = 10
	check(e.play_card(put_in_hand(e, "settler")), "Settler creates a City with no territory")
	var t: Zone = e.zone("tableau")
	var home := uid_of(t, "homeland")
	eq(groups(e), [
		[home, [home, uid_of(t, "capital")]],
		[-1, [uid_of(t, "city")]],
	], "groups")


# --- territory_summary (backlog 087) ---

## A game on Homeland with the Capital and 3 Farms built on it; population on with 2 pop when pop is true.
func summary_engine(pop: bool) -> Object:
	var o := {"territory_deck": {"hills": 1}}
	if pop:
		o["population"] = {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	var e: Object = make_engine({"farm": 10}, o)
	build_on(e, home_uid(e), ["farm", "farm", "farm"])
	return e


func test_territory_summary_counts_cities_buildings_and_idle() -> void:
	var e := summary_engine(true)
	eq(e.territory_summary(home_uid(e)), {"cities": 1, "buildings": 3, "idle": 1}, "Capital, 3 Farms, 2 pop: 1 idle")
	var off := summary_engine(false)
	eq(off.territory_summary(home_uid(off)), {"cities": 1, "buildings": 3, "idle": 0}, "population off: none idle")


func test_territory_summary_is_empty_for_anything_but_a_settled_territory() -> void:
	var e := summary_engine(true)
	to_frontier(e, ["hills"])
	var farm := uid_of(e.zone("tableau"), "farm")
	eq(e.territory_summary(farm), {}, "a building")
	eq(e.territory_summary(uid_of(e.zone("frontier"), "hills")), {}, "a frontier territory")
	eq(e.territory_summary(9999), {}, "an unknown uid")
