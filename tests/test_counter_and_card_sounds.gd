extends "res://tests/lib/test_case.gd"
## Counter and card sounds (188) in the real main.tscn, its sound clock frozen at 0: an odometer ticks as each digit
## lands and registers its total with a gain or loss, the top bar's counters share one tick stream and register left
## to right, quiet refreshes and new games are silent; a card flicks as it is picked up, pats as a played card lands,
## taps twice when refused, and a click that waits for a target ticks.


func sounds(main: Node, from := 0) -> Array:
	return main.sfx.played().slice(from)


## [token, at to the ms, db] of each sound from index from.
func heard(main: Node, from := 0) -> Array:
	return sounds(main, from).map(func(r): return [r.token, snappedf(r.at, 0.001), r.db])


func tokens(main: Node, from := 0) -> Array:
	return sounds(main, from).map(func(r): return r.token)


## An odometer added to main, showing start.
func new_odometer(main: Node, start: int) -> Object:
	var odo := Odometer.new()
	main.add_child(odo)
	odo.show_now(start)
	return odo


# --- AC1: ticks and a registration ---

func test_an_odometer_ticks_each_step_and_registers_the_last() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.sfx.set_clock(0.0)
		var odo: Object = new_odometer(main, 3)
		odo.set_value(6)
		var step := Anim.ODOMETER_STEP
		eq(heard(main), [[Sfx.COUNTER_TICK, snappedf(step, 0.001), 0.0], [Sfx.COUNTER_TICK, snappedf(2 * step, 0.001), -1.0],
			[Sfx.RESOURCE_GAIN, snappedf(3 * step, 0.001), 0.0]], "3 → 6: the 4 and the 5 tick, each a dB quieter; the 6 registers")
		await (Engine.get_main_loop() as SceneTree).create_timer(0.4).timeout  # the roll ends
		main.sfx.set_clock(10.0)
		odo.set_value(3)
		eq(heard(main, 3).map(func(h): return h[0]), [Sfx.COUNTER_TICK, Sfx.COUNTER_TICK, Sfx.RESOURCE_LOSS], "6 → 3: two ticks and a loss")
		close_main(main))


# --- AC2: only the shown steps ---

func test_a_long_roll_ticks_only_for_the_steps_it_shows() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.sfx.set_clock(0.0)
		var odo: Object = new_odometer(main, 12)
		odo.set_value(40)
		var got := tokens(main)
		eq(got.count(Sfx.COUNTER_TICK), 7, "7 ticks")
		eq(got.filter(func(t): return t != Sfx.COUNTER_TICK), [Sfx.RESOURCE_GAIN], "and one gain")
		var h := heard(main)
		eq(h[0][1] if h.size() == 8 else -1.0, snappedf(Anim.ODOMETER_STEP, 0.001), "the first tick ends the first shown step: the jump is silent")
		eq(h[6][2] if h.size() == 8 else 0.0, -6.0, "the 7th tick 6 dB down")
		close_main(main))


# --- AC3: one tick stream, registered left to right ---

func test_counters_changed_together_share_one_tick_stream_and_register_in_order() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.start_game(1)
		var e := Game.engine
		for pair in [[GameEngine.FOOD, 3], [GameEngine.WEALTH, 1], [GameEngine.INSIGHT, 0]]:
			e.resources[pair[0]] = pair[1]
		e.changed.emit()
		await wait_frames()
		main.sfx.set_clock(100.0)
		var before: int = main.sfx.played().size()
		for pair in [[GameEngine.FOOD, 5], [GameEngine.WEALTH, 4], [GameEngine.INSIGHT, 2]]:
			e.resources[pair[0]] = pair[1]
		e.changed.emit()
		var gains := sounds(main, before).filter(func(r): return r.token == Sfx.RESOURCE_GAIN)
		eq(gains.size(), 3, "every counter registers its gain")
		if gains.size() == 3:
			check(gains[0].at < gains[1].at and gains[1].at < gains[2].at,
				"food, then wealth, then insight: %s" % [gains.map(func(r): return r.at)])
		var ticks: Array = sounds(main, before).filter(func(r): return r.token == Sfx.COUNTER_TICK).map(func(r): return r.at)
		ticks.sort()
		for i in range(1, ticks.size()):
			check(ticks[i] - ticks[i - 1] >= 0.035 - 0.0001, "ticks %.3f and %.3f at least 35 ms apart" % [ticks[i - 1], ticks[i]])
		close_main(main))


# --- AC4: silent refreshes; Reduce motion ---

func test_a_refresh_that_changes_nothing_a_new_game_and_a_restart_are_silent() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.sfx.set_clock(0.0)
		main.start_game(1)
		await wait_frames()
		var counters := [Sfx.COUNTER_TICK, Sfx.RESOURCE_GAIN, Sfx.RESOURCE_LOSS]
		check(not tokens(main).any(func(t): return counters.has(t)), "a new game: %s" % [tokens(main)])
		Game.engine.changed.emit()
		main.start_game(2)
		await wait_frames()
		check(not tokens(main).any(func(t): return counters.has(t)), "a no-op refresh and a restart: %s" % [tokens(main)])
		close_main(main))


func test_closing_the_supply_screen_after_buying_is_silent() -> void:
	await with_reduce_motion(false, func():
		var real := Game.engine
		Game.engine = make_engine({"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})
		var main := open_main()
		main.start_game(1)
		Game.engine.resources[GameEngine.WEALTH] = 10
		Game.engine.changed.emit()
		await wait_frames()
		main.supply.open(Game.engine)
		await wait_frames()
		main.supply.buy(main.supply.views()[0])
		await wait_frames()
		main.sfx.set_clock(50.0)
		var before: int = main.sfx.played().size()
		main.supply.close()
		await wait_frames()
		var counters := [Sfx.COUNTER_TICK, Sfx.RESOURCE_GAIN, Sfx.RESOURCE_LOSS]
		eq(tokens(main, before).filter(func(t): return counters.has(t)), [], "the bar catches up in silence")
		close_main(main)
		Game.engine = real)


func test_with_reduce_motion_a_change_registers_once_with_no_ticks() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		main.sfx.set_clock(0.0)
		var odo: Object = new_odometer(main, 3)
		odo.set_value(7)
		eq(heard(main), [[Sfx.RESOURCE_GAIN, 0.0, 0.0]], "one gain, at once")
		main.sfx.set_clock(1.0)
		odo.set_value(5)
		eq(tokens(main, 1), [Sfx.RESOURCE_LOSS], "one loss")
		close_main(main))


# --- AC5: lift, place, reject ---

func test_picking_a_card_up_flicks_and_dragging_it_is_silent() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		main.start_game(1)
		await wait_frames()
		main.sfx.set_clock(0.0)
		var view: CardView = main.views[Game.engine.zone("hand").cards[0].uid]
		var hover := InputEventMouseMotion.new()
		hover.position = view.get_global_rect().get_center()
		hover.global_position = hover.position
		main.get_viewport().push_input(hover, true)
		eq(main.sfx.played(), [], "hovering a card is silent")
		main.drag.begin_drag(view, Vector2(10, 10))
		eq(tokens(main), [Sfx.CARD_LIFT], "the pick-up")
		check(not main.sfx.played().is_empty() and main.sfx.played()[0].input, "the player's own press")
		for x in [200.0, 400.0, 600.0]:
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(x, 500)
			motion.global_position = motion.position
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			main.get_viewport().push_input(motion, true)
		await wait_frames()
		eq(tokens(main), [Sfx.CARD_LIFT], "moving it and the lit drop zone are silent")
		main.drag.end_drag()
		close_main(main))


func test_a_played_building_pats_down_once_when_it_lands() -> void:
	await with_reduce_motion(false, func():
		await with_territories_main(func(main: Node):
			var e := Game.engine
			var temple := put_in_hand(e, "temple")
			e.changed.emit()
			await wait_frames()
			main.sfx.set_clock(0.0)
			e.play_card(temple)
			await wait_frames()
			eq(tokens(main).count(Sfx.CARD_PLACE), 0, "not while it flies")
			await (Engine.get_main_loop() as SceneTree).create_timer(1.2).timeout
			eq(tokens(main).count(Sfx.CARD_PLACE), 1, "once, as it lands on its territory")))


func test_a_building_played_into_the_open_territory_view_pats_down_in_its_slot() -> void:
	await with_reduce_motion(false, func():
		await with_territories_main(func(main: Node):
			var e := Game.engine
			main.territory_view.open(home_uid(e))
			await wait_screen_transition()
			var temple := put_in_hand(e, "temple")
			e.changed.emit()
			await wait_frames()
			main.sfx.set_clock(0.0)
			e.play_card(temple)
			await wait_frames()
			eq(tokens(main).count(Sfx.CARD_PLACE), 0, "not while it flies")
			await (Engine.get_main_loop() as SceneTree).create_timer(1.2).timeout
			check(main.views.has(temple) and (main.views[temple] as CardView).state == CardView.State.REST, "landed in the view")
			eq(tokens(main).count(Sfx.CARD_PLACE), 1, "once, as it lands")))


func test_a_refused_drop_taps_twice_as_the_card_shakes() -> void:
	await with_reduce_motion(false, func():
		await with_territories_main(func(main: Node):
			var e := Game.engine
			var hall := put_in_hand(e, "guildhall")
			e.resources[GameEngine.FOOD] = 0
			e.resources[GameEngine.WEALTH] = 0
			e.changed.emit()
			await (Engine.get_main_loop() as SceneTree).create_timer(1.0).timeout  # dealt in: at rest in the hand
			main.sfx.set_clock(0.0)
			var before: int = main.sfx.played().size()
			main.try_play(main.views[hall])
			eq(heard(main, before), [[Sfx.REJECT, 0.0, 0.0]], "the refusal's double tap, as the shake starts")))


# --- AC6: click-to-target ---

func test_a_click_that_waits_for_a_target_ticks_and_cancelling_is_silent() -> void:
	await with_reduce_motion(false, func():
		await with_territories_main(func(main: Node):
			var e := Game.engine
			settle(e, ["grassland"])
			var temple := put_in_hand(e, "temple")
			e.changed.emit()
			await wait_frames()
			main.sfx.set_clock(0.0)
			main.on_double_clicked(main.views[temple])
			check(main.drag.targeting != null, "targeting")
			eq(tokens(main), [Sfx.SELECTION], "the index tab clips on")
			check(main.sfx.played()[0].input if not main.sfx.played().is_empty() else false, "the player's own click")
			press_key(main, KEY_ESCAPE)
			check(main.drag.targeting == null, "cancelled")
			eq(tokens(main), [Sfx.SELECTION], "cancelling is silent")))
