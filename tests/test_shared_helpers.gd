extends "res://tests/lib/test_case.gd"
## Shared test helpers (backlog 334): the UI helpers the tests used to copy file to file live in test_case.gd
## (shown_button, wait_seconds, open_game/close_game, click_control, click_point, open_details), and the suite fails on a
## test file that copies a helper tests/lib/ defines. The checks live in tests/lib/helper_checks.gd.

const HelperChecks := preload("res://tests/lib/helper_checks.gd")
const DocChecks := preload("res://tests/lib/doc_checks.gd")
const SHARED := ["shown_button", "wait_seconds", "open_game", "close_game", "click_control", "click_point",
	"open_details", "click"]


## path -> source of the test files (tests/ and tests/balance/).
func suite_texts() -> Dictionary:
	var out := {}
	for path in DocChecks.suite_files():
		out[path] = FileAccess.get_file_as_string("res://" + path)
	return out


## path -> source of tests/lib/'s scripts.
func lib_texts() -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at("res://tests/lib"):
		if file.ends_with(".gd"):
			out["tests/lib/" + file] = FileAccess.get_file_as_string("res://tests/lib/" + file)
	return out


# --- AC1, AC2: the shared helpers live in test_case.gd ---

func test_test_case_defines_the_shared_ui_helpers() -> void:
	var defined: Array = (load("res://tests/lib/test_case.gd") as Script).get_script_method_list().map(
		func(m: Dictionary) -> String: return m.name)
	for name in ["shown_button", "wait_seconds", "open_game", "close_game", "click_control", "click_point",
			"open_details"]:
		check(defined.has(name), "test_case.gd defines %s" % name)


func test_definitions_names_the_files_that_define_a_function() -> void:
	var texts := {"tests/test_a.gd": "func click(main: Node) -> void:\nfunc other() -> void:\n\tclick(main)\n",
		"tests/test_b.gd": "static func wait_seconds(s: float) -> void:\n## func click(\n"}
	eq(HelperChecks.definitions(texts, ["click", "wait_seconds"]),
		["tests/test_a.gd: click", "tests/test_b.gd: wait_seconds"] as Array[String], "definitions, not calls or comments")


func test_no_test_file_defines_a_shared_ui_helper_or_click() -> void:
	var texts := suite_texts()
	check(texts.size() >= 150, "the check reads the test files (%d)" % texts.size())
	eq(HelperChecks.definitions(texts, SHARED), [] as Array[String], "test files defining a shared helper")


# --- AC1: open_game and close_game ---

func test_open_game_starts_seed_1_and_close_game_frees_main() -> void:
	var main := await open_game()
	eq(Game.engine.turn, 1, "a game on turn 1")
	check(main.is_inside_tree(), "main in the tree")
	close_game(main)
	check(not is_instance_valid(main), "main freed")


func test_open_game_big_is_1920_by_1080_and_close_game_restores_the_window() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	var main := await open_game(true)
	eq(window.size, Vector2i(1920, 1080), "1920 × 1080 while open")
	close_game(main)
	eq(window.size, before, "the window's size back")


func test_open_game_freezes_the_sound_clock_when_asked() -> void:
	var main := await open_game(false, true)
	eq(main.sfx.clock(), 0.0, "the clock at 0")
	await wait_frames()
	eq(main.sfx.clock(), 0.0, "and held there")
	close_game(main)


# --- AC2: the two meanings of click ---

## A button on main at a known place, recording its presses.
func pressable(main: Node) -> Array:
	var b := Button.new()
	b.text = "Probe"
	b.position = Vector2(400, 300)
	b.size = Vector2(120, 40)
	main.add_child(b)
	var presses := [0]
	b.pressed.connect(func(): presses[0] += 1)
	return [b, presses]


func test_click_control_presses_and_releases_at_the_controls_centre() -> void:
	var main := open_main()
	var probe := pressable(main)
	await wait_frames()
	click_control(main, probe[0])
	eq(probe[1][0], 1, "one press")
	close_main(main)


func test_click_point_presses_and_releases_at_a_point() -> void:
	var main := open_main()
	var probe := pressable(main)
	await wait_frames()
	click_point(main, (probe[0] as Button).get_global_rect().get_center())
	eq(probe[1][0], 1, "one press")
	click_point(main, Vector2(5, 5))
	eq(probe[1][0], 1, "a click elsewhere presses nothing")
	close_main(main)


func test_open_details_sends_a_cards_details_requested() -> void:
	var main := await open_game()
	var uid: int = Game.engine.zone("hand").cards[0].uid
	var asked := []
	(main.views[uid] as CardView).details_requested.connect(func(v: CardView): asked.append(v.uid))
	open_details(main, uid)
	eq(asked, [uid], "details_requested for uid")
	close_game(main)


# --- AC3: no copies of a shared helper ---

func test_copies_names_a_lib_helper_defined_in_two_test_files() -> void:
	var tests := {"tests/test_a.gd": "func hills_of(e) -> int:\nfunc mine() -> void:\n",
		"tests/test_b.gd": "func hills_of(e) -> int:\nfunc mine() -> void:\n",
		"tests/test_c.gd": "func levy_of(e) -> int:\n"}
	var lib := {"tests/lib/raid_case.gd": "func hills_of(e) -> int:\nfunc levy_of(e) -> int:\n"}
	eq(HelperChecks.copies(tests, lib), ["hills_of: tests/test_a.gd, tests/test_b.gd"] as Array[String],
		"hills_of; not mine (not in lib) nor levy_of (one file)")


func test_no_test_file_copies_a_shared_helper() -> void:
	eq(HelperChecks.copies(suite_texts(), lib_texts()), [] as Array[String], "lib helpers copied into test files")


# --- 340: check_loads, config_load, and the one-off loader rejections ---

const ERA_2_TECH := {"id": "x", "name": "X", "type": "tech", "cost": {"insight": 1}, "era": 2}
const ONE_OFF_REJECTIONS := ["test_settle_non_city_is_error", "test_settle_unknown_card_is_error",
	"test_explore_reveal_0_is_error", "test_government_effect_needing_a_target_is_a_load_error",
	"test_territory_printing_resource_keyword_is_error", "test_unknown_resource_cost_is_still_an_error",
	"test_administers_only_applies_to_governments", "test_tolerates_only_applies_to_governments",
	"test_an_events_revolt_field_is_unknown", "test_growth_surplus_is_an_unknown_population_field",
	"test_unrest_fallback_is_no_longer_read", "test_unrest_relief_is_no_longer_read",
	"test_population_start_must_fit_each_listed_home"]


## A fresh test case to run a helper on, so its failures are its own, not this test's.
func probe() -> Object:
	var t: Object = load("res://tests/lib/test_case.gd").new()
	t.test_name = "probe"
	return t


## The probe's failures after check_loads runs rows on a load that returns {cards: fixture_load's, config, errors,
## warnings}.
func probe_failures(rows: Array, config := {}, errors: Array[String] = [], warnings: Array[String] = []) -> Array[String]:
	var t := probe()
	var loaded := fixture_load([ERA_2_TECH])
	t.check_loads(rows, func(_input: Variant) -> Dictionary:
		return {"cards": loaded.cards, "config": config, "errors": errors, "warnings": warnings})
	return t.failures


func test_check_loads_passes_a_clean_row_whose_paths_match() -> void:
	var t := probe()
	var loaded := fixture_load([ERA_2_TECH])
	t.check_loads([["era 2", null, {"cards.x.era": 2, "cards.x.cost.insight": 1, "cards.x.is_permanent()": true}]],
		func(_input: Variant) -> Dictionary: return loaded)
	eq(t.failures, [] as Array[String], "failures")
	check(t.assertions > 0, "the row's checks count as assertions")


func test_check_loads_names_the_row_and_path_of_a_wrong_value() -> void:
	var failures := probe_failures([["era 1", null, {"cards.x.era": 1}]])
	eq(failures.size(), 1, "one failure: %s" % [failures])
	check(failures.size() == 1 and "era 1" in failures[0] and "cards.x.era" in failures[0],
		"names the label and the path: %s" % [failures])


func test_check_loads_fails_a_row_that_loads_with_a_warning_or_an_error() -> void:
	var warned := probe_failures([["warned", null, {"cards.x.era": 2}]], {}, [], ["'zz' is unknown (ignored)"])
	check(warned.size() == 1 and "warned" in warned[0] and "'zz' is unknown" in warned[0],
		"names the label and the warning: %s" % [warned])
	var failed := probe_failures([["failed", null, {}]], {}, ["'era' must be an integer"])
	check(failed.size() == 1 and "failed" in failed[0] and "'era' must be an integer" in failed[0],
		"names the label and the error: %s" % [failed])


func test_check_loads_a_missing_path_is_a_failure_naming_the_path() -> void:
	var failures := probe_failures([["missing", null, {"cards.y.era": 1, "cards.x.nope": 1, "config.list.5": 1,
		"cards.x.nope()": 1}]], {"list": ["a"]})
	eq(failures.size(), 4, "one failure per missing path: %s" % [failures])
	for path in ["cards.y.era", "cards.x.nope", "config.list.5", "cards.x.nope()"]:
		check(failures.any(func(f: String) -> bool: return "missing" in f and path in f), "names %s: %s" % [path, failures])


func test_check_loads_indexes_arrays_and_int_keys_and_calls_builtin_methods() -> void:
	var failures := probe_failures([["builtins", null, {"config.list.1": "b", "config.list.size()": 2,
		"config.unlocks.2.pop": 8, "config.unlocks.keys()": [2]}]], {"list": ["a", "b"], "unlocks": {2: {"pop": 8}}})
	eq(failures, [] as Array[String], "failures")


func test_config_load_returns_cards_config_errors_and_warnings() -> void:
	var r: Dictionary = probe().config_load({"event_deck": {"windfall": 2.0}}, [TEST_EVENTS])
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	check(r.cards.has("windfall"), "the sets' cards")
	eq(r.config.get("event_deck"), {"windfall": 2}, "the parsed config")
	has_msg(probe().config_load({"event_deck": {"nowhere": 1}}, [TEST_EVENTS]).errors, "config.json: event_deck")


func test_the_one_off_loader_rejections_are_table_rows() -> void:
	var defined: Array[String] = []
	for text: String in suite_texts().values():
		for name: String in ONE_OFF_REJECTIONS:
			if ("func %s(" % name) in text:
				defined.append(name)
	eq(defined, [] as Array[String], "one-off rejection tests still defined")
