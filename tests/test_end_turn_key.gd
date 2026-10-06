extends "res://tests/lib/test_case.gd"
## End turn as the specimen's key (backlog 203) at the foot of the sidebar (202), in the real main scene at 1920×1080.
## Hook: main.sidebar.end_turn (an EndTurnKey Button): lamp_lit(), lamp_color(), label_text() (as shown, in caps),
## plate_text(), caption_text() ("" while hidden), busy().
## In detail (from docs/testing.md, 331): End turn as the specimen's key (203) at the sidebar's foot in the real
## `main.tscn` at 1920×1080: `main.sidebar.end_turn` (`lamp_lit()`, `lamp_color()`, `label_text()`, `plate_text()`,
## `caption_text()`, `busy()`): its box, the lamp (ochre with actions left and no caption since 221, sage when ready or
## unlimited, brick and disabled with the reason when a discard is owed or the game is over), busy "UPKEEP…" after a
## press, the plate flapping to the new turn, the pressed travel, the rail's width × 80 in the window's corner (221);
## `with_key_game` restores the engine whatever happens

const TOLERANCE := 1.0

var _old_window_size := Vector2i.ZERO


## Runs body(main) on main at 1920×1080 on engine (the real data's when null), started on seed 1; then closes main and
## puts the real engine back, even when body fails. Use with await.
func with_key_game(engine: GameEngine, body: Callable) -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var old_size := window.size
	window.size = Vector2i(1920, 1080)
	var real := Game.engine
	if engine != null:
		Game.engine = engine
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real
	window.size = old_size


## The sidebar's End turn key, or null (read by name, so a test fails cleanly before it exists).
func key(main: Node) -> Button:
	return main.sidebar.get("end_turn")


func wait_seconds(s: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(s).timeout


# --- AC1: the key at the sidebar's foot ---

func test_end_turn_is_the_big_key_at_the_bottom_right_of_the_sidebar() -> void:
	await with_key_game(null, func(main: Node):
		var k := key(main)
		check(k != null and k.is_visible_in_tree(), "the key")
		if k == null:
			return
		check((main.sidebar as Control).is_ancestor_of(k), "in the sidebar")
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		var r := k.get_global_rect()
		check(rail.end.x - r.end.x <= Tokens.SPACE_5 + TOLERANCE, "at the right: ends %d, sidebar %d" % [r.end.x, rail.end.x])
		check(r.position.y > rail.position.y + rail.size.y * 0.6, "at the bottom: top at %d of %s" % [r.position.y, rail])
		var box := k.get_theme_stylebox("normal") as StyleBoxFlat
		eq(box.bg_color, Palette.ACCENT, "ACCENT fill")
		eq(box.border_color, Palette.TEXT, "TEXT border")
		eq(box.border_width_left, 3, "3 px")
		eq(box.corner_radius_top_left, Tokens.RADIUS_1, "RADIUS_1")
		eq(box.shadow_offset, Vector2(4, 4), "a 4,4 plinth")
		eq(box.shadow_color, Palette.SHADOW, "in SHADOW")
		eq(k.label_text(), "END TURN", "its label in caps")
		eq(k.plate_text(), "001", "the turn plate")
		check(k.lamp_lit(), "a lit lamp at its left")
		var strip: Control = (main.counter(GameEngine.FOOD) as Control).get_parent()
		check(not UIKit.buttons_in(strip).any(func(b): return b.text.begins_with("End turn")), "no End turn in the top strip (AC6)"))


# --- AC2: the lamp says whether you're ready ---

func test_the_lamp_is_ochre_with_actions_left_and_sage_when_spent_with_no_count_under_it() -> void:
	await with_key_game(gov_engine("band"), func(main: Node):
		var e := Game.engine
		var k := key(main)
		eq(e.actions_left(), 2, "precondition: 2 actions")
		eq(k.lamp_color(), Palette.WEALTH, "ochre: actions left")
		eq(k.caption_text(), "", "no actions count under the key (221: the hand's heading shows it)")
		check(e.play_card(put_in_hand(e, "shrine")), "play one")
		await wait_frames()
		eq(k.lamp_color(), Palette.WEALTH, "still ochre: one left")
		eq(k.caption_text(), "", "still no count")
		check(e.play_card(put_in_hand(e, "shrine")), "play the other")
		await wait_frames()
		eq(k.lamp_color(), Palette.GAIN, "sage: ready")
		eq(k.caption_text(), "", "no caption")
		check(not k.disabled, "enabled"))


func test_with_unlimited_actions_the_lamp_is_sage_without_a_caption() -> void:
	await with_key_game(gov_engine("council"), func(main: Node):
		var k := key(main)
		eq(Game.engine.actions_per_turn(), -1, "precondition: unlimited")
		eq(k.lamp_color(), Palette.GAIN, "sage")
		eq(k.caption_text(), "", "no caption"))


func test_a_discard_owed_lights_brick_and_disables_the_key_with_the_reason() -> void:
	await with_key_game(null, func(main: Node):
		var e := Game.engine
		for i in e.config.hand_limit + 2 - e.zone("hand").size():
			put_in_hand(e, e.zone("hand").cards[0].def.id)
		e.end_turn()
		while not main.event_modal().is_empty():
			main.event_modal_ok_button().pressed.emit()
		await wait_frames()
		await wait_seconds(1.3)  # past the end-of-turn busy spell
		var error := e.end_turn_error()
		check(error != "", "precondition: a discard is owed")
		var k := key(main)
		check(k.disabled, "disabled")
		eq(k.lamp_color(), Palette.UNREST, "brick")
		eq(k.caption_text(), error, "the reason under the key")
		eq((k.get_theme_stylebox("disabled") as StyleBoxFlat).shadow_size, 0, "no plinth"))


# --- AC3: busy while the turn resolves ---

func test_pressing_it_shows_upkeep_until_the_new_turn_then_its_plate() -> void:
	await with_reduce_motion(false, func():
		await with_key_game(gov_engine("council"), func(main: Node):
			var e := Game.engine
			var k := key(main)
			k.pressed.emit()
			eq(e.turn, 2, "the turn ended")
			check(k.busy(), "busy")
			eq(k.label_text(), "UPKEEP…", "its label")
			check(not k.lamp_lit(), "the lamp off")
			eq((k.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Palette.CONTROL, "CONTROL fill")
			k.pressed.emit()
			eq(e.turn, 2, "a press while busy is ignored")
			await wait_seconds(1.25)
			check(not k.busy(), "back within 1.2 s")
			eq(k.label_text(), "END TURN", "its label back")
			eq(k.plate_text(), "002", "the new turn on the plate")
			check(k.lamp_lit(), "the lamp back")))


func test_the_plate_flaps_to_the_new_turn_or_changes_at_once_with_reduce_motion() -> void:
	await with_reduce_motion(false, func():
		await with_key_game(gov_engine("council"), func(main: Node):
			var k := key(main)
			k.pressed.emit()
			await wait_frames()
			check(k.plate_text() != "002" or k.busy(), "mid-flap or still busy just after the press")
			await wait_seconds(1.25)
			eq(k.plate_text(), "002", "flapped to 002")))
	await with_reduce_motion(true, func():
		await with_key_game(gov_engine("council"), func(main: Node):
			var k := key(main)
			k.pressed.emit()
			eq(k.plate_text(), "002", "Reduce motion: at once")))


# --- AC4: the press ---

func test_pressed_it_sinks_into_its_plinth() -> void:
	await with_key_game(null, func(main: Node):
		var pressed := key(main).get_theme_stylebox("pressed") as StyleBoxFlat
		eq(pressed.shadow_size, 0, "no plinth")
		eq([pressed.expand_margin_left, pressed.expand_margin_top], [-4.0, -4.0], "moved +4,+4"))


# --- AC5: game over ---

func test_game_over_disables_it_with_a_brick_lamp() -> void:
	var main := open_main()
	play_seed_1(main, func(_m): pass)
	await wait_frames()
	check(Game.engine.is_over, "precondition: game over")
	var k := key(main)
	check(k != null and k.disabled, "disabled")
	if k != null and k.has_method("lamp_color"):
		eq(k.tooltip_text, Game.engine.end_turn_error(), "the reason")
		eq(k.lamp_color(), Palette.UNREST, "brick")
	close_main(main)


# --- 221: a bigger key filling the rail's foot ---

func test_the_key_fills_the_rails_width_at_80_px_in_the_windows_bottom_right_corner() -> void:
	await with_key_game(null, func(main: Node):
		var k: Object = key(main)
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		var viewport: Vector2 = main.get_viewport_rect().size
		var r: Rect2 = (k as Control).get_global_rect()
		eq(r.size, Vector2(rail.size.x - 2 * Tokens.SPACE_4, 80), "the rail's content width × 80")
		check(absf(viewport.x - r.end.x - Tokens.SPACE_4) <= TOLERANCE, "SPACE_4 from the right edge: ends at %d of %d" % [r.end.x, viewport.x])
		check(absf(viewport.y - r.end.y - Tokens.SPACE_4) <= TOLERANCE, "SPACE_4 from the bottom edge: ends at %d of %d" % [r.end.y, viewport.y])
		eq(k.label_font_size(), Tokens.TYPE_BODY, "its label at TYPE_BODY"))
