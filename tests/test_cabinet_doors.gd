extends "res://tests/lib/anarchy_case.gd"
## The government choice behind cabinet doors (backlog 209), in the real main scene on an anarchy_case game whose
## Anarchy burns out on the fourth end_turn (Chiefs and Kings in the government deck). Hooks: main.doors (left, right:
## the two door panels; moving(): whether they are running) and main.choices.government (the overlay).

const CLOSE := 0.20  # the doors meet (Anim.MACHINED)
const HOLD := 0.06
const PART := 0.26  # back to the edges (Anim.LATCH)
const SLACK := 0.06  # real-time tolerance on headless frames


## Runs body(main, e) on a deck_engine game one end_turn from the government choice, with Reduce motion calm.
func with_choice_coming(calm: bool, body: Callable) -> void:
	await with_temp_settings(func():
		Settings.store.reduce_motion = calm
		var real := Game.engine
		Game.engine = anarchy_engine()
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		var e := Game.engine
		e.resources["unrest"] = 5
		e.end_turn()  # Anarchy
		e.create_card("kings", "discard", null)
		for i in 3:
			e.end_turn()
		await wait_frames()
		check(e.pending().get("kind", "") != GameEngine.PENDING_GOVERNMENT, "precondition: no choice yet")
		await body.call(main, e)
		close_main(main)
		Game.engine = real)


func wait_seconds(s: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(s).timeout


## Where the doors' inner edges are: [the left door's right edge, the right door's left edge].
func edges(main: Node) -> Array[float]:
	return [(main.doors.left as Control).get_global_rect().end.x, (main.doors.right as Control).get_global_rect().position.x]


func overlay_shown(main: Node) -> bool:
	return (main.choices.government as Control).is_visible_in_tree()


## The times, from start, at which token played.
func played_at(main: Node, token: StringName, start: float) -> Array[float]:
	var out: Array[float] = []
	for r in main.sfx.played():
		if r.token == token:
			out.append(r.at - start)
	return out


# --- AC1: the doors close, hold and part on the choice ---

func test_the_doors_close_then_part_on_the_government_choice() -> void:
	await with_choice_coming(false, func(main: Node, e: GameEngine):
		var width: float = main.get_viewport_rect().size.x
		var start: float = main.sfx.clock()
		e.end_turn()  # Anarchy burns out: the government choice
		eq(e.pending().get("kind", ""), GameEngine.PENDING_GOVERNMENT, "precondition: the choice is owed")
		var at_start := edges(main)
		check((main.doors.left as Control).is_visible_in_tree() and (main.doors.right as Control).is_visible_in_tree(), "the doors show")
		check(at_start[0] <= 1.0 and at_start[1] >= width - 1.0, "they start at the edges: %s" % [at_start])
		eq((main.doors.left.get_theme_stylebox("panel") as StyleBoxFlat).bg_color, Palette.CONTROL, "CONTROL doors")
		var labels: Array = (main.doors as Node).find_children("*", "Label", true, false).map(func(l): return l.text)
		check(labels.has("CHOOSE A") and labels.has("GOVERNMENT"), "the door labels: %s" % [labels])
		check(not overlay_shown(main), "the overlay waits behind them")
		await wait_seconds(CLOSE + 0.02)
		var met := edges(main)
		check(absf(met[0] - width / 2) <= 2.0 and absf(met[1] - width / 2) <= 2.0, "met at the centre by 0.20 s: %s" % [met])
		await wait_seconds(HOLD + PART + SLACK)
		check(overlay_shown(main), "the choice is shown")
		var parted := edges(main)
		check(parted[0] <= 1.0 and parted[1] >= width - 1.0, "parted back to the edges: %s" % [parted])
		check(not main.doors.moving(), "and at rest")
		var closes := played_at(main, Sfx.CABINET_CLOSE, start)
		var parts := played_at(main, Sfx.CABINET_PART, start)
		eq(closes.size(), 1, "one close sound")
		eq(parts.size(), 1, "one part sound")
		if closes.size() == 1 and parts.size() == 1:
			check(absf(closes[0] - CLOSE) <= SLACK, "the close as they meet: %.2f s" % closes[0])
			check(absf(parts[0] - (CLOSE + HOLD)) <= SLACK, "the part as they part: %.2f s" % parts[0]))


# --- AC2: nothing gets through while they move ---

func test_keys_and_clicks_do_not_reach_the_board_while_the_doors_move() -> void:
	await with_choice_coming(false, func(main: Node, e: GameEngine):
		e.end_turn()
		await wait_frames()
		check(main.doors.moving(), "precondition: moving")
		var doors := main.doors as Control
		eq(doors.mouse_filter, Control.MOUSE_FILTER_STOP, "the doors take the clicks")
		check(doors.get_global_rect().encloses(main.get_viewport_rect()), "over the whole window")
		var turn := e.turn
		press_key(main, KEY_E)
		press_key(main, KEY_T)
		eq(e.turn, turn, "E does nothing")
		check(main.tech_tree.shown().is_empty(), "T does nothing"))


# --- AC3: choosing closes them over the overlay and parts them on the Realm ---

func test_choosing_closes_the_doors_then_parts_them_on_the_realm() -> void:
	await with_choice_coming(false, func(main: Node, e: GameEngine):
		var width: float = main.get_viewport_rect().size.x
		e.end_turn()
		await wait_seconds(CLOSE + HOLD + PART + SLACK)
		var kings := uid_of(e.zone("governments"), "kings")
		main.on_picked(main.views[kings])
		eq(ruling(e), "kings", "chosen at the click")
		check(overlay_shown(main), "the overlay stays while the doors close over it")
		await wait_seconds(CLOSE + 0.02)
		var met := edges(main)
		check(absf(met[0] - width / 2) <= 2.0 and absf(met[1] - width / 2) <= 2.0, "closed over it: %s" % [met])
		await wait_seconds(PART + SLACK)
		check(not overlay_shown(main), "the overlay gone")
		check(not main.doors.moving(), "the doors at rest")
		check(not (main.doors as Control).is_visible_in_tree(), "and out of the way"))


# --- AC4: Reduce motion ---

func test_with_reduce_motion_the_overlay_fades_with_no_doors() -> void:
	await with_choice_coming(true, func(main: Node, e: GameEngine):
		e.end_turn()
		await wait_frames()
		check(not (main.doors as Control).is_visible_in_tree(), "no doors")
		check(overlay_shown(main), "the overlay shows")
		check((main.choices.government as Control).modulate.a < 1.0, "fading in")
		await wait_seconds(0.12 + SLACK)
		eq((main.choices.government as Control).modulate.a, 1.0, "in by 0.12 s")
		main.on_picked(main.views[uid_of(e.zone("governments"), "kings")])
		await wait_frames()
		check(not (main.doors as Control).is_visible_in_tree(), "still no doors")
		await wait_seconds(0.12 + SLACK)
		check(not overlay_shown(main), "faded out"))


# --- AC5: once ---

func test_the_doors_play_once_however_often_the_board_refreshes() -> void:
	await with_choice_coming(false, func(main: Node, e: GameEngine):
		var start: float = main.sfx.clock()
		e.end_turn()
		await wait_frames()
		e.changed.emit()
		e.changed.emit()
		await wait_seconds(CLOSE + HOLD + PART + SLACK)
		e.changed.emit()
		await wait_frames()
		eq(played_at(main, Sfx.CABINET_CLOSE, start).size(), 1, "the doors closed once")
		check(overlay_shown(main) and not main.doors.moving(), "the overlay up, the doors at rest"))


func test_a_restart_while_the_choice_is_owed_shows_it_once() -> void:
	await with_choice_coming(false, func(main: Node, e: GameEngine):
		e.end_turn()
		await wait_seconds(CLOSE + HOLD + PART + SLACK)
		main.start_game(1)  # a new game: no choice owed
		await wait_frames()
		check(not overlay_shown(main), "a new game has no choice")
		check(not main.doors.moving() and not (main.doors as Control).is_visible_in_tree(), "and no doors"))
