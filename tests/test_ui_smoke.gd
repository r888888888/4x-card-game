extends "res://tests/lib/test_case.gd"
## Headless UI smoke test (backlog 045): the real main scene follows a ScriptedBot game on the real data (shortened to
## SEED_1_TURNS turns by play_seed_1, 066) without script errors (the runner fails a test on any logged error). No
## frames run, so animations never finish; the checks are on structure (views, overlay text), not on rendering.

const SETTINGS_PATH := "user://settings.cfg"


func test_main_scene_follows_a_whole_game_without_errors() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	check(Game.engine.is_over, "the bot finished the game")
	close_main(main)


func test_hand_views_match_the_hand_after_every_turn() -> void:
	var main := open_main()
	var mismatches: Array[String] = []
	var checked := [0]
	play_seed_1(main, func(m):
		checked[0] += 1
		var views: int = m.hand_view_count()
		var cards := Game.engine.zone("hand").size()
		if views != cards:
			mismatches.append("turn %d: %d views, %d cards" % [Game.engine.turn, views, cards]))
	check(checked[0] >= Game.engine.turn_limit() - 1, "checked after each turn (%d checks)" % checked[0])
	eq(mismatches, [] as Array[String], "hand views vs hand cards")
	close_main(main)


func test_game_over_overlay_shows_score_and_seed() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	var text: String = main.game_over_text()
	check(text.contains("Final score: %d" % Game.engine.score()), "score in '%s'" % text)
	check(text.contains("Seed: 1"), "seed in '%s'" % text)
	close_main(main)


func test_smoke_test_frees_the_scene_and_leaves_settings_alone() -> void:
	var existed := FileAccess.file_exists(SETTINGS_PATH)
	var modified := FileAccess.get_modified_time(SETTINGS_PATH) if existed else 0
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	close_main(main)
	check(not is_instance_valid(main), "main scene freed")
	eq(FileAccess.file_exists(SETTINGS_PATH), existed, "settings file created or deleted")
	if existed:
		eq(FileAccess.get_modified_time(SETTINGS_PATH), modified, "settings file modified time")


## Backlog 071: every card type mark is drawn as an icon from assets/icons/, so a new type can't go without one.
func test_every_type_mark_has_an_icon() -> void:
	var missing: Array[String] = []
	for type in CardFace.TYPE_MARKS:
		var mark: String = CardFace.TYPE_MARKS[type]
		if not Icons.GLYPHS.has(mark):
			missing.append("%s (%s)" % [type, mark])
			continue
		var path: String = Icons.GLYPHS[mark][0].resource_path
		check(path.begins_with("res://assets/icons/") and path.ends_with(".svg"), "%s's icon is an SVG in assets/icons/: %s" % [type, path])
	eq(missing, [] as Array[String], "type marks with no icon")


## Backlog 066: the turn counter reads "Turn 37 / 100" in full at the base resolution.
func test_the_turn_counter_shows_turn_37_of_100_untruncated() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var old_size := window.size
	window.size = Vector2i(1920, 1080)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"scout": 10}, {"turn_limit": 100}), resources(), cards, "test",
		errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	var main := open_main()
	main.start_game(1)
	for i in 36:
		Game.engine.end_turn()
	await wait_frames()
	var turn: Label = null
	for label in main.find_children("*", "Label", true, false):
		if label.text.begins_with("Turn "):
			turn = label
	check(turn != null, "a turn label")
	if turn != null:
		eq(turn.text, "Turn 37 / 100", "turn label")
		check(turn.get_minimum_size().x <= turn.size.x + 0.5, "not truncated (%d <= %d)" % [turn.get_minimum_size().x, turn.size.x])
		check(turn.get_global_rect().end.x <= 1920, "on screen")
	close_main(main)
	Game.engine = real
	window.size = old_size

