extends "res://tests/lib/test_case.gd"
## The territory view in the real main scene (backlog 101): a click on a settled territory's card (the single-click
## signal, details_requested) shows that territory, its city and buildings, stats and Grow in place of the Realm.
## Hooks on main.territory_view (a Control in the play area): is_open(), uid, back_button, grow_button, card_uids()
## (the cards shown, the territory first), stats_text() and target_at(global point) (the territory a drop there
## would target, or -1).


## Runs body(main) on the real main scene with Game.engine swapped for a TEST_CARDS game (deck, overrides; Grassland
## and Hills in the territory deck) started on seed 1, laid out; then puts the real engine back.
func with_fixture_main(body: Callable, deck := {"farm": 10}, overrides := {}) -> void:
	var real := Game.engine
	Game.engine = make_engine(deck, {"territory_deck": {"grassland": 1, "hills": 1}}.merged(overrides))
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}


## A single click on uid's card view (a Realm card sends details_requested once the double-click window passes).
func click(main: Node, uid: int) -> void:
	var view: CardView = main.views[uid]
	view.details_requested.emit(view)


## The uids of territory uid's group (engine order: the territory, then its city and buildings).
func group_cards(uid: int) -> Array[int]:
	var out: Array[int] = []
	for group in Game.engine.territory_groups():
		if group.territory == uid:
			out.assign(group.cards)
	return out


## The first button under main whose text starts with prefix, or null.
func button(main: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(main):
		if b.text.begins_with(prefix):
			return b
	return null


## A real left click (press and release) at the centre of uid's card view.
func mouse_click(main: Node, uid: int) -> void:
	var at: Vector2 = (main.views[uid] as CardView).get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		main.get_viewport().push_input(event, true)


func shown(c: Control) -> bool:
	return c != null and c.is_visible_in_tree()


# --- AC1: open ---

func test_clicking_a_territory_opens_its_view_in_place_of_the_realm() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm", "temple"])
		settle(e, ["grassland"])
		build_on(e, uid_of(e.zone("tableau"), "grassland"), ["farm"])
		e.changed.emit()  # build_on and settle bypass the actions that refresh the board
		await wait_frames()
		click(main, home)
		await wait_frames()
		var view: Object = main.territory_view
		check(view.is_open(), "the view is open")
		eq(view.uid, home, "for the home territory")
		eq(view.card_uids(), group_cards(home), "the territory, its Capital and its 2 buildings, in tableau order")
		check(not shown(main.tableau), "the Realm is hidden")
		check(shown(main.hand), "the hand is still shown")
		check(shown(button(main, "Menu")), "the top bar is still shown")
		check(shown(button(main, "End turn")), "the side panel is still shown")
		for uid in view.card_uids():
			check(shown(main.views[uid]), "card %d is shown in the view" % uid))


func test_clicking_a_city_or_building_still_shows_its_details() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var capital := uid_of(e.zone("tableau"), "capital")
		click(main, capital)
		await wait_frames()
		check(not main.territory_view.is_open(), "no view")
		eq(main.details.shown().get("name", ""), "Capital", "the Capital's details"))


# --- AC2: stats and Grow ---

func test_the_view_shows_slots_and_pop_and_grow() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		click(main, home)
		await wait_frames()
		var view: Object = main.territory_view
		var used := e.total_slots(home) - e.free_slots(home)
		var stats: String = view.stats_text()
		check(stats.contains("%d / %d slots used" % [used, e.total_slots(home)]), "slots in '%s'" % stats)
		check(stats.contains("Pop %d / %d" % [e.pop(home), e.housing(home)]), "pop in '%s'" % stats)
		var grow: Button = view.grow_button
		check(shown(grow), "Grow shown")
		eq(grow.text, "Grow (%d food)" % e.grow_cost(home), "Grow text")
		eq(grow.disabled, e.grow_error(home) != "", "disabled exactly when grow_error says so")
		eq(grow.tooltip_text, e.grow_error(home), "the reason as tooltip"), {"farm": 10}, POP)


func test_grow_in_the_view_adds_pop() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		e.resources.food = 20  # enough to grow
		e.changed.emit()
		click(main, home)
		await wait_frames()
		var view: Object = main.territory_view
		eq(e.grow_error(home), "", "can grow")
		var pop := e.pop(home)
		view.grow_button.pressed.emit()
		eq(e.pop(home), pop + 1, "pop +1")
		check(view.stats_text().contains("Pop %d / %d" % [pop + 1, e.housing(home)]), "stat updated: %s" % view.stats_text()), \
		{"farm": 10}, POP)


func test_grow_is_disabled_with_the_reason_when_it_cannot_grow() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		e.resources.food = 0
		e.changed.emit()
		click(main, home)
		await wait_frames()
		var grow: Button = main.territory_view.grow_button
		check(e.grow_error(home) != "", "can't grow with no food")
		check(grow.disabled, "disabled")
		eq(grow.tooltip_text, e.grow_error(home), "reason"), {"farm": 10}, POP)


func test_without_population_there_is_no_pop_stat_or_grow() -> void:
	await with_fixture_main(func(main: Node):
		click(main, home_uid(Game.engine))
		await wait_frames()
		var view: Object = main.territory_view
		check(not view.stats_text().contains("Pop"), "no Pop in '%s'" % view.stats_text())
		check(not shown(view.grow_button), "no Grow"))


# --- AC3: back ---

func test_back_and_esc_return_to_the_realm() -> void:
	await with_fixture_main(func(main: Node):
		var home := home_uid(Game.engine)
		for way in ["back", "esc"]:
			click(main, home)
			await wait_frames()
			check(main.territory_view.is_open(), "%s: open" % way)
			if way == "back":
				main.territory_view.back_button.pressed.emit()
			else:
				main.get_viewport().gui_release_focus()
				press_key(main, KEY_ESCAPE)
			await wait_frames()
			check(not main.territory_view.is_open(), "%s: closed" % way)
			check(shown(main.tableau), "%s: the Realm is back" % way)
			check(shown(main.views[home]), "%s: the territory card is back in the Realm" % way)
			check(not main.menu_buttons()[0].is_visible_in_tree(), "%s: no menu" % way))


func test_restart_new_game_and_game_over_close_the_view() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		click(main, home_uid(e))
		main.start_game(2)
		check(not main.territory_view.is_open(), "a new game closes it")
		check(shown(main.tableau), "the Realm is shown")
		click(main, home_uid(e))
		check(main.territory_view.is_open(), "open again")
		while not e.is_over:
			e.end_turn()
		check(not main.territory_view.is_open(), "game over closes it"), {"farm": 10}, {"turn_limit": 3})


# --- AC4: playing onto the viewed territory ---

func test_a_drop_anywhere_on_the_view_targets_its_territory() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		e.changed.emit()
		click(main, grass)
		await wait_frames()
		var view: Control = main.territory_view
		var rect := view.get_global_rect()
		eq(view.target_at(rect.get_center()), grass, "the middle of the view")
		eq(view.target_at(rect.position + Vector2(4, 4)), grass, "its corner")
		eq(view.target_at(rect.end + Vector2(20, 20)), -1, "outside the view")
		check(home != grass, "two territories"))


func test_double_clicking_a_building_plays_it_onto_the_viewed_territory() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		click(main, grass)
		await wait_frames()
		check(main.territory_view.is_open(), "Grassland's view is open")
		check(e.needs_target_choice(temple), "Temple could go on either territory")
		main.on_double_clicked(main.views[temple])
		await wait_frames()
		var card: CardInstance = e.zone("tableau").find(temple)
		check(card != null, "Temple played")
		if card != null:
			eq(card.territory_uid, grass, "onto the viewed territory")
		check(main.territory_view.card_uids().has(temple), "shown in the view")
		eq(main.drag.targeting, null, "no targeting mode"))


func test_double_clicking_a_building_the_viewed_territory_cannot_take_says_why() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var well := put_in_hand(e, "well")  # needs Fresh Water, which Grassland lacks
		e.resources.food = 5
		e.changed.emit()
		click(main, grass)
		await wait_frames()
		check(main.territory_view.is_open(), "Grassland's view is open")
		var reason := e.play_error(well, grass)
		check(reason != "", "Well can't go on Grassland")
		main.on_double_clicked(main.views[well])
		check(e.zone("hand").find(well) != null, "Well stays in the hand")
		eq(main.drag.targeting, null, "no targeting mode")
		var log := ""
		for c in main.find_children("*", "RichTextLabel", true, false):
			log += c.get_parsed_text()
		check(log.contains(reason), "the reason is shown: %s" % reason))


# --- AC5: targeting wins ---

func test_clicking_a_territory_while_targeting_picks_it() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		main.on_double_clicked(main.views[temple])
		check(main.drag.targeting != null, "targeting")
		mouse_click(main, grass)  # the lit territory card
		await (Engine.get_main_loop() as SceneTree).create_timer(Anim.DETAILS_CLICK_DELAY + 0.1).timeout
		eq(e.zone("tableau").find(temple).territory_uid if e.zone("tableau").find(temple) != null else -1, grass, "played there")
		check(not main.territory_view.is_open(), "no view"))


# --- AC6: keyboard ---

func test_up_from_the_hand_reaches_the_territories_and_enter_opens_one() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		e.changed.emit()
		await wait_frames()
		press_key(main, KEY_RIGHT)
		check(main.focus.focused != null and main.focus.focused.in_hand, "a hand card focused")
		press_key(main, KEY_UP)
		eq(main.focus.focused.uid if main.focus.focused != null else -1, home, "Up: the first territory")
		press_key(main, KEY_RIGHT)
		eq(main.focus.focused.uid if main.focus.focused != null else -1, grass, "Right: the next territory")
		press_key(main, KEY_DOWN)
		check(main.focus.focused != null and main.focus.focused.in_hand, "Down: back to the hand")
		press_key(main, KEY_UP)
		press_key(main, KEY_RIGHT)
		press_key(main, KEY_ENTER)
		await wait_frames()
		check(main.territory_view.is_open(), "Enter opens the view")
		eq(main.territory_view.uid, grass, "for Grassland"))


func test_keys_in_the_view_move_through_its_cards_show_details_and_esc_closes() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		await wait_frames()
		press_key(main, KEY_RIGHT)
		press_key(main, KEY_UP)
		press_key(main, KEY_ENTER)
		await wait_frames()
		var cards: Array[int] = main.territory_view.card_uids()
		eq(main.focus.focused.uid if main.focus.focused != null else -1, cards[0], "the territory card focused")
		press_key(main, KEY_RIGHT)
		eq(main.focus.focused.uid if main.focus.focused != null else -1, cards[1], "Right: its city")
		press_key(main, KEY_I)
		eq(main.details.shown().get("name", ""), e.zone("tableau").find(cards[1]).def.name, "I: its details")
		press_key(main, KEY_ESCAPE)  # closes the details
		press_key(main, KEY_ESCAPE)  # closes the view
		await wait_frames()
		check(not main.territory_view.is_open(), "Esc closes the view")
		eq(main.focus.focused.uid if main.focus.focused != null else -1, home, "the focus is back on the territory"))
