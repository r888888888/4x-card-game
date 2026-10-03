extends "res://tests/lib/test_case.gd"
## The territory view's pop meter (backlog 124): one plain pip per housing, the first `pop` filled. Grow
## (main.territory_view.grow_button) is a button in the view's actions row (territory_view.actions, 227), reading
## "Grow" and its food cost with the food icon; when it can't be used it is disabled with the reason as its tooltip.
## A grow pops the new pip in, and the top bar's Pop and Food figures roll to their new values, with no tags (218).
## Hooks: territory_view.pips() (the meter's pips in order); a pip is filled when its theme_type_variation is
## "PipFilled". Tweens are stepped by hand (step_tweens) to read positions and scales along the way.

const STEP := 0.05  # seconds per tween step
const STEPS := 40  # 2 s: longer than any roll
const POP := {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}

var _calm := false  # Reduce motion for with_meter


## Runs body(main, home) on the real main scene on a TEST_CARDS game (seed 1, population on, home pop 2) with food
## food, its home territory's view open.
func with_meter(body: Callable, food := 10, overrides := POP) -> void:
	await with_reduce_motion(_calm, func():
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
	return pip.theme_type_variation == "PipFilled"


func filled_count(pips: Array) -> int:
	return pips.filter(filled).size()


func shown(c: Control) -> bool:
	return c != null and c.is_visible_in_tree()


func labels_starting(root: Node, prefix: String) -> Array[Label]:
	var found: Array[Label] = []
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with(prefix) and label.is_visible_in_tree():
			found.append(label)
	return found


## Advances every running tween by STEP, STEPS times, calling sample.call() after each step.
func step_tweens(main: Node, sample: Callable) -> void:
	for i in STEPS:
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(STEP)
		sample.call()
	await wait_frames()


# --- 227 AC1: the actions row ---

func test_grow_is_in_the_actions_row_below_the_stats_and_meter_above_the_cards() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var actions: Control = view.actions
		check(shown(actions), "the actions row shows")
		check(view.frame.is_ancestor_of(actions), "inside the box")
		check(actions.is_ancestor_of(view.grow_button), "Grow is in it")
		check(not (view.pips() as Array).has(view.grow_button), "Grow isn't a pip")
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


# --- 227 AC3: the Grow button ---

func test_grow_is_a_button_reading_grow_and_its_food_cost() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var grow: Button = main.territory_view.grow_button
		check(shown(grow), "Grow shown")
		check(not grow.disabled, "enabled")
		eq(grow.text, "Grow %d" % e.grow_cost(home), "the action and its food cost (3)")
		check(grow.icon != null and grow.icon.resource_path.ends_with("food.svg"), "with the food icon")
		check(grow.tooltip_text.contains("Grow") and grow.tooltip_text.contains(str(e.grow_cost(home))),
			"tooltip names the action and the cost: '%s'" % grow.tooltip_text))


# --- 227 AC4: blocked, the reason as the tooltip ---

## The view's visible labels reading text.
func labels_reading(view: Node, text: String) -> Array:
	return view.find_children("*", "Label", true, false).filter(
		func(l: Label): return l.is_visible_in_tree() and l.text == text)


func test_without_enough_food_grow_is_disabled_with_the_reason_as_its_tooltip() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var grow: Button = view.grow_button
		check(e.grow_error(home).contains("needs 3 food"), "the engine says why: %s" % e.grow_error(home))
		check(shown(grow), "shown")
		check(grow.disabled, "disabled")
		eq(grow.tooltip_text, e.grow_error(home), "its tooltip reads grow_error")
		eq(labels_reading(view, e.grow_error(home)).size(), 0, "no reason line"), 1)


func test_at_housing_grow_is_disabled_with_the_reason_as_its_tooltip() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		e.zone("tableau").find(home).pop = e.housing(home)
		e.changed.emit()
		await wait_frames()
		var pips: Array = view.pips()
		eq(pips.size(), e.housing(home), "a pip per housing")
		eq(filled_count(pips), e.housing(home), "all filled")
		var grow: Button = view.grow_button
		check(e.grow_error(home) != "", "can't grow at housing")
		check(shown(grow), "Grow still shown")
		check(grow.disabled, "disabled")
		eq(grow.tooltip_text, e.grow_error(home), "its tooltip reads grow_error")
		eq(labels_reading(view, e.grow_error(home)).size(), 0, "no reason line"))


# --- 227 AC5: growing ---

func test_pressing_grow_fills_the_next_pip_and_raises_the_cost() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		view.grow_button.pressed.emit()
		await wait_frames()
		eq(e.pop(home), 3, "pop 3")
		eq(e.resources[GameEngine.FOOD], 7, "paid 3 food")
		var pips: Array = view.pips()
		eq(pips.size(), e.housing(home), "still a pip per housing")
		eq(filled_count(pips), 3, "3 filled")
		eq(view.grow_button.text, "Grow 4", "Grow now costs 4")
		eq(main.counter_text(TopBar.POP), str(e.total_pop()), "the top bar's Pop reads the new total"))


# --- 227 AC6: population off ---

func test_without_population_there_is_no_meter_grow_or_actions_row() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		eq((view.pips() as Array).filter(shown).size(), 0, "no pips shown")
		check(not shown(view.grow_button), "no Grow")
		check(not shown(view.actions), "no actions row"), 10, {})


# --- AC5: the grow animation ---

func test_a_grow_pops_the_pip_in_and_rolls_pop_and_food_with_no_tags() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		check(pip.scale.x < 1.0, "the new pip starts small: %s" % pip.scale)
		var tags := []  # every tag text seen beside Pop or Food while the tweens run
		await step_tweens(main, func():
			for key in [TopBar.POP, GameEngine.FOOD]:
				var tag := counter_tag(main.counter(key))
				if tag != null and not tags.has(tag.text):
					tags.append(tag.text))
		eq(tags, [], "no tags beside Pop or Food (218)")
		eq(main.counter_text(TopBar.POP), "3", "Pop reads 3")
		eq(main.counter_text(GameEngine.FOOD), "7", "Food reads 7")
		eq(pip.scale, Vector2.ONE, "the pip ends full size")
		eq(labels_starting(main, "+1 pop").size(), 0, "nothing floats"))


func test_with_reduce_motion_the_pip_doesnt_scale_and_pop_shows_no_tag() -> void:
	_calm = true
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var counter: Control = main.counter(TopBar.POP)
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		eq(pip.scale, Vector2.ONE, "no pop-in")
		eq(counter_tag(counter), null, "no +1 tag (218)")
		eq(main.counter_text(TopBar.POP), "3", "Pop reads 3 at once"))
	_calm = false


# --- AC6: a card's pop fills pips (its token is the bar's, 126) ---

func test_pop_from_a_card_fills_pips() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var festival := put_in_hand(e, "festival")  # grows every settled territory by 1
		e.changed.emit()
		await wait_frames()
		main.try_play(main.views[festival])
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
