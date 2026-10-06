extends "res://tests/lib/test_case.gd"
## The territory view in the real main scene (backlog 101): a click on a settled territory's card (the single-click
## signal, details_requested) shows that territory, its city and buildings and stats in place of the Realm (no Grow
## since 260). Hooks on main.territory_view (a Control in the play area): is_open(), uid, back_button, card_uids()
## (the cards shown, the territory first), stats_text() and target_at(global point) (the territory a drop there
## would target, or -1).
## In detail (from docs/testing.md, 331): The territory view in the real `main.tscn` (101) on a TEST_CARDS game: a
## click on a territory opens it in place of the Realm (a city's click still shows details), stats, Back / Esc / new
## game / game over close it, drops and double-clicks play onto it, targeting wins over opening, ↑/↓ and Enter from the
## hand; uses `main.territory_view` (`is_open`, `uid`, `card_uids`, `stats_text`, `target_at`, `back_button`); 105: the
## territory as the framed box (its name and info as the title, stats above the cards, its card left in the Realm),
## free-slot outlines after the cards, no pop-in or fly-off when opening or closing (`frame`, `title_text()`,
## `outlines()`, `free_slot_count()`); 200, 327: a left click anywhere outside the box (the hand, top bar, sidebar, a
## card or button there) only closes it, a drag from the hand still targets it, a modal over it takes the click first;
## 342: the city, buildings and enabled free slots take a hover look and the `ui.hover` tick


const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}


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
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm", "temple"])
		settle(e, ["grassland"])
		build_on(e, uid_of(e.zone("tableau"), "grassland"), ["farm"])
		e.changed.emit()  # build_on and settle bypass the actions that refresh the board
		await wait_frames()
		open_details(main, home)
		await wait_frames()
		var view: Object = main.territory_view
		check(view.is_open(), "the view is open")
		eq(view.uid, home, "for the home territory")
		eq(view.card_uids(), group_cards(home).slice(1), "its Capital and its 2 buildings, in tableau order (105: the territory is the box)")
		check(not shown(main.tableau), "the Realm is hidden")
		check(shown(main.hand), "the hand is still shown")
		check(shown(button(main, "Menu")), "the top bar is still shown")
		check(shown(button(main, "End turn")), "End turn is still shown")
		for uid in view.card_uids():
			check(shown(main.views[uid]), "card %d is shown in the view" % uid))


func test_clicking_a_city_or_building_still_shows_its_details() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		open_details(main, home)  # 102: a city has a card only in its territory's view
		await wait_frames()
		var capital := uid_of(e.zone("tableau"), "capital")
		open_details(main, capital)
		await wait_frames()
		eq(main.territory_view.uid, home, "still the home territory's view")
		eq(main.details.shown().get("name", ""), "Capital", "the Capital's details"))


# --- AC2: stats ---

func test_the_view_shows_slots_and_pop() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		open_details(main, home)
		await wait_frames()
		var view: Object = main.territory_view
		var stats: String = view.stats_text()
		eq(stats, "▢ %d   ⌂ %d/%d   ⚒ %d   ⛨ %d" % [e.free_slots(home), e.pop(home), e.housing(home),
			e.free_workers(home), e.defense(home)],
			"the card's live line (123)"), \
		{"farm": 10}, POP)


func test_without_population_there_is_no_pop_stat() -> void:
	await with_territories_main(func(main: Node):
		open_details(main, home_uid(Game.engine))
		await wait_frames()
		var view: Object = main.territory_view
		var home := home_uid(Game.engine)
		eq(view.stats_text(), "▢ %d   ⛨ %d" % [Game.engine.free_slots(home), Game.engine.defense(home)],
			"free slots and defence (123, 161)"))


# --- AC3: back ---

func test_back_and_esc_return_to_the_realm() -> void:
	await with_territories_main(func(main: Node):
		var home := home_uid(Game.engine)
		for way in ["back", "esc"]:
			open_details(main, home)
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
	await with_territories_main(func(main: Node):
		var e := Game.engine
		open_details(main, home_uid(e))
		main.start_game(2)
		check(not main.territory_view.is_open(), "a new game closes it")
		check(shown(main.tableau), "the Realm is shown")
		open_details(main, home_uid(e))
		check(main.territory_view.is_open(), "open again")
		while not e.is_over:
			e.end_turn()
		check(not main.territory_view.is_open(), "game over closes it"), {"farm": 10}, {"turn_limit": 3})


# --- AC4: playing onto the viewed territory ---

func test_a_drop_anywhere_on_the_view_targets_its_territory() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		e.changed.emit()
		open_details(main, grass)
		await wait_frames()
		var view: Control = main.territory_view
		var rect := view.get_global_rect()
		eq(view.target_at(rect.get_center()), grass, "the middle of the view")
		eq(view.target_at(rect.position + Vector2(4, 4)), grass, "its corner")
		eq(view.target_at(rect.end + Vector2(20, 20)), -1, "outside the view")
		check(home != grass, "two territories"))


func test_double_clicking_a_building_plays_it_onto_the_viewed_territory() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		open_details(main, grass)
		await wait_frames()
		check(main.territory_view.is_open(), "Grassland's view is open")
		check(e.needs_target_choice(temple), "Temple could go on either territory")
		main.card_actions.on_double_clicked(main.views[temple])
		await wait_frames()
		var card: CardInstance = e.zone("tableau").find(temple)
		check(card != null, "Temple played")
		if card != null:
			eq(card.territory_uid, grass, "onto the viewed territory")
		check(main.territory_view.card_uids().has(temple), "shown in the view")
		eq(main.drag.targeting, null, "no targeting mode"))


func test_double_clicking_a_building_the_viewed_territory_cannot_take_says_why() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var well := put_in_hand(e, "well")  # needs Fresh Water, which Grassland lacks
		e.resources.food = 5
		e.changed.emit()
		open_details(main, grass)
		await wait_frames()
		check(main.territory_view.is_open(), "Grassland's view is open")
		var reason := e.play_error(well, grass)
		check(reason != "", "Well can't go on Grassland")
		main.card_actions.on_double_clicked(main.views[well])
		check(e.zone("hand").find(well) != null, "Well stays in the hand")
		eq(main.drag.targeting, null, "no targeting mode")
		var log := ""
		for c in main.find_children("*", "RichTextLabel", true, false):
			log += c.get_parsed_text()
		check(log.contains(reason), "the reason is shown: %s" % reason))


# --- AC5: targeting wins ---

func test_clicking_a_territory_while_targeting_picks_it() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		main.card_actions.on_double_clicked(main.views[temple])
		check(main.drag.targeting != null, "targeting")
		mouse_click(main, grass)  # the lit territory card
		await (Engine.get_main_loop() as SceneTree).create_timer(Anim.DETAILS_CLICK_DELAY + 0.1).timeout
		eq(e.zone("tableau").find(temple).territory_uid if e.zone("tableau").find(temple) != null else -1, grass, "played there")
		check(not main.territory_view.is_open(), "no view"))


# --- AC6: keyboard ---

func test_up_from_the_hand_reaches_the_territories_and_enter_opens_one() -> void:
	await with_territories_main(func(main: Node):
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
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		await wait_frames()
		press_key(main, KEY_RIGHT)
		press_key(main, KEY_UP)
		press_key(main, KEY_ENTER)
		await wait_frames()
		var cards: Array[int] = main.territory_view.card_uids()  # 105: the Capital, then the Farm
		eq(main.focus.focused.uid if main.focus.focused != null else -1, cards[0], "its city focused (105)")
		press_key(main, KEY_RIGHT)
		eq(main.focus.focused.uid if main.focus.focused != null else -1, cards[1], "Right: its building")
		press_key(main, KEY_I)
		eq(main.details.shown().get("name", ""), e.zone("tableau").find(cards[1]).def.name, "I: its details")
		press_key(main, KEY_ESCAPE)  # closes the details
		press_key(main, KEY_ESCAPE)  # closes the view
		await wait_frames()
		check(not main.territory_view.is_open(), "Esc closes the view")
		eq(main.focus.focused.uid if main.focus.focused != null else -1, home, "the focus is back on the territory"))


# --- Backlog 105: the layout ---
# Hooks: territory_view.frame (the framed panel), .title_text() (its title line: the territory's name and info), .row
# (its city and buildings, then the outlines), .outlines() (the free-slot outlines, in order) and .free_slot_count().

func open_home(main: Node) -> int:
	var home := home_uid(Game.engine)
	open_details(main, home)
	await wait_screen_transition()
	return home


func test_the_view_is_framed_in_the_territory_colour() -> void:
	await with_territories_main(func(main: Node):
		await open_home(main)
		var frame: Control = main.territory_view.frame
		check(frame.is_visible_in_tree(), "the frame is shown")
		var box := frame.get_theme_stylebox("panel") as StyleBoxFlat
		check(box != null, "a flat panel")
		if box != null:
			eq(box.border_color.to_html(), CardView.TYPE_COLORS[CardDef.TERRITORY].to_html(), "bordered in the territory colour")
			check(box.bg_color.a > 0.0, "a tinted background")
		check(frame.is_ancestor_of(main.territory_view.row), "the cards are inside it"))


func test_the_territory_is_the_box_with_its_name_info_stats_and_actions_on_top() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home: int = await open_home(main)
		var view: Object = main.territory_view
		var territory: CardInstance = e.zone("tableau").find(home)
		var title: String = view.title_text()
		check(title.contains(territory.def.name), "the name in '%s'" % title)
		check(title.ends_with(load("res://ui/card_face.gd").keyword_line(territory)), "its keywords in '%s'" % title)
		check(not title.contains("▢") and not title.contains("⌂"), "no slots or housing beside the name: '%s'" % title)
		var card: CardView = main.views[home]
		check(not view.is_ancestor_of(card.slot), "the territory's card isn't in the view")
		eq(card.slot.get_parent(), main.tableau.row, "it stays in the Realm")
		eq(view.card_uids(), group_cards(home).slice(1), "the view's cards: its city and buildings")
		var top: float = view.row.get_global_rect().position.y
		var stats: Array = view.find_children("*", "RichTextLabel", true, false).filter(
			func(l): return l.get_meta("source", "") == view.stats_text())  # drawn with icons since 123
		check(not stats.is_empty(), "the stats line")
		for c in stats + [view.rename_button]:
			check(view.frame.is_ancestor_of(c), "%s in the box" % c)
			check((c as Control).get_global_rect().end.y <= top + 1.0, "%s above the cards" % c), \
		{"farm": 10}, POP)


func test_free_slots_show_as_outlines_after_the_cards() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await open_home(main)
		var view: Object = main.territory_view
		eq(view.free_slot_count(), e.free_slots(home), "one outline per free slot")
		var last_card := -1
		for v in main.views_in(view.row):
			last_card = maxi(last_card, v.slot.get_index())
		for outline in view.outlines():
			check(outline.get_index() > last_card, "the outlines come after the cards")
		var before: int = view.free_slot_count()
		main.card_actions.on_double_clicked(main.views[temple])
		await wait_frames()
		eq(view.free_slot_count(), before - 1, "one fewer after the Temple")
		eq(view.free_slot_count(), e.free_slots(home), "still one per free slot"))


func test_a_full_territory_shows_no_outlines() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var fill: Array = []
		for i in e.free_slots(home):
			fill.append("farm")
		build_on(e, home, fill)
		e.changed.emit()
		await open_home(main)
		eq(e.free_slots(home), 0, "full")
		eq(main.territory_view.free_slot_count(), 0, "no outlines"))


func test_an_outline_is_a_drop_target_for_the_territory() -> void:
	await with_territories_main(func(main: Node):
		var home: int = await open_home(main)
		var view: Object = main.territory_view
		check(view.free_slot_count() > 0, "an outline to drop on")
		if view.free_slot_count() > 0:
			var at: Vector2 = (view.outlines()[0] as Control).get_global_rect().get_center()
			eq(view.target_at(at), home, "a drop on an outline targets the territory")
			eq(main.drag.target_at(at), home, "and the drag agrees"))


# --- 105 AC5: no bounce when navigating ---

func test_opening_shows_the_cards_at_once_without_a_bounce() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		await wait_frames()
		open_details(main, home)
		for uid in main.territory_view.card_uids():
			var v: CardView = main.views.get(uid)
			check(v != null, "card %d has a view at once" % uid)
			if v != null:
				eq(v.state, CardView.State.REST, "card %d at rest at once" % uid)
				eq(v.fx_scale, Vector2.ONE, "card %d at full size (no pop-in)" % uid)
		eq(main.views[home].slot.get_parent(), main.tableau.row, "the territory's card didn't move"))


func test_closing_removes_the_cards_at_once() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		open_details(main, home)
		await wait_screen_transition()
		var shown: Array[int] = main.territory_view.card_uids()
		main.territory_view.back_button.pressed.emit()
		for uid in shown:
			check(not main.views.has(uid), "card %d's view is gone at once" % uid)
		var leaving: Array = main.fx.get_children().filter(func(c): return c is CardView and shown.has(c.uid))
		eq(leaving.size(), 0, "none of the view's cards flies off (hand cards may still be being dealt)")
		eq(main.views[home].state, CardView.State.REST, "the territory's card stays at rest"))


func test_a_card_played_in_the_view_still_flies_in() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		open_details(main, home)
		await wait_screen_transition()
		main.card_actions.on_double_clicked(main.views[temple])
		eq(main.views[temple].state, CardView.State.FLYING, "the Temple flies to its slot"))


# --- 200: a click outside the box closes the view ---

## A real mouse press and release of button at global point on main's viewport.
func mouse_at(main: Node, point: Vector2, button_index := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button_index
		event.pressed = pressed
		event.position = point
		event.global_position = point
		main.get_viewport().push_input(event, true)


## A point on the open view's area outside the territory box: its bottom-right corner, inset.
func outside_box(main: Node) -> Vector2:
	var point: Vector2 = main.territory_view.get_global_rect().end - Vector2(8, 8)
	check(not main.territory_view.frame.get_global_rect().has_point(point), "precondition: the box leaves room beside or below it")
	return point


func test_a_click_outside_the_box_goes_back_to_the_realm() -> void:
	await with_territories_main(func(main: Node):
		var home: int = await open_home(main)
		main.sfx.set_clock(0.0)
		var from: int = main.sfx.played().size()
		mouse_at(main, outside_box(main))
		await wait_frames()
		check(not main.territory_view.is_open(), "closed")
		await wait_screen_transition()
		check(shown(main.tableau), "the Realm is back")
		check(shown(main.views[home]), "the territory's card is back")
		var played: Array = main.sfx.played().slice(from).map(func(r): return r.token)
		eq(played.filter(func(t): return t == Sfx.NAV_BACK).size(), 1, "the back sound, once: %s" % [played]))


func test_a_click_inside_the_box_leaves_the_view_open() -> void:
	await with_territories_main(func(main: Node):
		await open_home(main)
		var view: TerritoryView = main.territory_view
		var title_rect: Rect2 = view.frame.get_global_rect()
		for point in [title_rect.position + Vector2(12, 12), title_rect.get_center(), title_rect.end - Vector2(12, 12)]:
			mouse_at(main, point)
			await wait_frames()
			check(view.is_open(), "a click in the box at %s leaves it open" % point)
		var outline: Panel = view.outlines()[0]
		mouse_at(main, outline.get_global_rect().get_center())
		await wait_frames()
		check(view.is_open(), "a click on an empty slot outline leaves it open"), \
		{"farm": 10}, POP)


# --- 327: a click anywhere outside the box closes the view, and does nothing else ---

## A real mouse move to global point on main's viewport, with the left button held when held.
func mouse_move(main: Node, point: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	main.get_viewport().push_input(event, true)


## Clicks point with the home territory's view open and checks it closed with one NAV_BACK.
func check_click_closes(main: Node, point: Vector2, where: String) -> void:
	await open_home(main)
	main.sfx.set_clock(main.sfx.clock() + 60.0)  # past earlier checks' sounds, which would fill the voices
	var from: int = main.sfx.played().size()
	mouse_at(main, point)
	await wait_frames()
	check(not main.territory_view.is_open(), "a click on %s closes the view" % where)
	await wait_screen_transition()
	check(shown(main.tableau), "the Realm is back after a click on %s" % where)
	var played: Array = main.sfx.played().slice(from).map(func(r): return r.token)
	eq(played.filter(func(t): return t == Sfx.NAV_BACK).size(), 1, "the back sound, once, for %s: %s" % [where, played])


func test_a_click_on_the_hand_or_sidebar_space_closes_the_view() -> void:
	await with_territories_main(func(main: Node):
		await check_click_closes(main, main.hand_scroll.get_global_rect().end - Vector2(8, 8), "the hand's empty space")
		var rail: Rect2 = main.sidebar.get_global_rect()
		await check_click_closes(main, Vector2(rail.get_center().x, main.sidebar.column.get_global_rect().position.y + 2),
			"the sidebar's padding"))


func test_a_click_on_a_control_outside_the_box_only_closes_the_view() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var hand_card: CardView = main.views[first_in_hand(e)]
		await wait_seconds(1.5)  # the opening deal settles: a hand card in motion takes no clicks
		var controls := {
			"a hand card": hand_card,
			"a top-bar counter": main.counter(GameEngine.FOOD),
			"End turn": main.sidebar.end_turn,
			"the civilization's name": main.sidebar.name_button,
		}
		for where in controls:
			var control: Control = controls[where]
			var turn := e.turn
			var hand := e.zone("hand").cards.size()
			var actions := e.actions_left()
			await check_click_closes(main, control.get_global_rect().get_center(), where)
			await wait_seconds(Anim.DETAILS_CLICK_DELAY + 0.1)
			check(not main.details.shown(), "a click on %s opens no details" % where)
			check(main.modals.top() == null, "a click on %s opens no modal" % where)
			eq(e.turn, turn, "a click on %s doesn't end the turn" % where)
			eq(e.zone("hand").cards.size(), hand, "a click on %s plays nothing" % where)
			eq(e.actions_left(), actions, "a click on %s spends no action" % where)
		mouse_move(main, hand_card.get_global_rect().get_center() + Vector2(0, -40), false)
		await wait_frames()
		check(main.drag.dragging == null, "a later mouse move doesn't pick up the clicked hand card"))


func test_a_drag_from_the_hand_onto_the_view_still_targets_the_territory() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home: int = await open_home(main)
		var view: TerritoryView = main.territory_view
		var card := first_in_hand(e)
		var start: Vector2 = (main.views[card] as CardView).get_global_rect().get_center()
		var point := outside_box(main)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = start
		press.global_position = start
		main.get_viewport().push_input(press, true)
		mouse_move(main, start + Vector2(0, -20))
		await wait_frames()
		check(main.drag.dragging != null, "precondition: the press on the hand card started a drag")
		mouse_move(main, point)
		await wait_frames()
		eq(main.drag.target_at(point), home, "a drop there targets the territory (101)")
		var release := press.duplicate() as InputEventMouseButton
		release.pressed = false
		release.position = point
		release.global_position = point
		main.get_viewport().push_input(release, true)
		await wait_frames()
		check(main.drag.dragging == null, "the release dropped the card")
		check(view.is_open(), "the view stays open after the drop"))


func test_a_click_outside_a_modal_over_the_view_closes_only_the_modal() -> void:
	await with_territories_main(func(main: Node):
		await open_home(main)
		var view: TerritoryView = main.territory_view
		main.details.open_def(Game.engine.zone("hand").cards[0].def.id)
		await wait_frames()
		mouse_at(main, main.hand_scroll.get_global_rect().end - Vector2(8, 8))
		await wait_frames()
		check(not main.details.shown(), "the modal closed")
		check(view.is_open(), "the view stays open"))


func test_a_right_click_on_the_hand_leaves_the_view_open() -> void:
	await with_territories_main(func(main: Node):
		await open_home(main)
		mouse_at(main, main.hand_scroll.get_global_rect().end - Vector2(8, 8), MOUSE_BUTTON_RIGHT)
		await wait_frames()
		check(main.territory_view.is_open(), "a right-click outside the box leaves it open"))


func test_with_the_view_closed_end_turn_still_works() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var turn := e.turn
		mouse_at(main, main.sidebar.end_turn.get_global_rect().get_center())
		await wait_frames()
		eq(e.turn, turn + 1, "End turn ends the turn when no view is open"))


func test_a_drop_or_right_click_outside_the_box_leaves_the_view_open() -> void:
	await with_territories_main(func(main: Node):
		var home: int = await open_home(main)
		var view: TerritoryView = main.territory_view
		var point := outside_box(main)
		eq(view.target_at(point), home, "a drop there targets the territory (101)")
		var card: CardView = main.views[first_in_hand(Game.engine)]
		main.drag.begin_drag(card, Vector2.ZERO)
		mouse_at(main, point)
		await wait_frames()
		check(view.is_open(), "a drop outside the box leaves it open")
		mouse_at(main, point, MOUSE_BUTTON_RIGHT)
		await wait_frames()
		check(view.is_open(), "a right-click there does nothing"))


func test_a_second_outside_click_while_leaving_does_nothing() -> void:
	await with_territories_main(func(main: Node):
		await open_home(main)
		var view: TerritoryView = main.territory_view
		var point := outside_box(main)
		var steps := [0]
		view.navigated.connect(func(): steps[0] += 1)
		mouse_at(main, point)
		mouse_at(main, point)
		await wait_screen_transition()
		eq(steps[0], 1, "one step back")
		check(shown(main.tableau), "the Realm is shown"))


# --- Backlog 342: hover ---
# Hover in the territory view (342) in the real main.tscn, its sound clock frozen at 0: the city and building cards
# take the card hover look (ink border, the hover shadow) and tick `ui.hover` once as the mouse enters, a free slot
# inks its outline and ticks once while its "+ Build" is enabled, and a disabled or hidden slot, a Realm card and a
# held mouse stay as they were.

const MENU := {"farm": {}}
const Looks := preload("res://tests/lib/surface_looks.gd")


## Runs body(main) on a 1920×1080 main over a territories game with build menu menu, a Farm built on the home
## territory and the home territory's view open. Use with await.
func with_view(body: Callable, menu := MENU) -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	window.size = Vector2i(1920, 1080)
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		e.changed.emit()
		main.sfx.set_clock(0.0)
		open_details(main, home)
		await wait_screen_transition()
		away(main)
		await wait_frames()
		await body.call(main), {"farm": 10}, {"build_menu": menu})
	window.size = before


func move_mouse(main: Node, at: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	main.get_viewport().push_input(event, true)


## Moves the mouse well away from everything.
func away(main: Node) -> void:
	move_mouse(main, Vector2(2, 2))


func hovers(main: Node) -> int:
	return main.sfx.played().filter(func(r): return r.token == Sfx.HOVER).size()


## The Farm's view in the open territory view.
func farm_view(main: Node) -> CardView:
	for v in main.views_in(main.territory_view.row):
		if (v as CardView).card_id == "farm":
			return v
	return null


## The city's view in the open territory view.
func city_view(main: Node) -> CardView:
	for v in main.views_in(main.territory_view.row):
		if Game.engine.zone("tableau").find((v as CardView).uid).def.type == CardDef.CITY:
			return v
	return null


func border(view: CardView) -> Color:
	return Looks.frame_of(view.get_theme_stylebox("panel")).border_color


func outline_border(outline: Panel) -> Color:
	return (outline.get_theme_stylebox("panel") as StyleBoxFlat).border_color


## Whether view shows the card hover look: the ink border and the hover shadow.
func hovered(view: CardView) -> bool:
	var frame := Looks.frame_of(view.get_theme_stylebox("panel"))
	return frame.border_color == Palette.TEXT and frame.shadow_size == Surfaces.CARD_HOVER[1]


func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


# --- AC1, AC2: building and city cards ---

func test_entering_a_building_in_the_view_lifts_it_and_ticks_once() -> void:
	await with_view(func(main: Node):
		var farm := farm_view(main)
		check(farm != null, "the Farm is in the view")
		check(not hovered(farm), "at rest before")
		move_mouse(main, centre(farm))
		await wait_frames()
		check(hovered(farm), "the hover look: border %s" % border(farm).to_html())
		eq(farm.scale, Vector2.ONE, "no scale")
		eq(hovers(main), 1, "one tick"))


func test_entering_the_city_in_the_view_lifts_it_and_ticks() -> void:
	await with_view(func(main: Node):
		var city := city_view(main)
		check(city != null, "the city is in the view")
		move_mouse(main, centre(city))
		await wait_frames()
		check(hovered(city), "the hover look")
		eq(hovers(main), 1, "one tick"))


func test_leaving_a_building_restores_it_silently_and_a_fresh_entry_ticks_again() -> void:
	await with_view(func(main: Node):
		var farm := farm_view(main)
		move_mouse(main, centre(farm))
		await wait_frames()
		away(main)
		await wait_frames()
		check(not hovered(farm), "back at rest")
		eq(hovers(main), 1, "leaving is silent")
		main.sfx.set_clock(1.0)
		move_mouse(main, centre(farm))
		await wait_frames()
		eq(hovers(main), 2, "a fresh entry ticks again"))


# --- AC3: the Realm keeps today's behaviour ---

func test_a_realm_card_has_no_hover() -> void:
	await with_view(func(main: Node):
		var home: CardView = main.views[home_uid(Game.engine)]
		main.territory_view.back_button.pressed.emit()
		await wait_screen_transition()
		away(main)
		await wait_frames()
		check(home.is_visible_in_tree(), "the territory is shown in the Realm")
		move_mouse(main, centre(home))
		await wait_frames()
		check(not hovered(home), "no hover look in the Realm")
		eq(hovers(main), 0, "silent in the Realm"))


# --- AC4, AC5: free slots ---

func test_entering_a_free_slot_inks_its_outline_and_ticks_once() -> void:
	await with_view(func(main: Node):
		var outlines: Array = main.territory_view.outlines()
		check(outlines.size() >= 2, "two free slots")
		eq(outline_border(outlines[0]).to_html(), Palette.GHOST_EDGE.to_html(), "a ghost edge at rest")
		move_mouse(main, centre(outlines[0]))
		await wait_frames()
		eq(outline_border(outlines[0]).to_html(), Palette.TEXT.to_html(), "inked under the mouse")
		eq(outline_border(outlines[1]).to_html(), Palette.GHOST_EDGE.to_html(), "the other slot unchanged")
		eq(hovers(main), 1, "one tick, not two")
		away(main)
		await wait_frames()
		eq(outline_border(outlines[0]).to_html(), Palette.GHOST_EDGE.to_html(), "back to the ghost edge"))


func test_a_disabled_free_slot_is_unchanged_and_silent() -> void:
	await with_view(func(main: Node):
		var e := Game.engine
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer: a territory choice is owed")
		e.changed.emit()
		await wait_frames()
		var outline: Panel = main.territory_view.outlines()[0]
		check(main.territory_view.slot_button(0).disabled, "+ Build is disabled")
		move_mouse(main, centre(outline))
		await wait_frames()
		eq(outline_border(outline).to_html(), Palette.GHOST_EDGE.to_html(), "unchanged")
		eq(hovers(main), 0, "silent"))


func test_a_free_slot_with_an_empty_build_menu_is_unchanged_and_silent() -> void:
	await with_view(func(main: Node):
		var outline: Panel = main.territory_view.outlines()[0]
		check(not main.territory_view.slot_button(0).visible, "+ Build is hidden")
		move_mouse(main, centre(outline))
		await wait_frames()
		eq(outline_border(outline).to_html(), Palette.GHOST_EDGE.to_html(), "unchanged")
		eq(hovers(main), 0, "silent"), {})


# --- AC6: a held mouse ---

func test_entering_a_building_or_slot_with_the_mouse_held_is_silent() -> void:
	await with_view(func(main: Node):
		move_mouse(main, centre(farm_view(main)), true)
		await wait_frames()
		move_mouse(main, centre(main.territory_view.outlines()[0]), true)
		await wait_frames()
		eq(hovers(main), 0, "silent"))
