extends "res://tests/lib/tech_case.gd"
## The Knowledge screen in the real main scene (backlog 208; the tech tree modal of 059 and 140 before it): the
## Knowledge button and T push it on the play area's navigator with a header ("Realm › Knowledge") and one row of tech
## tiles per era, named from era_names; T, Esc or the header's link go back. A click on an available tech's tile
## learns it (222; a Learn button before it, 140). Hooks on main.knowledge: shown() (the era names, top to bottom; []
## while closed), is_open(), open(), close(), header, context_text(), era_heading(i) (the i-th row's heading Label),
## era_tiles(i), era_vellum(i) and vellum_text(i) (222), tile(name) and tile_texts(name) (222), linked(name) (278), slide_offset() (how
## far the screen sits right of its place) and realm_shift() (how far the screen below has moved left).
## In detail (from docs/testing.md, 331): The Knowledge screen (208; the tech tree modal before it, 059, 140) in the
## real `main.tscn`: T and the Knowledge button push it on the play area's navigator (`main.knowledge`: `shown()`,
## `header`, `context_text()`, `era_heading(i)`, `slide_offset()`, `realm_shift()`), a row per era (caps heading, a
## future era dimmed with its unlocks), compact tiles (222: `tile(name)`, `tile_texts(name)`, `era_tiles(i)`,
## `era_vellum(i)`, `vellum_text(i)`) whose click, Enter, right-click or I opens the details, whose Learn button
## researches (229), a future era under vellum, back by Back / Esc / T / the link or a left click outside it that does
## nothing else (326; on End turn it also ends the turn, 348), the slide and the Realm's shift (a fade with Reduce motion), over a territory view


## Whether main has its Knowledge screen (checked, so a test without it fails instead of crashing and leaving a
## fixture engine in Game.engine for the tests after it).
func has_knowledge(main: Node) -> bool:
	var ok: bool = main.get("knowledge") != null
	check(ok, "main.knowledge exists")
	return ok


func knowledge_button(main: Node) -> Button:
	for b in main.find_children("*", "Button", true, false):
		if b.text.begins_with("Knowledge"):
			return b
	return null


func test_t_opens_knowledge_by_era_and_esc_closes_it() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	var names: Array[String] = []
	for era in Game.engine.tech_eras():
		names.append(Game.engine.era_name(era.era))
	check(names.size() >= 2, "the real tree has several eras: %s" % [names])
	eq(main.knowledge.shown(), names, "one row per era, by name")
	press_key(main, KEY_ESCAPE)
	eq(main.knowledge.shown(), [] as Array[String], "Esc closes")
	await wait_screen_transition()
	press_key(main, KEY_T)
	press_key(main, KEY_T)
	eq(main.knowledge.shown(), [] as Array[String], "T toggles it closed")
	close_main(main)


func test_the_knowledge_button_opens_the_screen() -> void:
	var main := open_main()
	main.start_game(1)
	var button := knowledge_button(main)
	check(button != null, "a Knowledge button")
	if button != null:
		button.pressed.emit()
		check(not main.knowledge.shown().is_empty(), "the screen is open")
	close_main(main)


# --- Backlog 092: the hint names the research card from the engine ---

const Looks := preload("res://tests/lib/surface_looks.gd")
const TREE_TOOLTIP := "Shortcut: T. The tech tree: every tech by era, what it costs now and what it gives.\nEra: Era 1."  # the fixture has no era names


## Opens main on a fixture game (TECHS in the research deck) with main deck deck, starts it, opens the tree and
## returns [Knowledge tooltip, tree header]. Puts the real engine back afterwards.
func hints_with_deck(deck: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config(deck, {"research_deck": {"pottery": 1, "writing": 1}}),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var real := Game.engine
	Game.engine = GameEngine.new(cards, config)
	var main := open_main()
	main.start_game(1)
	var out: Array[String] = ["", ""]
	if not has_knowledge(main):
		close_main(main)
		Game.engine = real
		return out
	var button := knowledge_button(main)
	if button != null:
		out[0] = button.tooltip_text
	press_key(main, KEY_T)
	for label in main.knowledge.find_children("*", "Label", true, false):
		if label.text.begins_with("Insight"):
			out[1] = label.text
	close_main(main)
	Game.engine = real
	return out


func test_hints_name_the_research_card() -> void:
	var hints := hints_with_deck({"farm": 5, "study": 1})
	eq(hints[0], TREE_TOOLTIP + "\nPlay a Research card for more insight.", "Knowledge tooltip")
	eq(hints[1], "Insight 0 · play a Research card for more", "tree header names Research")


func test_hints_leave_out_the_research_sentence_without_a_research_card() -> void:
	var hints := hints_with_deck({"farm": 5})
	eq(hints[0], TREE_TOOLTIP, "Knowledge tooltip")
	eq(hints[1], "Insight 0", "tree header without a research card")


# --- Backlog 140 AC6, 222 AC4: learning from the tree ---

## Runs body(main) on the real main scene with Game.engine swapped for a fixture game: research deck Pottery (2),
## Writing (3), Bronze Working (5) and Iron Working (6, prereq Bronze), insight 5, a Research card in the deck;
## the tree is open. Puts the real engine back.
func with_tree(body: Callable) -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing", "bronze", "iron"], {"farm": 5, "study": 1},
		{"starting": {"resources": {"food": 2, "insight": 5}, "tableau": ["capital"], "territory": "homeland"}})
	var main := open_main()
	main.start_game(1)
	Game.engine.resources["insight"] = 5
	Game.engine.changed.emit()
	press_key(main, KEY_T)
	if has_knowledge(main):
		await body.call(main)
	close_main(main)
	Game.engine = real


## Runs body(main) with the tree open on a fixture game of two eras: Pottery and Writing in era 1, Optics (4) in era
## 2, which opens at 8 pop. Puts the real engine back.
func with_two_eras(body: Callable, unlocks := {"pop": 8}) -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 5}, {"research_deck": {"pottery": 1, "writing": 1, "optics": 1},
		"era_unlocks": {"2": unlocks}}, [{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}])
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	await wait_screen_transition()
	if has_knowledge(main):
		await body.call(main)
	close_main(main)
	Game.engine = real


## The tech tile (a Button) in the open tree for tech_name, or null.
func tile(main: Node, tech_name: String) -> Button:
	return main.knowledge.tile(tech_name)


## The texts tech_name's tile shows, in order: its name, its marker, then "✔ Eureka" when met.
func tile_texts(main: Node, tech_name: String) -> Array[String]:
	return main.knowledge.tile_texts(tech_name)


## The Palette colour called name as it reads now, or transparent if there is none.
func role(name: String) -> Color:
	return (Palette.DAY if Palette.day else Palette.NIGHT).get(name, Color.TRANSPARENT)


## KnowledgeScreen.TILE_SIZE, or (-1, -1) while it doesn't exist.
func tile_size() -> Vector2:
	return (load("res://ui/knowledge_screen.gd") as Script).get_script_constant_map().get("TILE_SIZE", Vector2(-1, -1))


func learned(e: GameEngine, id: String) -> bool:
	return e.zone("researched").cards.any(func(c): return c.def.id == id)


func test_a_click_on_an_available_tile_opens_its_details_and_learns_nothing() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		await wait_screen_transition()
		check(tile(main, "Pottery") != null, "a Pottery tile")
		if tile(main, "Pottery") == null:
			return
		tile(main, "Pottery").pressed.emit()
		eq(main.details.shown().get("name", ""), "Pottery", "Pottery's details")
		check(not learned(e, "pottery"), "nothing learned")
		eq(e.resources.get("insight"), 5, "nothing paid")
		check(main.knowledge.is_open(), "over the open screen"))


func test_enter_on_a_focused_available_tile_opens_its_details_and_learns_nothing() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var t := tile(main, "Writing")
		check(t != null and t.focus_mode != Control.FOCUS_NONE, "a focusable Writing tile")
		if t == null:
			return
		t.grab_focus()
		press_key(main, KEY_ENTER)
		eq(main.details.shown().get("name", ""), "Writing", "Writing's details")
		check(not learned(Game.engine, "writing"), "Enter learned nothing"))


func test_there_is_no_learn_button() -> void:
	await with_tree(func(main: Node):
		var learn: Array = main.knowledge.find_children("*", "Button", true, false).filter(func(b): return b.text == "Learn")
		eq(learn.size(), 0, "no Learn buttons"))


# --- 229: Research from a tech's details. Hook: main.details.research_button() (hidden unless a tech to learn). ---

func test_research_in_a_techs_details_learns_it_and_closes_the_details() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		await wait_screen_transition()
		tile(main, "Pottery").pressed.emit()
		var research: Button = main.details.research_button()
		check(research.visible, "Research shows for an available tech")
		check(not research.disabled, "Research is enabled")
		check(research.get_parent() == main.details.footer, "Research sits in the footer")
		eq(accent_footer(main.details), [research.text] as Array[String], "251: it is the one primary")
		research.pressed.emit()
		await wait_frames()
		check(learned(e, "pottery"), "Pottery learned")
		eq(e.resources.get("insight"), 3, "5 − 2")
		eq(main.details.shown(), {}, "the details closed")
		check(main.knowledge.is_open(), "the screen stays open")
		eq(tile_texts(main, "Pottery"), ["Pottery", "✓"] as Array[String], "the tile now reads researched"))


func test_research_is_disabled_with_the_reason_when_the_tech_cant_be_learned() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		e.resources["insight"] = 4
		e.changed.emit()
		await wait_screen_transition()
		for pair in [["Bronze Working", "bronze"], ["Iron Working", "iron"]]:
			var error := e.buy_tech_error(uid_of(e.zone("research_deck"), pair[1]))
			check(error != "", "precondition: %s can't be learned" % pair[0])
			tile(main, pair[0]).pressed.emit()
			eq(main.details.shown().get("name", ""), pair[0], "%s's details" % pair[0])
			var research: Button = main.details.research_button()
			check(research.visible, "Research shows for %s" % pair[0])
			check(research.disabled, "Research is disabled for %s" % pair[0])
			eq(research.tooltip_text, error, "the tooltip says why")
			research.pressed.emit()
			check(not learned(e, pair[1]), "%s not learned" % pair[0])
			main.details.close()
		eq(e.resources.get("insight"), 4, "nothing paid"))


func test_research_is_hidden_for_a_researched_tech() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))
		await wait_screen_transition()
		tile(main, "Pottery").pressed.emit()
		eq(main.details.shown().get("name", ""), "Pottery", "Pottery's details")
		check(not main.details.research_button().visible, "no Research for a researched tech"))


func test_research_is_hidden_for_a_later_era_tech() -> void:
	await with_two_eras(func(main: Node):
		tile(main, "Optics").pressed.emit()
		eq(main.details.shown().get("name", ""), "Optics", "Optics' details")
		check(not main.details.research_button().visible, "no Research for a later-era tech"))


func test_research_goes_when_the_details_reopen_for_another_card() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		tile(main, "Writing").pressed.emit()
		check(main.details.research_button().visible, "Research shows for Writing")
		main.details.open_def("farm")
		check(not main.details.research_button().visible, "Research is gone for another card"))


func test_an_available_tiles_tooltip_says_a_click_shows_the_details() -> void:
	await with_tree(func(main: Node):
		var lines := tile(main, "Writing").tooltip_text.split("\n")
		eq(lines[-1], "Click, right click or I for the details.", "the tooltip's last line"))


# --- 222 AC2, AC3: the tiles ---

func test_each_tile_shows_its_name_and_a_marker_for_its_state() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))  # 5 − 2 = 3 insight
		eq(tile_texts(main, "Pottery"), ["Pottery", "✓"] as Array[String], "researched: a tick")
		eq(tile_texts(main, "Writing"), ["Writing", "3"] as Array[String], "available: its cost now")
		eq(tile_texts(main, "Iron Working"), ["Iron Working", "needs Bronze Working"] as Array[String], "locked: its prereq")
		check(tile(main, "Pottery").tooltip_text.begins_with("Researched"), "state in words: %s" % tile(main, "Pottery").tooltip_text)
		check(tile(main, "Writing").tooltip_text.begins_with("Available"), "state in words: %s" % tile(main, "Writing").tooltip_text)
		check(tile(main, "Iron Working").tooltip_text.begins_with("Locked"), "state in words: %s" % tile(main, "Iron Working").tooltip_text))


func test_a_future_tile_has_no_marker_and_says_later_era() -> void:
	await with_two_eras(func(main: Node):
		eq(tile_texts(main, "Optics"), ["Optics"] as Array[String], "no marker")
		check(tile(main, "Optics").tooltip_text.begins_with("Later era"), "state in words: %s" % tile(main, "Optics").tooltip_text))


func test_every_tile_is_one_fixed_size() -> void:
	await with_tree(func(main: Node):
		await wait_frames()
		var sizes := ["Pottery", "Writing", "Bronze Working", "Iron Working"].map(func(n): return tile(main, n).size if tile(main, n) != null else Vector2.ZERO)
		for s in sizes:
			eq(s, tile_size(), "a tile's size"))


func test_a_tiles_texts_all_have_room_to_show() -> void:
	await with_tree(func(main: Node):
		await wait_frames()
		for tech_name in ["Writing", "Iron Working"]:
			for label: Label in tile(main, tech_name).find_children("*", "Label", true, false):
				var font := label.get_theme_font("font")
				var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
				check(label.size.x >= width, "%s: '%s' is %s wide, needs %s" % [tech_name, label.text, label.size.x, width]))


func test_tiles_look_like_their_state() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))
		var looks := {
			"Pottery": ["TechTileResearched", role("RESEARCHED_FILL"), role("TEXT_ON_PLANE")],
			"Writing": ["TechTile", Palette.TILE, Palette.TEXT],
			"Iron Working": ["TechTileLocked", Palette.FIELD, Palette.TEXT_DISABLED],
		}
		for tech_name in looks:
			var t := tile(main, tech_name)
			var look: Array = looks[tech_name]
			eq(t.theme_type_variation, look[0], "%s's variation" % tech_name)
			var box := t.get_theme_stylebox("normal") as StyleBoxFlat
			eq(box.bg_color if box != null else Color.TRANSPARENT, look[1], "%s's fill" % tech_name)
			for label in t.find_children("*", "Label", true, false):
				eq(label.get_theme_color("font_color"), look[2], "%s's text colour" % tech_name)
		var available := tile(main, "Writing").get_theme_stylebox("normal") as StyleBoxFlat
		eq(available.border_color, Palette.TEXT, "available: an ink border")
		eq(available.border_width_left, 2, "of 2 px")
		eq((tile(main, "Iron Working").get_theme_stylebox("normal") as StyleBoxFlat).border_color, Palette.CONTROL_BORDER,
			"locked: a rule border"))


# --- 222 AC5: details ---

func test_a_click_on_a_tile_that_isnt_available_opens_its_details() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		tile(main, "Iron Working").pressed.emit()
		eq(main.details.shown().get("name", ""), "Iron Working", "Iron Working's details")
		check(main.knowledge.is_open(), "over the open screen"))


func test_a_right_click_on_an_available_tile_opens_its_details_and_learns_nothing() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		click_control(main, tile(main, "Writing"), MOUSE_BUTTON_RIGHT)
		eq(main.details.shown().get("name", ""), "Writing", "Writing's details")
		check(not learned(Game.engine, "writing"), "not learned"))


func test_i_on_a_focused_tile_opens_its_details() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		tile(main, "Writing").grab_focus()
		press_key(main, KEY_I)
		eq(main.details.shown().get("name", ""), "Writing", "Writing's details")
		check(not learned(Game.engine, "writing"), "not learned"))


func test_a_tiles_tooltip_lists_what_it_gives() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["masonry"], {"farm": 5}, {}, [{"id": "masonry", "name": "Masonry", "type": "tech",
		"cost": {"insight": 2}, "effects": [{"op": "create", "card": "farm"}]}])
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	if has_knowledge(main):
		var t := tile(main, "Masonry")
		check(t != null and t.tooltip_text.contains("gives Farm"), "names what it gives: %s" % [t.tooltip_text if t != null else "no tile"])
	close_main(main)
	Game.engine = real



func test_the_tree_header_counts_insight_and_names_the_research_card() -> void:
	await with_tree(func(main: Node):
		var header := ""
		for label in main.knowledge.find_children("*", "Label", true, false):
			if label.text.begins_with("Insight"):
				header = label.text
		eq(header, "Insight 5 · play a Research card for more", "header"))


func test_the_board_has_no_research_choice() -> void:
	await with_tree(func(main: Node):
		check(not "research_row" in main.choices, "no research overlay")
		var declines := main.find_children("*", "Button", true, false).filter(func(b): return b.text == "Decline")
		eq(declines.size(), 0, "no Decline button"))



# --- 208: a navigated screen ---

func test_knowledge_is_a_screen_on_the_play_areas_navigator_with_a_header() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var screen: Control = main.knowledge
		check(main.knowledge.is_open(), "open")
		eq(main.modals.depth(), 0, "not a modal")
		check(not main.tableau.is_visible_in_tree(), "in place of the Realm")
		eq(screen.header.back_button.text, "◂ Realm", "its tab back (241)")
		eq(screen.header.title_text(), "Knowledge", "its title")
		eq(main.knowledge.context_text(), "Turn 1 · %s" % Game.engine.era_name(Game.engine.era()), "its context")
		check(not FileAccess.file_exists("res://ui/tech_tree_modal.gd"), "the tech tree modal is gone")
		check(main.get("tech_tree") == null, "and main has no tech_tree"))


func test_each_era_is_a_row_headed_in_caps() -> void:
	await with_tree(func(main: Node):
		var eras: Array = Game.engine.tech_eras()
		eq(main.knowledge.shown(), eras.map(func(era): return era.name), "a row per era, top to bottom")
		for i in eras.size():
			var heading: Label = main.knowledge.era_heading(i)
			eq(heading.text, eras[i].name, "row %d's heading" % i)
			check(heading.uppercase, "in caps")
		check(tile(main, "Pottery") != null, "Pottery's tile"))


func test_each_era_has_its_title_block_at_the_left_of_its_tiles() -> void:
	await with_two_eras(func(main: Node):
		await wait_frames()
		var first: Label = main.knowledge.era_heading(0)
		var second: Label = main.knowledge.era_heading(1)
		eq(second.global_position.x, first.global_position.x, "the title blocks share a column")
		eq(second.size.x, first.size.x, "of one width")
		for i in 2:
			var heading: Label = main.knowledge.era_heading(i)
			var tiles: Array = main.knowledge.era_tiles(i)
			check(not tiles.is_empty(), "era %d has tiles" % i)
			for t in tiles:
				check(t.global_position.x >= heading.get_global_rect().end.x, "era %d: a tile right of its title block" % i)
				check(t.global_position.y < heading.get_global_rect().end.y and t.get_global_rect().end.y > heading.global_position.y,
					"era %d: a tile level with its title block" % i))


# --- 222 AC6: an era not reached is under vellum ---

func test_a_future_era_is_under_vellum_with_its_unlocks() -> void:
	await with_two_eras(func(main: Node):
		await wait_frames()
		eq(main.knowledge.era_vellum(0), null, "a reached era has no vellum")
		var vellum: Control = main.knowledge.era_vellum(1)
		check(vellum != null and vellum.is_visible_in_tree(), "the era not reached is under vellum")
		if vellum == null:
			return
		eq(main.knowledge.vellum_text(1), "%s · OPENS AT 8 POP" % Game.engine.era_name(2).to_upper(), "its name and unlocks")
		var optics: Button = tile(main, "Optics")
		check(vellum.get_global_rect().encloses(optics.get_global_rect()), "it covers the era's tiles")
		eq(main.knowledge.era_heading(1).get_parent().modulate, Color.WHITE, "the row isn't dimmed")
		click_control(main, optics)
		eq(main.details.shown(), {}, "a click on the vellum opens nothing"))


func test_the_vellum_names_each_threshold() -> void:
	await with_two_eras(func(main: Node):
		eq(main.knowledge.vellum_text(1), "%s · OPENS AT 8 POP OR 30 WEALTH" % Game.engine.era_name(2).to_upper(), "both"),
		{"pop": 8, "wealth": 30})  # the fixture starts with 20 wealth



func test_back_esc_t_and_the_realm_link_go_back_and_give_the_focus_back() -> void:
	for way in ["esc", "t", "link"]:
		await with_tree(func(main: Node):
			await wait_screen_transition()
			match way:
				"esc":
					press_key(main, KEY_ESCAPE)
				"t":
					press_key(main, KEY_T)
				"link":
					(main.knowledge.header.back_button as Button).pressed.emit()
			await wait_screen_transition()
			check(not main.knowledge.is_open(), "%s: closed" % way)
			check(main.tableau.is_visible_in_tree(), "%s: the Realm is back" % way))


func test_it_slides_in_from_the_right_as_the_realm_shifts_left() -> void:
	await with_reduce_motion(false, func():
		await with_tree(func(main: Node):
			main.knowledge.close()
			await wait_screen_transition()
			main.knowledge.open()
			var width: float = (main.knowledge as Control).size.x
			check(main.knowledge.slide_offset() >= width - 1.0, "starts off the right edge: %s" % main.knowledge.slide_offset())
			eq(main.knowledge.realm_shift(), 0.0, "the Realm in place")
			await (Engine.get_main_loop() as SceneTree).create_timer(0.32 + 0.1).timeout
			eq(main.knowledge.slide_offset(), 0.0, "in place by 0.32 s")
			eq(main.knowledge.realm_shift(), -24.0, "the Realm 24 px left")
			main.knowledge.close()
			await (Engine.get_main_loop() as SceneTree).create_timer(0.26 + 0.1).timeout
			eq(main.knowledge.realm_shift(), 0.0, "the Realm back by 0.26 s")
			check(not (main.knowledge as Control).is_visible_in_tree(), "the screen gone")))


func test_with_reduce_motion_it_only_fades() -> void:
	await with_reduce_motion(true, func():
		await with_tree(func(main: Node):
			eq(main.knowledge.slide_offset(), 0.0, "no slide")
			eq(main.knowledge.realm_shift(), 0.0, "the Realm stays")
			check((main.knowledge as Control).modulate.a < 1.0, "a fade")
			await (Engine.get_main_loop() as SceneTree).create_timer(0.12 + 0.1).timeout
			eq((main.knowledge as Control).modulate.a, 1.0, "in by 0.12 s")))


## Checks every frame for seconds (and a little after) that the hand's row stays at rect. Use with await.
func check_hand_stays(main: Node, rect: Rect2, seconds: float, what: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var end := Time.get_ticks_msec() + int((seconds + 0.1) * 1000.0)
	var moved := 0
	var at := rect
	while Time.get_ticks_msec() < end:
		await tree.process_frame
		var now: Rect2 = (main.hand_scroll as Control).get_global_rect()
		if now != rect:
			moved += 1
			at = now
	eq(moved, 0, "%s: the hand stays at %s (frames off: %d, last at %s)" % [what, rect, moved, at])


func test_bug_224_the_hand_stays_put_while_it_slides_in_and_out() -> void:
	await with_reduce_motion(false, func():
		await with_tree(func(main: Node):
			main.knowledge.close()
			await wait_screen_transition()
			await wait_frames()
			var rest: Rect2 = (main.hand_scroll as Control).get_global_rect()
			main.knowledge.open()
			await check_hand_stays(main, rest, 0.32, "sliding in")
			main.knowledge.close()
			await check_hand_stays(main, rest, 0.26, "sliding out")))


func test_bug_224_with_reduce_motion_the_hand_stays_put() -> void:
	await with_reduce_motion(true, func():
		await with_tree(func(main: Node):
			main.knowledge.close()
			await wait_screen_transition()
			await wait_frames()
			var rest: Rect2 = (main.hand_scroll as Control).get_global_rect()
			main.knowledge.open()
			await check_hand_stays(main, rest, 0.12, "fading in")
			main.knowledge.close()
			await check_hand_stays(main, rest, 0.12, "fading out")))


func test_bug_224_it_runs_in_from_the_play_areas_edge_under_the_sidebar() -> void:
	await with_reduce_motion(false, func():
		await with_tree(func(main: Node):
			main.knowledge.close()
			await wait_screen_transition()
			main.knowledge.open()
			var width: float = (main.knowledge as Control).size.x
			eq(main.knowledge.slide_offset(), width, "it travels its own width, from the play area's right edge")
			var sidebar := main.sidebar as Control
			check(sidebar.z_index > (main.knowledge as Control).z_index, "the sidebar draws over the sliding sheet")
			var grain := Looks.texture_of(sidebar.get_theme_stylebox("panel"))  # the board's opaque grain (341)
			check(grain != null and not grain.has_alpha(), "the sidebar is opaque, so the sheet passes under it")))


func test_bug_224_the_sheet_is_opaque() -> void:
	await with_tree(func(main: Node):
		var color: Color = main.knowledge.sheet_color()
		eq(color.a, 1.0, "an opaque fill")
		eq(color, Palette.BACKGROUND, "the board's colour"))


func test_over_a_territory_view_it_pushes_on_top_and_back_returns_to_the_view() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 5})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var home := home_uid(Game.engine)
	main.views[home].details_requested.emit(main.views[home])  # opens its territory view
	await wait_screen_transition()
	check(main.territory_view.is_open(), "precondition: the territory view")
	var home_name: String = Game.engine.zone("tableau").find(home).def.name
	press_key(main, KEY_T)
	await wait_screen_transition()
	if not has_knowledge(main):
		close_main(main)
		Game.engine = real
		return
	eq(main.knowledge.header.back_button.text, "◂ " + home_name, "over the view: the tab names the view, not the path (241)")
	eq(main.knowledge.header.title_text(), "Knowledge", "its title")
	press_key(main, KEY_ESCAPE)
	await wait_screen_transition()
	check(not main.knowledge.is_open(), "closed")
	check(main.territory_view.is_open(), "back to the territory view")
	close_main(main)
	Game.engine = real


# --- 241: the title bar ---

func test_knowledge_opens_under_a_tech_coloured_bar_with_its_context_at_the_right() -> void:
	await with_tree(func(main: Node):
		var header: Control = main.knowledge.header
		var box := header.get_theme_stylebox("panel") as StyleBoxFlat
		check(box != null and box.draw_center, "the header is a filled bar")
		if box != null:
			eq(box.bg_color, Palette.TECH, "filled with the tech colour")
		var texts: Array[String] = []
		for l in header.find_children("*", "Label", true, false):
			if (l as Label).is_visible_in_tree():
				texts.append((l as Label).text)
		eq(texts, ["Knowledge", "Turn 1 · %s" % Game.engine.era_name(Game.engine.era())] as Array[String],
			"the title, then the turn and era, in the bar"))


func test_over_a_territory_its_tab_goes_back_one_step_to_the_view() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 5})
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	var home := home_uid(Game.engine)
	main.views[home].details_requested.emit(main.views[home])
	await wait_screen_transition()
	press_key(main, KEY_T)
	await wait_screen_transition()
	if has_knowledge(main):
		var home_name: String = Game.engine.zone("tableau").find(home).def.name
		eq(main.knowledge.header.back_button.text, "◂ " + home_name, "the tab names the view below")
		main.knowledge.header.back_button.pressed.emit()
		await wait_screen_transition()
		check(not main.knowledge.is_open(), "Knowledge closes")
		check(main.territory_view.is_open(), "the territory view is still open")
	close_main(main)
	Game.engine = real


# --- 278: hovering an available tile marks its prerequisite and the techs it opens ---

## Whether tech_name's tile is marked as linked to the hovered one.
func linked(main: Node, tech_name: String) -> bool:
	return main.knowledge.linked(tech_name)


## Every tech's name in with_tree.
const TREE_NAMES := ["Pottery", "Writing", "Bronze Working", "Iron Working"]


func marked(main: Node) -> Array[String]:
	var out: Array[String] = []
	for n in TREE_NAMES:
		if linked(main, n):
			out.append(n)
	return out


func test_hovering_an_available_tile_marks_the_techs_it_opens() -> void:
	await with_tree(func(main: Node):
		tile(main, "Bronze Working").mouse_entered.emit()
		eq(marked(main), ["Iron Working"] as Array[String], "Bronze Working opens Iron Working"))


func test_hovering_an_available_tile_marks_its_prerequisite() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "bronze"))  # Iron Working is available now
		tile(main, "Iron Working").mouse_entered.emit()
		eq(marked(main), ["Bronze Working"] as Array[String], "Iron Working needs Bronze Working"))


func test_the_mark_is_a_look_of_its_own() -> void:
	await with_tree(func(main: Node):
		var before := tile(main, "Iron Working").get_theme_stylebox("normal") as StyleBoxFlat
		tile(main, "Bronze Working").mouse_entered.emit()
		var after := tile(main, "Iron Working").get_theme_stylebox("normal") as StyleBoxFlat
		check(before.border_color != after.border_color or before.bg_color != after.bg_color,
			"a linked tile's look differs from its unmarked look")
		eq(tile(main, "Iron Working").custom_minimum_size, tile_size(), "still a tile of one size"))


func test_the_mark_clears_when_the_mouse_leaves() -> void:
	await with_tree(func(main: Node):
		tile(main, "Bronze Working").mouse_entered.emit()
		tile(main, "Bronze Working").mouse_exited.emit()
		eq(marked(main), [] as Array[String], "nothing marked"))


func test_hovering_a_researched_or_locked_tile_marks_nothing() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))
		tile(main, "Pottery").mouse_entered.emit()
		eq(marked(main), [] as Array[String], "researched: nothing")
		tile(main, "Pottery").mouse_exited.emit()
		tile(main, "Iron Working").mouse_entered.emit()  # locked: Bronze Working isn't researched
		eq(marked(main), [] as Array[String], "locked: nothing"))


func test_hovering_a_later_era_tile_marks_nothing() -> void:
	await with_two_eras(func(main: Node):
		tile(main, "Optics").mouse_entered.emit()
		check(not linked(main, "Pottery") and not linked(main, "Writing") and not linked(main, "Optics"),
			"a tile under its vellum marks nothing"))


func test_a_rebuild_leaves_no_mark_behind() -> void:
	await with_tree(func(main: Node):
		tile(main, "Bronze Working").mouse_entered.emit()
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))  # rebuilds the screen, no mouse_exited
		eq(marked(main), [] as Array[String], "no stale mark"))


# --- 280: the hovered tile is highlighted (the cards' ink rule on a 4 px shadow, the buttons' lighter fill) ---

## Checks that tile t's hover look is the shared one: an ink border, a solid 4 px shadow, its resting fill lightened.
func check_hover(t: Button, what: String) -> void:
	var hover := t.get_theme_stylebox("hover") as StyleBoxFlat
	var normal := t.get_theme_stylebox("normal") as StyleBoxFlat
	eq(hover.border_color, Palette.TEXT, "%s: an ink border on hover" % what)
	eq(hover.shadow_color, Palette.SHADOW, "%s: the shadow colour" % what)
	eq(hover.shadow_size, 1, "%s: a solid shadow" % what)
	eq(hover.shadow_offset, GameTheme.SELECTED_SHADOW, "%s: a 4 px shadow" % what)
	eq(hover.bg_color, normal.bg_color.lightened(0.08), "%s: its fill lightened" % what)


func test_a_hovered_tile_of_any_state_reuses_the_cards_and_buttons_hover() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))
		for tech_name in ["Pottery", "Writing", "Iron Working"]:
			check_hover(tile(main, tech_name), tech_name))


func test_a_hovered_tile_of_a_later_era_reuses_the_hover() -> void:
	await with_two_eras(func(main: Node):
		check_hover(tile(main, "Optics"), "Optics"))


func test_a_hovered_linked_tile_shows_the_hover_not_the_link() -> void:
	await with_tree(func(main: Node):
		var unlinked := tile(main, "Iron Working").get_theme_stylebox("hover") as StyleBoxFlat
		var rest_fill := (tile(main, "Iron Working").get_theme_stylebox("normal") as StyleBoxFlat).bg_color
		tile(main, "Bronze Working").mouse_entered.emit()  # marks Iron Working
		check(linked(main, "Iron Working"), "Iron Working is linked")
		var hover := tile(main, "Iron Working").get_theme_stylebox("hover") as StyleBoxFlat
		eq(hover.border_color, Palette.TEXT, "an ink border, not the link's gold")
		eq(hover.bg_color, rest_fill.lightened(0.08), "its unlinked fill lightened")
		eq(hover.shadow_offset, unlinked.shadow_offset, "the same shadow as unlinked"))


func test_the_hover_keeps_the_tiles_border_and_margins() -> void:
	await with_tree(func(main: Node):
		Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery"))
		for tech_name in ["Pottery", "Writing", "Iron Working"]:
			var hover := tile(main, tech_name).get_theme_stylebox("hover") as StyleBoxFlat
			var normal := tile(main, tech_name).get_theme_stylebox("normal") as StyleBoxFlat
			eq(hover.border_width_left, normal.border_width_left, "%s: the same border width" % tech_name)
			eq(hover.get_minimum_size(), normal.get_minimum_size(), "%s: the same margins" % tech_name))


# --- Backlog 325: what the insight covers ---

func test_an_available_tile_the_insight_doesnt_cover_looks_short_until_it_does() -> void:
	await with_tree(func(main: Node):
		var e := Game.engine
		e.resources["insight"] = 4
		e.changed.emit()
		await wait_screen_transition()
		eq(tile(main, "Writing").theme_type_variation, &"TechTile", "Writing (3) is covered")
		var short := tile(main, "Bronze Working")
		eq(short.theme_type_variation, &"TechTileShort", "Bronze Working (5) is short")
		var box := short.get_theme_stylebox("normal") as StyleBoxFlat
		eq(box.bg_color if box != null else Color.TRANSPARENT, Palette.TILE, "short: still the sheet, not the locked well")
		for label in short.find_children("*", "Label", true, false):
			eq(label.get_theme_color("font_color"), Palette.TEXT_DISABLED, "short: muted text")
		var error := e.buy_tech_error(uid_of(e.zone("research_deck"), "bronze"))
		check(error != "" and short.tooltip_text.contains(error), "the tooltip says what's short: %s" % short.tooltip_text)
		e.resources["insight"] = 5
		e.changed.emit()
		await wait_screen_transition()
		eq(tile(main, "Bronze Working").theme_type_variation, &"TechTile", "5 insight covers it"))


# --- 326: a left click outside the screen closes it, and does nothing else ---

## The first card view in main's hand, or null.
func first_hand_card(main: Node) -> CardView:
	var views: Array[CardView] = main.views_in(main.hand)
	check(not views.is_empty(), "a card in hand")
	return views[0] if not views.is_empty() else null


## Waits past a hand card's details delay, so a click that would show its details has done so.
func wait_details_delay() -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(Anim.DETAILS_CLICK_DELAY + 0.1).timeout


func test_a_left_click_outside_the_screen_closes_it_and_does_nothing_else() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var card := first_hand_card(main)
		if card == null:
			return
		var in_hand: int = main.hand_view_count()
		check(not main.knowledge.get_global_rect().intersects(card.get_global_rect()), "the hand card is outside the sheet")
		click_control(main, card)
		check(not main.knowledge.is_open(), "a click on the hand closes the screen")
		await wait_details_delay()
		eq(main.details.shown(), {}, "the click opens no card's details")
		eq(main.hand_view_count(), in_hand, "the hand is unchanged")
		eq(card.state, CardView.State.REST, "the card is not picked up"))


func test_a_click_on_end_turn_closes_the_screen_and_ends_the_turn() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var turn := Game.engine.turn
		click_control(main, main.sidebar.end_turn)
		await wait_frames()
		check(not main.knowledge.is_open(), "the click closes the screen")
		eq(Game.engine.turn, turn + 1, "and ends the turn (348)"))


func test_e_on_the_screen_ends_the_turn_and_closes_it() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var turn := Game.engine.turn
		press_key(main, KEY_E)
		await wait_frames()
		eq(Game.engine.turn, turn + 1, "E ends the turn (348)")
		check(not main.knowledge.is_open(), "and the screen closes (290)"))


func test_a_click_inside_the_screen_leaves_it_open() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var insight: Label = null
		for label in main.knowledge.find_children("*", "Label", true, false):
			if label.text.begins_with("Insight"):
				insight = label
		check(insight != null, "the Insight line")
		if insight == null:
			return
		click_control(main, insight)
		check(main.knowledge.is_open(), "a click on the sheet's background leaves it open")
		click_control(main, main.knowledge.era_heading(0))
		check(main.knowledge.is_open(), "a click on an era's title leaves it open"))


func test_a_click_outside_a_tech_details_modal_closes_only_the_modal() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		click_control(main, tile(main, "Pottery"))
		eq(main.details.shown().get("name", ""), "Pottery", "Pottery's details")
		await wait_screen_transition()
		var card := first_hand_card(main)
		if card == null:
			return
		click_control(main, card)
		eq(main.details.shown(), {}, "the click closes the details")
		check(main.knowledge.is_open(), "the screen stays open"))


func test_a_right_click_outside_the_screen_leaves_it_open() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		var heading: Label = null
		for label in main.find_children("*", "Label", true, false):
			if label.text.begins_with("In Hand") and label.is_visible_in_tree():
				heading = label
		check(heading != null, "the In Hand heading")
		if heading == null:
			return
		click_control(main, heading, MOUSE_BUTTON_RIGHT)
		check(main.knowledge.is_open(), "a right click outside leaves it open"))


func test_a_click_on_the_hand_works_as_before_once_the_screen_is_closed_or_leaving() -> void:
	await with_tree(func(main: Node):
		await wait_screen_transition()
		press_key(main, KEY_ESCAPE)  # leaving: closed as soon as it starts to leave
		var card := first_hand_card(main)
		if card == null:
			return
		click_control(main, card)
		await wait_details_delay()
		eq(main.details.shown().get("name", ""), Game.engine.def_details(card.card_id).get("name", "?"), "the click shows the card's details"))
