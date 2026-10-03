extends "res://tests/lib/test_case.gd"
## Territory names (backlog 248): each settled territory takes the next of its civilization's `city_names` (the
## starting territory the first), then the list again with numerals (II, III, …); without a list a territory keeps its
## card's name. rename_territory / rename_territory_error rename a settled territory. Fixtures: Founders name their
## cities Alpha, Beta, Gamma; Tribe (TEST_CIVS) has no list.

const NAMED_CIVS := [
	{"id": "founders", "name": "Founders", "type": "civilization", "city_names": ["Alpha", "Beta", "Gamma"]},
]


## TEST_CARDS + TEST_CIVS + NAMED_CIVS + extra, parsed.
func names_db(extra: Array = [], errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_CIVS + NAMED_CIVS + extra}, resources(), "cards.json",
		errors, warnings, keywords())


## A game as civilization civ ("" for none) with a hand of Pioneers and 3 of each of Hills, Grassland and River to settle.
func names_engine(civ: String) -> Object:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := names_db([], errors, warnings)
	var overrides := {"civilizations": ["tribe", "founders"], "territory_deck": {"hills": 3, "grassland": 3, "river": 3}}
	var config := DataLoader.parse_config(raw_config({"pioneer": 20}, overrides), resources(), cards, "config.json",
		errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1, civ)
	return e


## Moves territory id to the frontier and settles it with a Pioneer from the hand; returns its uid.
func settle_one(e: GameEngine, id: String) -> int:
	to_frontier(e, [id])
	var uid := uid_of(e.zone("frontier"), id)
	e.resources.food = 3
	e.state.actions_used = 0
	check(e.play_card(put_in_hand(e, "pioneer"), uid), "settle %s" % id)
	return uid


# --- AC1: the civilization's names, in order ---

func test_settled_territories_take_the_civilizations_names_in_order() -> void:
	var e: Object = names_engine("founders")
	eq(e.territory_name(home_uid(e)), "Alpha", "the starting territory")
	eq(e.territory_name(settle_one(e, "hills")), "Beta", "the first settled")
	eq(e.territory_name(settle_one(e, "grassland")), "Gamma", "the second settled")


# --- AC2: the list again with numerals ---

func test_names_repeat_with_numerals_when_the_list_runs_out() -> void:
	var e: Object = names_engine("founders")
	var names: Array[String] = []
	for id in ["hills", "grassland", "river", "hills", "grassland", "river"]:
		names.append(e.territory_name(settle_one(e, id)))
	eq(names, ["Beta", "Gamma", "Alpha II", "Beta II", "Gamma II", "Alpha III"] as Array[String], "names settled")


# --- AC3: no list, and the frontier ---

func test_without_city_names_a_territory_keeps_its_card_name() -> void:
	var tribe: Object = names_engine("tribe")
	eq(tribe.territory_name(home_uid(tribe)), "Homeland", "Tribe's starting territory")
	eq(tribe.territory_name(settle_one(tribe, "hills")), "Hills", "Tribe settles Hills")
	var none: Object = names_engine("")
	eq(none.territory_name(settle_one(none, "river")), "River", "no civilization")


func test_a_frontier_territory_has_its_card_name() -> void:
	var e: Object = names_engine("founders")
	to_frontier(e, ["hills"])
	eq(e.territory_name(uid_of(e.zone("frontier"), "hills")), "Hills", "frontier Hills")
	eq(e.territory_name(settle_one(e, "grassland")), "Beta", "the frontier didn't use a name")


# --- AC4: renaming ---

func test_rename_trims_the_name_and_spends_nothing() -> void:
	var e: Object = names_engine("founders")
	var home := home_uid(e)
	var resources_before: Dictionary = e.resources.duplicate()
	var actions_before: int = e.state.actions_used
	eq(e.rename_territory_error(home, "  Nile Gate  "), "", "a good name")
	check(e.rename_territory(home, "  Nile Gate  "), "rename returns true")
	eq(e.territory_name(home), "Nile Gate", "renamed, trimmed")
	eq(e.resources, resources_before, "no resource spent")
	eq(e.state.actions_used, actions_before, "no action spent")


func test_renaming_does_not_shift_the_next_default_name() -> void:
	var e: Object = names_engine("founders")
	e.rename_territory(home_uid(e), "Alpha Prime")
	eq(e.territory_name(settle_one(e, "hills")), "Beta", "the next name is still Beta")
	var tribe: Object = names_engine("tribe")
	check(tribe.rename_territory(home_uid(tribe), "Camp"), "a territory with no list can be renamed")
	eq(tribe.territory_name(home_uid(tribe)), "Camp", "Tribe's renamed home")


# --- AC5: refusals ---

func test_rename_territory_error_refuses_bad_names_and_targets() -> void:
	var e: Object = names_engine("founders")
	var home := home_uid(e)
	var beta := settle_one(e, "hills")
	to_frontier(e, ["river"])
	var frontier := uid_of(e.zone("frontier"), "river")
	var capital := uid_of(e.zone("tableau"), "capital")
	var long_name := "x".repeat(25)
	eq(e.rename_territory_error(home, "   "), "Enter a name.", "blank")
	check(e.rename_territory_error(home, long_name) != "", "25 characters")
	eq(e.rename_territory_error(home, "  %s  " % "x".repeat(24)), "", "24 characters after trimming")
	eq(e.rename_territory_error(home, "Beta"), "", "a name another territory has")
	for uid in [frontier, capital, 999]:
		check(e.rename_territory_error(uid, "Delta") != "", "uid %d isn't a settled territory" % uid)
	for row in [[home, "   "], [home, long_name], [frontier, "Delta"], [capital, "Delta"], [999, "Delta"]]:
		var before: GameState = e.state.copy()
		check(not e.rename_territory(row[0], row[1]), "rename %s to '%s' refused" % row)
		eq(state_diff(e.state, before), "", "refused rename changes nothing; changed")
	eq(e.territory_name(beta), "Beta", "Beta untouched")


func test_rename_is_refused_while_a_decision_is_owed_or_the_game_is_over() -> void:
	var explore := explore_engine()
	eq(explore.call("rename_territory_error", home_uid(explore), "Delta"), "Choose a territory first.", "explore owed")
	var over := over_engine()
	eq(over.call("rename_territory_error", home_uid(over), "Delta"), "The game is over.", "game over")


# --- AC6: names are game state ---

func test_names_survive_a_state_copy() -> void:
	var e: Object = names_engine("founders")
	var beta := settle_one(e, "hills")
	e.rename_territory(beta, "Delta")
	var fork: Object = e.fork()
	eq(fork.territory_name(beta), "Delta", "the renamed territory in the copy")
	eq(fork.territory_name(home_uid(fork)), "Alpha", "the starting territory in the copy")
	eq(fork.territory_name(settle_one(fork, "grassland")), "Gamma", "the copy settles the next name")


# --- AC7: loading city_names ---

func test_city_names_load_on_a_civilization() -> void:
	var errors: Array[String] = []
	var cards := names_db([], errors)
	eq(errors, [] as Array[String], "no errors")
	eq(cards.founders.get("city_names"), ["Alpha", "Beta", "Gamma"] as Array[String], "Founders' names")
	eq(cards.tribe.get("city_names"), [] as Array[String], "no names by default")


func test_city_names_validation() -> void:
	check_cases([
		["not a list", [{"id": "a", "name": "A", "type": "civilization", "city_names": "Ur"}],
			["cards.json: card 'a'", "city_names"]],
		["not strings", [{"id": "b", "name": "B", "type": "civilization", "city_names": ["Ur", 3]}],
			["cards.json: card 'b'", "city_names"]],
		["empty name", [{"id": "c", "name": "C", "type": "civilization", "city_names": ["Ur", " "]}],
			["cards.json: card 'c'", "city_names"]],
		["repeated name", [{"id": "d", "name": "D", "type": "civilization", "city_names": ["Ur", "Kish", "Ur"]}],
			["cards.json: card 'd'", "city_names", "'Ur'"]],
	], func(extra):
		var errors: Array[String] = []
		names_db(extra, errors)
		return errors)
	var warnings: Array[String] = []
	names_db([{"id": "hut", "name": "Hut", "type": "building", "city_names": ["Ur"]}], [] as Array[String], warnings)
	has_msg(warnings, "card 'hut': 'city_names' only applies to civilizations")
