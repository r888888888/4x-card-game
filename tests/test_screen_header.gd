extends "res://tests/lib/test_case.gd"
## The screen header and transitions in the real main scene (backlog 104): the new game and settings screens and
## the territory view each carry a ScreenHeader (`header`: back_button, breadcrumb_text()), and a territory's view
## grows out of its card. with_reduce_motion (test_case.gd) sets Reduce motion for the transition test.


## Runs body(main) on the real main scene with Game.engine swapped for a TEST_CARDS game on seed 1.
func with_fixture_main(body: Callable) -> void:
	var real := Game.engine
	Game.engine = make_engine({"farm": 10})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


# --- AC3: every navigated screen has the header ---

func test_the_new_game_and_settings_screens_have_a_header() -> void:
	var main := open_main()
	main.start_screen.new_game_button.pressed.emit()
	var header: Object = main.new_game_screen.header
	eq(header.back_button.text, "← Main menu", "new game: back")
	eq(header.breadcrumb_text(), "Main menu › New game", "new game: path")
	eq(main.new_game_screen.back_button, header.back_button, "its Back is the header's")
	header.back_button.pressed.emit()
	main.start_screen.settings_button.pressed.emit()
	header = main.settings_screen.header
	eq(header.back_button.text, "← Main menu", "settings: back")
	eq(header.breadcrumb_text(), "Main menu › Settings", "settings: path")
	eq(main.settings_screen.back_button, header.back_button, "its Back is the header's")
	close_main(main)


func test_the_territory_view_has_a_header() -> void:
	await with_fixture_main(func(main: Node):
		var home := home_uid(Game.engine)
		main.views[home].details_requested.emit(main.views[home])  # a click on the territory
		var header: Object = main.territory_view.header
		eq(header.back_button.text, "← Realm", "back")
		eq(header.breadcrumb_text(), "Realm › Homeland", "path")
		eq(main.territory_view.back_button, header.back_button, "its Back is the header's")
		header.back_button.pressed.emit()
		check(not main.territory_view.is_open(), "the header's back closes the view"))


# --- AC6: a territory's view grows out of its card ---

func test_a_territory_view_grows_out_of_its_card_and_shrinks_back() -> void:
	await with_reduce_motion(false, func():
		await with_fixture_main(func(main: Node):
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
