extends "res://tests/lib/test_case.gd"
## The territory view's pop meter (backlog 124): one pip per housing, the first `pop` filled; the first empty pip is
## Grow (main.territory_view.grow_button), showing its food cost with the food icon; a dim reason line
## (territory_view.grow_reason) says why Grow can't be used. A grow from the meter pops the new pip in, flies a
## "+1 pop" token to the top bar's Pop counter and floats the food cost up from Food. Hooks: territory_view.pips()
## (the meter's pips in order, the Grow pip among them); a pip is filled when its theme_type_variation is
## "PipFilled". Tweens are stepped by hand (step_tweens) to read positions and scales along the way.

const STEP := 0.05  # seconds per tween step
const STEPS := 30  # 1.5 s: longer than any token's life
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


## The one visible label under root whose text starts with prefix, or null (fails the test if not exactly one).
func only_label(root: Node, prefix: String) -> Label:
	var found := labels_starting(root, prefix)
	eq(found.size(), 1, "labels starting '%s'" % prefix)
	return found[0] if not found.is_empty() else null


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
		var counter := only_label(main, "Pop:")
		if counter != null:
			eq(counter.text, "Pop: %d" % e.total_pop(), "the top bar's Pop reads the new total"))


# --- AC5: the grow animation ---

func test_a_grow_pops_the_pip_in_and_flies_plus_one_pop_to_the_pop_counter() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var counter := only_label(main, "Pop:")
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		check(pip.scale.x < 1.0, "the new pip starts small: %s" % pip.scale)
		var from := pip.get_global_rect().get_center()
		var tokens := labels_starting(main, "+1 pop")
		eq(tokens.size(), 1, "one +1 pop token")
		var food_tokens := labels_starting(main, "−3 food")
		eq(food_tokens.size(), 1, "one −3 food token")
		if tokens.is_empty() or food_tokens.is_empty() or counter == null:
			return
		var token := tokens[0]
		var food := food_tokens[0]
		var path: Array[Vector2] = [token.get_global_rect().get_center()]
		var food_ys: Array[float] = [food.global_position.y]
		var food_x := food.global_position.x
		var scales: Array[float] = []  # the Pop counter's, after the token lands
		var landed := [false]
		await step_tweens(main, func():
			if is_instance_valid(token):
				path.append(token.get_global_rect().get_center())
				if path.back().distance_to(counter.get_global_rect().get_center()) < 1.0:
					landed[0] = true
			if landed[0]:
				scales.append(counter.scale.x)
			if is_instance_valid(food):
				food_ys.append(food.global_position.y)
				eq(food.global_position.x, food_x, "the food token stays in x"))
		check(path[0].distance_to(from) < 1.0, "+1 pop starts at the pip: %s vs %s" % [path[0], from])
		check(landed[0], "+1 pop reaches the Pop counter")
		check(not scales.is_empty() and scales.max() > 1.0, "the Pop counter pulses when it lands")
		check(food_ys.back() < food_ys[0], "−3 food floats up")
		eq(pip.scale, Vector2.ONE, "the pip ends full size")
		check(not is_instance_valid(token), "+1 pop freed"))


func test_with_reduce_motion_the_pip_doesnt_scale_and_plus_one_pop_fades_at_the_counter() -> void:
	_calm = true
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		var counter := only_label(main, "Pop:")
		view.grow_button.pressed.emit()
		await wait_frames()
		var pip: Control = (view.pips() as Array)[2]
		eq(pip.scale, Vector2.ONE, "no pop-in")
		var tokens := labels_starting(main, "+1 pop")
		eq(tokens.size(), 1, "one +1 pop token")
		if tokens.is_empty() or counter == null:
			return
		var token := tokens[0]
		var at := counter.get_global_rect().get_center()
		var moved := [0.0]
		await step_tweens(main, func():
			if is_instance_valid(token):
				moved[0] = maxf(moved[0], token.get_global_rect().get_center().distance_to(at)))
		check(moved[0] < 1.0, "+1 pop stays at the Pop counter (off by %s)" % moved[0])
		check(not is_instance_valid(token), "and fades out"))
	_calm = false


# --- AC6: only a grow animates ---

func test_pop_from_a_card_fills_pips_without_a_token() -> void:
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
		eq(labels_starting(main, "+1 pop").size(), 0, "no +1 pop token"))


func test_a_refresh_that_changes_nothing_starts_no_animation() -> void:
	await with_meter(func(main: Node, _home: int):
		var view: Object = main.territory_view
		Game.engine.changed.emit()
		await wait_frames()
		eq(labels_starting(main, "+1 pop").size(), 0, "no +1 pop token")
		eq((view.pips() as Array).filter(func(p: Control): return p.scale != Vector2.ONE).size(), 0, "no pip scaling"))
