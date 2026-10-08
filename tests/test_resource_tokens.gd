extends "res://tests/lib/test_case.gd"
## Counter changes in the real main scene. A cost or gain used to float up as a token (114, 126), then (181) the
## figure rolled like an odometer with a "+N" / "−N" tag beside it; since 218 the roll alone shows the change: no tag,
## and the counters stay put while it rolls (the tag used to push every counter right of it along). Tweens are stepped
## by hand (step_tweens).

const STEP := 0.02  # seconds per tween step
const LONG := 2.0  # seconds: longer than any roll

var _calm := false  # Reduce motion for with_token_main

const COUNTERS := [GameEngine.FOOD, GameEngine.WEALTH, TopBar.SCORE, TopBar.POP]  # the bar's order
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}, "territory_deck": {"grassland": 1}}
const START := 20  # the fixture's food and wealth: changes in the tests keep them two digits, so no counter widens


## Runs body(main) on the real main scene on a TEST_CARDS game (seed 1) with START food and wealth, its own rolls done.
func with_token_main(body: Callable, deck := {"scout": 10}, overrides := {}) -> void:
	await with_reduce_motion(_calm, func():
		var real := Game.engine
		Game.engine = make_engine(deck, overrides)
		var main := open_main()
		main.start_game(1)
		Game.engine.resources[GameEngine.FOOD] = START
		Game.engine.resources[GameEngine.WEALTH] = START
		Game.engine.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
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
		var tag := counter_tag(MainProbe.counter(main, key))
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


## Each counter's left edge on screen, by key (every key in the bar, the hidden ones too).
func lefts(main: Node) -> Dictionary:
	var out := {}
	for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST, TopBar.SCORE, TopBar.POP]:
		out[key] = (MainProbe.counter(main, key) as Control).get_global_rect().position.x
	return out


## Runs change (which changes the engine and emits changed, awaitable), then steps the rolls through, asserting that no
## counter shows a tag at any step, nothing floats, and every counter sits where it ends up at every step of the roll:
## nothing shifts and shifts back (218). (A forecast or digit count that changes moves its neighbours for good; the
## tests keep figures within two digits.)
func assert_steady(main: Node, change: Callable, what: String) -> void:
	var before := values(Game.engine)
	await change.call()
	await wait_frames()
	check(values(Game.engine) != before, "%s: a counter changed" % what)
	var tags := []
	var samples := []
	var sample := func():
		for t in tags_on(main):
			if not tags.has(t):
				tags.append(t)
		samples.append(lefts(main))
	sample.call()
	for i in roundi(LONG / STEP):  # a frame per step, so the bar lays out what each step shows before it is read
		step_tweens(main, STEP)
		await wait_frames(1)
		sample.call()
	var settled: Dictionary = samples.back()
	var moved := {}  # key -> the furthest it strayed from where it settled
	for at: Dictionary in samples:
		for key in at:
			if absf(at[key] - settled[key]) > 0.5:
				moved[key] = maxf(moved.get(key, 0.0), absf(at[key] - settled[key]))
	eq(tags, [], "%s: no tags" % what)
	eq(moved, {}, "%s: no counter strays from where it settles (key: px)" % what)
	eq(floats_on(main), [], "%s: nothing floats" % what)


## Plays the card id from the hand onto the home territory if it needs a target.
func play(main: Node, id: String) -> void:
	var e := Game.engine
	var uid := put_in_hand(e, id)
	e.changed.emit()  # so the board deals it a view
	await wait_frames()
	var view: CardView = main.views[uid]
	main.card_actions.try_play(view, home_uid(e) if e.needs_target(uid) else -1)
	await wait_frames()


# --- 218 AC1: a change rolls with no tag, and nothing moves ---

func test_the_tags_are_gone() -> void:
	var names := (load("res://ui/anim.gd") as Script).get_script_constant_map()
	for name in ["TAG_HOLD", "TAG_STAGGER", "CALM_TAG_HOLD"]:
		check(not names.has(name), "Anim.%s is gone" % name)
	check(not (load("res://ui/counter.gd") as Script).get_script_method_list().any(func(m): return m.name == "show_tag"),
		"Counter.show_tag is gone")


func test_a_food_change_rolls_with_no_tag_and_no_counter_moves() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		await assert_steady(main, func():
			e.resources[GameEngine.FOOD] += 3
			e.resources[GameEngine.FOOD] -= 1
			e.changed.emit(), "+2 food")
		await assert_steady(main, func():
			e.resources[GameEngine.FOOD] -= 3
			e.changed.emit(), "−3 food")
		eq(MainProbe.counter_text(main, GameEngine.FOOD), str(START - 1), "food reads 19"))


func test_wealth_score_and_pop_changes_roll_with_no_tag_and_no_counter_moves() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		await assert_steady(main, func():
			e.resources[GameEngine.WEALTH] -= 4
			e.changed.emit(), "−4 wealth")
		await assert_steady(main, func():
			e.zone("tableau").find(home_uid(e)).pop += 1  # +1 pop and, at 1 VP per pop, +1 VP
			e.changed.emit(), "+1 pop"), {"scout": 10}, POP)


func test_a_played_cards_costs_and_gains_roll_with_no_tag_and_no_counter_moves() -> void:
	await with_token_main(func(main: Node):
		for id in ["farm", "caravan", "shrine"]:
			await assert_steady(main, func(): await play(main, id), id), {"scout": 10}, POP)


func test_end_turn_upkeep_rolls_with_no_tag_and_no_counter_moves() -> void:
	await with_token_main(func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["temple", "stall"])  # upkeep: +1 VP, +1 wealth; pop eats 2 food
		e.changed.emit()
		await wait_frames()
		step_tweens(main, LONG)
		await assert_steady(main, func(): e.end_turn(), "upkeep"), {"scout": 10}, POP)


func test_with_reduce_motion_a_change_shows_at_once_with_no_tag_and_no_counter_moves() -> void:
	_calm = true
	await with_token_main(func(main: Node):
		var e := Game.engine
		await assert_steady(main, func():
			e.resources[GameEngine.FOOD] += 2
			e.changed.emit(), "+2 food")
		eq(MainProbe.counter(main, GameEngine.FOOD).figure().shown(), START + 2, "the figure shows 22"))
	_calm = false


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
		main.supply.buy(main.supply.views()[0])
		step_tweens(main, LONG)
		main.supply.close()
		await wait_frames()
		step_tweens(main, 0.3)
		eq(tags_on(main), [], "no top-bar tag on closing")
		eq(floats_on(main), [], "nothing floats"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


# --- 218 AC2: the Supply screen's wealth ---

func test_buying_rolls_the_supply_screens_wealth_down_with_no_tag() -> void:
	await with_token_main(func(main: Node):
		main.supply.open(Game.engine)
		await wait_frames()
		var counter: Control = main.supply.counter(GameEngine.WEALTH)
		main.supply.buy(main.supply.views()[0])
		await wait_frames()
		eq(counter.figure().value, START - 3, "the screen's wealth figure rolls 20 → 17")
		var tags := []
		step_tweens(main, LONG, func():
			var tag := counter_tag(counter)
			if tag != null and not tags.has(tag.text):
				tags.append(tag.text))
		eq(tags, [], "no tag beside it")
		eq(floats_on(main), [], "no floating −3 wealth"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


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
		var figure: Odometer = MainProbe.counter(main, GameEngine.FOOD).figure()
		eq(figure.value, 5, "the odometer's value is 5")
		eq(MainProbe.counter_text(main, GameEngine.FOOD), "5", "the reading is new at once")
		eq(figure.shown(), 3, "while the digits still show 3")
		step_tweens(main, 0.5)
		eq(figure.shown(), 5, "and roll to 5"))


func test_every_counters_figure_is_an_odometer() -> void:
	await with_token_main(func(main: Node):
		for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST, TopBar.SCORE, TopBar.POP]:
			var figure: Odometer = MainProbe.counter(main, key).figure()
			check(figure != null and figure.get_script() != null and figure.get_script().resource_path == "res://ui/odometer.gd",
				"'%s' figure is an Odometer" % key)
		main.supply.open(Game.engine)
		await wait_frames()
		var supply_figure: Odometer = main.supply.counter(GameEngine.WEALTH).figure()
		check(supply_figure != null and supply_figure.get_script().resource_path == "res://ui/odometer.gd",
			"the Supply screen's wealth figure is an Odometer"),
		{"scout": 10}, {"supply": {"scout": {"price": 3, "count": 2}}})


func test_a_figure_sits_against_its_glyph_and_grows_rightward() -> void:
	_calm = true
	await with_token_main(func(main: Node):
		var counter: Control = MainProbe.counter(main, GameEngine.FOOD)
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
