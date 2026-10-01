extends "res://tests/lib/test_case.gd"
## Territories as plain cards in the Realm (backlog 102), in the real main scene on a TEST_CARDS game (Grassland and
## Hills in the territory deck). main.tableau.row holds the Realm's card slots; main.views_in(main.tableau.row) are
## its cards in order. A city or building on a territory has a view only while that territory's view (101) is open.
## Headless runs don't move the mouse for pushed events, so drops are checked through main.drag.target_at(point) (what
## a drop there targets) and main.try_play, and a lit card's click through main.on_picked.


## Runs body(main) on the real main scene with Game.engine swapped for a TEST_CARDS game (deck, overrides) started on
## seed 1 and laid out; then puts the real engine back.
func with_fixture_main(body: Callable, deck := {"farm": 10}, overrides := {}) -> void:
	var real := Game.engine
	Game.engine = make_engine(deck, {"territory_deck": {"grassland": 1, "hills": 1}}.merged(overrides))
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	await body.call(main)
	close_main(main)
	Game.engine = real


## The uids of the Realm's card views, in order.
func realm_uids(main: Node) -> Array[int]:
	var out: Array[int] = []
	for view in main.views_in(main.tableau.row):
		out.append(view.uid)
	return out


## A single click on uid's card view (the details_requested signal a Realm card sends after one click).
func click(main: Node, uid: int) -> void:
	var view: CardView = main.views[uid]
	view.details_requested.emit(view)


## Waits until cards have popped in and flown to their slots (so their rects are laid out).
func settle_motion() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(0.8).timeout


func territory_of(e: GameEngine, uid: int) -> int:
	var card := e.zone("tableau").find(uid)
	return card.territory_uid if card != null else -1


# --- AC1: one card per territory ---

func test_the_realm_shows_one_card_per_territory() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm"])
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		e.changed.emit()  # build_on and settle bypass the actions that refresh the board
		await wait_frames()
		eq(realm_uids(main), [home, grass] as Array[int], "the two territories, in tableau order")
		for uid in [home, grass]:
			eq((main.views[uid] as CardView).slot_size(), CardView.BOARD_SIZE, "territory %d at board size (138)" % uid)
		for id in ["capital", "farm"]:
			check(not main.views.has(uid_of(e.zone("tableau"), id)), "no view for the %s" % id)
		click(main, home)
		await wait_frames()
		for id in ["capital", "farm"]:
			check(main.views.has(uid_of(e.zone("tableau"), id)), "the %s has a view in the territory view" % id)
		main.territory_view.back_button.pressed.emit()
		await wait_frames()
		for id in ["capital", "farm"]:
			check(not main.views.has(uid_of(e.zone("tableau"), id)), "the %s's view goes when the view closes" % id))


# --- AC2: cards on no territory ---

func test_a_card_on_no_territory_follows_the_territories() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var shrine: CardInstance = e.create_card("shrine", "tableau", null)  # on no territory
		eq(shrine.territory_uid, -1, "no territory")
		e.changed.emit()
		await wait_frames()
		eq(realm_uids(main), [home, shrine.uid] as Array[int], "the territory, then the Shrine"))


# --- AC3: stats on the card ---

func test_a_territory_card_shows_its_slots_and_pop() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var text: String = main.views[home].face_text()
		var free := e.free_slots(home)
		check(text.contains("▢ %d" % free), "free slots in: %s" % text)  # the live line since 123
		check(text.contains("⌂ %d/%d" % [e.pop(home), e.housing(home)]), "pop in: %s" % text)
		build_on(e, home, ["farm"])
		e.changed.emit()
		text = main.views[home].face_text()
		check(text.contains("▢ %d" % (free - 1)), "one fewer free slot: %s" % text), \
		{"farm": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}})


# --- AC4: playing onto a territory card ---

func test_dragging_a_building_lights_its_targets_and_a_drop_plays_it_there() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		await settle_motion()
		main.drag.begin_drag(main.views[temple], Vector2.ZERO)
		eq(sorted(main.drag.lit), sorted([home, grass]), "both territory cards lit")
		var at: Vector2 = (main.views[grass] as CardView).get_global_rect().get_center()
		eq(main.drag.target_at(at), grass, "a drop on Grassland's card targets it")
		main.drag.end_drag()
		main.try_play(main.views[temple], grass)  # what the drop does with that target
		eq(territory_of(e, temple), grass, "the Temple went on Grassland"))


func test_dropping_on_a_territory_that_cannot_take_it_says_why() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var well := put_in_hand(e, "well")  # needs Fresh Water, which Grassland lacks
		e.resources.food = 5
		e.changed.emit()
		await wait_frames()
		var reason := e.play_error(well, grass)
		check(reason != "", "Well can't go on Grassland")
		main.try_play(main.views[well], grass)  # a drop of the Well on Grassland's card
		check(e.zone("hand").find(well) != null, "Well stays in the hand")
		var log := ""
		for c in main.find_children("*", "RichTextLabel", true, false):
			log += c.get_parsed_text()
		check(log.contains(reason), "the reason is shown: %s" % reason))


func test_clicking_a_lit_territory_card_while_targeting_plays_there() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		main.on_double_clicked(main.views[temple])
		check(main.drag.targeting != null, "targeting")
		main.on_picked(main.views[grass])  # the lit card's click
		eq(territory_of(e, temple), grass, "played on Grassland")
		check(not main.territory_view.is_open(), "no territory view"))


func test_keyboard_targeting_moves_between_territory_cards() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["grassland"])
		var grass := uid_of(e.zone("tableau"), "grassland")
		var temple := put_in_hand(e, "temple")
		e.changed.emit()
		await wait_frames()
		main.on_double_clicked(main.views[temple])
		main.focus.move(1)
		var first: int = main.focus.focused.uid if main.focus.focused != null else -1
		main.focus.move(1)
		var second: int = main.focus.focused.uid if main.focus.focused != null else -1
		eq(sorted([first, second]), sorted([home, grass]), "the focus moves between the two territory cards")
		main.focus.activate()
		eq(territory_of(e, temple), second, "the Temple went on the focused territory"))


# --- AC5: no collapse and no Grow in the Realm ---

func test_the_realm_has_no_collapse_toggles_or_grow() -> void:
	await with_fixture_main(func(main: Node):
		for b in UIKit.buttons_in(main):
			if b.is_visible_in_tree():
				check(not (b.text.begins_with("Collapse all") or b.text.begins_with("Expand all")), "no '%s'" % b.text)
		for b in UIKit.buttons_in(main.tableau):
			check(not b.is_visible_in_tree(), "no button in the Realm: '%s'" % b.text)
		for method in ["set_collapsed", "is_collapsed", "set_all_collapsed", "all_collapsed", "has_toggle", "group_summary"]:
			check(not main.tableau.has_method(method), "TableauView has no %s" % method), \
		{"farm": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}})


# --- AC6: a new territory ---

func test_settling_adds_a_territory_card_that_opens_with_its_city() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		to_frontier(e, ["grassland"])
		var grass := uid_of(e.zone("frontier"), "grassland")
		var pioneer := put_in_hand(e, "pioneer")
		e.resources.food = 5
		e.changed.emit()
		await wait_frames()
		check(e.play_card(pioneer, grass), "settle Grassland")
		await wait_frames()
		eq(realm_uids(main), [home, grass] as Array[int], "a new card for Grassland")
		check(main.views[grass].face_text().contains("▢ "), "with its live line (123)")
		click(main, grass)
		await wait_frames()
		var city := -1
		for card in e.zone("tableau").cards:
			if card.def.type == CardDef.CITY and card.territory_uid == grass:
				city = card.uid
		check(city != -1, "Grassland has a city")
		check(main.territory_view.card_uids().has(city) and main.views.has(city), "its view shows the city"))


# --- 078 kept: many cards don't widen the Realm ---

func test_many_territories_wrap_instead_of_widening_the_realm() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var before: float = main.tableau.get_combined_minimum_size().x
		for i in 8:
			e.create_card("grassland", "tableau", null)
		e.changed.emit()
		await wait_frames()
		eq(realm_uids(main).size(), 9, "9 territory cards")
		var after: float = main.tableau.get_combined_minimum_size().x
		check(after <= before, "the Realm's minimum width (%d) is no greater than with 1 card (%d)" % [after, before]))



# --- 123: a settled territory's card ---

const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}


## The live line a settled territory's card should show (123): "▢ F   ⌂ P/H   ⚒ W", or "▢ F" with population off.
func live_line(e: GameEngine, uid: int) -> String:
	if not e.population_on():
		return "▢ %d" % e.free_slots(uid)
	return "▢ %d   ⌂ %d/%d   ⚒ %d" % [e.free_slots(uid), e.pop(uid), e.housing(uid), e.free_workers(uid)]


func test_a_settled_territory_card_shows_its_name_keywords_and_live_line_only() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		settle(e, ["hills"])
		var hills := uid_of(e.zone("tableau"), "hills")
		e.changed.emit()
		await wait_frames()
		eq((main.views[home] as CardView).face_text(), "Homeland\n" + live_line(e, home), "Homeland: no keywords line")
		eq((main.views[hills] as CardView).face_text(), "Hills\nMountain\n" + live_line(e, hills), "Hills")
		for uid in [home, hills]:
			var tip: String = (main.views[uid] as CardView).tooltip_text
			check(tip.begins_with(e.call("territory_tooltip", uid)), "the tooltip spells it out: %s" % tip), \
		{"farm": 10}, POP)


func test_the_live_line_follows_building_and_growth() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var farm := put_in_hand(e, "farm")
		e.resources.food = 20
		check(e.play_card(farm, home), "build a Farm on Homeland")
		check(e.grow(home), "grow Homeland")
		await wait_frames()
		var text := (main.views[home] as CardView).face_text()
		check(text.ends_with(live_line(e, home)), "the live line now: %s (want %s)" % [text, live_line(e, home)]), \
		{"farm": 10}, POP)


func test_without_population_the_live_line_is_free_slots_only() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		eq((main.views[home] as CardView).face_text(), "Homeland\n▢ %d" % e.free_slots(home), "free slots only"))


func test_the_worker_glyph_is_an_icon() -> void:
	check(Icons.GLYPHS.has("⚒"), "⚒ is drawn as an icon like ▢ and ⌂")


func test_frontier_cards_keep_their_printed_slots_and_housing() -> void:
	await with_fixture_main(func(main: Node):
		var e := Game.engine
		to_frontier(e, ["grassland"])
		var grass := uid_of(e.zone("frontier"), "grassland")
		e.changed.emit()
		await wait_frames()
		var text := (main.views[grass] as CardView).face_text()
		var def := e.card_db["grassland"] as CardDef
		check(text.contains("▢%d ⌂%d" % [def.slots, def.housing]), "printed slots and housing: %s" % text))
