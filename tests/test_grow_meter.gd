extends "res://tests/lib/test_case.gd"
## The territory view's pop meter (backlog 124): one plain pip per housing, the first `pop` filled, above the view's
## actions row (territory_view.actions, 227). Its Grow button went in 260: pop grows by itself at upkeep.
## Hooks: territory_view.pips() (the meter's pips in order); a pip is the pop glyph (242), filled when tinted
## Palette.POP.

const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}



## Runs body(main, home) on the real main scene on a TEST_CARDS game (seed 1, population on, home pop 2) with food
## food, its home territory's view open.
func with_meter(body: Callable, food := 10, overrides := POP) -> void:
	await with_reduce_motion(false, func():
		var real := Game.engine
		Game.engine = make_engine({"farm": 10}, overrides)
		var main := open_main()
		main.start_game(1)
		Game.engine.resources[GameEngine.FOOD] = food
		Game.engine.changed.emit()
		await wait_frames()
		var home := home_uid(Game.engine)
		var view: CardView = main.views[home]
		view.details_requested.emit(view)
		await wait_screen_transition()
		await body.call(main, home)
		close_main(main)
		Game.engine = real)


func filled(pip: Control) -> bool:
	return pip is TextureRect and pip.self_modulate == Palette.POP


func filled_count(pips: Array) -> int:
	return pips.filter(filled).size()


func shown(c: Control) -> bool:
	return c != null and c.is_visible_in_tree()


# --- 227 AC1: the actions row ---

func test_the_actions_row_is_below_the_stats_and_meter_above_the_cards() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var actions: Control = view.actions
		check(shown(actions), "the actions row shows")
		check(view.frame.is_ancestor_of(actions), "inside the box")
		check(actions.is_ancestor_of(view.rename_button), "Rename… is in it (Grow went in 260)")
		var top: float = actions.get_global_rect().position.y
		var stats: Array = view.find_children("*", "RichTextLabel", true, false).filter(
			func(l): return l.get_meta("source", "") == view.stats_text())
		check(not stats.is_empty(), "the stats line")
		for c: Control in stats + view.pips():
			check(c.get_global_rect().end.y <= top + 1.0, "%s above the actions row" % c)
		check(actions.get_global_rect().end.y <= view.row.get_global_rect().position.y + 1.0,
			"the actions row above the cards"))


# --- 227 AC2: plain pips ---

func test_the_meter_is_plain_pips_one_per_housing_with_pop_filled() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var housing := e.housing(home)
		check(housing >= 4, "room to grow twice (housing %d)" % housing)
		eq(e.pop(home), 2, "pop 2")
		var pips: Array = view.pips()
		eq(pips.size(), housing, "a pip per housing")
		eq(pips.filter(func(p): return p is BaseButton).size(), 0, "no pip is a button")
		eq(filled_count(pips), 2, "pop pips filled")
		eq(pips.slice(0, 2).all(filled), true, "the first two"))


# --- 242 AC2: the pips are pop glyphs at the stats line's text size ---

func test_the_meter_pips_are_pop_glyphs_the_size_of_the_stats_text() -> void:
	await with_meter(func(main: Node, home: int):
		var pips: Array = main.territory_view.pips()
		eq(pips.size(), Game.engine.housing(home), "a pip per housing")
		for pip: Control in pips:
			check(pip is TextureRect and (pip as TextureRect).texture == Icons.RESOURCES[TopBar.POP],
				"%s is the pop glyph" % pip)
			eq(pip.custom_minimum_size, Vector2.ONE * Tokens.TYPE_BODY, "sized to the stats line's text")
		var empty: Control = pips[2]
		check(empty.self_modulate != Palette.POP, "an empty pip is dimmer: %s" % empty.self_modulate))


# --- 227 AC4: at housing ---

## The view's visible labels reading text.
func test_at_housing_every_pip_is_filled() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		e.zone("tableau").find(home).pop = e.housing(home)
		e.changed.emit()
		await wait_frames()
		var pips: Array = view.pips()
		eq(pips.size(), e.housing(home), "a pip per housing")
		eq(filled_count(pips), e.housing(home), "all filled"))


# --- 227 AC6: population off ---

func test_without_population_there_is_no_meter_or_actions_row() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		eq((view.pips() as Array).filter(shown).size(), 0, "no pips shown")
		check(not shown(view.actions), "no actions row"), 10, {})


# --- AC6: a card's pop fills pips (its token is the bar's, 126) ---

func test_pop_from_a_card_fills_pips() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var festival := put_in_hand(e, "festival")  # grows every settled territory by 1
		e.changed.emit()
		await wait_frames()
		main.card_actions.try_play(main.views[festival])
		await wait_frames()
		eq(e.pop(home), 3, "Festival grew home")
		eq(filled_count(view.pips()), 3, "3 pips filled")
		eq((view.pips() as Array).filter(func(p: Control): return p.scale != Vector2.ONE).size(), 0, "no pip pops in"))


func test_a_refresh_that_changes_nothing_starts_no_animation() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		Game.engine.changed.emit()
		await wait_frames()
		eq(counter_tag(main.counter(TopBar.POP)), null, "no +1 tag")
		eq((view.pips() as Array).filter(func(p: Control): return p.scale != Vector2.ONE).size(), 0, "no pip scaling"))
