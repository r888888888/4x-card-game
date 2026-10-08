extends "res://tests/lib/tech_case.gd"
## The build menu (295): config build_menu {card_id: {locked, once}}; build(card_id, territory) puts a new copy of an
## unlocked entry on a settled territory for an action and its cost, as playing it would; build_error, build_menu,
## build_targets; the unlock op opening an entry; once entries; the loader. Band (2 actions) rules, so actions run out.
## In detail (from docs/testing.md, 331): The build menu (295): config `build_menu` ({card_id: {locked, once}}) and its
## loader checks; `build` / `build_error` (an action and the discounted cost, a fresh copy on a territory,
## `card_played`, each refusal), `build_menu`, `build_targets`; the `unlock` op opening an entry ("… can now be
## built."); `once` entries; copies; `build_preview` (299: cost and before → after lines, only what changes, untouched
## game). Band rules, so actions run out

## Played when built: +2 VP.
const OBELISK := {"id": "obelisk", "name": "Obelisk", "type": "building", "cost": {"food": 1},
	"effects": [{"op": "score", "amount": 2}]}
## Played when built: adds a Scout to the deck (364, Fishing Huts adding a Net Fishing).
const NET_LOFT := {"id": "net_loft", "name": "Net Loft", "type": "building",
	"effects": [{"op": "create", "card": "scout", "zone": "deck"}]}
## Costs two resources, so a price it can't meet names both (337).
const TOLL_HOUSE := {"id": "toll_house", "name": "Toll House", "type": "building", "cost": {"food": 1, "wealth": 2}}
## Opens the Granary entry.
const POTTERY_KILN := {"id": "kiln", "name": "Kiln", "type": "tech", "cost": {"insight": 2},
	"effects": [{"op": "unlock", "card": "granary"}]}
## Farms cost 1 food less (Sumer's discount, in food).
const FARMERS := {"id": "farmers", "name": "Farmers", "type": "civilization",
	"discounts": [{"tag": "farm", "food": 1}]}
const POP := {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
const MENU := {"farm": {}, "obelisk": {}, "well": {}, "granary": {"locked": true}}


## A game with Band ruling (2 actions), population on (2 pop on the home), build_menu menu, Kiln and Pottery to learn,
## and food food (wealth and insight 10). overrides last; extra cards join the fixtures.
func build_engine(food := 3, menu := MENU, overrides := {}, extra := []) -> GameEngine:
	var o := {"build_menu": menu, "population": POP,
		"starting": {"resources": {"food": food, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": "band"}}
	o.merge(overrides, true)
	var e := tech_engine(["kiln", "pottery"], {"scout": 10}, o,
		[OBELISK, POTTERY_KILN, FARMERS, TOLL_HOUSE, NET_LOFT] + TEST_GOVS + extra)
	e.resources.food = food
	return e


## Card ids in zone name, sorted.
func ids_in(e: GameEngine, name: String) -> Array:
	return sorted(card_ids(e.zone(name)))


## Settles Grassland too, so two territories could take a building.
func two_territories(e: GameEngine) -> int:
	settle(e, ["grassland"])
	var grass := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grass).pop = 2
	return grass


## What build changes: [food, actions used, tableau ids, hand, deck, discard].
func snapshot(e: GameEngine) -> Array:
	return [e.resources.food, e.actions_left(), ids_in(e, "tableau"), ids_in(e, "hand"), ids_in(e, "deck"),
		ids_in(e, "discard")]


func assert_refused(e: GameEngine, card_id: String, territory: int, message: String) -> void:
	eq(e.build_error(card_id, territory), message, "build_error(%s)" % card_id)
	var before := snapshot(e)
	check(not e.build(card_id, territory), "build(%s) refuses" % card_id)
	eq(snapshot(e), before, "build(%s) changes nothing" % card_id)


# --- AC1: build ---

func test_building_puts_a_new_copy_on_the_territory_for_an_action_and_its_cost() -> void:
	var e := build_engine(3)
	var home := home_uid(e)
	var outcomes: Array[Dictionary] = []
	e.card_played.connect(func(o): outcomes.append(o))
	var before := [ids_in(e, "hand"), ids_in(e, "deck"), ids_in(e, "discard")]
	var uids_before: Array = e.zone("tableau").cards.map(func(c): return c.uid)
	eq(e.build_menu(), ["farm", "obelisk", "well"] as Array[String], "unlocked entries, in config order")
	eq(e.build_error("farm", home), "", "build_error")
	check(e.build("farm", home), "build returns true")
	var farm: CardInstance = e.zone("tableau").cards.back()
	eq(farm.def.id, "farm", "a Farm joined the tableau")
	check(not uids_before.has(farm.uid), "a fresh uid")
	eq(farm.territory_uid, home, "on the home")
	eq(e.resources.food, 1, "3 - 2 food")
	eq(e.actions_left(), 1, "an action used")
	eq(outcomes.size(), 1, "card_played once")
	if not outcomes.is_empty():
		eq([outcomes[0].uid, outcomes[0].target], [farm.uid, home], "card_played names the Farm and its territory")
	eq([ids_in(e, "hand"), ids_in(e, "deck"), ids_in(e, "discard")], before, "hand, deck and discard unchanged")


func test_building_resolves_play_effects_and_pays_the_discounted_cost() -> void:
	var e := build_engine(3)
	var score: int = e.score()
	check(e.build("obelisk", home_uid(e)), "build an Obelisk")
	eq(e.score(), score + 2, "its play effect scored 2")
	var sumer := build_engine(3, MENU, {"starting": {"resources": {"food": 3, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland", "government": "band", "civilization": "farmers"}})
	check(sumer.build("farm", home_uid(sumer)), "build a Farm as Farmers")
	eq(sumer.resources.food, 2, "Farm costs 2 - 1 food")


func test_each_building_built_adds_the_card_its_play_effect_creates_to_the_deck() -> void:
	var e := build_engine(3, MENU.merged({"net_loft": {}}))
	var home := home_uid(e)
	var before := [card_ids(e.zone("deck")).count("scout"), ids_in(e, "hand"), ids_in(e, "discard")]
	for i in 2:
		check(e.build("net_loft", home), "build Net Loft %d: %s" % [i + 1, e.build_error("net_loft", home)])
	eq(card_ids(e.zone("deck")).count("scout"), before[0] + 2, "two Scouts more in the deck")
	eq(ids_in(e, "hand"), before[1], "hand unchanged")
	eq(ids_in(e, "discard"), before[2], "discard unchanged")


func test_a_building_with_a_unique_create_adds_its_card_once() -> void:
	var loft := NET_LOFT.duplicate(true)
	loft.id = "unique_loft"
	loft.effects[0].card = "settler"  # one the player doesn't own: the deck is Scouts
	loft.effects[0].unique = true
	var e := build_engine(3, MENU.merged({"unique_loft": {}}), {}, [loft])
	var home := home_uid(e)
	var before := card_ids(e.zone("deck")).count("settler")
	for i in 2:
		check(e.build("unique_loft", home), "build Loft %d: %s" % [i + 1, e.build_error("unique_loft", home)])
	eq(card_ids(e.zone("deck")).count("settler"), before + 1, "one Settler more, not two")


func test_with_no_territory_named_it_builds_on_the_only_one_that_takes_it() -> void:
	var e := build_engine(3)
	check(e.build("farm"), "build with territory -1")
	eq(e.zone("tableau").cards.back().territory_uid, home_uid(e), "on the home, the only territory")


# --- AC2: refusals ---

func test_build_refuses_with_a_reason_and_changes_nothing() -> void:
	var e := build_engine(3)
	var home := home_uid(e)
	assert_refused(e, "scout", home, "Scout can't be built.")
	assert_refused(e, "granary", home, "Granary isn't unlocked yet.")
	e.resources.food = 1
	assert_refused(e, "farm", home, "Farm needs 2 food (you have 1).")
	assert_refused(e, "well", home, "Well needs a territory with Fresh Water.")
	e.resources.food = 10
	check(e.build("farm", home) and e.build("obelisk", home), "use both actions")
	assert_refused(e, "farm", home, "No actions left this turn.")


func test_build_refuses_without_a_slot_or_a_worker() -> void:
	var e := build_engine(10, MENU, {"population": {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}})
	check(e.build("farm", home_uid(e)), "the home's one worker builds a Farm")
	e.end_turn()
	e.resources.food = 10
	assert_refused(e, "farm", -1, "No free worker.")
	eq(e.build_targets("farm"), [] as Array[int], "no targets")
	var full := build_engine(10, MENU, {"population": {"start": 7, "food_upkeep": 0, "vp_per_pop": 0}})
	var temples := []
	for i in full.free_slots(home_uid(full)):
		temples.append("temple")
	check(temples.size() < 7, "precondition: workers to spare once the slots are full (%d slots)" % temples.size())
	build_on(full, home_uid(full), temples)
	assert_refused(full, "farm", -1, "No territory with a free slot.")


func test_build_refuses_an_invalid_target_or_an_unnamed_choice() -> void:
	var e := build_engine(10, MENU, {"territory_deck": {"grassland": 1}})
	var grass := two_territories(e)
	assert_refused(e, "farm", -1, "Choose a territory for Farm.")
	assert_refused(e, "farm", uid_of(e.zone("tableau"), "capital"), "That target isn't valid.")
	eq(sorted(e.build_targets("farm")), sorted([home_uid(e), grass]), "both territories take a Farm")
	check(e.build("farm", grass), "naming one builds there")


func test_build_targets_ignore_cost_and_are_empty_for_a_locked_or_unknown_entry() -> void:
	var e := build_engine(0)
	eq(e.build_targets("farm"), [home_uid(e)] as Array[int], "the home, though the food is short")
	eq(e.build_targets("granary"), [] as Array[int], "locked")
	eq(e.build_targets("scout"), [] as Array[int], "no entry")


func test_build_refuses_when_the_game_is_over_or_a_decision_is_owed() -> void:
	var over := build_engine(3, MENU, {"turn_limit": 1})
	over.end_turn()
	assert_refused(over, "farm", home_uid(over), "The game is over.")
	var explore := build_engine(3, MENU, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(explore.play_card(put_in_hand(explore, "explorer")), "play Explorer")
	assert_refused(explore, "farm", home_uid(explore), "Choose a territory first.")


# --- Backlog 337 AC3: short of two resources, play and build name both ---

func test_short_of_two_resources_play_and_build_name_both() -> void:
	var e := build_engine(0, MENU.merged({"toll_house": {}}))
	e.resources.wealth = 0
	var message := "Toll House needs 1 food, 2 wealth (you have 0 food, 0 wealth)."
	eq(e.play_error(put_in_hand(e, "toll_house")), message, "play_error")
	assert_refused(e, "toll_house", home_uid(e), message)


# --- AC3: a tech unlocks an entry ---

func test_a_tech_unlocks_a_build_menu_entry_without_creating_a_card() -> void:
	var e := build_engine(3)
	var recorded := record_messages(e)
	var before := {}
	for name in GameEngine.ZONES:
		before[name] = card_ids(e.zone(name)).count("granary")
	check(e.buy_tech(uid_of(e.zone("research_deck"), "kiln")), "learn Kiln")
	eq(e.build_menu(), ["farm", "obelisk", "well", "granary"] as Array[String], "Granary is on the menu")
	eq(e.build_error("granary", home_uid(e)), "", "Granary can be built")
	check_noticed(recorded, "Granary can now be built.", GameEngine.NOTICE_INFO)
	for name in GameEngine.ZONES:
		eq(card_ids(e.zone(name)).count("granary"), before[name], "no Granary created in %s" % name)


func test_an_unlock_of_a_building_reads_can_now_be_built() -> void:
	var e := build_engine(3)
	eq((e.card_db["kiln"] as CardDef).rules_tooltip(e.card_db), "Granary can now be built.", "a building's unlock")
	var charter: CardDef = DataLoader.parse_cards({"cards": TEST_CARDS.cards + [{"id": "x", "name": "X", "type": "tech",
		"cost": {"insight": 1}, "effects": [{"op": "unlock", "card": "scout"}]}]}, resources(), "cards.json", [], [],
		keywords())["x"]
	eq(charter.rules_tooltip(e.card_db), "Scout can now be bought in the supply.", "an action's unlock")


# --- AC4: once ---

func test_a_once_entry_is_built_once_for_the_whole_game() -> void:
	var e := build_engine(10, {"granary": {"once": true}, "farm": {}})
	var home := home_uid(e)
	check(e.build("granary", home), "build the Granary")
	assert_refused(e, "granary", home, "Granary is already built.")
	var granary: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "granary"))
	e.zone("tableau").remove(granary)
	e.zone("discard").add(granary)
	e.end_turn()
	e.resources.food = 10
	assert_refused(e, "granary", home, "Granary is already built.")


func test_an_entry_without_once_builds_any_number_of_times() -> void:
	var e := build_engine(6, MENU, {"starting": {"resources": {"food": 6, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland", "government": "court"},
		"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0}})
	var home := home_uid(e)
	for i in 3:
		check(e.build("farm", home), "Farm %d" % (i + 1))
	eq(card_ids(e.zone("tableau")).count("farm"), 3, "three Farms")


func test_a_copy_keeps_what_is_unlocked_and_built() -> void:
	var e := build_engine(10, {"granary": {"once": true, "locked": true}, "farm": {}})
	var f := e.fork()
	check(f.buy_tech(uid_of(f.zone("research_deck"), "kiln")), "learn Kiln on the copy")
	check(f.build_menu().has("granary"), "unlocked on the copy")
	check(not e.build_menu().has("granary"), "still locked on the original")
	check(e.buy_tech(uid_of(e.zone("research_deck"), "kiln")), "learn Kiln on the original")
	check(e.build("granary", home_uid(e)), "build the Granary")
	eq(e.fork().build_error("granary", home_uid(e)), "Granary is already built.", "a copy knows it was built")


# --- AC5: the loader ---

## The fixtures and a config with build_menu menu (and overrides) (config_load_on).
func menu_load(menu: Variant, overrides := {}) -> Dictionary:
	return config_load_on(fixture_load([OBELISK, POTTERY_KILN], [TECHS]), {"build_menu": menu}.merged(overrides))


func test_build_menu_loads_with_defaults() -> void:
	check_loads([
		["normalized", {"farm": {}, "granary": {"locked": true, "once": true}},
			{"config.build_menu": {"farm": {"locked": false, "once": false}, "granary": {"locked": true, "once": true}}}],
		["an empty menu", {}, {"config.build_menu": {}}],
	], menu_load)
	check_loads([
		["no build_menu: {}", {}, {"config.build_menu": {}}],
	], config_load.bind([TECHS]))


func test_build_menu_validation() -> void:
	check_cases([
		["unknown card", [{"dragon": {}}, {}], "config.json: build_menu: unknown card 'dragon'"],
		["an action", [{"scout": {}}, {}], "config.json: build_menu: 'scout' is an action"],
		["locked not a bool", [{"farm": {"locked": 1}}, {}], "config.json: build_menu: 'farm': 'locked' must be true or false"],
		["once not a bool", [{"farm": {"once": "yes"}}, {}], "config.json: build_menu: 'farm': 'once' must be true or false"],
		["also in the supply", [{"farm": {}}, {"supply": {"farm": {"price": 2, "count": 1}}}],
			"config.json: build_menu: 'farm' is also in the supply"],
		["unknown field", [{"farm": {"price": 2}}, {}], "config.json: build_menu: 'farm': unknown field 'price'",
			"warning_only"],
	], menu_load.callv)


func test_an_unlock_may_name_a_build_menu_entry() -> void:
	var r := menu_load({"granary": {"locked": true}}, {"research_deck": {"kiln": 1}})
	eq(r.errors, [] as Array[String], "Kiln unlocks the Granary entry")
	r = menu_load({}, {"research_deck": {"kiln": 1}})
	check(has_message(r.errors, "'kiln' unlocks 'granary', which has no supply pile"), "neither: %s" % [r.errors])


# --- Backlog 299: build_preview ---

## A unit of strength 2 for 1 food.
const SPEARS := {"id": "spears", "name": "Spears", "type": "unit", "cost": {"food": 1}, "strength": 2}


## build_engine with Paddy, Well and Spears on the menu and River settled at 2 pop; 4 food. gov "" for no government.
func preview_engine(gov := "band") -> GameEngine:
	var starting := {"resources": {"food": 4, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"build_menu": {"paddy": {}, "well": {}, "spears": {}, "granary": {"locked": true}}, "population": POP, "starting": starting,
		"territory_deck": {"river": 1}}
	var e := tech_engine(["kiln", "pottery"], {"scout": 10}, o, [OBELISK, POTTERY_KILN, FARMERS, SPEARS] + TEST_GOVS)
	settle(e, ["river"])
	e.zone("tableau").find(river_of(e)).pop = 2
	e.resources.food = 4
	return e


func river_of(e: GameEngine) -> int:
	return uid_of(e.zone("tableau"), "river")


func test_a_preview_lists_the_cost_and_what_building_would_change() -> void:
	var e := preview_engine()
	var river := river_of(e)
	var food: int = e.upkeep_forecast().get(GameEngine.FOOD, 0)
	eq([e.free_slots(river), e.free_workers(river), e.actions_left()], [2, 2, 2], "precondition: slots, workers, actions")
	eq(e.build_preview("paddy", river), {"cost": {"food": 2}, "lines": [["food", food, food + 2], ["free_slots", 2, 1],
		["free_workers", 2, 1], ["actions_left", 2, 1]]}, "Paddy on River (+1, +1 on a flood plain)")


func test_a_preview_lists_only_what_changes() -> void:
	var e := preview_engine()
	var river := river_of(e)
	eq(e.build_preview("well", river).get("lines"), [["free_slots", 2, 1], ["free_workers", 2, 1], ["actions_left", 2, 1]],
		"a Well changes no forecast")
	var d: int = e.military.defense(river)
	eq(e.build_preview("spears", river).get("lines"), [["free_workers", 2, 1], ["defense", d, d + 2],
		["actions_left", 2, 1]], "a unit takes no slot and defends")
	var free := preview_engine("")
	eq(free.build_preview("well", river_of(free)).get("lines"), [["free_slots", 2, 1], ["free_workers", 2, 1]],
		"no actions line while actions are unlimited")


func test_a_refused_preview_is_empty_and_a_preview_changes_nothing() -> void:
	var e := preview_engine()
	var river := river_of(e)
	eq(e.build_preview("granary", river), {}, "a locked entry")
	eq(e.build_preview("well", home_uid(e)), {}, "a territory it can't go on")
	var before := e.state.copy()
	var signals: Array[String] = []
	e.changed.connect(func(): signals.append("changed"))
	e.card_played.connect(func(_o): signals.append("card_played"))
	e.build_preview("paddy", river)
	eq(state_diff(e.state, before), "", "the game is untouched")
	eq(signals, [] as Array[String], "no signal")


# --- Backlog 297: the cost the Build modal shows ---

func test_build_cost_is_an_entrys_cost_after_discounts() -> void:
	var e := build_engine(3)
	eq(e.call("build_cost", "farm"), {"food": 2}, "Farm's printed cost")
	eq(e.call("build_cost", "granary"), {"food": 1}, "a locked entry still has a cost")
	eq(e.call("build_cost", "scout"), {}, "no entry: {}")
	var sumer := build_engine(3, MENU, {"starting": {"resources": {"food": 3, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland", "government": "band", "civilization": "farmers"}})
	eq(sumer.call("build_cost", "farm"), {"food": 1}, "Farmers' discount")


## 297: why nothing can be built now, whatever the entry (Build… and the "+ Build" slots' reason), or "".
func test_build_menu_error_says_why_nothing_can_be_built() -> void:
	var e := build_engine(3, MENU, {"territory_deck": {"hills": 1, "grassland": 1}})
	eq(e.call("build_menu_error"), "", "nothing blocks building")
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	eq(e.call("build_menu_error"), "Choose a territory first.", "a territory choice owed")
	var over := build_engine(3, MENU, {"turn_limit": 1})
	over.end_turn()
	eq(over.call("build_menu_error"), "The game is over.", "game over")
