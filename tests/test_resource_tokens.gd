extends "res://tests/lib/test_case.gd"
## Resource tokens in the real main scene (backlog 114): a cost ("−2 food", "−3 wealth") floats straight up from
## just below its counter and fades out; a gain still flies from the played card to its counter. Tokens are Labels
## on an fx layer; their tweens are stepped by hand (step_tweens) so positions can be read along the way.

const STEP := 0.05  # seconds per tween step
const STEPS := 30  # 1.5 s: longer than any token's life

var _calm := false  # Reduce motion for with_fixture_main


## Runs body(main) on the real main scene on a TEST_CARDS game (seed 1) with 10 food and 10 wealth.
func with_fixture_main(body: Callable, deck := {"scout": 10}, overrides := {}) -> void:
	await with_reduce_motion(_calm, func():
		var real := Game.engine
		Game.engine = make_engine(deck, overrides)
		var main := open_main()
		main.start_game(1)
		Game.engine.resources[GameEngine.FOOD] = 10
		Game.engine.resources[GameEngine.WEALTH] = 10
		await wait_frames()
		await body.call(main)
		close_main(main)
		Game.engine = real)

## The visible labels under root whose text starts with prefix.
func labels_starting(root: Node, prefix: String) -> Array[Label]:
	var found: Array[Label] = []
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with(prefix) and label.is_visible_in_tree():
			found.append(label)
	return found


## The one visible label under root whose text starts with prefix (fails the test if not exactly one).
func only_label(root: Node, prefix: String) -> Label:
	var found := labels_starting(root, prefix)
	eq(found.size(), 1, "labels starting '%s'" % prefix)
	return found[0] if not found.is_empty() else null


## Where a cost token for counter starts: centred just below it.
func below(counter: Label) -> Vector2:
	return counter.get_global_rect().get_center() + Vector2(0, counter.size.y)


func centre(token: Label) -> Vector2:
	return token.get_global_rect().get_center()


## Anim.TOKEN_FLOAT_PX, read by name so this file parses before it exists (red phase).
func float_px() -> float:
	return float((Anim as Script).get_script_constant_map().get("TOKEN_FLOAT_PX", 0.0))


## Advances every running tween by STEP, STEPS times, recording each token's centre and alpha after every step
## until it is freed. Returns token -> {"path": Array[Vector2], "alpha": Array[float], "freed": bool}.
func step_tweens(main: Node, tokens: Array[Label]) -> Dictionary:
	var tracks := {}
	for token in tokens:
		tracks[token] = {"path": [centre(token)], "alpha": [token.modulate.a], "freed": false}
	for i in STEPS:
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(STEP)
		for token in tokens:
			if is_instance_valid(token):
				tracks[token].path.append(centre(token))
				tracks[token].alpha.append(token.modulate.a)
	await wait_frames()
	for token in tokens:
		tracks[token].freed = not is_instance_valid(token)
	return tracks


## Asserts the token started centred at start (just below its counter), then only rose (x fixed, y never
## increasing) by Anim.TOKEN_FLOAT_PX in all, faded to transparent and was freed.
func assert_floats_up(track: Dictionary, start: Vector2, what: String) -> void:
	var path: Array = track.path
	check((path[0] as Vector2).distance_to(start) < 1.0, "%s: starts just below its counter: %s vs %s" % [what, path[0], start])
	var x_drift := 0.0
	var drop := 0.0  # the largest downward step
	var rise := 0.0
	for i in path.size():
		var p: Vector2 = path[i]
		x_drift = maxf(x_drift, absf(p.x - path[0].x))
		if i > 0:
			drop = maxf(drop, p.y - path[i - 1].y)
		rise = maxf(rise, path[0].y - p.y)
	eq(x_drift < 0.5, true, "%s: x stays put (drifts %s px)" % [what, x_drift])
	eq(drop < 0.01, true, "%s: never moves down (drops %s px)" % [what, drop])
	check(float_px() > 0.0, "Anim.TOKEN_FLOAT_PX is set")
	check(absf(rise - float_px()) < 0.5, "%s: rises Anim.TOKEN_FLOAT_PX (%s): rose %s" % [what, float_px(), rise])
	check(track.alpha.max() > 0.9, "%s: shown" % what)
	check(track.alpha.back() < 0.05, "%s: fades out: %s" % [what, track.alpha.back()])
	check(track.freed, "%s: freed" % what)


## Plays the card id from the hand onto the home territory if it needs a target; returns its view's centre.
func play(main: Node, id: String) -> Vector2:
	var e := Game.engine
	var uid := put_in_hand(e, id)
	e.changed.emit()  # so the board deals it a view
	await wait_frames()
	var view: CardView = main.views[uid]
	var point := view.get_global_rect().get_center()
	main.try_play(view, home_uid(e) if e.needs_target(uid) else -1)
	return point


# --- AC1, AC2, AC4: paying for a played card ---

func test_a_food_cost_floats_up_from_the_food_counter() -> void:
	await with_fixture_main(func(main: Node):
		var counter := only_label(main, "Food:")
		await play(main, "farm")
		var start := below(counter)
		var tokens := labels_starting(main, "−2 food")
		eq(tokens.size(), 1, "one −2 food token")
		if tokens.is_empty():
			return
		var tracks := await step_tweens(main, tokens)
		assert_floats_up(tracks[tokens[0]], start, "−2 food"))


func test_food_and_wealth_costs_float_up_from_their_own_counters_one_after_the_other() -> void:
	await with_fixture_main(func(main: Node):
		var food := only_label(main, "Food:")
		var wealth := only_label(main, "Wealth:")
		await play(main, "guildhall")
		var starts := [below(food), below(wealth)]
		var food_tokens := labels_starting(main, "−2 food")
		var wealth_tokens := labels_starting(main, "−2 wealth")
		eq([food_tokens.size(), wealth_tokens.size()], [1, 1], "one token each")
		if food_tokens.is_empty() or wealth_tokens.is_empty():
			return
		var tokens: Array[Label] = [food_tokens[0], wealth_tokens[0]]
		var tracks := await step_tweens(main, tokens)
		assert_floats_up(tracks[tokens[0]], starts[0], "−2 food")
		assert_floats_up(tracks[tokens[1]], starts[1], "−2 wealth")
		# after one step (0.05 s, under Anim.TOKEN_STAGGER) the food token shows and the wealth one hasn't started
		check(tracks[tokens[0]].alpha[1] > 0.0, "food token starts first")
		eq(tracks[tokens[1]].alpha[1], 0.0, "wealth token waits Anim.TOKEN_STAGGER")
		eq(tracks[tokens[1]].path[1], tracks[tokens[1]].path[0], "wealth token hasn't moved yet"))


# --- AC3: buying in the supply screen ---

func test_a_supply_purchase_floats_up_from_the_screens_wealth_counter() -> void:
	await with_fixture_main(func(main: Node):
		var top_bar_wealth := only_label(main, "Wealth:")
		main.supply.open(Game.engine)
		await wait_frames()
		var counters := labels_starting(main, "Wealth:")
		counters.erase(top_bar_wealth)
		eq(counters.size(), 1, "the supply screen's own wealth counter")
		var pile: CardView = main.supply.views()[0]
		main.supply.pick(pile)
		var start := below(counters[0]) if not counters.is_empty() else Vector2.ZERO
		var tokens := labels_starting(main, "−3 wealth")
		eq(tokens.size(), 1, "one −3 wealth token")
		if tokens.is_empty() or counters.is_empty():
			return
		var tracks := await step_tweens(main, tokens)
		assert_floats_up(tracks[tokens[0]], start, "−3 wealth"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


# --- AC5: gains still fly to their counter ---

func test_a_food_gain_still_flies_from_the_card_to_the_food_counter() -> void:
	await with_fixture_main(func(main: Node):
		var counter := only_label(main, "Food:")
		var point: Vector2 = await play(main, "caravan")
		var tokens := labels_starting(main, "+")
		tokens = tokens.filter(func(l: Label): return l.text.ends_with("food"))
		eq(tokens.size(), 1, "one +N food token")
		if tokens.is_empty():
			return
		var tracks := await step_tweens(main, tokens)
		var path: Array = tracks[tokens[0]].path
		check((path[0] as Vector2).distance_to(point) < 1.0, "starts at the card: %s vs %s" % [path[0], point])
		var target := counter.get_global_rect().get_center()
		check((path.back() as Vector2).distance_to(target) < 1.0, "ends at the counter: %s vs %s" % [path.back(), target]))


# --- AC6: Reduce motion ---

func test_with_reduce_motion_a_cost_fades_in_place_below_its_counter() -> void:
	_calm = true
	await with_fixture_main(func(main: Node):
		var counter := only_label(main, "Food:")
		await play(main, "farm")
		var start := below(counter)
		var tokens := labels_starting(main, "−2 food")
		eq(tokens.size(), 1, "one −2 food token")
		if tokens.is_empty():
			return
		var tracks := await step_tweens(main, tokens)
		var track: Dictionary = tracks[tokens[0]]
		var furthest := 0.0
		for p: Vector2 in track.path:
			furthest = maxf(furthest, p.distance_to(start))
		check(furthest < 1.0, "stays just below the counter %s: strays %s px" % [start, furthest])
		check(track.alpha.max() > 0.9, "shown")
		check(track.freed, "fades and is freed"))
	_calm = false
