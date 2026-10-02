extends "res://tests/lib/test_case.gd"
## The screen header and transitions in the real main scene (backlog 104): the new game and settings screens and
## the territory view each carry a ScreenHeader (`header`: back_button, breadcrumb_text()), and a territory's view
## grows out of its card. with_reduce_motion (test_case.gd) sets Reduce motion for the transition test.


## Runs body(main) on the real main scene with Game.engine swapped for a TEST_CARDS game on seed 1.
func with_farm_main(body: Callable) -> void:
	var real := Game.engine
	Game.engine = make_engine({"farm": 10})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


# --- AC3: every navigated screen has the header ---

func test_the_new_game_screen_has_a_header() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	var header: Object = main.new_game_screen.header
	eq(header.back_button.text, "Main menu", "new game: the link back (118)")
	eq(header.breadcrumb_text(), "Main menu › New game", "new game: path")
	eq(main.new_game_screen.back_button, header.back_button, "its Back is the header's")
	header.back_button.pressed.emit()  # Settings is a modal since 206: no screen, no header
	close_main(main)


func test_the_territory_view_has_a_header() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])  # a click on the territory
		var header: Object = main.territory_view.header
		eq(header.back_button.text, "Realm", "the link back (118)")
		eq(header.breadcrumb_text(), "Realm › Homeland", "path")
		eq(main.territory_view.back_button, header.back_button, "its Back is the header's")
		header.back_button.pressed.emit()
		check(not main.territory_view.is_open(), "the header's back closes the view"))


# --- AC6: a territory's view grows out of its card ---

func test_a_territory_view_grows_out_of_its_card_and_shrinks_back() -> void:
	await with_reduce_motion(false, func():
		await with_farm_main(func(main: Node):
			var home := home_uid(Game.engine)
			var card := (main.views[home] as CardView).get_global_rect()
			main.views[home].details_requested.emit(main.views[home])
			var view: Control = main.territory_view
			check(view.scale.x < 1.0, "starts small: %s" % view.scale)
			var top_left: Vector2 = view.get_global_transform() * Vector2.ZERO
			check(top_left.distance_to(card.position) < 2.0, "over the card: %s vs %s" % [top_left, card.position])
			await wait_screen_transition()
			eq(view.scale, Vector2.ONE, "full size")
			view.back_button.pressed.emit()
			check(not view.is_open(), "closed at once")
			check(main.tableau.is_visible_in_tree(), "the Realm is back at once")
			check(view.visible and view.scale.x <= 1.0, "still drawn while it shrinks")
			await wait_screen_transition()
			check(not view.visible, "then hidden")))



# --- 118: the parent title is the way back ---

## Checks header's link back: the parent's title as a flat link (hand cursor, "Back to …" tooltip), first in the
## header, followed by the current title as plain text, and no "←" button anywhere in the header.
func check_link_back(header: Control, parent_title: String, title: String) -> void:
	var link: Button = header.back_button
	eq(link.text, parent_title, "the link names the screen below")
	check(link.flat, "a flat link, not a boxed button")
	eq(link.mouse_default_cursor_shape, Control.CURSOR_POINTING_HAND, "a hand cursor")
	eq(link.tooltip_text, "Back to %s" % parent_title, "tooltip")
	eq(header.breadcrumb_text(), "%s › %s" % [parent_title, title], "the breadcrumb reads as before")
	var buttons := UIKit.buttons_in(header)
	eq(buttons, [link], "the link is the header's only button: the current title is plain text")
	check(not buttons.any(func(b: Button): return b.text.contains("←")), "no ← button")


func test_the_territory_header_goes_back_through_its_realm_link() -> void:
	await with_farm_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])
		check_link_back(main.territory_view.header, "Realm", "Homeland")
		main.territory_view.header.back_button.pressed.emit()
		check(not main.territory_view.is_open(), "the link closes the view"))


func test_the_new_game_header_goes_back_through_its_main_menu_link() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	check_link_back(main.new_game_screen.header, "Main menu", "New game")
	main.new_game_screen.header.back_button.pressed.emit()
	check(not main.new_game_screen.is_open(), "the link goes back to the title screen")
	check(main.start_screen.is_open(), "back on the title screen")
	close_main(main)
