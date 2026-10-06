extends "res://tests/lib/test_case.gd"
## Hover in the territory view (342) in the real main.tscn, its sound clock frozen at 0: the city and building cards
## take the card hover look (ink border, the hover shadow) and tick `ui.hover` once as the mouse enters, a free slot
## inks its outline and ticks once while its "+ Build" is enabled, and a disabled or hidden slot, a Realm card and a
## held mouse stay as they were.

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
