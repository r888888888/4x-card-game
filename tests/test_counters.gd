extends "res://tests/lib/test_case.gd"
## The top bar's and the Supply screen's counters found by name (177): `counter(key)` and `counter_text(key)` on main
## and on `main.supply`, so tests don't find a counter by the text it starts with.

## Pop on, eating 1 food: with the Capital's +2 food at upkeep, food's forecast is +1.
const POP_ON := {"population": {"start": 1, "food_upkeep": 1, "vp_per_pop": 1}}
const SUPPLY := {"supply": {"scout": {"price": 3, "count": 2}}}


## Every key the top bar answers to, in the bar's order.
func bar_keys() -> Array:
	return [TopBar.TURN, GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, GameEngine.UNREST,
		TopBar.SCORE, TopBar.POP]


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
		eq(main.counter_text(GameEngine.FOOD), "3", "food: its figure (180: no word; 201: the forecast apart)")
		eq(forecast(main, GameEngine.FOOD), "+1", "and its forecast"))


func test_each_counter_text_is_that_counters_text() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		eq(main.counter_text(TopBar.TURN), "T 001", "the turn plate (201)")
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
		for key in [GameEngine.UNREST, TopBar.POP]:
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
		var discard = main.supply.counter(SupplyScreen.DISCARD)
		check(discard is Control and discard != wealth, "the discard counter is another Control")
		eq(main.supply.counter("nonsense"), null, "no counter for an unknown key"))


# --- 201: the strip in the specimen's style ---

## The Label beside counter key reading its forecast, or null.
func forecast_label(main: Node, key: String) -> Label:
	var counter: Control = main.counter(key)
	for l in counter.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text == forecast(main, key) and l.text != "":
			return l
	return null


func test_the_turn_shows_as_a_plate_with_the_limit_in_its_tooltip() -> void:
	await with_main(make_engine({"farm": 10}, {"turn_limit": 3}), func(main: Node):
		var plate: Label = main.counter(TopBar.TURN)
		eq(main.counter_text(TopBar.TURN), "T 001", "three digits, zero-padded")
		eq(plate.tooltip_text, "Turn 1 of 3", "the limit in its tooltip")
		eq(plate.theme_type_variation, &"Plate", "the Plate look: mono numerals on a well")
		var well := plate.get_theme_stylebox("normal") as StyleBoxFlat
		check(well != null and well.bg_color == Palette.FIELD, "on FIELD"))


func test_each_resource_shows_its_forecast_as_a_separate_quieter_figure() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] = 6
		e.changed.emit()
		await wait_frames()
		var ahead: int = e.upkeep_forecast()[GameEngine.FOOD]
		eq(main.counter_text(GameEngine.FOOD), "6", "the figure alone")
		eq(forecast(main, GameEngine.FOOD), "%+d" % ahead, "the forecast, signed, no brackets")
		var label := forecast_label(main, GameEngine.FOOD)
		check(label != null, "a label of its own")
		if label != null:
			eq(label.get_theme_color("font_color"), Palette.TEXT_DIM, "TEXT_DIM")
			eq(label.get_theme_font_size("font_size"), Tokens.TYPE_NUMERAL_S, "TYPE_NUMERAL_S")
			var figure_end: float = (main.counter(GameEngine.FOOD).figure() as Control).get_global_rect().end.x
			check(label.get_global_rect().position.x - figure_end >= Tokens.SPACE_1 - 0.5, "SPACE_1 from the figure: %d" % [
				label.get_global_rect().position.x - figure_end])
		var ahead_all: Dictionary = e.upkeep_forecast()
		for key in [GameEngine.WEALTH, GameEngine.INSIGHT]:
			var want: String = ("%+d" % ahead_all[key]) if ahead_all.has(key) else ""  # no entry: no forecast label
			eq(forecast(main, key), want, "%s's forecast" % key))


func test_score_and_pop_show_no_forecast() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		for key in [TopBar.SCORE, TopBar.POP]:
			eq(forecast(main, key), "", "%s: none" % key)
			check(forecast_label(main, key) == null, "%s: no forecast label" % key))


func test_the_figures_are_numerals_beside_20_px_glyphs() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		eq(TopBar.GLYPH, 20, "glyphs at 20 px, the mock's strip")
		for key in [GameEngine.FOOD, GameEngine.WEALTH, TopBar.SCORE]:
			var figure: Control = main.counter(key).figure()
			eq(figure.get_theme_font_size("font_size"), Tokens.TYPE_NUMERAL, "%s's figure at TYPE_NUMERAL" % key))


func test_the_strip_keeps_buy_cards_knowledge_log_and_menu_at_its_right() -> void:
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var strip: Control = (main.counter(GameEngine.FOOD) as Control).get_parent()
	var texts: Array = UIKit.buttons_in(strip).filter(func(b): return b.is_visible_in_tree()).map(func(b): return b.text)
	eq(texts, ["Buy Cards", "Knowledge", "Log", "Menu"], "the strip's buttons (the civilization and End turn left: 202, 203)")
	close_main(main)


## main.forecast_text(key) (201), or "<no hook>" before it exists, so a test fails without crashing its caller.
func forecast(main: Node, key: String) -> String:
	return main.forecast_text(key) if main.has_method("forecast_text") else "<no hook>"
