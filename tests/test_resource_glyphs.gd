extends "res://tests/lib/test_case.gd"
## Resources named by their glyphs (180): the top bar's counters show a glyph beside a bare figure, and a hand card
## shows its cost at the top right as glyph + figure per resource, red where the player is short (play_shortfall).

const POP_ON := {"population": {"start": 1, "food_upkeep": 1, "vp_per_pop": 1}}
## Counter key -> [glyph file in assets/icons/, tint's Palette name] (183: read when the test runs).
const GLYPHS := {
	GameEngine.FOOD: ["food.svg", &"GAIN"], GameEngine.WEALTH: ["wealth.svg", &"WEALTH"],
	GameEngine.INSIGHT: ["insight.svg", &"INSIGHT"], GameEngine.UNREST: ["unrest.svg", &"UNREST"],
	TopBar.SCORE: ["score.svg", &"TEXT"], TopBar.POP: ["pop.svg", &"POP"],
}


## The glyph inside counter (its TextureRect), or null.
func glyph_of(counter: Control) -> TextureRect:
	if counter == null:
		return null
	var found := counter.find_children("*", "TextureRect", true, false)
	return found[0] if not found.is_empty() else null


## The cost row on view's face, or null.
func cost_row(view: CardView) -> Control:
	return view.find_child("Cost", true, false) as Control


## The cost row's entries as [glyph file, figure text, figure colour] (glyph "" for a text entry).
func entries(view: CardView) -> Array:
	var out := []
	var row := cost_row(view)
	if row == null:
		return out
	for entry in row.get_children():
		var glyphs := entry.find_children("*", "TextureRect", true, false)
		var labels := entry.find_children("*", "Label", true, false)
		var file: String = (glyphs[0] as TextureRect).texture.resource_path.get_file() if not glyphs.is_empty() else ""
		var figure: Label = labels[0] if not labels.is_empty() else null
		out.append([file, figure.text if figure else "", figure.get_theme_color("font_color").to_html() if figure else ""])
	return out


## Puts card id in Game.engine's hand and lets the board deal it a view; returns the view.
func hand_view(main: Node, id: String) -> CardView:
	var uid := put_in_hand(Game.engine, id)
	Game.engine.changed.emit()
	await wait_frames()
	return main.views.get(uid)


# --- AC2: glyphs in the top bar ---

func test_each_counter_shows_its_glyph_in_its_hue_left_of_an_ink_figure() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		for key: String in GLYPHS:
			var counter: Control = main.counter(key)
			var glyph := glyph_of(counter)
			check(glyph != null, "'%s' has a glyph" % key)
			if glyph == null:
				continue
			eq(glyph.texture.resource_path, "res://assets/icons/" + GLYPHS[key][0], "'%s' glyph" % key)
			eq(glyph.self_modulate.to_html(), Palette.color(GLYPHS[key][1]).to_html(), "'%s' glyph tint" % key)
			check(glyph.get_global_rect().position.x - counter.get_global_rect().position.x < 2.0,
				"'%s' glyph at the counter's left" % key)
			if key != GameEngine.UNREST:  # unrest is off in this game
				check(glyph.is_visible_in_tree(), "'%s' glyph shown" % key)
		for key in [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT, TopBar.SCORE, TopBar.POP]:
			eq((main.counter(key).figure().color as Color).to_html(), Palette.TEXT.to_html(),
				"'%s' figure in ink" % key))


func test_the_food_figure_warns_when_pop_would_starve() -> void:
	await with_main(make_engine({"farm": 10}, {"population": {"start": 5, "food_upkeep": 1, "vp_per_pop": 1}}),
		func(main: Node):
			Game.engine.resources[GameEngine.FOOD] = 0
			Game.engine.changed.emit()
			await wait_frames()
			check(Game.engine.upkeep_forecast().get("starve", 0) > 0, "precondition: pop would starve")
			eq((main.counter(GameEngine.FOOD).figure().color as Color).to_html(), Palette.WARN.to_html(),
				"food figure: WARN"))


func test_a_hidden_counter_hides_its_glyph() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		for key in [GameEngine.UNREST, TopBar.POP]:
			var glyph := glyph_of(main.counter(key))
			check(glyph != null and not glyph.is_visible_in_tree(), "'%s' glyph hidden with its counter" % key))


# --- AC3: the counters drop their words ---

func test_the_counters_read_figures_only() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON), func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] = 3
		e.changed.emit()
		await wait_frames()
		eq(main.counter_text(GameEngine.FOOD), "3", "food (its forecast apart since 201)")
		eq(main.counter_text(TopBar.SCORE), str(e.score()), "score")
		eq(main.counter_text(TopBar.POP), str(e.total_pop()), "pop")
		eq(main.counter_text(TopBar.TURN), "T 001", "the turn: its plate (201)"))


# --- AC4: the cost at the top right of a hand card ---

func test_a_hand_cards_cost_is_glyphs_and_figures_on_its_name_line() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		Game.engine.resources[GameEngine.FOOD] = 5
		Game.engine.resources[GameEngine.WEALTH] = 5
		var view: CardView = await hand_view(main, "guildhall")
		var row := cost_row(view)
		check(row != null, "a Cost row")
		if row == null:
			return
		eq(entries(view).map(func(x): return [x[0], x[1]]), [["food.svg", "2"], ["wealth.svg", "2"]], "food 2, wealth 2")
		check(row.get_parent() is HBoxContainer and row.get_parent().find_children("*", "Label", true, false).any(
			func(l: Label): return l.text == "Guildhall"), "on the name's line")
		check(row.get_index() == row.get_parent().get_child_count() - 1, "at the right of the name")
		eq(row.get_theme_constant("separation"), 12, "entries 12 px apart")
		var entry: Control = row.get_child(0)
		eq(entry.get_theme_constant("separation"), 3, "glyph and figure 3 px apart")
		var glyph := entry.find_children("*", "TextureRect", true, false)[0] as TextureRect
		eq(glyph.custom_minimum_size, Vector2(20, 20), "a 20 px glyph")
		check(row.find_children("*", "PanelContainer", true, false).is_empty(), "no box")
		var type_row := view.find_child("TypeRow", true, false)
		check(type_row != null and not type_row.is_ancestor_of(row), "the type line no longer holds the cost"))


func test_a_free_card_shows_no_cost() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		var view: CardView = await hand_view(main, "scout")
		eq(entries(view), [], "no entries")
		check(not view.face_text().contains("Free"), "no 'Free': %s" % view.face_text()))


func test_cost_entries_go_food_wealth_insight_then_others_by_name() -> void:
	var cards := fixture_db([{"id": "odd", "name": "Odd", "type": "action",
		"cost": {"insight": 1, "stone": 2, "wealth": 3, "food": 4}}], [], ["food", "wealth", "insight", "stone"])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"resources": ["food", "wealth", "insight", "stone"]}),
		["food", "wealth", "insight", "stone"] as Array[String], cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	await with_main(GameEngine.new(cards, config), func(main: Node):
		var view: CardView = await hand_view(main, "odd")
		eq(entries(view).map(func(x): return [x[0], x[1]]),
			[["food.svg", "4"], ["wealth.svg", "3"], ["insight.svg", "1"], ["", "2 stone"]], "the order"))


# --- AC5: what the player is short of, in the warning colour ---

func test_a_figure_the_player_is_short_of_is_red_until_they_have_it() -> void:
	await with_main(make_engine({"farm": 10}), func(main: Node):
		var e := Game.engine
		e.resources[GameEngine.FOOD] = 1
		e.resources[GameEngine.WEALTH] = 5
		var view: CardView = await hand_view(main, "guildhall")
		eq(entries(view).map(func(x): return x[2]), [Palette.WARN.to_html(), Palette.TEXT.to_html()],
			"1 food: food red, wealth ink")
		e.resources[GameEngine.FOOD] = 2
		e.changed.emit()
		await wait_frames()
		view = main.views.get(view.uid)
		eq(entries(view).map(func(x): return x[2]), [Palette.TEXT.to_html(), Palette.TEXT.to_html()],
			"2 food: both ink"))


# --- AC6: one food glyph everywhere ---

func test_the_grow_pip_uses_the_top_bars_food_glyph() -> void:
	await with_main(make_engine({"farm": 10}, POP_ON.merged({"territory_deck": {"grassland": 1}})), func(main: Node):
		var glyph := glyph_of(main.counter(GameEngine.FOOD))
		check(glyph != null, "the food counter's glyph")
		if glyph != null:
			eq(Icons.FOOD.resource_path, glyph.texture.resource_path, "the Grow pip's icon is the sprout"))
