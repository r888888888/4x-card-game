extends "res://tests/lib/test_case.gd"
## A scroll area that glides (backlog 356, guide §7.17 "Scroll area"): SmoothScroll takes the wheel itself, so a notch
## eases the content Anim.SCROLL_STEP px with momentum that coasts to a stop at the content's ends; Reduce motion jumps.
## The theme's scrollbars: a thin steel grabber on a well track. Sideways too (363): a SmoothScroll whose vertical
## scrolling is disabled glides scroll_horizontal, and the hand is one that eases a card the focus reaches into view.

const SIZE := Vector2(200, 200)  # the scroll area; its content is 2000 px tall


## A SmoothScroll of SIZE over 2000 px of content in main, laid out.
func fixture_scroll(main: Node) -> SmoothScroll:
	var scroll := SmoothScroll.new()
	scroll.position = Vector2(100, 100)
	scroll.size = SIZE
	scroll.z_index = 50  # above the board, so the wheel reaches it
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(SIZE.x, 2000)
	scroll.add_child(tall)
	main.add_child(scroll)
	await wait_frames()
	return scroll


# --- AC1: a notch glides and coasts ---

func test_a_wheel_notch_glides_the_step_and_coasts_to_rest() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		wheel_notch(main, scroll)
		eq(scroll.scroll_vertical, 0, "nothing moves in the notch's own frame")
		var seen: Array[int] = []
		for i in 8:
			await wait_frames(1)
			seen.append(scroll.scroll_vertical)
		check(seen[0] > 0, "moving after one frame: %s" % [seen])
		check(seen[7] > seen[3] and seen[3] > seen[0], "still coasting frames after the notch: %s" % [seen])
		await wait_frames(240)
		check(absi(scroll.scroll_vertical - int(Anim.SCROLL_STEP)) <= 2, "at rest one step down: %d" % scroll.scroll_vertical)
		wheel_notch(main, scroll, false)
		await wait_frames(240)
		eq(scroll.scroll_vertical, 0, "a notch up brings it back")
		close_main(main))


# --- AC2: the ends ---

func test_a_notch_past_the_bottom_stops_there_with_no_motion_left() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		scroll.scroll_vertical = scroll_bottom(scroll) - 10
		await wait_frames()
		wheel_notch(main, scroll)
		await wait_frames(30)
		eq(scroll.scroll_vertical, scroll_bottom(scroll), "stopped at the bottom")
		scroll.scroll_vertical = scroll_bottom(scroll) - 50
		await wait_frames(30)
		eq(scroll.scroll_vertical, scroll_bottom(scroll) - 50, "no velocity left to carry it on")
		close_main(main))


# --- AC3: Reduce motion ---

func test_with_reduce_motion_a_notch_jumps_the_step() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		wheel_notch(main, scroll)
		eq(scroll.scroll_vertical, int(Anim.SCROLL_STEP), "one step down at once")
		await wait_frames(30)
		eq(scroll.scroll_vertical, int(Anim.SCROLL_STEP), "and no further")
		close_main(main))


# --- AC4: the scrollbar ---

## Checks bar (what) is a thin steel grabber on a well: thickness its size across the bar.
func check_bar_look(bar: ScrollBar, what: String) -> void:
	var looks := {"grabber": Palette.CONTROL, "grabber_highlight": Palette.TEXT_DIM, "grabber_pressed": Palette.TEXT_DIM,
		"scroll": Palette.FIELD}
	for state in looks:
		var box := bar.get_theme_stylebox(state) as StyleBoxFlat
		check(box != null and box.draw_center, "%s %s: a filled box" % [what, state])
		if box == null:
			continue
		eq(box.bg_color.to_html(), (looks[state] as Color).to_html(), "%s %s's colour" % [what, state])
		eq(box.corner_radius_top_left, 0, "%s %s: square" % [what, state])
	var size := bar.get_combined_minimum_size()
	var thickness := size.x if bar is VScrollBar else size.y
	check(thickness > 0 and thickness <= Tokens.SPACE_2, "%s: no thicker than 8 px: %s" % [what, thickness])


func test_the_scrollbar_is_a_thin_steel_grabber_on_a_well() -> void:
	var main := open_main()
	var bar := VScrollBar.new()
	main.add_child(bar)
	await wait_frames()
	check_bar_look(bar, "the vertical bar")
	close_main(main)


# --- Backlog 363: sideways ---

## A SmoothScroll of SIZE with vertical scrolling disabled over 2000 px wide content in main, laid out.
func fixture_wide_scroll(main: Node) -> SmoothScroll:
	var scroll := SmoothScroll.new()
	scroll.position = Vector2(100, 100)
	scroll.size = SIZE
	scroll.z_index = 50  # above the board, so the wheel reaches it
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var wide := Control.new()
	wide.custom_minimum_size = Vector2(2000, SIZE.y / 2)
	scroll.add_child(wide)
	main.add_child(scroll)
	await wait_frames()
	return scroll


## The furthest scroll's scroll_horizontal can go.
func scroll_right_end(scroll: ScrollContainer) -> int:
	var bar := scroll.get_h_scroll_bar()
	return int(bar.max_value - bar.page)


func test_a_notch_glides_a_sideways_scroll_the_step_and_coasts_to_rest() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_wide_scroll(main)
		var step := int(Anim.SCROLL_STEP)
		for turn in [[MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, "wheel down", "wheel up"],
				[MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT, "wheel right", "wheel left"]]:
			wheel_turn(main, scroll, turn[0])
			eq(scroll.scroll_horizontal, 0, "%s: nothing moves in the notch's own frame" % turn[2])
			var seen: Array[int] = []
			for i in 8:
				await wait_frames(1)
				seen.append(scroll.scroll_horizontal)
			check(seen[0] > 0, "%s: moving after one frame: %s" % [turn[2], seen])
			check(seen[7] > seen[3] and seen[3] > seen[0], "%s: still coasting: %s" % [turn[2], seen])
			await wait_frames(240)
			check(absi(scroll.scroll_horizontal - step) <= 2, "%s: at rest a step right: %d" % [turn[2],
				scroll.scroll_horizontal])
			wheel_turn(main, scroll, turn[1])
			await wait_frames(240)
			eq(scroll.scroll_horizontal, 0, "%s brings it back" % turn[3])
		close_main(main))


func test_a_notch_past_the_right_end_stops_there_with_no_motion_left() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_wide_scroll(main)
		check(scroll_right_end(scroll) > 100, "room to scroll: %d" % scroll_right_end(scroll))
		scroll.scroll_horizontal = scroll_right_end(scroll) - 10
		await wait_frames()
		wheel_notch(main, scroll)
		await wait_frames(30)
		eq(scroll.scroll_horizontal, scroll_right_end(scroll), "stopped at the right end")
		scroll.scroll_horizontal = scroll_right_end(scroll) - 50
		await wait_frames(30)
		eq(scroll.scroll_horizontal, scroll_right_end(scroll) - 50, "no velocity left to carry it on")
		close_main(main))


func test_with_reduce_motion_a_notch_jumps_a_sideways_scroll_the_step() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		var scroll := await fixture_wide_scroll(main)
		wheel_notch(main, scroll)
		eq(scroll.scroll_horizontal, int(Anim.SCROLL_STEP), "one step right at once")
		await wait_frames(30)
		eq(scroll.scroll_horizontal, int(Anim.SCROLL_STEP), "and no further")
		close_main(main))


## Checks, on a board_engine game in a 1280 × 720 window with more cards in the hand than fit, that the hand is a
## SmoothScroll and Right across the hand brings the last card's slot wholly into view: in the same frame if calm,
## else once it settles.
func check_hand_follows_focus(calm: bool) -> void:
	await with_reduce_motion(calm, func(): await with_window_size(Vector2i(1280, 720), func():
		await with_main(board_engine(), func(main: Node):
			var e := Game.engine
			for i in 16:
				put_in_hand(e, "farm")
			e.changed.emit()
			await wait_frames()
			await settle_motion()
			var hand: ScrollContainer = main.hand_scroll
			check(hand is SmoothScroll, "the hand is a SmoothScroll, not a %s" % hand.get_class())
			var cards: Array = main.views_in(main.hand)
			var last: CardView = cards[-1]
			check(not hand.get_global_rect().encloses(last.slot.get_global_rect()), "the last card starts out of view")
			for i in cards.size():
				press_key(main, KEY_RIGHT)
				if i < cards.size() - 1:
					await wait_frames(1)
			eq(main.focus.focused, last, "Right reached the last card")
			if not calm:
				await wait_frames(120)
			var slot := last.slot.get_global_rect()
			check(hand.get_global_rect().encloses(slot), "its slot %s inside the hand %s" % [slot, hand.get_global_rect()])
			hand.scroll_horizontal = 0
			await wait_frames(1)
			for i in cards.size() - 1:
				press_key(main, KEY_LEFT)
			if not calm:
				await wait_frames(120)
			check(hand.get_global_rect().encloses((cards[0] as CardView).slot.get_global_rect()),
				"Left back to the first card shows it"))))


func test_the_hand_eases_the_focused_card_into_view() -> void:
	await check_hand_follows_focus(false)


func test_with_reduce_motion_the_hand_jumps_the_focused_card_into_view() -> void:
	await check_hand_follows_focus(true)


func test_the_sideways_scrollbar_is_a_thin_steel_grabber_on_a_well() -> void:
	var main := open_main()
	var bar := HScrollBar.new()
	main.add_child(bar)
	await wait_frames()
	check_bar_look(bar, "the horizontal bar")
	close_main(main)
