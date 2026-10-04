extends "res://tests/lib/test_case.gd"
## Toasts and the Log button's unread marker in the real main scene (backlog 116). The engine's noticed signal shows a
## toast, a notification flag out of the rail since 250 (its place and look: test_notification_flags) (engine tests: the notice tests beside each scenario, e.g. test_famine). Hook: main.toasts
## (shown(): the toasts top to bottom, texts(): their text). Tweens are stepped by hand (step_tweens) to pass time.

const TARGET_HINT := "Esc cancels."


## Emits the engine's noticed signal, as the engine does for a notable log line (an information notice, 190).
func notice(message: String) -> void:
	Game.engine.emit_signal("noticed", message, GameEngine.NOTICE_INFO)


## Anim.TOAST_TIME, read by name so this file parses before it exists (red phase).
func toast_time() -> float:
	return float((Anim as Script).get_script_constant_map().get("TOAST_TIME", 0.0))


## Advances every running tween by seconds, in 0.05 s steps, then lets freed nodes go.
func step_tweens(main: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(0.05)
		t += 0.05
	await wait_frames()


## The first visible button under root whose text starts with prefix, or null.
func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


# --- AC3: a notice shows a toast ---

func test_an_information_notice_shows_a_flag_for_toast_time() -> void:
	await with_game(false, func(main: Node):
		check(toast_time() == 3.0, "Anim.TOAST_TIME is 3 s: %s" % toast_time())
		notice("Famine ends.")
		await wait_frames()
		eq(main.toasts.texts(), ["Famine ends."], "one flag (where it shows: test_notification_flags)")
		await step_tweens(main, toast_time() - 0.2)
		eq(main.toasts.texts(), ["Famine ends."], "still there just before TOAST_TIME")
		await step_tweens(main, 1.0)
		eq(main.toasts.texts(), [], "gone after it"))


func test_at_most_three_flags_show_newest_at_the_bottom() -> void:
	await with_game(false, func(main: Node):
		for text in ["A", "B", "C", "D"]:
			notice(text)
		await wait_frames()
		eq(main.toasts.texts(), ["B", "C", "D"], "the oldest goes when a fourth arrives (250: newest at the bottom)"))


func test_with_reduce_motion_toasts_fade_in_place() -> void:
	await with_game(true, func(main: Node):
		notice("Famine ends.")
		await wait_frames()
		var shown: Array = main.toasts.shown()
		check(shown.size() == 1, "one toast")
		if shown.size() != 1:
			return
		var toast: Control = shown[0]
		var start := toast.get_global_rect().position
		var alpha_before := toast.modulate.a
		check(alpha_before < 1.0, "fading in: %s" % alpha_before)
		await step_tweens(main, 0.5)
		eq(toast.get_global_rect().position, start, "doesn't slide")
		eq(toast.modulate.a, 1.0, "then shown"))


# --- AC4: the targeting hint ---

func test_the_targeting_hint_is_a_toast_until_targeting_ends() -> void:
	await with_game(false, func(main: Node):
		var winnow := put_in_hand(Game.engine, "winnow")
		Game.engine.resources.food = 5
		Game.engine.changed.emit()  # put_in_hand bypasses the actions that refresh the board
		await wait_frames()
		main.on_double_clicked(main.views[winnow])
		check(main.drag.targeting != null, "targeting Winnow")
		var hints: Array = main.toasts.texts().filter(func(t: String): return t.contains(TARGET_HINT))
		eq(hints.size(), 1, "the hint is a toast: %s" % [main.toasts.texts()])
		if hints.size() == 1:
			check(not hints[0].contains("[color"), "plain text: %s" % hints[0])
		await step_tweens(main, toast_time() + 2.0)
		eq(main.toasts.texts().filter(func(t: String): return t.contains(TARGET_HINT)).size(), 1,
			"it stays while targeting, past TOAST_TIME")
		press_key(main, KEY_ESCAPE)
		check(main.drag.targeting == null, "Esc cancels targeting")
		await step_tweens(main, 1.0)
		eq(main.toasts.texts().filter(func(t: String): return t.contains(TARGET_HINT)), [], "then it fades out"))


func test_refusals_are_logged_but_do_not_toast() -> void:
	await with_game(false, func(main: Node):
		var settler := put_in_hand(Game.engine, "settler")
		Game.engine.resources.food = 0
		Game.engine.changed.emit()
		await wait_frames()
		var error := Game.engine.play_error(settler)
		check(error != "", "Settler can't be afforded")
		main.try_play(main.views[settler])
		await wait_frames()
		eq(main.toasts.texts(), [], "no toast: the refusal floats over the card")
		check(main.log_drawer.text().contains(error), "the log still says why"))


# --- AC5: the unread marker ---

## Ends the turn and presses OK on the drawn event's pop-up, which otherwise takes the keys (L included).
func end_turn_and_close_event(main: Node) -> void:
	Game.engine.end_turn()
	if not main.event_modal().is_empty():
		main.event_modal_ok_button().pressed.emit()


func test_the_log_button_marks_lines_not_yet_seen() -> void:
	await with_game(true, func(main: Node):
		var button := shown_button(main, "Log")
		check(button != null, "the Log button")
		if button == null:
			return
		eq(button.text, "Log", "a new game's own lines don't mark it")
		end_turn_and_close_event(main)
		eq(button.text, "Log •", "a line while closed marks it")
		press_key(main, KEY_L)
		eq(button.text, "Log", "opening clears it")
		end_turn_and_close_event(main)
		eq(button.text, "Log", "lines while open don't mark it")
		press_key(main, KEY_L)
		eq(button.text, "Log", "closing doesn't mark it")
		end_turn_and_close_event(main)
		eq(button.text, "Log •", "a new line after closing marks it")
		main.start_game(2)
		eq(button.text, "Log", "a new game clears it"))


# --- AC6: toasts never block play (the mouse and focus: test_notification_flags, 250) ---

func test_toasts_hide_while_the_menu_is_open_and_show_when_it_closes() -> void:
	await with_game(false, func(main: Node):
		main.open_menu()
		notice("Famine ends.")
		await wait_frames()
		check(not (main.toasts as Control).is_visible_in_tree(), "hidden under the menu")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check((main.toasts as Control).is_visible_in_tree(), "shown when the menu closes")
		eq(main.toasts.texts(), ["Famine ends."], "the notice waited"))


func test_toasts_hide_while_knowledge_is_open() -> void:
	await with_game(false, func(main: Node):
		main.knowledge.open()  # a screen since 208
		notice("Famine ends.")
		await wait_frames()
		check(not (main.toasts as Control).is_visible_in_tree(), "hidden under Knowledge")
		main.knowledge.close()
		await wait_screen_transition()
		check((main.toasts as Control).is_visible_in_tree(), "shown when it closes"))
