extends "res://tests/lib/test_case.gd"
## Choosing a civilization (backlog 064): config `civilizations`, civilizations(), new_game(seed, civ_id) and
## new_game_error(civ_id). Fixtures: TEST_CIVS Tribe (start +3 food, upkeep +1 wealth) and Nomads (1 VP, upkeep
## score 1).

const LISTED := {"civilizations": ["tribe", "nomads"]}


func with_starting(civ: String, overrides := {}) -> Dictionary:
	var o := {"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "civilization": civ}}
	o.merge(overrides, true)
	return o


## A game on civ_db with the civilizations list and starting.civilization civ ("" for none).
func listed_engine(civ := "", deck := {"farm": 10}) -> GameEngine:
	return civ_engine(civ, deck, LISTED)


# --- AC1: config civilizations ---

func test_civilizations_list_loads() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 1}, LISTED), resources(), civ_db(), "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "warnings")
	eq(config.get("civilizations"), ["tribe", "nomads"] as Array[String], "civilizations in order")


func test_civilizations_list_is_optional() -> void:
	eq(config_errors({}, [TEST_CIVS]), [] as Array[String], "no list")
	eq(config_errors(with_starting("tribe"), [TEST_CIVS]), [] as Array[String], "starting.civilization without a list")


func test_civilizations_list_validation() -> void:
	check_cases([
		["unknown id", {"civilizations": ["zzz"]}, "config.json: civilizations: unknown card 'zzz'", "one_error"],
		["not a civilization", {"civilizations": ["farm"]}, "config.json: civilizations: 'farm' is not a civilization", "one_error"],
		["duplicate", {"civilizations": ["tribe", "nomads", "tribe"]}, "config.json: civilizations: 'tribe' is listed twice", "one_error"],
		["not an array", {"civilizations": "tribe"}, "config.json: 'civilizations' must be", "one_error"],
		["starting civilization not listed", with_starting("tribe", {"civilizations": ["nomads"]}),
			"config.json: starting.civilization: 'tribe' is not in 'civilizations'", "one_error"],
	], func(overrides): return config_errors(overrides, [TEST_CIVS]))
	eq(config_errors(with_starting("nomads", LISTED), [TEST_CIVS]), [] as Array[String], "starting civilization in the list")


# --- AC2: civilizations() and new_game(seed, civ_id) ---

func test_civilizations_returns_the_list_in_order() -> void:
	var e: GameEngine = listed_engine()
	eq(e.civilizations(), ["tribe", "nomads"] as Array[String], "civilizations()")


func test_civilizations_is_empty_without_a_list() -> void:
	var e: GameEngine = civ_engine("tribe")
	eq(e.civilizations(), [] as Array[String], "civilizations()")


func test_new_game_with_a_civilization_uses_it() -> void:
	var e: GameEngine = listed_engine("tribe")
	e.new_game(1, "nomads")
	eq(card_ids(e.zone("civilization")), ["nomads"] as Array[String], "Nomads chosen over starting Tribe")
	eq(e.score(), 4, "Capital 2 + Nomads 1 + 1 upkeep")


func test_new_game_without_a_civilization_uses_starting() -> void:
	var e: GameEngine = listed_engine("tribe")
	e.new_game(1, "")
	eq(card_ids(e.zone("civilization")), ["tribe"] as Array[String], "starting.civilization")
	e.new_game(1)
	eq(card_ids(e.zone("civilization")), ["tribe"] as Array[String], "civ_id defaults to \"\"")


func test_new_game_without_any_civilization_has_none() -> void:
	var e: GameEngine = listed_engine("")
	e.new_game(1, "")
	eq(e.civilization(), -1, "no civilization")


# --- AC3: new_game_error ---

func test_new_game_error_accepts_a_listed_civilization_or_none() -> void:
	var e: GameEngine = listed_engine()
	eq(e.new_game_error("tribe"), "", "tribe")
	eq(e.new_game_error("nomads"), "", "nomads")
	eq(e.new_game_error(""), "", "none")


func test_new_game_error_names_an_unlisted_civilization() -> void:
	var e: GameEngine = listed_engine()
	eq(e.new_game_error("zzz"), "Unknown civilization 'zzz'.", "unknown id")
	eq(e.new_game_error("farm"), "Unknown civilization 'farm'.", "not a civilization")


func test_new_game_with_an_unlisted_civilization_changes_nothing() -> void:
	var e: GameEngine = listed_engine("tribe")
	e.end_turn()
	var changes := [0]
	e.changed.connect(func(): changes[0] += 1)
	var before := {"seed": e.seed_value, "turn": e.turn, "resources": e.resources.duplicate(),
		"hand": card_ids(e.zone("hand")), "civ": card_ids(e.zone("civilization"))}
	e.new_game(7, "zzz")
	eq({"seed": e.seed_value, "turn": e.turn, "resources": e.resources,
		"hand": card_ids(e.zone("hand")), "civ": card_ids(e.zone("civilization"))}, before, "state")
	eq(changes[0], 0, "changed not emitted")


# --- AC4: the civilization doesn't change the seeded shuffle ---

func test_same_seed_same_decks_whatever_the_civilization() -> void:
	var deck := {"farm": 3, "scout": 3, "temple": 3, "settler": 3}
	var o := {"civilizations": ["tribe", "nomads"], "territory_deck": {"grassland": 2, "hills": 2, "river": 2, "jungle": 2}}
	var a: GameEngine = civ_engine("", deck, o)
	var b: GameEngine = civ_engine("", deck, o)
	for s in [3, 11, 42]:
		a.new_game(s, "tribe")
		b.new_game(s, "nomads")
		for z in ["deck", "hand", "territory_deck"]:
			eq(card_ids(a.zone(z)), card_ids(b.zone(z)), "seed %d: %s order" % [s, z])
		var rolls_a := []
		var rolls_b := []
		for c in a.zone("territory_deck").cards:
			rolls_a.append(a.territory_keywords(c.uid))
		for c in b.zone("territory_deck").cards:
			rolls_b.append(b.territory_keywords(c.uid))
		eq(rolls_a, rolls_b, "seed %d: territory keywords" % s)
		a.end_turn()
		b.end_turn()
		eq(card_ids(a.zone("hand")), card_ids(b.zone("hand")), "seed %d: turn 2 hand" % s)
