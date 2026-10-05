extends "res://tests/lib/raid_case.gd"
## Recruiting units from the build menu (296): build() on a unit entry homes and stations a new copy on a territory
## with a free worker (no slot, no terrain); a recruited unit that is disbanded or lost to a pillage leaves play instead
## of going to the discard; an unlocked unit entry "can now be recruited". Raid fixtures from tests/lib/raid_case.gd
## (Levy: strength 2, 1 food; Raiders: strength 3 at mountains). Band rules (2 actions).

## Opens the Levy entry.
const DRILL := {"id": "drill", "name": "Drill", "type": "tech", "cost": {"insight": 1},
	"effects": [{"op": "unlock", "card": "levy"}]}


## A game on the raid fixtures with Farms in the deck, build_menu menu, Drill to learn, Band ruling, population on
## (Homeland at 3 pop), Hills settled at 1 pop, 10 food and 5 insight, and ids_on_top on the event deck. Still turn 1.
func recruit_engine(menu := {"levy": {}}, ids_on_top := ["omen"]) -> GameEngine:
	var r := raid_load(TEST_GOVS + [DRILL])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var o := {"resources": RESOURCES, "keywords": keywords(), "build_menu": menu, "research_deck": {"drill": 1},
		"event_deck": {"raiders": 1, "horde": 1, "omen": 3},
		"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"territory_deck": {"hills": 1, "grassland": 1, "river": 1},
		"starting": {"resources": {}, "tableau": ["capital"], "territory": "homeland", "government": "band"}}
	var config := DataLoader.parse_config(raw_config({"farm": 10}, o), RESOURCES, r.cards, "config.json", errors,
		warnings)
	check(errors.is_empty() and r.errors.is_empty(), "test data should load: %s %s" % [r.errors, errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	raid_setup(e, ids_on_top)
	e.resources.food = 10
	e.resources.insight = 5
	return e


## The Levy on e's tableau with the highest uid (the newest), or -1.
func newest_levy(e: GameEngine) -> int:
	var out := -1
	for c in e.zone("tableau").cards:
		if c.def.id == "levy":
			out = maxi(out, c.uid)
	return out


## Whether uid is in no zone.
func gone(e: GameEngine, uid: int) -> bool:
	return GameEngine.ZONES.all(func(z): return e.zone(z).find(uid) == null)


# --- AC1: recruiting ---

func test_recruiting_a_unit_homes_and_stations_it_using_a_worker_but_no_slot() -> void:
	var e := recruit_engine()
	var hills := hills_of(e)
	e.zone("tableau").find(hills).pop = 4
	build_on(e, hills, ["stockade", "stockade", "stockade"])
	eq(e.free_slots(hills), 0, "precondition: no free slot on Hills")
	eq(e.free_workers(hills), 1, "precondition: one free worker on Hills")
	e.state.actions_used = 1  # 1 of Band's 2 actions left
	e.resources.food = 1
	var defense := e.defense(hills)
	var outcomes: Array[Dictionary] = []
	e.card_played.connect(func(o): outcomes.append(o))
	check(e.build("levy", hills), "recruit a Levy on Hills: %s" % e.build_error("levy", hills))
	var levy := newest_levy(e)
	eq(e.zone("tableau").find(levy).territory_uid, hills, "homed on Hills")
	eq(e.unit_station(levy), hills, "stationed on Hills")
	eq(e.free_workers(hills), 0, "it uses Hills' worker")
	eq(e.free_slots(hills), 0, "and no slot")
	eq(e.resources.food, 0, "1 - 1 food")
	eq(e.actions_left(), 0, "no actions left")
	eq(outcomes.size(), 1, "card_played")
	eq(e.defense(hills), defense + 2, "its strength defends Hills")


# --- AC2: where a unit can go ---

func test_a_unit_entry_goes_on_any_territory_with_a_free_worker_and_nowhere_else() -> void:
	var e := recruit_engine()
	var home := home_uid(e)
	var hills := hills_of(e)
	eq(sorted(e.build_targets("levy")), sorted([home, hills]), "every settled territory with a free worker")
	build_on(e, hills, ["farm"])  # Hills' one worker
	eq(e.build_targets("levy"), [home] as Array[int], "Hills has no free worker left")
	build_on(e, home, ["farm", "farm", "farm"])  # the home's three
	eq(e.build_error("levy"), "No territory with a free worker.", "build_error")
	var before := card_ids(e.zone("tableau"))
	check(not e.build("levy"), "build refuses")
	eq(card_ids(e.zone("tableau")), before, "nothing changes")


# --- AC3: a recruited unit leaves play ---

func test_a_recruited_unit_disbanded_leaves_play_and_can_be_recruited_again() -> void:
	var e := recruit_engine()
	var hills := hills_of(e)
	check(e.build("levy", hills), "recruit a Levy on Hills")
	var levy := newest_levy(e)
	var workers: int = e.free_workers(hills)
	check(e.disband(levy), "disband it")
	check(gone(e, levy), "it is in no zone (zone: '%s')" % e.zone_of(levy))
	eq(e.free_workers(hills), workers + 1, "its worker is free again")
	eq(e.build_error("levy", hills), "", "a Levy can be recruited again")


func test_a_recruited_unit_lost_to_a_pillage_leaves_play() -> void:
	var e := recruit_engine({"levy": {}}, ["raiders"])
	var outcomes := record_raids(e)
	e.end_turn()  # Raiders drawn, aimed at Hills (mountain)
	e.resources.food = 10
	check(e.build("levy", hills_of(e)), "recruit a Levy on Hills: %s" % e.build_error("levy", hills_of(e)))
	var levy := newest_levy(e)
	e.end_turn()
	e.end_turn()  # strikes two event phases after it was drawn (257)
	if outcomes.size() != 1:
		check(false, "one raid resolved: %s" % [outcomes])
		return
	eq([outcomes[0].repelled, outcomes[0].units_lost], [false, [levy]], "pillaged; the Levy lost")
	check(gone(e, levy), "it is in no zone (zone: '%s')" % e.zone_of(levy))


# --- AC5: unlocking a unit entry ---

func test_unlocking_a_unit_entry_says_it_can_now_be_recruited() -> void:
	var e := recruit_engine({"levy": {"locked": true}})
	eq(e.build_error("levy", home_uid(e)), "Levy isn't unlocked yet.", "locked")
	eq((e.card_db["drill"] as CardDef).rules_tooltip(e.card_db), "Levy can now be recruited.", "card text")
	var recorded := record_messages(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "drill")), "learn Drill")
	check_noticed(recorded, "Levy can now be recruited.", GameEngine.NOTICE_INFO)
	eq(e.build_error("levy", home_uid(e)), "", "the Levy can be recruited")


# --- Backlog 297: what Disband does, for the details' wording ---

func test_disbands_to_discard_tells_a_dealt_unit_from_a_recruited_one() -> void:
	var e := recruit_engine({"levy": {}})
	check(e.build("levy", home_uid(e)), "recruit a Levy")
	eq(e.call("disbands_to_discard", newest_levy(e)), false, "a recruited unit leaves play")
	var dealt := raid_engine()
	var levy := uid_of(dealt.zone("hand"), "levy")
	check(dealt.play_card(levy, home_uid(dealt)), "play a Levy from the hand")
	eq(dealt.call("disbands_to_discard", levy), true, "a dealt unit goes to the discard")
