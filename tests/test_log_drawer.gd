extends "res://tests/lib/test_case.gd"
## The log drawer in the real main scene (backlog 115): closed at the start, L or the top bar's Log button opens
## it from the right edge over the board, L / Esc / the button / a click outside close it, lines append open or
## closed, a new game clears it. Hook: main.log_drawer (is_open(), text(): the log as plain text).


## Runs body(main) on a seed 1 game of the real data, with Reduce motion set to calm.
func with_game(calm: bool, body: Callable) -> void:
	await with_reduce_motion(calm, func():
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		await body.call(main)
		close_main(main))


## The first visible button under root whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


func drawer_rect(main: Node) -> Rect2:
	return (main.log_drawer as Control).get_global_rect()


func click_at(main: Node, point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		main.get_viewport().push_input(event)


# --- AC5: the drawer ---

func test_the_log_starts_closed_and_off_screen() -> void:
	await with_game(false, func(main: Node):
		var drawer: Object = main.log_drawer
		check(not drawer.is_open(), "closed")
		check(not (drawer as Control).is_visible_in_tree(), "not shown"))


func test_l_opens_the_drawer_at_the_right_edge_with_the_log_so_far() -> void:
	await with_game(false, func(main: Node):
		var drawer: Object = main.log_drawer
		var width: float = main.get_viewport_rect().size.x
		press_key(main, KEY_L)
		check(drawer.is_open(), "L opens it")
		await wait_frames()
		check(drawer_rect(main).end.x > width + 1.0, "it starts off the right edge and slides in: %s" % drawer_rect(main))
		await wait_screen_transition()
		var r := drawer_rect(main)
		check(absf(r.end.x - width) <= 1.0, "then rests against the right edge: %s" % r)
		check(r.size.x < width / 2, "a drawer, not the whole screen: %s" % r)
		check(str(drawer.text()).contains("New game — seed 1"), "the log so far: %s" % drawer.text())
		press_key(main, KEY_L)
		check(not drawer.is_open(), "L again closes it"))


func test_with_reduce_motion_the_drawer_fades_in_place() -> void:
	await with_game(true, func(main: Node):
		var width: float = main.get_viewport_rect().size.x
		press_key(main, KEY_L)
		await wait_frames()
		var drawer := main.log_drawer as Control
		check(absf(drawer_rect(main).end.x - width) <= 1.0, "at the right edge at once: %s" % drawer_rect(main))
		check(drawer.modulate.a < 1.0, "fading in: %s" % drawer.modulate.a)
		await wait_screen_transition()
		eq(drawer.modulate.a, 1.0, "then opaque"))


func test_the_log_button_esc_and_a_click_outside_close_it() -> void:
	await with_game(true, func(main: Node):
		var drawer: Object = main.log_drawer
		var button := shown_button(main, "Log")
		check(button != null, "a Log button")
		if button == null:
			return
		button.pressed.emit()
		check(drawer.is_open(), "the button opens it")
		button.pressed.emit()
		check(not drawer.is_open(), "the button again closes it")
		press_key(main, KEY_L)
		await wait_screen_transition()
		press_key(main, KEY_ESCAPE)
		check(not drawer.is_open(), "Esc closes it")
		check(not main.menu_buttons()[0].is_visible_in_tree(), "Esc doesn't also open the menu")
		press_key(main, KEY_L)
		await wait_screen_transition()
		click_at(main, Vector2(100, 500))  # on the board, left of the drawer
		check(not drawer.is_open(), "a click outside closes it"))


## The drawer's "Deck N · Discard M" label (121), or null.
func pile_counts(main: Node) -> Label:
	for node in (main.log_drawer as Node).find_children("*", "Label", true, false):
		if (node as Label).text.begins_with("Deck "):
			return node
	return null


func counts_now() -> String:
	return "Deck %d · Discard %d" % [Game.engine.zone("deck").size(), Game.engine.zone("discard").size()]


# --- 121: the pile counts ---

func test_the_drawer_shows_the_deck_and_discard_counts() -> void:
	await with_game(true, func(main: Node):
		main.log_drawer.open()
		await wait_frames()
		var counts := pile_counts(main)
		check(counts != null and counts.is_visible_in_tree(), "the counts in the open drawer")
		if counts == null:
			return
		eq(counts.text, counts_now(), "the engine's counts")
		var before := counts.text
		for i in 2:  # the full hand is kept between turns: discard so the counts move
			check(Game.engine.discard_card(Game.engine.zone("hand").cards[0].uid), "discard a hand card")
		Game.engine.end_turn()
		eq(counts.text, counts_now(), "updated after a turn")
		check(counts.text != before, "and they changed: %s, %s" % [before, counts.text]))


func test_dealt_cards_start_from_the_log_button_and_it_pulses_as_cards_arrive() -> void:
	await with_game(false, func(main: Node):
		var button: Button = null
		for b in UIKit.buttons_in(main):
			if b.text.begins_with("Log"):
				button = b
		var origin := button.get_global_rect().get_center()
		for i in 2:  # room in the hand, so the next turn deals cards; the discards fly to the Log button
			check(Game.engine.discard_card(Game.engine.zone("hand").cards[0].uid), "discard a hand card")
		var hand_before := Game.engine.zone("hand").cards.map(func(c): return c.uid)
		Game.engine.end_turn()
		if not main.event_modal().is_empty():
			main.event_modal_ok_button().pressed.emit()
		var dealt: Array = Game.engine.zone("hand").cards.filter(func(c): return not hand_before.has(c.uid))
		check(not dealt.is_empty(), "cards dealt")
		for card in dealt:
			var view: CardView = main.views[card.uid]
			var centre := view.global_position + view.size / 2
			check(centre.distance_to(origin) < 2.0, "card %d starts at the Log button: %s vs %s" % [card.uid, centre, origin])
		var pulsed := false
		var timer := (Engine.get_main_loop() as SceneTree).create_timer(Anim.DISCARD_POP_TIME + Anim.DISCARD_FLY_TIME + 0.4)
		while timer.time_left > 0.0:
			await wait_frames(1)
			pulsed = pulsed or button.scale.x > 1.01
		check(pulsed, "the Log button pulses as discarded cards arrive"))


func test_lines_append_while_closed_and_a_new_game_clears_it() -> void:
	await with_game(true, func(main: Node):
		var drawer: Object = main.log_drawer
		Game.engine.end_turn()
		check(str(drawer.text()).contains("— Turn 2 —"), "a line logged while closed: %s" % drawer.text())
		main.start_game(2)
		var text := str(drawer.text())
		check(not text.contains("seed 1") and text.contains("seed 2"), "a new game starts a new log: %s" % text))
