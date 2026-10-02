extends "res://tests/lib/tech_case.gd"
## Engine queries for rules the UI used to work out itself (backlog 049): playable_error, end_turn_error,
## supply_error, upcoming_era_unlocks and territory_groups.


## A game on Grassland (2 slots) with plenty of food and a hand of Farms. With hills, Hills is settled too.
func grassland_engine(hills: bool) -> GameEngine:
	var e: GameEngine = make_engine({"farm": 10}, {
		"starting": {"resources": {"food": 20}, "tableau": ["capital"], "territory": "grassland"},
		"territory_deck": {"hills": 1},
	})
	if hills:
		settle(e, ["hills"])
	return e


## A game with an explore choice open (Hills and Grassland revealed).
func choice_engine() -> GameEngine:
	var e: GameEngine = make_engine({"farm": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	check(e.pending().get("kind") == GameEngine.PENDING_EXPLORE, "a choice is open")
	return e


## A game on turn 1 with 1 card to discard (hand 8, limit 7).
func discard_engine() -> GameEngine:
	var e: GameEngine = make_engine({"scout": 10})
	for i in 3:
		check(e.play_card(first_in_hand(e)), "play Scout %d" % i)
	e.end_turn()
	eq(e.discard_needed(), 1, "1 to discard")
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
		["discard owed", discard_engine(), "Discard down to 7 cards first."],
		["game over", over_engine(), "The game is over."],
	]
	for row in cases:
		var e: GameEngine = row[1]
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
	eq(over_engine().supply_error(), "The game is over.", "game over")


# --- AC4: upcoming_era_unlocks ---

func test_upcoming_era_unlocks_drops_eras_already_reached() -> void:
	var e: GameEngine = make_engine({"farm": 10}, {"era_unlocks": {"2": {"pop": 8}, "3": {"wealth": 30}}})
	eq(e.upcoming_era_unlocks(), {2: {"pop": 8}, 3: {"wealth": 30}}, "at the start")
	e.add_era(2)
	eq(e.upcoming_era_unlocks(), {3: {"wealth": 30}}, "after era 2")


# --- AC5: territory_groups ---

## territory_groups as [[territory uid, [card uids]], ...] with plain arrays, for comparing.
func groups(e: GameEngine) -> Array:
	return e.territory_groups().map(func(g): return [g.territory, Array(g.cards)])


func test_territory_groups_put_each_territory_first_with_its_cards() -> void:
	var e: GameEngine = make_engine({"farm": 10}, {"territory_deck": {"river": 1}})
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
	var e: GameEngine = make_engine({"farm": 10})
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
func summary_engine(pop: bool) -> GameEngine:
	var o := {"territory_deck": {"hills": 1}}
	if pop:
		o["population"] = {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	var e: GameEngine = make_engine({"farm": 10}, o)
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


# --- Backlog 094 AC1: needs_target_choice ---

func test_needs_target_choice_with_two_territories_to_pick_from() -> void:
	var e := grassland_engine(true)
	check(e.needs_target_choice(first_in_hand(e)), "a Farm with Grassland and Hills free")


func test_needs_target_choice_is_false_with_one_target_no_food_or_no_target() -> void:
	var e := grassland_engine(false)
	check(not e.needs_target_choice(first_in_hand(e)), "only Grassland")
	e = grassland_engine(true)
	e.resources.food = 0
	check(not e.needs_target_choice(first_in_hand(e)), "no food to pay")
	check(not e.needs_target_choice(put_in_hand(e, "scout")), "a Scout needs no target")


# --- Backlog 094 AC2: tech_eras ---

const OPTICS := {"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}


## The tech_case fixture with Optics (era 2) waiting in future_techs; era_unlocks as given.
func era_unlocks_engine(era_unlocks: Dictionary) -> GameEngine:
	return tech_engine(["pottery", "writing"], {"farm": 10},
		{"research_deck": {"pottery": 1, "writing": 1, "optics": 1}, "era_unlocks": era_unlocks}, [OPTICS])


## tech_tree() entries of era n, in order.
func tree_of_era(e: GameEngine, n: int) -> Array:
	return e.tech_tree().filter(func(t): return t.era == n)


func test_tech_eras_list_each_era_with_its_status_and_techs() -> void:
	var e := era_unlocks_engine({"2": {"pop": 8}})
	eq(e.tech_eras(), [
		{"era": 1, "name": e.era_name(1), "reached": true, "unlocks": {}, "techs": tree_of_era(e, 1)},
		{"era": 2, "name": e.era_name(2), "reached": false, "unlocks": {"pop": 8}, "techs": tree_of_era(e, 2)},
	], "era 1 reached, era 2 unlocks at 8 pop")
	eq(tree_of_era(e, 2).map(func(t): return t.id), ["optics"], "era 2 holds Optics")


func test_tech_eras_unlocks_are_empty_when_reached_or_only_a_tech_adds_the_era() -> void:
	var e := era_unlocks_engine({})
	eq(e.tech_eras().map(func(x): return [x.era, x.reached, x.unlocks]), [[1, true, {}], [2, false, {}]], "no era_unlocks")
	e = era_unlocks_engine({"2": {"pop": 8}})
	e.add_era(2)
	eq(e.tech_eras().map(func(x): return [x.era, x.reached, x.unlocks]), [[1, true, {}], [2, true, {}]], "era 2 reached")


func test_tech_eras_is_empty_without_a_research_deck() -> void:
	eq(make_engine({"farm": 10}).tech_eras(), [] as Array[Dictionary], "no techs")


# --- Backlog 094 AC4: open_supply_piles ---

func test_open_supply_piles_are_the_unlocked_ones_in_config_order() -> void:
	var e := make_engine({"farm": 10}, {
		"starting": {"resources": {"food": 20, "wealth": 20}, "tableau": ["capital"], "territory": "homeland"},
		"supply": {"scout": {"price": 1, "count": 2}, "temple": {"price": 1, "count": 1, "locked": true},
			"settler": {"price": 1, "count": 1}},
	})
	eq(e.open_supply_piles(), ["scout", "settler"] as Array[String], "locked Temple left out")
	check(e.buy("settler"), "buy the last Settler")
	eq(e.open_supply_piles(), ["scout", "settler"] as Array[String], "a sold-out pile still counts")
	e.unlock_supply("temple", null)
	eq(e.open_supply_piles(), ["scout", "temple", "settler"] as Array[String], "an unlocked pile joins in config order")


func test_supply_screen_does_not_open_when_every_pile_is_locked() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 5},
		{"supply": {"scout": {"price": 1, "count": 1, "locked": true}}}), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var opened: bool = main.supply.is_open()
	close_main(main)
	Game.engine = real
	check(not opened, "the supply screen stays closed")


# --- 175 AC2: the hand limit and whether there is research ---

func test_hand_limit_and_research_on_are_engine_queries() -> void:
	var limited := make_engine({"farm": 10}, {"hand_limit": 6})
	eq(limited.hand_limit(), 6, "config hand_limit")
	eq(limited.research_on(), false, "no research deck")
	var researching := tech_engine(["pottery"])
	eq(researching.research_on(), true, "a research deck")


# --- 176 AC3: the zone a card is in ---

func test_zone_of_names_the_zone_holding_a_card() -> void:
	var e := make_engine({"farm": 10})
	var farm := first_in_hand(e)
	eq(e.zone_of(farm), "hand", "a hand card")
	eq(e.zone_of(home_uid(e)), "tableau", "the home territory")
	var gone := put_in(e, "farm", "trashed")
	eq(e.zone_of(gone), "trashed", "a trashed card")
	eq(e.zone_of(9999), "", "an unknown uid")


# --- 180: play_shortfall ---

## A game with food and wealth on hand and a Guildhall (2 food, 2 wealth) in hand; returns [engine, its uid].
func shortfall_game(food: int, wealth: int) -> Array:
	var e := make_engine({"farm": 10})
	var uid := put_in_hand(e, "guildhall")
	e.resources[GameEngine.FOOD] = food
	e.resources[GameEngine.WEALTH] = wealth
	return [e, uid]


func test_play_shortfall_lists_the_resources_the_player_is_short_of_in_cost_order() -> void:
	for case in [[1, 5, ["food"]], [0, 0, ["food", "wealth"]], [2, 2, []]]:
		var g := shortfall_game(case[0], case[1])
		var e: Object = g[0]
		eq(e.play_shortfall(g[1]), case[2], "%d food, %d wealth" % [case[0], case[1]])


func test_play_shortfall_is_empty_for_a_card_not_in_the_hand() -> void:
	var g := shortfall_game(0, 0)
	var e: Object = g[0]
	eq(e.play_shortfall(9999), [], "no such hand card")
