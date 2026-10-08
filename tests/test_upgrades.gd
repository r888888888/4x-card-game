extends "res://tests/lib/test_case.gd"
## Building upgrades (300): a building with upgrade_of is built from the build menu onto a building already in play
## (its base), takes no slot and no worker, and adds to its base while the base works; a base carries several
## different upgrades and an upgrade can be a base. upgrade_base, upgrades_on, fallen_back_reason; the loader. 387:
## upgrade_rows, a building's upgrades for its details. 410: has_unbuilt_upgrades, for its badge.

const PLOUGH := {"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "vp": 1,
	"upgrade_of": "farm", "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
const DITCH := {"id": "ditch", "name": "Ditch", "type": "building", "cost": {"food": 1}, "upgrade_of": "farm",
	"housing": 1, "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "flood_plain"}]}
const CHAPEL := {"id": "chapel", "name": "Chapel", "type": "building", "cost": {"food": 1}}
const SANCTUM := {"id": "sanctum", "name": "Sanctum", "type": "building", "cost": {"food": 1}, "upgrade_of": "chapel",
	"modifiers": {"hand_size": 1}}
const CATHEDRAL := {"id": "cathedral", "name": "Cathedral", "type": "building", "cost": {"food": 1},
	"upgrade_of": "sanctum", "vp": 2}
## Not in the item's fixture: an upgrade with a play effect, defence, training and a famine guard.
const RAMPART := {"id": "rampart", "name": "Rampart", "type": "building", "upgrade_of": "chapel", "defense": 1,
	"training": 1, "famine_guard": 1, "effects": [{"op": "score", "amount": 2}]}
## An upgrade that needs fresh water on its base's territory.
const WEIR := {"id": "weir", "name": "Weir", "type": "building", "upgrade_of": "farm", "requires": ["fresh_water"]}
## Opens the Plough entry.
const FURROW := {"id": "furrow", "name": "Furrow", "type": "tech", "cost": {"insight": 1},
	"effects": [{"op": "unlock", "card": "plough"}]}
const SPEARS := {"id": "spears", "name": "Spears", "type": "unit", "cost": {"food": 1}, "strength": 2}
const UPGRADES := [PLOUGH, DITCH, CHAPEL, SANCTUM, CATHEDRAL, RAMPART, WEIR, FURROW, SPEARS]
const MENU := {"farm": {}, "plough": {}, "ditch": {}, "chapel": {}, "sanctum": {}, "cathedral": {}, "rampart": {},
	"weir": {}, "spears": {}}
const POP := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}


## A game with population on (2 pop on Homeland), build_menu MENU, River and Grassland in the territory deck and food
## food (insight 10). gov "" rules nothing (unlimited actions); "band" gives 2 actions. overrides last.
func upgrade_engine(food := 10, gov := "", overrides := {}) -> GameEngine:
	var starting := {"resources": {"food": food, "insight": 10}, "tableau": ["capital"], "territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"build_menu": MENU, "population": POP, "starting": starting,
		"territory_deck": {"river": 1, "grassland": 1}}
	o.merge(overrides, true)
	var e := make_engine({"scout": 10}, o, 1, UPGRADES + TEST_GOVS)
	e.resources.food = food
	return e


## A new copy of building id straight on territory, unpaid: its uid.
func put_on(e: GameEngine, territory: int, id: String) -> int:
	build_on(e, territory, [id])
	return e.zone("tableau").cards.back().uid


## Settles territory id at pop, returning its uid.
func settle_at(e: GameEngine, id: String, pop: int) -> int:
	settle(e, [id])
	var uid := uid_of(e.zone("tableau"), id)
	e.zone("tableau").find(uid).pop = pop
	return uid


## Builds upgrade id on base, failing the test if it refuses: the new card's uid.
func upgrade(e: GameEngine, id: String, base: int) -> int:
	check(e.build(id, base), "build %s on %d: %s" % [id, base, e.build_error(id, base)])
	return e.zone("tableau").cards.back().uid


## What build changes: [food, actions left, tableau ids, score].
func snapshot(e: GameEngine) -> Array:
	return [e.resources.food, e.actions_left(), card_ids(e.zone("tableau")), e.score()]


func assert_refused(e: GameEngine, card_id: String, target: int, message: String) -> void:
	eq(e.build_error(card_id, target), message, "build_error(%s, %d)" % [card_id, target])
	var before := snapshot(e)
	check(not e.build(card_id, target), "build(%s, %d) refuses" % [card_id, target])
	eq(snapshot(e), before, "build(%s, %d) changes nothing" % [card_id, target])


# --- AC1: the loader ---

## Loads TEST_CARDS, UPGRADES and extra: {errors, warnings}.
func upgrade_load(extra: Array) -> Dictionary:
	return fixture_load(UPGRADES + extra)


func test_an_upgrade_loads_its_base() -> void:
	check_loads([
		["Plough, Cathedral and a Farm (no upgrade)", [], {"cards.plough.upgrade_of": "farm",
			"cards.cathedral.upgrade_of": "sanctum", "cards.farm.upgrade_of": ""}],
	], upgrade_load)


func test_upgrade_of_validation() -> void:
	var project := {"id": "site", "name": "Site", "type": "building", "cost": {"wealth": 5}, "project": true}
	check_cases([
		["unknown card", [{"id": "x", "name": "X", "type": "building", "upgrade_of": "dragon"}],
			"cards.json: card 'x': upgrade_of: unknown card 'dragon'"],
		["not a building", [{"id": "x", "name": "X", "type": "building", "upgrade_of": "scout"}],
			"cards.json: card 'x': upgrade_of: 'scout' is an action"],
		["its own base", [{"id": "x", "name": "X", "type": "building", "upgrade_of": "x"}],
			"cards.json: card 'x': upgrade_of: cycle x → x"],
		["a project upgrade", [project.merged({"upgrade_of": "farm"})],
			"cards.json: card 'site': upgrade_of: a project can't take or be an upgrade"],
		["on a project", [project, {"id": "x", "name": "X", "type": "building", "upgrade_of": "site"}],
			"cards.json: card 'x': upgrade_of: a project can't take or be an upgrade"],
		["not a string", [{"id": "x", "name": "X", "type": "building", "upgrade_of": 3}],
			"cards.json: card 'x': 'upgrade_of' must be a string"],
		["on an action", [{"id": "x", "name": "X", "type": "action", "upgrade_of": "farm"}],
			"cards.json: card 'x': 'upgrade_of' only applies to buildings (ignored)", "warning_only"],
	], upgrade_load)


func test_an_upgrade_cycle_is_reported_once_on_its_first_card() -> void:
	var r := upgrade_load([{"id": "a", "name": "A", "type": "building", "upgrade_of": "b"},
		{"id": "b", "name": "B", "type": "building", "upgrade_of": "a"}])
	var cycles: Array = r.errors.filter(func(m): return "cycle" in m)
	eq(cycles, ["cards.json: card 'a': upgrade_of: cycle a → b → a"], "one error, on a")


## The errors from a config with overrides over the build menu, against TEST_CARDS, UPGRADES and extra.
func upgrade_config_errors(overrides: Dictionary, deck := {"farm": 1}, extra := []) -> Array[String]:
	var r := upgrade_load(extra)
	var errors: Array[String] = []
	errors.append_array(r.errors)
	var raw := raw_config(deck, {"build_menu": MENU})
	raw.merge(overrides, true)
	DataLoader.parse_config(raw, resources(), r.cards, "config.json", errors, [])
	return errors


func test_an_upgrade_is_never_in_the_deck_the_supply_or_created() -> void:
	has_msg(upgrade_config_errors({}, {"plough": 1}),
		"config.json: deck: 'plough' is an upgrade; build it from the build menu")
	has_msg(upgrade_config_errors({"build_menu": {}, "supply": {"plough": {"price": 2, "count": 1}}}),
		"config.json: supply: 'plough' is an upgrade; build it from the build menu")
	has_msg(upgrade_config_errors({}, {"farm": 1}, [{"id": "x", "name": "X", "type": "action",
		"effects": [{"op": "create", "card": "plough"}]}]),
		"card 'x': 'create' effect: 'plough' is an upgrade; build it from the build menu")
	eq(upgrade_config_errors({}), [] as Array[String], "the build menu may hold upgrades")


# --- AC2: building one ---

func test_an_upgrade_builds_onto_its_base_without_a_slot_or_a_worker() -> void:
	var e := upgrade_engine(1, "band")
	var home := home_uid(e)
	var farm := put_on(e, home, "farm")
	check(not e.is_idle(farm), "precondition: the Farm works")
	var slots: int = e.free_slots(home)
	var workers: int = e.free_workers(home)
	var outcomes: Array[Dictionary] = []
	e.card_played.connect(func(o): outcomes.append(o))
	eq(e.build_error("plough", farm), "", "build_error")
	check(e.build("plough", farm), "build returns true")
	var plough: CardInstance = e.zone("tableau").cards.back()
	eq(plough.def.id, "plough", "a Plough joined the tableau")
	eq(plough.territory_uid, home, "on the Farm's territory")
	eq(e.upgrade_base(plough.uid), farm, "upgrade_base")
	eq(e.upgrades_on(farm), [plough.uid] as Array[int], "upgrades_on")
	eq(e.resources.food, 0, "1 - 1 food")
	eq(e.actions_left(), 1, "an action used")
	eq([e.free_slots(home), e.free_workers(home)], [slots, workers], "no slot or worker taken")
	eq(outcomes.size(), 1, "card_played once")
	if not outcomes.is_empty():
		eq([outcomes[0].uid, outcomes[0].target], [plough.uid, farm], "card_played names the Plough and its Farm")


func test_an_upgrade_resolves_its_play_effects() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	var score: int = e.score()
	upgrade(e, "rampart", chapel)
	eq(e.score(), score + 2, "Rampart's play effect scored 2")


func test_build_targets_list_every_base_that_could_take_it_in_tableau_order() -> void:
	var e := upgrade_engine(0)
	var river := settle_at(e, "river", 1)
	var first := put_on(e, river, "farm")
	var second := put_on(e, home_uid(e), "farm")
	eq(e.build_targets("plough"), [first, second] as Array[int], "both Farms, though the food is short")
	e.resources.food = 10
	upgrade(e, "plough", first)
	eq(e.build_targets("plough"), [second] as Array[int], "a Farm with a Plough takes no other")
	check(e.build("plough"), "target -1 with one Farm left")
	eq(e.upgrade_base(e.zone("tableau").cards.back().uid), second, "built on the other Farm")
	eq(e.build_targets("plough"), [] as Array[int], "none left")


func test_an_idle_base_can_be_upgraded() -> void:
	var e := upgrade_engine()
	var farm := put_on(e, home_uid(e), "farm")
	set_home_pop(e, 0)
	check(e.is_idle(farm), "precondition: the Farm is idle")
	eq(e.build_targets("plough"), [farm] as Array[int], "the idle Farm is a target")
	var plough := upgrade(e, "plough", farm)
	eq(e.upgrade_base(plough), farm, "built on the idle Farm")


# --- AC3: refusals ---

func test_an_upgrade_refuses_a_target_that_isnt_its_base() -> void:
	var e := upgrade_engine()
	var home := home_uid(e)
	var chapel := put_on(e, home, "chapel")
	put_on(e, home, "farm")
	assert_refused(e, "plough", home, "Plough builds on a Farm.")
	assert_refused(e, "plough", chapel, "Plough builds on a Farm.")
	assert_refused(e, "plough", 999, "Plough builds on a Farm.")
	assert_refused(e, "cathedral", chapel, "Cathedral builds on a Sanctum.")


func test_a_base_takes_each_upgrade_once() -> void:
	var e := upgrade_engine()
	var farm := put_on(e, home_uid(e), "farm")
	upgrade(e, "plough", farm)
	assert_refused(e, "plough", farm, "That Farm already has a Plough.")
	assert_refused(e, "plough", -1, "No Farm to build Plough on.")


func test_an_upgrade_with_no_target_named_needs_exactly_one_base() -> void:
	var e := upgrade_engine()
	assert_refused(e, "plough", -1, "No Farm to build Plough on.")
	put_on(e, home_uid(e), "farm")
	put_on(e, home_uid(e), "farm")
	assert_refused(e, "plough", -1, "Choose a Farm for Plough.")


func test_an_upgrade_refuses_as_any_build_does() -> void:
	var e := upgrade_engine(0, "band", {"build_menu": MENU.merged({"plough": {"locked": true}}, true)})
	var farm := put_on(e, home_uid(e), "farm")
	assert_refused(e, "plough", farm, "Plough isn't unlocked yet.")
	assert_refused(e, "ditch", farm, "Ditch needs 1 food (you have 0).")
	e.resources.food = 10
	var chapel := put_on(e, home_uid(e), "chapel")
	upgrade(e, "ditch", farm)
	upgrade(e, "sanctum", chapel)
	assert_refused(e, "rampart", chapel, "No actions left this turn.")
	var over := upgrade_engine(10, "", {"turn_limit": 1})
	var over_farm := put_on(over, home_uid(over), "farm")
	over.end_turn()
	assert_refused(over, "plough", over_farm, "The game is over.")


func test_an_upgrade_needs_what_it_requires_on_its_bases_territory() -> void:
	var e := upgrade_engine()
	var dry := put_on(e, home_uid(e), "farm")
	var river := settle_at(e, "river", 1)
	var wet := put_on(e, river, "farm")
	assert_refused(e, "weir", dry, "Weir needs a territory with Fresh Water.")
	eq(e.build_targets("weir"), [wet] as Array[int], "only the River's Farm")
	upgrade(e, "weir", wet)


func test_a_building_that_isnt_an_upgrade_refuses_a_building_target() -> void:
	var e := upgrade_engine()
	var farm := put_on(e, home_uid(e), "farm")
	assert_refused(e, "chapel", farm, "That target isn't valid.")


# --- AC4: stack and chain ---

func test_a_base_carries_several_different_upgrades_in_build_order() -> void:
	var e := upgrade_engine()
	var first := put_on(e, home_uid(e), "farm")
	var second := put_on(e, home_uid(e), "farm")
	var plough := upgrade(e, "plough", first)
	var ditch := upgrade(e, "ditch", first)
	var ditch_2 := upgrade(e, "ditch", second)
	var plough_2 := upgrade(e, "plough", second)
	eq(e.upgrades_on(first), [plough, ditch] as Array[int], "Plough then Ditch")
	eq(e.upgrades_on(second), [ditch_2, plough_2] as Array[int], "Ditch then Plough")
	eq(e.upgrades_on(plough), [] as Array[int], "nothing on a Plough")


func test_upgrades_chain_one_build_at_a_time() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	eq(e.build_targets("cathedral"), [] as Array[int], "no Sanctum yet")
	var sanctum := upgrade(e, "sanctum", chapel)
	eq(e.build_targets("cathedral"), [sanctum] as Array[int], "the Sanctum takes a Cathedral")
	var cathedral := upgrade(e, "cathedral", sanctum)
	eq(e.upgrades_on(chapel), [sanctum] as Array[int], "upgrades_on(Chapel)")
	eq(e.upgrades_on(sanctum), [cathedral] as Array[int], "upgrades_on(Sanctum)")
	eq(e.upgrade_base(cathedral), sanctum, "the Cathedral's base")
	eq(e.upgrade_base(chapel), -1, "a base that is no upgrade")


# --- AC5: an upgrade adds while its base works ---

## Food from the next upkeep.
func food_forecast(e: GameEngine) -> int:
	return e.upkeep_forecast().get(GameEngine.FOOD, 0)


func test_upgrades_add_to_a_working_base() -> void:
	var e := upgrade_engine()
	var river := settle_at(e, "river", 1)
	var food := food_forecast(e)
	var score: int = e.score()
	var farm := put_on(e, river, "farm")
	var housing: int = e.housing(river)
	var plough := upgrade(e, "plough", farm)
	var ditch := upgrade(e, "ditch", farm)
	eq(food_forecast(e), food + 3, "Farm 1, Plough 1, Ditch 1 on a flood plain")
	eq(e.housing(river), housing + 1, "the Ditch's housing")
	eq(e.score(), score + 1, "the Plough's VP")
	eq([e.fallen_back_reason(plough), e.fallen_back_reason(ditch)], ["", ""], "working")
	var held: int = e.resources.food
	var forecast := food_forecast(e)
	e.end_turn()
	eq(e.resources.food, held + forecast, "the upkeep that follows matches the forecast")


func test_a_chain_adds_while_its_root_works() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	var hand: int = e.hand_size()
	var score: int = e.score()
	var sanctum := upgrade(e, "sanctum", chapel)
	upgrade(e, "cathedral", sanctum)
	eq(e.hand_size(), hand + 1, "the Sanctum's hand size")
	eq(e.score(), score + 2, "the Cathedral's VP")


func test_upgrades_on_an_idle_base_count_for_nothing_until_it_works_again() -> void:
	var e := upgrade_engine()
	var river := settle_at(e, "river", 1)
	var food := food_forecast(e)
	var score: int = e.score()
	var farm := put_on(e, river, "farm")
	var housing: int = e.housing(river)
	var plough := upgrade(e, "plough", farm)
	var ditch := upgrade(e, "ditch", farm)
	var river_card: CardInstance = e.zone("tableau").find(river)
	river_card.pop = 0
	check(e.is_idle(farm), "precondition: the Farm is idle")
	eq(food_forecast(e), food, "no upkeep from the Farm or its upgrades")
	eq(e.housing(river), housing, "no housing from the Ditch")
	eq(e.score(), score, "no VP from the Plough")
	eq([e.fallen_back_reason(plough), e.fallen_back_reason(ditch)], ["Its Farm is idle.", "Its Farm is idle."],
		"why they fell back")
	var held: int = e.resources.food
	e.end_turn()
	eq(e.resources.food, held + food, "the upkeep matches the forecast")
	river_card.pop = 1
	eq(food_forecast(e), food + 3, "back at no cost")
	eq(e.housing(river), housing + 1, "the Ditch's housing is back")
	eq(e.score(), score + 1, "the Plough's VP is back")
	eq(e.fallen_back_reason(plough), "", "working again")


func test_upgrades_on_a_base_past_its_slots_count_for_nothing() -> void:
	var e := upgrade_engine()
	var grass := settle_at(e, "grassland", 3)
	var food := food_forecast(e)
	build_on(e, grass, ["chapel", "chapel"])
	var farm := put_on(e, grass, "farm")
	check(e.is_idle(farm), "precondition: the Farm is past Grassland's 2 slots")
	var plough := upgrade(e, "plough", farm)
	eq(food_forecast(e), food, "no upkeep from the Plough")
	eq(e.fallen_back_reason(plough), "Its Farm is idle.", "why")


func test_a_chain_on_an_idle_root_counts_for_nothing() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	var hand: int = e.hand_size()
	var score: int = e.score()
	var sanctum := upgrade(e, "sanctum", chapel)
	var cathedral := upgrade(e, "cathedral", sanctum)
	set_home_pop(e, 0)
	eq(e.hand_size(), hand, "no hand size from the Sanctum")
	eq(e.score(), score, "no VP from the Cathedral")
	eq(e.fallen_back_reason(sanctum), "Its Chapel is idle.", "the Sanctum's reason")
	eq(e.fallen_back_reason(cathedral), "Its Chapel is idle.", "the Cathedral's reason names the idle root")
	eq(e.fallen_back_reason(chapel), "", "an idle base itself hasn't fallen back")


func test_a_fallen_back_upgrade_adds_no_defence_or_training() -> void:
	var e := upgrade_engine()
	var home := home_uid(e)
	var spears := put_on(e, home, "spears")
	e.zone("tableau").find(spears).station_uid = home
	var chapel := put_on(e, home, "chapel")
	var defense: int = e.military.defense(home)
	upgrade(e, "rampart", chapel)
	eq(e.military.strength(spears), 3, "Spears 2 + 1 training")
	eq(e.military.defense(home), defense + 2, "Rampart 1 + 1 training")
	set_home_pop(e, 1)  # one worker: the Spears work, the Chapel is idle
	eq(e.military.strength(spears), 2, "no training from the Rampart")
	eq(e.military.defense(home), defense, "no defence from the Rampart")


## Homeland at 4 pop, a Famine of 1 counter under way and no food (as test_famine's guard test), with the buildings
## first on Homeland: home pop after the next upkeep, a Rampart built on the Chapel.
func pop_after_famine(first: Array) -> int:
	var e := upgrade_engine(0, "", {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 0}})
	set_home_pop(e, 4)
	e.end_turn()  # famine 1: 4 -> 3
	set_home_pop(e, 4)
	build_on(e, home_uid(e), first)
	upgrade(e, "rampart", uid_of(e.zone("tableau"), "chapel"))
	e.resources.food = 0
	e.end_turn()  # famine 2: two deaths, less what the guards save
	return e.pop(home_uid(e))


func test_a_fallen_back_upgrade_saves_no_pop_from_famine() -> void:
	eq(pop_after_famine(["chapel"]), 3, "the Rampart on a working Chapel saves 1 of 2")
	eq(pop_after_famine(["temple", "temple", "temple", "temple", "chapel"]), 2,
		"the Chapel has no worker: no guard")


# --- AC6: state and text ---

func test_a_copy_keeps_each_upgrades_base() -> void:
	var e := upgrade_engine()
	var farm := put_on(e, home_uid(e), "farm")
	var plough := upgrade(e, "plough", farm)
	var f := e.fork()
	eq(f.upgrade_base(plough), farm, "fork keeps the base")
	eq(f.upgrades_on(farm), [plough] as Array[int], "fork's upgrades_on")
	var copied: CardInstance = e.state.copy().zones["tableau"].find(plough)
	eq(copied.get("base_uid"), farm, "GameState.copy keeps base_uid")


func test_an_upgrades_text_says_what_it_builds_on() -> void:
	var e := upgrade_engine()
	var plough: CardDef = e.card_db["plough"]
	check(not plough.rules_text(e.card_db).contains("Builds on"), "the face leaves it to the type line (382)")
	eq(plough.rules_tooltip(e.card_db).split("\n")[0], "Builds on a Farm.", "tooltip's first line")
	eq(e.def_details("plough").rules[0], "Builds on a Farm.", "details' first rule")
	var plain := make_engine({"scout": 10})
	var farm: CardDef = e.card_db["farm"]
	eq(farm.rules_text(e.card_db), (plain.card_db["farm"] as CardDef).rules_text(plain.card_db), "a base's text unchanged")
	eq(farm.rules_tooltip(e.card_db), (plain.card_db["farm"] as CardDef).rules_tooltip(plain.card_db), "and tooltip")


func test_an_unlock_of_an_upgrade_names_its_base() -> void:
	var e := upgrade_engine(10, "", {"build_menu": MENU.merged({"plough": {"locked": true}}, true),
		"research_deck": {"furrow": 1}})
	eq((e.card_db["furrow"] as CardDef).rules_tooltip(e.card_db), "Plough can now be built on a Farm.", "the tech's text")
	var recorded := record_messages(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "furrow")), "learn Furrow")
	check_noticed(recorded, "Plough can now be built on a Farm.", GameEngine.NOTICE_INFO)


# --- Backlog 302: what the territory view and the Build modal ask ---

func test_upgrade_base_name_names_the_building_an_entry_builds_on() -> void:
	var e := upgrade_engine()
	eq([e.upgrade_base_name("plough"), e.upgrade_base_name("cathedral")], ["Farm", "Sanctum"], "upgrades")
	eq([e.upgrade_base_name("farm"), e.upgrade_base_name("dragon")], ["", ""], "a building, an unknown id")


func test_upgrade_rules_text_leaves_out_the_builds_on_line() -> void:
	var e := upgrade_engine()
	eq(e.upgrade_rules_text("plough"), "⟳ +1 food", "the Plough")
	eq(e.upgrade_rules_text("ditch"), "Flood Plain: ⟳ +1 food\n+1 housing", "the Ditch")
	eq(e.upgrade_rules_text("farm"), "", "a building that is no upgrade")


func test_upgrade_tree_lists_a_bases_upgrades_depth_first() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	var sanctum := upgrade(e, "sanctum", chapel)
	var rampart := upgrade(e, "rampart", chapel)
	var cathedral := upgrade(e, "cathedral", sanctum)
	eq(e.upgrade_tree(chapel), [sanctum, cathedral, rampart] as Array[int], "each upgrade, then what is built on it")
	eq(e.upgrade_tree(sanctum), [cathedral] as Array[int], "from the Sanctum")
	eq(e.upgrade_tree(cathedral), [] as Array[int], "nothing on the Cathedral")


func test_upgrade_options_pair_each_upgrade_entry_with_each_building_on_a_territory() -> void:
	var e := upgrade_engine()
	var home := home_uid(e)
	var farm := put_on(e, home, "farm")
	var chapel := put_on(e, home, "chapel")
	eq(e.upgrade_options(home), [{"card_id": "plough", "base": farm}, {"card_id": "ditch", "base": farm},
		{"card_id": "weir", "base": farm}, {"card_id": "sanctum", "base": chapel}, {"card_id": "rampart", "base": chapel}],
		"by base in tableau order, then menu order, refused ones too")
	var plough := upgrade(e, "plough", farm)
	var sanctum := upgrade(e, "sanctum", chapel)
	var options: Array = e.upgrade_options(home)
	check(options.has({"card_id": "plough", "base": farm}), "a built upgrade is still an option on its base")
	check(options.has({"card_id": "cathedral", "base": sanctum}), "an upgrade is a base too")
	check(not options.any(func(o): return o.base == plough), "nothing builds on a Plough")
	eq(e.upgrade_options(settle_at(e, "grassland", 1)), [] as Array[Dictionary], "a territory with no buildings")


func test_an_upgrades_preview_reads_its_bases_territory() -> void:
	var e := upgrade_engine(10, "band")
	var river := settle_at(e, "river", 1)
	var farm := put_on(e, river, "farm")
	var food := food_forecast(e)
	var housing: int = e.housing(river)
	eq(e.build_preview("ditch", farm), {"cost": {"food": 1}, "lines": [["food", food, food + 1],
		["housing", housing, housing + 1], ["actions_left", 2, 1]]}, "no slot or worker line")
	eq(e.build_preview("ditch", river), {}, "refused on the territory itself")


# --- 387: a building's upgrade rows, for its details ---

func test_a_farms_rows_are_every_upgrade_in_menu_order_built_or_not() -> void:
	var e := upgrade_engine(10, "", {"build_menu": MENU.merged({"plough": {"locked": true}}, true)})
	var home := home_uid(e)
	var farm := put_on(e, home, "farm")
	var ditch := upgrade(e, "ditch", farm)
	eq(e.upgrade_rows(farm), [
		{"card_id": "plough", "base": farm, "built": -1, "error": "Plough isn't unlocked yet."},
		{"card_id": "ditch", "base": farm, "built": ditch, "error": ""},
		{"card_id": "weir", "base": farm, "built": -1, "error": e.build_error("weir", farm)},
	], "Plough locked, the Ditch built, the Weir short of fresh water")
	check(e.build_error("weir", farm) != "", "the Weir is refused: %s" % e.build_error("weir", farm))


func test_a_chain_lists_its_bases_in_order_and_a_link_only_once_its_base_stands() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	eq(e.upgrade_rows(chapel).map(func(r): return r.card_id), ["sanctum", "rampart"], "no Cathedral before a Sanctum")
	var sanctum := upgrade(e, "sanctum", chapel)
	eq(e.upgrade_rows(chapel), [
		{"card_id": "sanctum", "base": chapel, "built": sanctum, "error": ""},
		{"card_id": "rampart", "base": chapel, "built": -1, "error": ""},
		{"card_id": "cathedral", "base": sanctum, "built": -1, "error": ""},
	], "the Sanctum built, the Rampart and the Cathedral (on the Sanctum) buildable")


func test_no_rows_for_anything_but_a_building_something_upgrades() -> void:
	var e := upgrade_engine()
	var home := home_uid(e)
	var capital := uid_of(e.zone("tableau"), "capital")
	var spears := put_on(e, home, "spears")
	eq([e.upgrade_rows(home), e.upgrade_rows(capital), e.upgrade_rows(spears), e.upgrade_rows(999)], [[], [], [], []],
		"a territory, a city, a unit, no card")
	var sanctum := upgrade(e, "sanctum", put_on(e, home, "chapel"))
	var cathedral := upgrade(e, "cathedral", sanctum)
	eq(e.upgrade_rows(cathedral), [], "a Cathedral: nothing upgrades it")


# --- 410: whether a building has an upgrade not yet built, for its badge ---

func test_a_farm_has_unbuilt_upgrades_whatever_stops_them_now() -> void:
	var e := upgrade_engine(10, "", {"build_menu": MENU.merged({"plough": {"locked": true}}, true)})
	var farm := put_on(e, home_uid(e), "farm")
	upgrade(e, "ditch", farm)
	e.resources.food = 0
	check(e.has_unbuilt_upgrades(farm), "Plough locked and the Weir short of fresh water, with no food")
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer: a territory choice is owed")
	check(e.has_unbuilt_upgrades(farm), "while a decision is owed")


func test_a_chain_has_unbuilt_upgrades_until_its_last_link_stands() -> void:
	var e := upgrade_engine()
	var chapel := put_on(e, home_uid(e), "chapel")
	var sanctum := upgrade(e, "sanctum", chapel)
	upgrade(e, "rampart", chapel)
	check(e.has_unbuilt_upgrades(chapel), "the Cathedral, on the Sanctum")
	upgrade(e, "cathedral", sanctum)
	check(not e.has_unbuilt_upgrades(chapel), "the whole chain built")


func test_no_unbuilt_upgrades_for_anything_but_a_building() -> void:
	var e := upgrade_engine()
	var home := home_uid(e)
	var capital := uid_of(e.zone("tableau"), "capital")
	var spears := put_on(e, home, "spears")
	eq([e.has_unbuilt_upgrades(home), e.has_unbuilt_upgrades(capital), e.has_unbuilt_upgrades(spears),
		e.has_unbuilt_upgrades(999)], [false, false, false, false], "a territory, a city, a unit, no card")
