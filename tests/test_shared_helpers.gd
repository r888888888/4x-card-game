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
	var main: Node = await call("open_game")
	eq(Game.engine.turn, 1, "a game on turn 1")
	check(main.is_inside_tree(), "main in the tree")
	call("close_game", main)
	check(not is_instance_valid(main), "main freed")


func test_open_game_big_is_1920_by_1080_and_close_game_restores_the_window() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	var main: Node = await call("open_game", true)
	eq(window.size, Vector2i(1920, 1080), "1920 × 1080 while open")
	call("close_game", main)
	eq(window.size, before, "the window's size back")


func test_open_game_freezes_the_sound_clock_when_asked() -> void:
	var main: Node = await call("open_game", false, true)
	eq(main.sfx.clock(), 0.0, "the clock at 0")
	await wait_frames()
	eq(main.sfx.clock(), 0.0, "and held there")
	call("close_game", main)


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
	call("click_control", main, probe[0])
	eq(probe[1][0], 1, "one press")
	close_main(main)


func test_click_point_presses_and_releases_at_a_point() -> void:
	var main := open_main()
	var probe := pressable(main)
	await wait_frames()
	call("click_point", main, (probe[0] as Button).get_global_rect().get_center())
	eq(probe[1][0], 1, "one press")
	call("click_point", main, Vector2(5, 5))
	eq(probe[1][0], 1, "a click elsewhere presses nothing")
	close_main(main)


func test_open_details_sends_a_cards_details_requested() -> void:
	var main: Node = await call("open_game")
	var uid: int = Game.engine.zone("hand").cards[0].uid
	var asked := []
	(main.views[uid] as CardView).details_requested.connect(func(v: CardView): asked.append(v.uid))
	call("open_details", main, uid)
	eq(asked, [uid], "details_requested for uid")
	call("close_game", main)


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
