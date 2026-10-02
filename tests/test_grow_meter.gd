extends "res://tests/lib/test_case.gd"
## The territory view's pop meter (backlog 124): one pip per housing, the first `pop` filled; the first empty pip is
## Grow (main.territory_view.grow_button), showing its food cost with the food icon; a dim reason line
## (territory_view.grow_reason) says why Grow can't be used. A grow from the meter pops the new pip in, and (126, 181)
## its "+1" pop and "−3" food show as tags beside the top bar's Pop and Food figures. Hooks: territory_view.pips()
## (the meter's pips in order, the Grow pip among them); a pip is filled when its theme_type_variation is
## "PipFilled". Tweens are stepped by hand (step_tweens) to read positions and scales along the way.

const STEP := 0.05  # seconds per tween step
const STEPS := 40  # 2 s: longer than any tag's life
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


# --- AC1: pips ---

func test_the_meter_has_a_pip_per_housing_with_pop_filled_and_grow_on_the_first_empty_one() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var housing := e.housing(home)
		check(housing >= 4, "room to grow twice (housing %d)" % housing)
		eq(e.pop(home), 2, "pop 2")
		var pips: Array = view.pips()
		eq(pips.size(), housing, "a pip per housing")
		eq(filled_count(pips), 2, "pop pips filled")
		eq(pips.slice(0, 2).all(filled), true, "the first two")
		eq(pips[2], view.grow_button, "the third pip is Grow")
		var grow: Button = view.grow_button
		check(shown(grow), "Grow shown")
		eq(grow.text, str(e.grow_cost(home)), "its food cost (3)")
		check(grow.icon != null and grow.icon.resource_path.ends_with("food.svg"), "with the food icon")
		check(not grow.text.contains("food"), "no word 'food'")
		check(grow.tooltip_text.contains("Grow") and grow.tooltip_text.contains(str(e.grow_cost(home))),
			"tooltip names the action and the cost: '%s'" % grow.tooltip_text)
		for pip in pips.slice(3):
			check(not pip is BaseButton, "the pips after Grow are plain")
			check(not filled(pip), "and empty"))


func test_without_population_there_is_no_meter_grow_or_reason() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		eq((view.pips() as Array).filter(shown).size(), 0, "no pips shown")
		check(not shown(view.grow_button), "no Grow")
		check(not shown(view.grow_reason), "no reason line"), 10, {})


# --- AC2, AC3: the reason line ---

func test_at_housing_every_pip_is_filled_grow_is_hidden_and_the_reason_shows() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		e.zone("tableau").find(home).pop = e.housing(home)
		e.changed.emit()
		await wait_frames()
		var pips: Array = view.pips()
		eq(pips.size(), e.housing(home), "a pip per housing")
		eq(filled_count(pips), e.housing(home), "all filled")
		check(not shown(view.grow_button), "no Grow")
		check(shown(view.grow_reason), "the reason shows")
		eq(view.grow_reason.text, e.grow_error(home), "it reads grow_error"))


func test_without_enough_food_grow_is_disabled_and_the_reason_shows() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		var grow: Button = view.grow_button
		eq((view.pips() as Array)[2], grow, "Grow on the third pip")
		check(shown(grow), "shown")
		check(grow.disabled, "disabled")
		check(e.grow_error(home).contains("needs 3 food"), "the engine says why: %s" % e.grow_error(home))
		check(shown(view.grow_reason), "the reason shows")
		eq(view.grow_reason.text, e.grow_error(home), "it reads grow_error"), 1)


func test_when_grow_is_legal_the_reason_line_is_hidden() -> void:
	await with_meter(func(main: Node, home: int):
		var view: Object = main.territory_view
		eq(Game.engine.grow_error(home), "", "can grow")
		check(not view.grow_button.disabled, "Grow enabled")
		check(not shown(view.grow_reason), "no reason line"))


# --- AC4: growing ---

func test_pressing_grow_fills_the_pip_and_moves_grow_to_the_next() -> void:
	await with_meter(func(main: Node, home: int):
		var e := Game.engine
		var view: Object = main.territory_view
		view.grow_button.pressed.emit()
		await wait_frames()
		eq(e.pop(home), 3, "pop 3")
		eq(e.resources[GameEngine.FOOD], 7, "paid 3 food")
		var pips: Array = view.pips()
		eq(filled_count(pips), 3, "3 filled")
		eq(pips[3], view.grow_button, "Grow on the fourth pip")
		eq(view.grow_button.text, "4", "costing 4")
		eq(main.counter_text(TopBar.POP), str(e.total_pop()), "the top bar's Pop reads the new total"))


# --- AC5: the grow animation ---

func test_a_grow_pops_the_pip_in_and_tags_the_pop_and_food_counters() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		check(pip.scale.x < 1.0, "the new pip starts small: %s" % pip.scale)
		var tags := {"pop": [], "food": []}  # every tag text seen while the tweens run
		await step_tweens(main, func():
			for key in [TopBar.POP, GameEngine.FOOD]:
				var tag := counter_tag(main.counter(key))
				if tag != null and not tags[key].has(tag.text):
					tags[key].append(tag.text))
		eq(tags[TopBar.POP], ["+1"], "a +1 tag beside Pop")
		eq(tags[GameEngine.FOOD], ["−3"], "a −3 tag beside Food")
		eq(pip.scale, Vector2.ONE, "the pip ends full size")
		check(counter_tag(main.counter(TopBar.POP)) == null, "the +1 tag is gone")
		eq(labels_starting(main, "+1 pop").size(), 0, "nothing floats"))


func test_with_reduce_motion_the_pip_doesnt_scale_and_the_pop_tag_appears_in_place() -> void:
	_calm = true
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var counter: Control = main.counter(TopBar.POP)
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		eq(pip.scale, Vector2.ONE, "no pop-in")
		var tag := counter_tag(counter)
		eq(tag.text if tag != null else "", "+1", "the +1 tag shows at once")
		if tag == null:
			return
		var at := tag.get_global_rect().position
		var moved := [0.0]
		await step_tweens(main, func():
			if is_instance_valid(tag):
				moved[0] = maxf(moved[0], tag.get_global_rect().position.distance_to(at)))
		check(moved[0] < 0.5, "the tag stays in place (off by %s)" % moved[0])
		check(counter_tag(counter) == null, "and is gone"))
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
