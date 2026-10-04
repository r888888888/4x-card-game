extends "res://tests/lib/test_case.gd"
## Notification flags (250, guide §10.7, §15.9): the engine's notices slide out of the rail as flags in the real
## main.tscn. Hook: main.toasts (shown(): the flags top to bottom; close_button, glyph and bar of a flag). Tweens are
## stepped by hand (step_tweens) to pass time. When each priority rings and how text reaches a flag: test_toasts and
## test_notice_priorities.

## Each priority, its hue bar's Palette role and its glyph's file.
const LOOKS := [[&"info", &"INSIGHT", "insight.svg"], [&"caution", &"WEALTH", "shield.svg"],
	[&"urgent", &"WARN", "blocked.svg"]]


## Advances every running tween by seconds, in 0.05 s steps, then lets freed nodes go.
func step_tweens(main: Node, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(0.05)
		t += 0.05
	await wait_frames()


## A Toasts constant, read by name so this file parses before it exists (red phase).
func toasts_const(key: String) -> Variant:
	return (Toasts as Script).get_script_constant_map().get(key, 0)


## The one flag showing, or null (with a failed check).
func only_flag(main: Node) -> Control:
	var shown: Array = main.toasts.shown()
	eq(shown.size(), 1, "one flag")
	return shown[0] if shown.size() == 1 else null


## The nearest ancestor of flag, up to main.toasts, that clips its children, or null.
func clip_of(main: Node, flag: Control) -> Control:
	var node := flag.get_parent()
	while node != null and node != main.toasts.get_parent():
		if node is Control and (node as Control).clip_contents:
			return node
		node = node.get_parent()
	return null


# --- AC1: out of the rail ---

func test_a_flag_slides_out_of_the_rail_and_rests_against_it() -> void:
	await with_game(false, func(main: Node):
		main.toasts.notice("Famine ends.")
		var flag := only_flag(main)
		if flag == null:
			return
		check(flag.position.x >= flag.size.x - 0.5,
			"at first a full width right of its place, behind the rail: at %s, %s wide" % [flag.position.x, flag.size.x])
		await wait_frames()
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		var clip := clip_of(main, flag)
		check(clip != null, "clipped by an ancestor")
		if clip != null:
			check(absf(clip.get_global_rect().end.x - rail.position.x) <= 1.0,
				"the clip ends at the rail's left edge (%s): %s" % [rail.position.x, clip.get_global_rect()])
		await step_tweens(main, 0.1)
		var halfway := flag.get_global_rect()
		check(halfway.position.x < rail.position.x and halfway.end.x > rail.position.x + 1.0,
			"part way out after 0.1 s: %s" % halfway)
		await step_tweens(main, 0.15)
		var r := flag.get_global_rect()
		check(absf(r.end.x - rail.position.x) <= 1.0, "at rest against the rail (%s): %s" % [rail.position.x, r])
		check(r.position.y >= rail.position.y, "below the top bar (the rail's top %s): %s" % [rail.position.y, r])
		check(r.size.x >= float(toasts_const("WIDTH")) and toasts_const("WIDTH") == 360, "at least 360 wide: %s" % r)
		check(r.size.y >= float(toasts_const("MIN_HEIGHT")) and toasts_const("MIN_HEIGHT") == Tokens.SPACE_7,
			"at least 48 tall: %s" % r))


func test_a_long_notice_widens_its_flag_on_one_line() -> void:
	await with_game(true, func(main: Node):
		var text := "Anarchy burns out and order returns: choose a government."
		main.toasts.notice(text)
		await step_tweens(main, 0.5)
		var flag := only_flag(main)
		if flag == null:
			return
		var labels: Array = flag.find_children("*", "Label", true, false).filter(func(l: Label): return l.text == text)
		eq(labels.size(), 1, "the text on a label")
		if labels.size() == 1:
			eq((labels[0] as Label).get_line_count(), 1, "one line")
			check((labels[0] as Label).get_global_rect().end.x <= flag.get_global_rect().end.x, "inside the flag")
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		check(absf(flag.get_global_rect().end.x - rail.position.x) <= 1.0, "still against the rail"))


func test_with_reduce_motion_a_flag_appears_at_rest_and_fades_in() -> void:
	await with_game(true, func(main: Node):
		main.toasts.notice("Famine ends.")
		await wait_frames()
		var flag := only_flag(main)
		if flag == null:
			return
		var rail: Rect2 = (main.sidebar as Control).get_global_rect()
		check(absf(flag.get_global_rect().end.x - rail.position.x) <= 1.0,
			"against the rail at once (%s): %s" % [rail.position.x, flag.get_global_rect()])
		check(flag.modulate.a < 1.0, "fading in: %s" % flag.modulate.a)
		await step_tweens(main, 0.15)
		eq(flag.modulate.a, 1.0, "shown after 120 ms"))


# --- AC2: the flag's look ---

func test_a_flag_is_a_square_sheet_strip_open_on_the_rail_side() -> void:
	await with_game(true, func(main: Node):
		main.toasts.notice("Famine ends.")
		await wait_frames()
		var flag := only_flag(main)
		if flag == null:
			return
		eq(flag.theme_type_variation, &"Flag", "the Flag variation")
		var style := flag.get_theme_stylebox("panel") as StyleBoxFlat
		check(style != null, "a flat stylebox")
		if style == null:
			return
		eq(style.bg_color, Palette.RAISED, "RAISED fill")
		eq(style.border_color, Palette.TEXT, "an ink border")
		eq([style.border_width_top, style.border_width_left, style.border_width_bottom, style.border_width_right],
			[2, 2, 2, 0], "2 px on three sides, none against the rail")
		eq([style.corner_radius_top_left, style.corner_radius_top_right, style.corner_radius_bottom_left,
			style.corner_radius_bottom_right], [0, 0, 0, 0], "square")
		eq(style.shadow_offset, GameTheme.PLINTH, "a plinth shadow")
		check(style.shadow_size > 0 and style.shadow_color == Palette.SHADOW, "a hard shadow"))


func test_each_priority_has_its_glyph_and_hue_bar_in_order_left_to_right() -> void:
	await with_game(true, func(main: Node):
		for look in LOOKS:
			main.toasts.notice("A %s notice." % look[0], look[0])
		await step_tweens(main, 0.2)
		var shown: Array = main.toasts.shown()
		eq(shown.size(), 3, "three flags")
		for i in mini(shown.size(), 3):
			var flag: Control = shown[i]
			var look: Array = LOOKS[i]
			var glyph: TextureRect = main.toasts.glyph(flag)
			var close: Button = main.toasts.close_button(flag)
			var bar: Control = main.toasts.bar(flag)
			var label: Label = null
			for l: Label in flag.find_children("*", "Label", true, false):
				if l.text == "A %s notice." % look[0]:
					label = l
			check(glyph != null and close != null and bar != null and label != null, "%s: glyph, text, ×, bar" % look[0])
			if glyph == null or close == null or bar == null or label == null:
				continue
			check(glyph.texture.resource_path.ends_with(look[2]), "%s glyph: %s" % [look[0], glyph.texture.resource_path])
			eq(glyph.self_modulate, Palette.color(look[1]), "%s glyph tinted its hue" % look[0])
			eq(main.toasts.bar_role(flag), look[1], "%s bar role" % look[0])
			eq(bar.get_global_rect().size.x, float(Toasts.BAR_WIDTH), "%s bar 4 px" % look[0])
			check(absf(bar.get_global_rect().end.x - flag.get_global_rect().end.x) <= 0.5,
				"%s bar flush with the rail side: %s in %s" % [look[0], bar.get_global_rect(), flag.get_global_rect()])
			check(glyph.get_global_rect().end.x <= label.get_global_rect().position.x
				and label.get_global_rect().end.x <= close.get_global_rect().position.x
				and close.get_global_rect().end.x <= bar.get_global_rect().position.x,
				"%s: glyph, text, ×, bar, left to right" % look[0])
			eq(close.text, "×", "the close button reads ×"))


func test_the_targeting_hint_flag_has_text_only() -> void:
	await with_game(true, func(main: Node):
		main.toasts.hint("Choose a territory.")
		await wait_frames()
		var flag := only_flag(main)
		if flag == null:
			return
		eq(main.toasts.texts(), ["Choose a territory."], "its text")
		check(main.toasts.glyph(flag) == null, "no glyph")
		check(main.toasts.close_button(flag) == null, "no ×")
		check(main.toasts.bar(flag) == null, "no bar"))


# --- AC3: how long a flag stays ---

func test_info_and_caution_flags_go_after_toast_time_and_an_urgent_one_stays_until_dismissed() -> void:
	await with_game(false, func(main: Node):
		main.toasts.notice("Order restored.", GameEngine.NOTICE_INFO)
		main.toasts.notice("A new era stirs the people: +2 unrest.", GameEngine.NOTICE_CAUTION)
		main.toasts.notice("Revolution! Anarchy begins next turn.", GameEngine.NOTICE_URGENT)
		await step_tweens(main, Anim.TOAST_TIME - 0.3)
		eq(main.toasts.priorities().size(), 3, "all three just before TOAST_TIME")
		await step_tweens(main, 0.6)
		eq(main.toasts.priorities(), [GameEngine.NOTICE_URGENT], "information and caution have gone")
		await step_tweens(main, 10.0)
		eq(main.toasts.priorities(), [GameEngine.NOTICE_URGENT], "the urgent flag is still there after 10 s")
		if main.toasts.shown().size() != 1:
			return
		var flag: Control = main.toasts.shown()[0]
		var close: Button = main.toasts.close_button(flag)
		check(close != null, "its ×")
		if close == null:
			return
		close.pressed.emit()
		eq(main.toasts.shown(), [], "gone from shown() at once")
		check(is_instance_valid(flag), "still sliding back")
		await step_tweens(main, 0.3)
		check(not is_instance_valid(flag), "freed within 0.3 s"))


func test_a_flag_slides_back_into_the_rail_when_closed() -> void:
	await with_game(false, func(main: Node):
		main.toasts.notice("Famine ends.")
		await step_tweens(main, 0.3)
		var flag := only_flag(main)
		if flag == null:
			return
		var rail_x: float = (main.sidebar as Control).get_global_rect().position.x
		main.toasts.close_button(flag).pressed.emit()
		await step_tweens(main, 0.1)
		if is_instance_valid(flag):
			check(flag.get_global_rect().end.x > rail_x + 1.0, "sliding in behind the rail: %s" % flag.get_global_rect())
		await step_tweens(main, 0.2)
		check(not is_instance_valid(flag), "then freed"))


# --- AC4: the stack ---

func test_flags_stack_down_newest_at_the_bottom_a_step_apart() -> void:
	await with_game(true, func(main: Node):
		for text in ["A", "B", "C", "D"]:
			main.toasts.notice(text)
		await step_tweens(main, 0.2)
		eq(main.toasts.texts(), ["B", "C", "D"], "the oldest goes when a fourth arrives; newest at the bottom")
		var shown: Array = main.toasts.shown()
		for i in range(1, shown.size()):
			var above: Rect2 = (shown[i - 1] as Control).get_global_rect()
			var below: Rect2 = (shown[i] as Control).get_global_rect()
			check(absf(below.position.y - above.end.y - Tokens.SPACE_2) <= 1.0,
				"SPACE_2 between flags %d and %d: %s, %s" % [i - 1, i, above, below]))


func test_a_fourth_flag_pushes_out_the_oldest_even_when_urgent() -> void:
	await with_game(true, func(main: Node):
		main.toasts.notice("Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
		for text in ["B", "C", "D"]:
			main.toasts.notice(text)
		await wait_frames()
		eq(main.toasts.texts(), ["B", "C", "D"], "the urgent flag was the oldest"))


# --- AC5: never in the way ---

func test_only_a_flags_close_button_takes_the_mouse_and_nothing_takes_focus() -> void:
	await with_game(false, func(main: Node):
		main.toasts.notice("Famine ends.")
		main.toasts.hint("Choose a territory.")
		await wait_frames()
		var shown: Array = main.toasts.shown()
		eq(shown.size(), 2, "a notice's flag and the hint's")
		var closes: Array = []
		for flag in shown:
			var close: Button = main.toasts.close_button(flag)
			if close != null:
				closes.append(close)
		eq(closes.size(), 1, "one ×: the notice's")
		var controls: Array = [main.toasts]
		controls.append_array((main.toasts as Node).find_children("*", "Control", true, false))
		for c: Control in controls:
			eq(c.focus_mode, Control.FOCUS_NONE, "%s takes no focus" % c)
			if closes.has(c):
				eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, "the × takes the mouse")
			else:
				eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % c))


# --- AC6: a new game clears them ---

func test_a_new_game_clears_every_flag() -> void:
	await with_game(true, func(main: Node):
		main.toasts.notice("Famine! Pop went hungry.", GameEngine.NOTICE_URGENT)
		await wait_frames()
		eq(main.toasts.shown().size(), 1, "the urgent flag")
		main.start_game(2)
		await wait_frames()
		eq(main.toasts.shown(), [], "none after a new game"))
