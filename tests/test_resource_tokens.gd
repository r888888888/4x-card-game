extends "res://tests/lib/test_case.gd"
## Counter changes in the real main scene. A cost or gain used to float up as a token (114, 126); since 181 the
## counter's figure rolls like an odometer and a short "+N" / "−N" tag sits right of it for Anim.TAG_HOLD, one net tag
## per changed counter per refresh, whatever caused it, staggered left to right. Nothing floats on the fx layer any more.
## Tags are Labels inside a counter reading "+N" or "−N"; tweens are stepped by hand (step_tweens).

const STEP := 0.02  # seconds per tween step
const LONG := 2.0  # seconds: longer than any tag's life, Reduce motion's included

var _calm := false  # Reduce motion for with_token_main

const COUNTERS := [GameEngine.FOOD, GameEngine.WEALTH, TopBar.SCORE, TopBar.POP]  # the bar's order
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}, "territory_deck": {"grassland": 1}}


## Anim's constant name, read by name so this file parses before it exists (red phase).
func anim(name: String) -> float:
	return float((load("res://ui/anim.gd") as Script).get_script_constant_map().get(name, 0.0))


## Runs body(main) on the real main scene on a TEST_CARDS game (seed 1) with 10 food and 10 wealth, its own tags gone.
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
		step_tweens(main, LONG)  # the fixture's own tags come and go
		await wait_frames()
		await body.call(main)
		close_main(main)
		Game.engine = real)


## Advances every running tween by STEP until seconds have passed, calling sample.call() after each step if given.
func step_tweens(main: Node, seconds: float, sample := Callable()) -> void:
	for i in roundi(seconds / STEP):
		for tween in main.get_tree().get_processed_tweens():
			tween.custom_step(STEP)
		if sample.is_valid():
			sample.call()


## The bar's tags now: [key, text] for each counter in COUNTERS showing one, in the bar's order.
func tags_on(main: Node) -> Array:
	var out := []
	for key in COUNTERS:
		var tag := counter_tag(main.counter(key))
		if tag != null:
			out.append([key, tag.text])
	return out


## Every visible "+N unit" / "−N unit" label floating on main's fx layer (the old tokens; there should be none).
func floats_on(main: Node) -> Array:
	var token := RegEx.create_from_string("^[+−][0-9]+ ")
	return main.fx.get_children().filter(func(n: Node):
		return n is Label and (n as Label).is_visible_in_tree() and token.search(n.text) != null).map(
		func(l: Label): return l.text)


## The bar's counter values now, by counter key.
func values(e: GameEngine) -> Dictionary:
	return {GameEngine.FOOD: e.resources.get(GameEngine.FOOD, 0), GameEngine.WEALTH: e.resources.get(GameEngine.WEALTH, 0),
		TopBar.SCORE: e.score(), TopBar.POP: e.total_pop()}


## "+2" / "−3" (a real minus) for a change of n.
func tag_text(n: int) -> String:
	return "%s%d" % ["+" if n > 0 else "−", absi(n)]


## Asserts that each counter that changed since before shows exactly one tag (its net change, in the gain or cost
## colour, directly right of its figure) and that no other counter shows one and nothing floats; then that every tag is
## gone after Anim.TAG_HOLD plus its stagger and a short fade.
func assert_net_tags(main: Node, before: Dictionary, what: String) -> void:
	step_tweens(main, anim("TAG_STAGGER") * COUNTERS.size())  # every tag has appeared
	var after := values(Game.engine)
	var expected := []
	for key in COUNTERS:
		var n: int = after[key] - before[key]
		if n == 0:
			continue
		expected.append([key, tag_text(n)])
		var counter: Control = main.counter(key)
		var tag := counter_tag(counter)
		if tag == null:
			continue
		eq(tag.get_theme_color("font_color"), UIKit.GAIN_COLOR if n > 0 else UIKit.COST_COLOR, "%s: %s colour" % [what, key])
		var figure: Control = counter.figure()
		check(tag.get_global_rect().position.x >= figure.get_global_rect().end.x - 0.5,
			"%s: %s tag right of its figure" % [what, key])
		check(tag.get_global_rect().position.x - figure.get_global_rect().end.x < 24.0,
			"%s: %s tag directly beside its figure" % [what, key])
	eq(tags_on(main), expected, "%s: one net tag per changed counter" % what)
	eq(floats_on(main), [], "%s: nothing floats" % what)
	step_tweens(main, anim("TAG_HOLD") + 0.3)
	await wait_frames()
	eq(tags_on(main), [], "%s: the tags are gone after Anim.TAG_HOLD" % what)


## Plays the card id from the hand onto the home territory if it needs a target.
func play(main: Node, id: String) -> void:
	var e := Game.engine
	var uid := put_in_hand(e, id)
	e.changed.emit()  # so the board deals it a view
	await wait_frames()
	var view: CardView = main.views[uid]
	main.try_play(view, home_uid(e) if e.needs_target(uid) else -1)
	await wait_frames()


# --- 181 AC4: a tag per changed counter ---

func test_the_tag_constants() -> void:
	eq(anim("TAG_HOLD"), 0.6, "Anim.TAG_HOLD")
	eq(anim("TAG_STAGGER"), 0.06, "Anim.TAG_STAGGER")


func test_a_change_shows_one_net_tag_per_counter_in_its_colour() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		var before := values(e)
		e.resources[GameEngine.FOOD] += 3
		e.resources[GameEngine.FOOD] -= 1  # +3 and −1 before one refresh: one "+2"
		e.changed.emit()
		await wait_frames()
		await assert_net_tags(main, before, "+2 food")
		before = values(e)
		e.resources[GameEngine.FOOD] -= 3
		e.changed.emit()
		await wait_frames()
		await assert_net_tags(main, before, "−3 food"))


func test_wealth_score_and_pop_changes_tag_their_counters() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		for change: Callable in [
				func(): e.resources[GameEngine.WEALTH] -= 4,
				func(): e.zone("tableau").find(home_uid(e)).pop += 1]:  # +1 pop and, at 1 VP per pop, +1 VP
			var before := values(e)
			change.call()
			e.changed.emit()
			await wait_frames()
			await assert_net_tags(main, before, "a change"), {"scout": 10}, POP)


# --- 181 AC5: none for a refresh that changes nothing ---

func test_a_refresh_that_changes_no_counter_shows_no_tag() -> void:
	await with_token_main(func(main: Node):
		Game.engine.changed.emit()
		await wait_frames()
		step_tweens(main, 0.3)
		eq(tags_on(main), [], "no tags"))


# --- whatever caused it (126 AC2) ---

func test_a_played_cards_costs_gains_and_vp_tag_their_counters() -> void:
	await with_token_main(func(main: Node):
		for id in ["farm", "caravan", "bazaar", "shrine", "guildhall"]:
			var before := values(Game.engine)
			await play(main, id)
			await assert_net_tags(main, before, id), {"scout": 10}, POP)


func test_a_grow_effect_tags_the_pop_counter() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		e.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
		var before := values(e)
		await play(main, "festival")
		eq(e.total_pop() - before[TopBar.POP], 2, "Festival grew both territories")
		await assert_net_tags(main, before, "festival"), {"scout": 10}, POP)


func test_a_grow_from_the_meter_tags_food_and_pop() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var view: CardView = main.views[home]
		view.details_requested.emit(view)
		await wait_screen_transition()
		var before := values(e)
		main.territory_view.grow_button.pressed.emit()
		await wait_frames()
		eq(e.total_pop() - before[TopBar.POP], 1, "grew")
		await assert_net_tags(main, before, "grow"), {"scout": 10}, POP)


func test_end_turn_upkeep_tags_its_net_changes() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["temple", "stall"])  # upkeep: +1 VP, +1 wealth; pop eats 2 food
		e.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
		var before := values(e)
		e.end_turn()
		await wait_frames()
		check(values(e) != before, "upkeep changed the counters")
		await assert_net_tags(main, before, "upkeep"), {"scout": 10}, POP)


func test_starving_pop_tags_the_pop_counter() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		e.zone("tableau").find(home_uid(e)).pop = 6  # eats 6, the Capital makes 2
		e.resources[GameEngine.FOOD] = 0
		e.end_turn()  # a hungry upkeep brings a Famine (083); the next one costs pop
		e.resources[GameEngine.FOOD] = 0
		e.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
		var before := values(e)
		e.end_turn()
		await wait_frames()
		check(e.total_pop() < before[TopBar.POP], "pop starved")
		await assert_net_tags(main, before, "starving"), {"scout": 10}, POP)


# --- several at once (126 AC3) ---

func test_several_tags_appear_left_to_right_a_stagger_apart() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] += 1
		e.resources[GameEngine.WEALTH] += 1
		e.zone("tableau").find(home_uid(e)).pop += 1  # +1 pop, +1 VP
		e.changed.emit()
		var first_seen := {}  # key -> the first step its tag shows
		var steps := [0]
		var sample := func():
			steps[0] += 1
			for key in COUNTERS:
				if not first_seen.has(key) and counter_tag(main.counter(key)) != null:
					first_seen[key] = steps[0]
		sample.call()
		step_tweens(main, 0.4, sample)
		eq(first_seen.keys().size(), 4, "a tag per counter: %s" % [first_seen])
		if first_seen.size() != 4:
			return
		var at: Array = COUNTERS.map(func(k): return first_seen[k])
		for i in range(1, 4):
			check(at[i] > at[i - 1], "%s after %s: %s" % [COUNTERS[i], COUNTERS[i - 1], at])
		check((at[3] - at[0]) * STEP >= 3 * anim("TAG_STAGGER") - STEP, "three staggers from first to last: steps %s" % [at])
		eq(floats_on(main), [], "nothing floats"), {"scout": 10}, POP)


# --- 181 AC5: none for a fresh game, or behind the supply screen ---

func test_starting_and_restarting_a_game_shows_no_tags() -> void:
	await with_token_main(func(main: Node):
		Game.engine.resources[GameEngine.FOOD] = 30
		main.start_game(2)
		await wait_frames()
		step_tweens(main, 0.3)
		eq(tags_on(main), [], "no tags after a restart")
		main.start_game(1)
		await wait_frames()
		step_tweens(main, 0.3)
		eq(tags_on(main), [], "no tags after a new game"), {"scout": 10}, POP)


func test_closing_the_supply_screen_after_buying_shows_no_top_bar_tag() -> void:
	await with_token_main(func(main: Node):
		main.supply.open(Game.engine)
		await wait_frames()
		main.supply.pick(main.supply.views()[0])
		step_tweens(main, LONG)
		main.supply.close()
		await wait_frames()
		step_tweens(main, 0.3)
		eq(tags_on(main), [], "no top-bar tag on closing")
		eq(floats_on(main), [], "nothing floats"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


func test_buying_rolls_the_supply_screens_wealth_down_with_a_tag() -> void:
	await with_token_main(func(main: Node):
		main.supply.open(Game.engine)
		await wait_frames()
		var counter: Control = main.supply.counter(GameEngine.WEALTH)
		main.supply.pick(main.supply.views()[0])
		await wait_frames()
		eq(counter.figure().value, 7, "the screen's wealth figure rolls 10 → 7")
		step_tweens(main, 0.1)
		var tag := counter_tag(counter)
		eq(tag.text if tag != null else "", "−3", "a −3 tag beside it")
		if tag != null:
			eq(tag.get_theme_color("font_color"), UIKit.COST_COLOR, "in the cost colour")
		eq(floats_on(main), [], "no floating −3 wealth"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


# --- 181 AC4: Reduce motion ---

func test_with_reduce_motion_a_tag_appears_in_place_and_holds_longer() -> void:
	_calm = true
	await with_token_main(func(main: Node):
		var counter: Control = main.counter(GameEngine.FOOD)
		Game.engine.resources[GameEngine.FOOD] += 2
		Game.engine.changed.emit()
		await wait_frames()
		var tag := counter_tag(counter)
		check(tag != null, "the +2 tag shows at once")
		if tag == null:
			return
		var start := tag.get_global_rect().position
		var furthest := [0.0]
		step_tweens(main, 1.4, func():
			if is_instance_valid(tag):
				furthest[0] = maxf(furthest[0], tag.get_global_rect().position.distance_to(start)))
		check(furthest[0] < 0.5, "doesn't move: strays %s px" % furthest[0])
		check(counter_tag(counter) != null, "still there at 1.4 s")
		step_tweens(main, 0.4)
		await wait_frames()
		check(counter_tag(counter) == null, "gone by 1.8 s"))
	_calm = false


# --- 181 AC3: the figures are odometers ---

func test_a_refresh_rolls_the_figure_and_the_reading_changes_at_once() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] = 3
		e.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
		e.resources[GameEngine.FOOD] = 5
		e.changed.emit()
		var figure: Object = main.counter(GameEngine.FOOD).figure()
		eq(figure.value, 5, "the odometer's value is 5")
		eq(main.counter_text(GameEngine.FOOD), "5", "the reading is new at once")
		eq(figure.shown(), 3, "while the digits still show 3")
		step_tweens(main, 0.5)
		eq(figure.shown(), 5, "and roll to 5"))


func test_every_counters_figure_is_an_odometer() -> void:
	await with_token_main(func(main: Node):
		for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST, TopBar.SCORE, TopBar.POP]:
			var figure: Object = main.counter(key).figure()
			check(figure != null and figure.get_script() != null and figure.get_script().resource_path == "res://ui/odometer.gd",
				"'%s' figure is an Odometer" % key)
		main.supply.open(Game.engine)
		await wait_frames()
		var supply_figure: Object = main.supply.counter(GameEngine.WEALTH).figure()
		check(supply_figure != null and supply_figure.get_script().resource_path == "res://ui/odometer.gd",
			"the Supply screen's wealth figure is an Odometer"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


func test_a_figure_sits_against_its_glyph_and_grows_rightward() -> void:
	_calm = true
	await with_token_main(func(main: Node):
		var counter: Control = main.counter(GameEngine.FOOD)
		Game.engine.resources[GameEngine.FOOD] = 9
		Game.engine.changed.emit()
		await wait_frames()
		var figure: Control = counter.figure()
		var glyph := counter.find_children("*", "TextureRect", true, false)[0] as TextureRect
		var left := figure.get_global_rect().position.x
		check(left >= glyph.get_global_rect().end.x, "the figure starts right of the glyph")
		var width := figure.size.x
		Game.engine.resources[GameEngine.FOOD] = 10
		Game.engine.changed.emit()
		await wait_frames()
		eq(figure.get_global_rect().position.x, left, "its left edge stays put")
		check(figure.size.x > width, "it grows rightward: %s → %s" % [width, figure.size.x]))
	_calm = false


# --- 181 AC6: nothing floats ---

func test_the_floating_tokens_are_gone() -> void:
	check(not (load("res://ui/ui_kit.gd") as Script).get_script_method_list().any(func(m): return m.name == "float_token"),
		"UIKit.float_token is gone")
	var names := (load("res://ui/anim.gd") as Script).get_script_constant_map()
	for name in ["TOKEN_FLY_TIME", "TOKEN_FLOAT_PX", "TOKEN_STAGGER"]:
		check(not names.has(name), "Anim.%s is gone" % name)
