extends "res://tests/lib/test_case.gd"
## Abandoning buildings (412): abandon(uid) takes a finished building or upgrade out of play for no action and no
## refund, with every upgrade built on it. A build-menu building is gone (it can be built again); one dealt from a deck
## goes to the discard. Wonders, once entries and a building whose housing its territory's pop needs can't be
## abandoned. Sites (286) are in test_wonder_sites.gd. Fixtures: Hut (nothing), Plough on a Farm and Deep Plough on
## the Plough, Insula (housing 2), Obelisk (a once entry), Colossus (a project), Levy (a unit).

const HUT := {"id": "hut", "name": "Hut", "type": "building", "cost": {"food": 1}}
const PLOUGH := {"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "vp": 1,
	"upgrade_of": "farm", "housing": 1, "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
const DEEP_PLOUGH := {"id": "deep_plough", "name": "Deep Plough", "type": "building", "cost": {"food": 1}, "vp": 2,
	"upgrade_of": "plough", "modifiers": {"hand_size": 1}}
const INSULA := {"id": "insula", "name": "Insula", "type": "building", "cost": {"food": 1}, "housing": 2}
const OBELISK := {"id": "obelisk", "name": "Obelisk", "type": "building", "cost": {"food": 1}, "vp": 3}
const COLOSSUS := {"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 4}, "vp": 5,
	"tags": ["wonder"], "project": true}
const LEVY := {"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 1}
const FIXTURES := [HUT, PLOUGH, DEEP_PLOUGH, INSULA, OBELISK, COLOSSUS, LEVY]
const MENU := {"farm": {}, "hut": {}, "plough": {}, "deep_plough": {}, "insula": {}, "obelisk": {"once": true},
	"colossus": {}, "levy": {}}
const NOT_IN_PLAY := "That isn't a building in play."


## A game with population on (pop on Homeland, no food upkeep, no pop VP), build_menu MENU, 20 food, 20 wealth and
## gov ruling (Court: 3 actions; "" for none: unlimited actions).
func abandon_engine(pop := 2, gov := "court") -> GameEngine:
	var starting := {"resources": {"food": 20, "wealth": 20}, "tableau": ["capital"], "territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"build_menu": MENU, "population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}, "starting": starting}
	var e := make_engine({"scout": 10}, o, 1, FIXTURES + TEST_GOVS)
	set_home_pop(e, pop)
	return e


## Builds id from the menu on target (a territory, or a base for an upgrade), failing the test if it refuses: its uid.
func built(e: GameEngine, id: String, target: int) -> int:
	check(e.build(id, target), "build %s on %d: %s" % [id, target, e.build_error(id, target)])
	return e.zone("tableau").cards.back().uid


## The zone card uid is in, or "".
func zone_of(e: GameEngine, uid: int) -> String:
	for z in GameEngine.ZONES:
		if e.zone(z).find(uid) != null:
			return z
	return ""


## What the Farm tree adds to e's Homeland and score: [score, hand size, housing, free slots, free workers].
func figures(e: GameEngine) -> Array:
	var home := home_uid(e)
	return [e.score(), e.hand_size(), e.housing(home), e.free_slots(home), e.free_workers(home)]


## What a refused abandon must leave unchanged: [tableau ids, hand ids, discard ids, resources, actions left].
func snapshot(e: GameEngine) -> Array:
	return [card_ids(e.zone("tableau")), card_ids(e.zone("hand")), card_ids(e.zone("discard")), e.resources.duplicate(),
		e.actions_left()]


## Checks abandon(uid) refuses with message and changes nothing.
func assert_refused(e: GameEngine, uid: int, message: String, what: String) -> void:
	eq(e.abandon_error(uid), message, "%s: abandon_error" % what)
	var before := snapshot(e)
	check(not e.abandon(uid), "%s: abandon refuses" % what)
	eq(snapshot(e), before, "%s: nothing changes" % what)


# --- AC1: the main path ---

func test_abandoning_a_building_frees_its_slot_and_worker_for_nothing() -> void:
	var e := abandon_engine()
	var home := home_uid(e)
	var hut := built(e, "hut", home)
	var slots: int = e.free_slots(home)
	var workers: int = e.free_workers(home)
	var actions: int = e.actions_left()
	var held: Dictionary = e.resources.duplicate()
	var messages := record_messages(e)
	var changes := [0]
	e.changed.connect(func(): changes[0] += 1)
	check(e.abandon(hut), "abandon the Hut: %s" % e.abandon_error(hut))
	eq(zone_of(e, hut), "", "the Hut is in no zone")
	eq([e.free_slots(home), e.free_workers(home)], [slots + 1, workers + 1], "[free slots, free workers]")
	eq([e.actions_left(), e.resources], [actions, held], "[actions left, resources]: no action, no refund")
	has_msg(messages, "Abandoned Hut.")
	eq(changes[0], 1, "changed fires once")
	eq(e.build_error("hut", home), "", "the Hut can be built again")


# --- AC2: a dealt building goes to the discard ---

func test_abandoning_a_building_played_from_the_hand_discards_it() -> void:
	var e := abandon_engine()
	var temple := put_in_hand(e, "temple")
	check(e.play_card(temple, home_uid(e)), "play the Temple: %s" % e.play_error(temple, home_uid(e)))
	check(e.abandon(temple), "abandon the Temple: %s" % e.abandon_error(temple))
	eq(zone_of(e, temple), "discard", "the Temple (not on the build menu) goes to the discard")


# --- AC3: its upgrades go with it ---

func test_abandoning_a_base_takes_its_upgrade_tree_with_it() -> void:
	var e := abandon_engine()
	var before := figures(e)
	var farm := built(e, "farm", home_uid(e))
	var plough := built(e, "plough", farm)
	var deep := built(e, "deep_plough", plough)
	check(figures(e) != before, "precondition: the tree changes the figures: %s" % [figures(e)])
	check(e.abandon(farm), "abandon the Farm: %s" % e.abandon_error(farm))
	eq([zone_of(e, farm), zone_of(e, plough), zone_of(e, deep)], ["", "", ""], "all three leave play")
	eq(figures(e), before, "[score, hand size, housing, free slots, free workers] as with no Farm")


func test_abandoning_an_upgrade_takes_the_upgrades_on_it_and_leaves_its_base() -> void:
	var e := abandon_engine()
	var farm := built(e, "farm", home_uid(e))
	var plough := built(e, "plough", farm)
	var deep := built(e, "deep_plough", plough)
	check(e.abandon(plough), "abandon the Plough: %s" % e.abandon_error(plough))
	eq([zone_of(e, farm), zone_of(e, plough), zone_of(e, deep)], ["tableau", "", ""], "[Farm, Plough, Deep Plough]")
	eq([e.is_idle(farm), e.upgrades_on(farm)], [false, [] as Array[int]], "[the Farm idle, its upgrades]")


# --- AC4: idle buildings wake ---

func test_abandoning_a_building_wakes_an_idle_one_behind_it() -> void:
	var e := abandon_engine(2)
	var home := home_uid(e)
	build_on(e, home, ["hut", "farm", "farm"])
	var cards := e.zone("tableau").cards
	var hut: int = cards[-3].uid
	var last: int = cards[-1].uid
	check(e.is_idle(last), "precondition: the last Farm is idle (2 pop, 3 buildings)")
	var food: int = e.upkeep_forecast().get(GameEngine.FOOD, 0)
	check(e.abandon(hut), "abandon the Hut: %s" % e.abandon_error(hut))
	check(not e.is_idle(last), "the last Farm works now")
	eq(e.upkeep_forecast().get(GameEngine.FOOD, 0), food + 1, "the forecast counts its ⟳ +1 food")


# --- AC5: what can and can't be abandoned ---

func test_a_wonder_or_a_once_entry_cant_be_abandoned() -> void:
	var e := abandon_engine(4)
	var home := home_uid(e)
	var obelisk := built(e, "obelisk", home)
	assert_refused(e, obelisk, "Obelisk can't be abandoned.", "a once entry")
	var colossus := built(e, "colossus", home)
	e.zone("tableau").find(colossus).progress = e.site_cost(colossus)
	check(not e.is_site(colossus), "precondition: the Colossus is complete")
	assert_refused(e, colossus, "Colossus can't be abandoned.", "a completed wonder")


func test_a_building_whose_housing_the_pop_needs_cant_be_abandoned() -> void:
	var e := abandon_engine()
	var home := home_uid(e)
	var insula := built(e, "insula", home)
	var housing: int = e.housing(home)
	set_home_pop(e, housing)
	assert_refused(e, insula, "Homeland's %d pop need Insula's housing." % housing, "housing in use")
	set_home_pop(e, housing - 2)
	check(e.abandon(insula), "with 2 pop fewer it can go: %s" % e.abandon_error(insula))


func test_only_a_building_in_play_can_be_abandoned() -> void:
	var e := abandon_engine()
	var home := home_uid(e)
	var levy := built(e, "levy", home)
	var held := put_in_hand(e, "hut")
	var capital := uid_of(e.zone("tableau"), "capital")
	for case in [[levy, "a unit"], [capital, "a city"], [home, "a territory"], [held, "a building in hand"],
			[999, "an unknown uid"]]:
		assert_refused(e, case[0], NOT_IN_PLAY, case[1])


func test_an_idle_or_fallen_back_building_can_be_abandoned() -> void:
	var e := abandon_engine(1)
	var home := home_uid(e)
	build_on(e, home, ["hut", "farm"])
	var farm: int = e.zone("tableau").cards[-1].uid
	var plough := built(e, "plough", farm)
	check(e.is_idle(farm) and e.fallen_back_reason(plough) != "", "precondition: the Farm idle, the Plough fallen back")
	check(e.abandon(plough), "abandon the fallen-back Plough: %s" % e.abandon_error(plough))
	check(e.abandon(farm), "abandon the idle Farm: %s" % e.abandon_error(farm))


func test_abandoning_a_building_is_refused_while_a_decision_is_owed_or_the_game_is_over() -> void:
	var e := abandon_engine()
	var hut := built(e, "hut", home_uid(e))
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}
	assert_refused(e, hut, "Choose a government first.", "a decision owed")
	e.state.pending = {}
	e.is_over = true
	assert_refused(e, hut, "The game is over.", "the game over")


# --- AC7: the bot sees it ---

func test_legal_actions_list_abandoning_each_building_that_can_go() -> void:
	var e := abandon_engine(4, "")
	var home := home_uid(e)
	var farm := built(e, "farm", home)
	var plough := built(e, "plough", farm)
	built(e, "obelisk", home)
	var site := built(e, "colossus", home)
	var insula := built(e, "insula", home)
	set_home_pop(e, e.housing(home) - 1)
	check(e.abandon_error(insula) != "", "precondition: the Insula's housing is needed (not the Plough's 1)")
	var want := [["abandon", farm], ["abandon", plough], ["abandon", site]]
	eq(e.legal_actions().filter(func(a): return a[0] == "abandon"), want, "Farm, Plough and the site; not the Obelisk or Insula")
	eq(e.fork().legal_actions().filter(func(a): return a[0] == "abandon"), want, "a fork lists the same")


# --- The confirmation's text (UI support) ---

func test_abandon_line_says_where_the_card_goes_and_what_goes_with_it() -> void:
	var e := abandon_engine(4, "")
	var home := home_uid(e)
	var hut := built(e, "hut", home)
	var farm := built(e, "farm", home)
	var plough := built(e, "plough", farm)
	built(e, "deep_plough", plough)
	var temple := put_in_hand(e, "temple")
	e.play_card(temple, home)
	eq(e.abandon_line(hut), "Hut leaves play. Nothing is refunded.", "a build-menu building")
	eq(e.abandon_line(farm), "Farm leaves play, with its Plough and Deep Plough. Nothing is refunded.", "with upgrades")
	eq(e.abandon_line(temple), "Temple goes to your discard. Nothing is refunded.", "a dealt building")
	var site := built(e, "colossus", home)
	eq(e.abandon_line(site), "Colossus goes to your discard. Nothing has been paid in yet.", "a site")
	e.zone("tableau").find(site).progress = 3
	eq(e.abandon_line(site), "Colossus goes to your discard. The 3 wealth paid in is lost.", "a site with wealth in")
	eq(e.abandon_line(home), "", "not something abandon takes")


# --- Manual check support: the details' Abandon… (UI) ---

func test_details_abandon_a_building_or_an_upgrade_after_confirming() -> void:
	await with_main(abandon_engine(4, ""), func(main: Node):
		var e := Game.engine
		set_home_pop(e, 4)  # start_game began a new game
		var farm := built(e, "farm", home_uid(e))
		var plough := built(e, "plough", farm)
		await wait_frames()
		main.details.open_card(e.zone("tableau").find(farm))
		var row: Dictionary = main.details.upgrade_rows().filter(func(r): return r.name == "Plough")[0]
		check(row.abandon != null and not row.abandon.disabled, "the built Plough's row offers Abandon…")
		row.abandon.pressed.emit()
		await wait_frames()
		check(main.details.abandon_modal.is_open(), "it asks first")
		eq(main.details.abandon_modal.body_text(), e.abandon_line(plough), "with what abandoning does")
		main.details.abandon_modal.confirm_button.pressed.emit()
		await wait_frames()
		eq([zone_of(e, farm), zone_of(e, plough)], ["tableau", ""], "only the Plough went")
		main.details.open_card(e.zone("tableau").find(farm))
		var abandon: Button = main.details.site_buttons()[1]
		check(abandon.visible and not abandon.disabled, "the Farm's details offer Abandon…")
		check(not main.details.site_buttons()[0].visible, "but no Contribute")
		abandon.pressed.emit()
		await wait_frames()
		main.details.abandon_modal.confirm_button.pressed.emit()
		await wait_frames()
		eq(zone_of(e, farm), "", "the Farm went")
		main.details.open_card(e.zone("tableau").find(home_uid(e)))
		check(not main.details.site_buttons()[1].visible, "no Abandon… on a territory")
		main.details.close())
