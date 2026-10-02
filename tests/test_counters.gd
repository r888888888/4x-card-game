extends "res://tests/lib/test_case.gd"
## The top bar's and the Supply screen's counters found by name (177): `counter(key)` and `counter_text(key)` on main
## and on `main.supply`, so tests don't find a counter by the text it starts with.

## Pop on, eating 1 food: with the Capital's +2 food at upkeep, food's forecast is +1.
const POP_ON := {"population": {"start": 1, "food_upkeep": 1, "vp_per_pop": 1}}
const SUPPLY := {"supply": {"scout": {"price": 3, "count": 2}}}


## Red phase only: script's constant name, so the file parses before the constant exists.
func const_of(script: Script, name: String) -> Variant:
	return script.get_script_constant_map().get(name, "<no %s>" % name)


## Every key the top bar answers to, in the bar's order.
func bar_keys() -> Array:
	return [const_of(TopBar, "TURN"), GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST,
		const_of(TopBar, "SCORE"), const_of(TopBar, "POP")]


## Whether node sits inside the top bar.
func in_top_bar(node: Node) -> bool:
	for n in range(64):
		node = node.get_parent()
		if node == null:
			return false
		if node is TopBar:
			return true
	return false


# --- AC1: a counter per key ---

func test_each_counter_is_a_different_control_in_the_top_bar() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		var found := {}
		for key in bar_keys():
			var counter = main.counter(key)
			check(counter is Control, "a Control for '%s'" % key)
			if counter is Control:
				check(in_top_bar(counter), "'%s' is in the top bar" % key)
				check(not found.has(counter), "'%s' has its own counter" % key)
				found[counter] = key)


func test_an_unknown_key_has_no_counter() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		eq(main.counter("nonsense"), null, "no counter for an unknown key"))


# --- AC2: the counter's text ---

func test_the_food_counter_text_is_the_reading_the_bar_shows() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] = 3
		e.changed.emit()
		await wait_frames()
		eq(e.upkeep_forecast().get(GameEngine.FOOD), 1, "precondition: +1 food at the next upkeep")
		eq(main.counter_text(GameEngine.FOOD), "Food: 3 (+1)", "food, with its forecast"))


func test_each_counter_text_is_that_counters_text() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		eq(main.counter_text(const_of(TopBar, "TURN")), "Turn 1 / 20", "the turn counter")
		for key in bar_keys():
			var counter = main.counter(key)
			if counter is Label:
				eq(main.counter_text(key), counter.text, "'%s' reads as shown" % key))


func test_an_unknown_key_has_no_text() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		eq(main.counter_text("nonsense"), "", "no text for an unknown key"))


# --- AC3: counters that are off still exist, hidden ---

func test_the_unrest_and_pop_counters_exist_but_hide_when_off() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		check(not Game.engine.unrest_on() and not Game.engine.population_on(), "precondition: unrest and pop off")
		for key in [GameEngine.UNREST, const_of(TopBar, "POP")]:
			var counter = main.counter(key)
			check(counter is Control, "'%s' still has a counter" % key)
			if counter is Control:
				check(not counter.is_visible_in_tree(), "'%s' is hidden" % key))


# --- AC4: the Supply screen's own counters ---

func test_the_supply_screen_names_its_wealth_and_discard_counters() -> void:
	await with_main(make_engine({"scout": 10}, SUPPLY), func(main: Node):
		Game.engine.resources[GameEngine.WEALTH] = 10
		Game.engine.changed.emit()
		main.supply.open(Game.engine)
		await wait_frames()
		var wealth = main.supply.counter(GameEngine.WEALTH)
		check(wealth is Control and wealth.is_visible_in_tree(), "the screen's wealth counter, shown")
		check(wealth != main.counter(GameEngine.WEALTH), "not the top bar's")
		eq(main.supply.counter_text(GameEngine.WEALTH), "Wealth: 10", "its text")
		var discard = main.supply.counter(const_of(SupplyScreen, "DISCARD"))
		check(discard is Control and discard != wealth, "the discard counter is another Control")
		eq(main.supply.counter("nonsense"), null, "no counter for an unknown key"))
