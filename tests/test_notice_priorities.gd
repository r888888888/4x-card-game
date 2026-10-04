extends "res://tests/lib/test_case.gd"
## Notice priorities (190): the engine's three priorities, and the toast that hears and shows them in the real
## main.tscn (a bell pattern each, a hue bar on its rail side; how long a flag stays: test_notification_flags, 250). Each notice's
## priority is checked beside its scenario (check_noticed in test_famine, test_anarchy, test_revolution, …).

const PRIORITIES := [[&"info", &"INSIGHT"], [&"caution", &"WEALTH"], [&"urgent", &"WARN"]]


func open_game() -> Node:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.sfx.set_clock(0.0)
	return main


# --- AC1 ---

func test_there_are_three_priorities() -> void:
	eq([GameEngine.NOTICE_INFO, GameEngine.NOTICE_CAUTION, GameEngine.NOTICE_URGENT], [&"info", &"caution", &"urgent"],
		"info, caution, urgent")


# --- AC5: heard and seen ---

func test_each_priority_rings_its_own_pattern() -> void:
	var main: Node = await open_game()
	main.toasts.notice("Pottery can now be bought.", GameEngine.NOTICE_INFO)
	main.toasts.notice("A new era stirs the people: +2 unrest.", GameEngine.NOTICE_CAUTION)
	main.toasts.notice("Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
	var bells: Array = main.sfx.played().filter(func(r): return Sfx.NOTIFICATIONS.has(r.token)).map(func(r): return r.token)
	eq(bells, [Sfx.NOTIFICATION_INFO, Sfx.NOTIFICATION_CAUTION, Sfx.NOTIFICATION_URGENT], "one bell, two, a falling pair")
	eq(main.sfx.played().filter(func(r): return Sfx.NOTIFICATIONS.has(r.token)).map(func(r): return r.db), [0.0, 0.0, 0.0],
		"all at the same volume")
	close_main(main)


func test_each_toast_carries_its_priority_as_a_hue_bar() -> void:
	var main: Node = await open_game()
	for p in PRIORITIES:
		main.toasts.notice("A %s notice." % p[0], p[0])
	eq(main.toasts.priorities(), [GameEngine.NOTICE_INFO, GameEngine.NOTICE_CAUTION, GameEngine.NOTICE_URGENT],
		"the flags' priorities, top to bottom (250: newest at the bottom)")
	var shown: Array = main.toasts.shown()
	for i in shown.size():
		var want: Array = PRIORITIES[i]
		eq(main.toasts.bar_role(shown[i]), want[1], "a %s toast's bar" % want[0])
	eq((Toasts as Script).get_script_constant_map().get("BAR_WIDTH"), 4, "4 px")
	close_main(main)


func test_the_engines_notice_reaches_the_toast_with_its_priority() -> void:
	var main: Node = await open_game()
	Game.engine.noticed.emit("Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
	eq(main.toasts.priorities(), [GameEngine.NOTICE_URGENT], "urgent")
	check(main.sfx.played().any(func(r): return r.token == Sfx.NOTIFICATION_URGENT), "the urgent bell")
	close_main(main)


# --- AC6: urgent stays longer (until dismissed since 250: test_notification_flags) ---
