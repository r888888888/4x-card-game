extends "res://tests/lib/test_case.gd"
## Headless UI smoke test (backlog 045): the real main scene follows a whole ScriptedBot game on the real data
## without script errors (the runner fails a test on any logged error). No frames run, so animations never
## finish; the checks are on structure (views, overlay text), not on rendering.

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
