extends "res://tests/lib/test_case.gd"
## Resource tokens in the real main scene: a cost ("−2 food", "−3 wealth") floats straight up from just below its
## counter and fades out (114); since 126 every change to Food, Wealth, Score or Pop does, as one net token per counter
## ("+2 food", "−1 wealth", "+1 VP", "+1 pop"), whatever caused it. Tokens are Labels on an fx layer; their tweens are
## stepped by hand (step_tweens) so positions can be read along the way.

const STEP := 0.05  # seconds per tween step
const STEPS := 30  # 1.5 s: longer than any token's life

var _calm := false  # Reduce motion for with_token_main


## Runs body(main) on the real main scene on a TEST_CARDS game (seed 1) with 10 food and 10 wealth.
func with_token_main(body: Callable, deck := {"scout": 10}, overrides := {}) -> void:
	await with_reduce_motion(_calm, func():
		var real := Game.engine
		Game.engine = make_engine(deck, overrides)
		var main := open_main()
		main.start_game(1)
		Game.engine.resources[GameEngine.FOOD] = 10
		Game.engine.resources[GameEngine.WEALTH] = 10
		Game.engine.changed.emit()
		await wait_frames()
		await step_tweens(main, [])  # the fixture's own +food / +wealth tokens come and go
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
	await with_token_main(func(main: Node):
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
	await with_token_main(func(main: Node):
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
	await with_token_main(func(main: Node):
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


# --- AC5 (changed by 126): gains float up from their counter too ---

func test_a_food_gain_floats_up_from_the_food_counter() -> void:
	await with_token_main(func(main: Node):
		var counter := only_label(main, "Food:")
		await play(main, "caravan")
		var tokens := labels_starting(main, "+")
		tokens = tokens.filter(func(l: Label): return l.text.ends_with("food"))
		eq(tokens.size(), 1, "one +N food token")
		if tokens.is_empty():
			return
		var start := below(counter)
		var tracks := await step_tweens(main, tokens)
		assert_floats_up(tracks[tokens[0]], start, "+N food"))


# --- AC6: Reduce motion ---

func test_with_reduce_motion_a_cost_fades_in_place_below_its_counter() -> void:
	_calm = true
	await with_token_main(func(main: Node):
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


# --- 126: every counter change floats its net change up from the counter ---

const COUNTERS := ["Food:", "Wealth:", "Score:", "Pop:"]  # the bar's order
const UNITS := {"Food:": "food", "Wealth:": "wealth", "Score:": "VP", "Pop:": "pop"}
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}, "territory_deck": {"grassland": 1}}


## The bar's counter values now, by counter prefix.
func values(e: GameEngine) -> Dictionary:
	return {"Food:": e.resources.get(GameEngine.FOOD, 0), "Wealth:": e.resources.get(GameEngine.WEALTH, 0),
		"Score:": e.score(), "Pop:": e.total_pop()}


## "+2 food" / "−3 wealth" (a real minus) for a change of n on counter.
func token_text(counter: String, n: int) -> String:
	return "%s%d %s" % ["+" if n > 0 else "−", absi(n), UNITS[counter]]


## Every visible token on main's fx layer: its Labels reading "+N …" or "−N …" (cards in flight aren't tokens).
func tokens_on(main: Node) -> Array[Label]:
	var token := RegEx.create_from_string("^[+−][0-9]+ ")
	var found: Array[Label] = []
	for node in main.fx.get_children():
		if node is Label and (node as Label).is_visible_in_tree() and token.search(node.text) != null:
			found.append(node)
	return found


## Asserts that for each counter that changed since before there is exactly one token, its net change, which floats
## up from just below that counter (centred under it, within its width: the counter's text may since have changed)
## in the gain or cost colour; and that no other token is on the fx layer.
func assert_net_tokens(main: Node, before: Dictionary, what: String) -> void:
	var after := values(Game.engine)
	var expected: Array[Label] = []
	var counters: Array[Label] = []
	var texts: Array[String] = []
	for counter in COUNTERS:
		var n: int = after[counter] - before[counter]
		if n == 0:
			continue
		var text := token_text(counter, n)
		var found := labels_starting(main.fx, text)
		eq(found.size(), 1, "%s: one '%s' token" % [what, text])
		if found.is_empty():
			continue
		eq(found[0].get_theme_color("font_color"), UIKit.GAIN_COLOR if n > 0 else UIKit.COST_COLOR, "%s: %s colour" % [what, text])
		expected.append(found[0])
		counters.append(only_label(main, counter))
		texts.append(text)
	var others := tokens_on(main).filter(func(l: Label): return not texts.has(l.text))
	eq(others.map(func(l: Label): return l.text), [], "%s: no other tokens" % what)
	var tracks := await step_tweens(main, expected.duplicate())
	for i in expected.size():
		var track: Dictionary = tracks[expected[i]]
		var start: Vector2 = track.path[0]
		var rect := counters[i].get_global_rect()
		var under := below(counters[i])
		check(absf(start.y - under.y) < 1.0 and start.x >= rect.position.x and start.x <= rect.end.x,
			"%s: %s starts just below its counter %s: %s" % [what, texts[i], rect, start])
		assert_floats_up(track, start, "%s: %s" % [what, texts[i]])


func test_a_change_floats_one_net_token_per_counter_in_its_colour() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		var before := values(e)
		e.resources[GameEngine.FOOD] += 3
		e.resources[GameEngine.FOOD] -= 1  # +3 and −1 before one refresh: one "+2 food"
		e.changed.emit()
		await wait_frames()
		await assert_net_tokens(main, before, "+2 food")
		before = values(e)
		e.resources[GameEngine.FOOD] -= 3
		e.changed.emit()
		await wait_frames()
		await assert_net_tokens(main, before, "−3 food"))


func test_wealth_score_and_pop_changes_float_up_from_their_counters() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		for change: Callable in [
				func(): e.resources[GameEngine.WEALTH] -= 4,
				func(): e.zone("tableau").find(home_uid(e)).pop += 1]:  # +1 pop and, at 1 VP per pop, +1 VP
			var before := values(e)
			change.call()
			e.changed.emit()
			await wait_frames()
			await assert_net_tokens(main, before, "a change"), {"scout": 10}, POP)


func test_a_refresh_that_changes_no_counter_floats_nothing() -> void:
	await with_token_main(func(main: Node):
		Game.engine.changed.emit()
		await wait_frames()
		eq(tokens_on(main).map(func(l: Label): return l.text), [], "no tokens"))


# --- 126 AC2: whatever caused it ---

func test_a_played_cards_costs_gains_and_vp_float_up_from_their_counters() -> void:
	await with_token_main(func(main: Node):
		for id in ["farm", "caravan", "bazaar", "shrine", "guildhall"]:
			var before := values(Game.engine)
			await play(main, id)
			await wait_frames()
			await assert_net_tokens(main, before, id), {"scout": 10}, POP)


func test_a_grow_effect_floats_its_pop_up_from_the_pop_counter() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		e.changed.emit()
		await wait_frames()
		await step_tweens(main, [])
		var before := values(e)
		await play(main, "festival")
		await wait_frames()
		eq(e.total_pop() - before["Pop:"], 2, "Festival grew both territories")
		await assert_net_tokens(main, before, "festival"), {"scout": 10}, POP)


func test_a_grow_from_the_meter_floats_food_and_pop_up_from_their_counters() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var view: CardView = main.views[home]
		view.details_requested.emit(view)
		await wait_screen_transition()
		var before := values(e)
		main.territory_view.grow_button.pressed.emit()
		await wait_frames()
		eq(e.total_pop() - before["Pop:"], 1, "grew")
		await assert_net_tokens(main, before, "grow"), {"scout": 10}, POP)


func test_end_turn_upkeep_floats_its_net_changes() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["temple", "stall"])  # upkeep: +1 VP, +1 wealth; pop eats 2 food
		e.changed.emit()
		await wait_frames()
		await step_tweens(main, [])
		var before := values(e)
		e.end_turn()
		await wait_frames()
		check(values(e) != before, "upkeep changed the counters")
		await assert_net_tokens(main, before, "upkeep"), {"scout": 10}, POP)


func test_starving_pop_floats_down_from_the_pop_counter() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		e.zone("tableau").find(home_uid(e)).pop = 6  # eats 6, the Capital makes 2
		e.resources[GameEngine.FOOD] = 0
		e.end_turn()  # a hungry upkeep brings a Famine (083); the next one costs pop
		e.resources[GameEngine.FOOD] = 0
		e.changed.emit()
		await wait_frames()
		await step_tweens(main, [])
		var before := values(e)
		e.end_turn()
		await wait_frames()
		check(e.total_pop() < before["Pop:"], "pop starved")
		await assert_net_tokens(main, before, "starving"), {"scout": 10}, POP)


# --- 126 AC3: several at once ---

func test_several_counters_float_left_to_right_a_stagger_apart() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		var before := values(e)
		e.resources[GameEngine.FOOD] += 1
		e.resources[GameEngine.WEALTH] += 1
		e.zone("tableau").find(home_uid(e)).pop += 1  # +1 pop, +1 VP
		e.changed.emit()
		await wait_frames()
		var tokens: Array[Label] = []
		for counter in COUNTERS:
			tokens.append_array(labels_starting(main.fx, token_text(counter, 1)))
		eq(tokens.map(func(l: Label): return l.text), ["+1 food", "+1 wealth", "+1 VP", "+1 pop"], "a token per counter")
		if tokens.size() != 4:
			return
		var texts: Array = tokens.map(func(l: Label): return l.text)  # read before the tokens are freed
		var tracks := await step_tweens(main, tokens)
		var shown_at: Array[int] = []  # the first step each token shows
		for token in tokens:
			shown_at.append((tracks[token].alpha as Array).find_custom(func(a: float): return a > 0.0))
		for i in range(1, 4):
			check(shown_at[i] > shown_at[i - 1], "%s after %s: %s" % [texts[i], texts[i - 1], shown_at])
		check((shown_at[3] - shown_at[0]) * STEP >= 3 * Anim.TOKEN_STAGGER - STEP,
			"three staggers from first to last: steps %s" % [shown_at]), {"scout": 10}, POP)


# --- 126 AC4: no tokens for a fresh game ---

func test_starting_and_restarting_a_game_floats_nothing() -> void:
	await with_token_main(func(main: Node):
		Game.engine.resources[GameEngine.FOOD] = 30
		main.start_game(2)
		await wait_frames()
		eq(tokens_on(main).map(func(l: Label): return l.text), [], "no tokens after a restart")
		main.start_game(1)
		await wait_frames()
		eq(tokens_on(main).map(func(l: Label): return l.text), [], "no tokens after a new game"), {"scout": 10}, POP)


# --- 126 AC5: the supply screen shows its own ---

func test_closing_the_supply_screen_after_buying_floats_nothing() -> void:
	await with_token_main(func(main: Node):
		main.supply.open(Game.engine)
		await wait_frames()
		main.supply.pick(main.supply.views()[0])
		await step_tweens(main, [])
		main.supply.close()
		await wait_frames()
		eq(tokens_on(main).map(func(l: Label): return l.text), [], "no top-bar token on closing"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


# --- 126 AC6: Reduce motion ---

func test_with_reduce_motion_a_gain_fades_in_place_below_its_counter() -> void:
	_calm = true
	await with_token_main(func(main: Node):
		var counter := only_label(main, "Food:")
		Game.engine.resources[GameEngine.FOOD] += 2
		Game.engine.changed.emit()
		await wait_frames()
		var start := below(counter)
		var tokens := labels_starting(main.fx, "+2 food")
		eq(tokens.size(), 1, "one +2 food token")
		if tokens.is_empty():
			return
		var tracks := await step_tweens(main, tokens)
		var furthest := 0.0
		for p: Vector2 in tracks[tokens[0]].path:
			furthest = maxf(furthest, p.distance_to(start))
		check(furthest < 1.0, "stays just below the counter: strays %s px" % furthest)
		check(tracks[tokens[0]].freed, "fades and is freed"))
	_calm = false
