extends "res://tests/lib/test_case.gd"
## A scroll area that glides (backlog 356, guide §7.17 "Scroll area"): SmoothScroll takes the wheel itself, so a notch
## eases the content Anim.SCROLL_STEP px with momentum that coasts to a stop at the content's ends; Reduce motion jumps.
## The theme's vertical scrollbar: a thin steel grabber on a well track.

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


## One wheel notch (down, or up) at the centre of scroll, as the mouse sends it: pressed, then released.
func wheel(main: Node, scroll: ScrollContainer, down := true) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		event.factor = 1.0
		event.position = scroll.get_global_rect().get_center()
		event.global_position = event.position
		main.get_viewport().push_input(event, true)


## The furthest scroll_vertical can go.
func bottom(scroll: ScrollContainer) -> int:
	var bar := scroll.get_v_scroll_bar()
	return int(bar.max_value - bar.page)


# --- AC1: a notch glides and coasts ---

func test_a_wheel_notch_glides_the_step_and_coasts_to_rest() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		wheel(main, scroll)
		eq(scroll.scroll_vertical, 0, "nothing moves in the notch's own frame")
		var seen: Array[int] = []
		for i in 8:
			await wait_frames(1)
			seen.append(scroll.scroll_vertical)
		check(seen[0] > 0, "moving after one frame: %s" % [seen])
		check(seen[7] > seen[3] and seen[3] > seen[0], "still coasting frames after the notch: %s" % [seen])
		await wait_frames(240)
		check(absi(scroll.scroll_vertical - int(Anim.SCROLL_STEP)) <= 2, "at rest one step down: %d" % scroll.scroll_vertical)
		wheel(main, scroll, false)
		await wait_frames(240)
		eq(scroll.scroll_vertical, 0, "a notch up brings it back")
		close_main(main))


# --- AC2: the ends ---

func test_a_notch_past_the_bottom_stops_there_with_no_motion_left() -> void:
	await with_reduce_motion(false, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		scroll.scroll_vertical = bottom(scroll) - 10
		await wait_frames()
		wheel(main, scroll)
		await wait_frames(30)
		eq(scroll.scroll_vertical, bottom(scroll), "stopped at the bottom")
		scroll.scroll_vertical = bottom(scroll) - 50
		await wait_frames(30)
		eq(scroll.scroll_vertical, bottom(scroll) - 50, "no velocity left to carry it on")
		close_main(main))


# --- AC3: Reduce motion ---

func test_with_reduce_motion_a_notch_jumps_the_step() -> void:
	await with_reduce_motion(true, func():
		var main := open_main()
		var scroll := await fixture_scroll(main)
		wheel(main, scroll)
		eq(scroll.scroll_vertical, int(Anim.SCROLL_STEP), "one step down at once")
		await wait_frames(30)
		eq(scroll.scroll_vertical, int(Anim.SCROLL_STEP), "and no further")
		close_main(main))


# --- AC4: the scrollbar ---

func test_the_scrollbar_is_a_thin_steel_grabber_on_a_well() -> void:
	var main := open_main()
	var bar := VScrollBar.new()
	main.add_child(bar)
	await wait_frames()
	var looks := {"grabber": Palette.CONTROL, "grabber_highlight": Palette.TEXT_DIM, "grabber_pressed": Palette.TEXT_DIM,
		"scroll": Palette.FIELD}
	for state in looks:
		var box := bar.get_theme_stylebox(state) as StyleBoxFlat
		check(box.draw_center, "%s: a filled box" % state)
		eq(box.bg_color.to_html(), (looks[state] as Color).to_html(), "%s's colour" % state)
		eq(box.corner_radius_top_left, 0, "%s: square" % state)
	var width := bar.get_combined_minimum_size().x
	check(width > 0 and width <= Tokens.SPACE_2, "no wider than 8 px: %s" % width)
	close_main(main)
