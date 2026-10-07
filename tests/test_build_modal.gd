extends "res://tests/lib/tech_case.gd"
## Building from a territory's view (297) in the real main scene: Build… (B) and the "+ Build" free-slot outlines open
## main.build_modal ("Build on <territory>"): a selectable list of the build menu under Buildings and Units headings,
## refused rows dimmed with their reason, and a sheet with the selected entry's card, its build_preview lines and one
## key (Build / Recruit). Hooks on BuildModal: list (SelectList), headings(), row_text(id), row_reason(id),
## row_dimmed(id), shown_card(), preview_lines(), refusal_text(), build_button, cancel_button; on TerritoryView:
## build_button, slot_button(i). 343: laid out as a ledger sheet (Modal.LEDGER_*), the card hand size and still,
## long rows wrapping in the list column; hook card_view(). 347: a row refused for want of a worker, and such a hand
## card, carry build_error_detail / play_error_detail as their tooltip. 354: the selected entry's flavor under its card,
## in the Flavor look; hook flavor_text().

const WARRIORS := {"id": "warriors", "name": "Warriors", "type": "unit", "cost": {"food": 2}, "strength": 2,
	"tags": ["military"]}
const MENU := {"farm": {}, "well": {}, "granary": {}, "warriors": {}}


## A game with build_menu menu (Farm, Well, Granary, Warriors), Band ruling (2 actions), Homeland at 3 pop and food
## food; overrides last.
func modal_engine(food := 5, menu := MENU, overrides := {}) -> GameEngine:
	var o := {"build_menu": menu, "population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"starting": {"resources": {"food": food, "wealth": 10, "insight": 0}, "tableau": ["capital"],
			"territory": "homeland", "government": "band"}}
	o.merge(overrides, true)
	return tech_engine(["pottery"], {"scout": 10}, o, [WARRIORS, LONG_HALL, KILN, OVEN, LORE_HALL] + TEST_GOVS)


## Sets the food on hand to food (the Capital's upkeep has already paid turn 1's) and lets the board show it.
func set_food(food: int) -> void:
	Game.engine.resources.food = food
	Game.engine.changed.emit()
	await wait_frames()


## Opens the home's territory view; returns the home's uid.
func open_home(main: Node) -> int:
	var home := home_uid(Game.engine)
	main.territory_view.open(home)
	await wait_frames()
	return home


## Opens the home's view, then the Build modal from Build…; returns the modal.
func open_build(main: Node) -> Object:
	await open_home(main)
	(main.territory_view.build_button as Button).pressed.emit()
	await wait_frames()
	return main.build_modal


# --- AC1: the modal and its list ---

func test_build_opens_a_modal_listing_the_build_menu_by_kind() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var modal: Object = await open_build(main)
		var home := home_uid(e)
		check(modal.is_open() and main.modals.top() == modal, "the Build modal is on top")
		eq(modal.title, "Build on Homeland", "its title")
		eq(modal.headings(), ["Buildings", "Units"], "headings")
		eq(modal.list.ids(), ["farm", "well", "granary", "warriors"], "rows in build_menu order")
		check(modal.row_text("farm").contains("Farm") and modal.row_text("farm").contains("2 food"), "name and cost: %s"
			% modal.row_text("farm"))
		eq([modal.row_dimmed("farm"), modal.row_reason("farm")], [false, ""], "Farm can be built")
		eq([modal.row_dimmed("well"), modal.row_reason("well")], [true, e.build_error("well", home)],
			"Well is dimmed with its reason"))


func test_b_opens_the_build_modal_from_the_territory_view() -> void:
	await with_main(modal_engine(), func(main: Node):
		await open_home(main)
		main.get_viewport().gui_release_focus()
		press_key(main, KEY_B)
		await wait_frames()
		check(main.build_modal.is_open(), "B opens it")
		check((main.territory_view.build_button as Button).tooltip_text.contains("B"), "Build… names B in its tooltip"))


# --- AC2: selection and the sheet ---

func test_the_first_buildable_row_is_selected_and_the_sheet_previews_it() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		var modal: Object = await open_build(main)
		eq(modal.list.selected, "farm", "Farm, the first buildable row, is selected")
		check(modal.list.row("farm").button_pressed, "drawn as the selected row")
		eq(modal.shown_card(), "farm", "the sheet shows Farm's card")
		var lines: Array = modal.preview_lines()
		var preview := e.build_preview("farm", home)
		check(lines.has("If built on Homeland"), "the preview's heading: %s" % [lines])
		for line in preview.lines:
			if line[0] == "free_slots":
				check(lines.has("Free slots %d → %d" % [line[1], line[2]]), "a free-slots line: %s" % [lines])
			if line[0] == GameEngine.FOOD:
				check(lines.has("Food at next upkeep %+d → %+d" % [line[1], line[2]]), "a food line: %s" % [lines])
		check(lines.any(func(l): return l.contains("2 food")), "the cost: %s" % [lines]))


func test_a_refused_first_row_is_skipped_and_none_buildable_selects_the_first() -> void:
	await with_main(modal_engine(), func(main: Node):
		await set_food(1)
		var modal: Object = await open_build(main)
		eq(modal.list.selected, "granary", "Farm (2 food) and Well (no fresh water) refused: Granary"))
	await with_main(modal_engine(), func(main: Node):
		await set_food(0)
		var modal: Object = await open_build(main)
		eq(modal.list.selected, "farm", "nothing buildable: the first row"))


func test_arrows_and_clicks_select_another_row() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		press_key(main, KEY_DOWN)
		await wait_frames()
		eq(modal.list.selected, "well", "Down selects the next row")
		eq(modal.shown_card(), "well", "the sheet follows")
		press_key(main, KEY_UP)
		await wait_frames()
		eq(modal.list.selected, "farm", "Up goes back")
		(modal.list.row("warriors") as Button).pressed.emit()
		await wait_frames()
		eq(modal.list.selected, "warriors", "a click selects"))


# --- AC3: the key ---

func test_build_builds_the_selected_entry_and_closes() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		await set_food(5)
		var modal: Object = await open_build(main)
		eq(modal.build_button.text, "Build Farm", "the key")
		(modal.build_button as Button).pressed.emit()
		await wait_frames()
		check(not modal.is_open(), "the modal closed")
		check(main.territory_view.is_open(), "the territory view stays open")
		var farms := e.zone("tableau").cards.filter(func(c): return c.def.id == "farm" and c.territory_uid == home)
		eq(farms.size(), 1, "a Farm on Homeland")
		if not farms.is_empty():
			check(main.territory_view.card_uids().has(farms[0].uid), "the view shows it")
		eq(e.resources.food, 3, "5 - 2 food")
		eq(main.counter_text(GameEngine.FOOD).get_slice(" ", 0), "3", "the top bar's food"))


func test_enter_builds_and_a_unit_reads_recruit() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var modal: Object = await open_build(main)
		(modal.list.row("warriors") as Button).pressed.emit()
		await wait_frames()
		eq(modal.build_button.text, "Recruit Warriors", "a unit's key")
		main.get_viewport().gui_release_focus()
		press_key(main, KEY_ENTER)
		await wait_frames()
		eq(card_ids(e.zone("tableau")).count("warriors"), 1, "Enter recruited Warriors")
		check(not modal.is_open(), "closed"))


func test_a_refused_row_shows_its_reason_and_disables_the_key() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var modal: Object = await open_build(main)
		(modal.list.row("well") as Button).pressed.emit()
		await wait_frames()
		eq(modal.shown_card(), "well", "Well's card")
		eq(modal.refusal_text(), e.build_error("well", home_uid(e)), "its refusal")
		eq(modal.preview_lines(), [], "no preview")
		check(modal.build_button.disabled, "the key is disabled"))


func test_a_row_refused_for_want_of_a_worker_explains_in_its_tooltip() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var home := home_uid(e)
		build_on(e, home, ["farm", "farm", "farm"])
		var modal: Object = await open_build(main)
		eq(modal.row_reason("granary"), "No free worker.", "the short reason (347)")
		var detail: String = e.build_error_detail("granary", home)
		check(detail != "", "the engine explains it")
		eq((modal.list.row("granary") as Button).tooltip_text, detail, "the row's tooltip is the detail"))


func test_a_hand_card_with_no_free_worker_explains_in_its_tooltip() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["farm", "farm", "farm"])
		var farm := put_in_hand(e, "farm")
		e.changed.emit()
		await wait_frames()
		eq(e.play_error(farm), "No free worker.", "refused")
		var tip: String = (main.views[farm] as CardView).tooltip_text
		check(tip.contains("No free worker.") and tip.contains(e.play_error_detail(farm)), "reason and detail: %s" % tip))


# --- AC4: "+ Build" on free slots ---

func test_a_free_slot_reads_build_and_opens_the_modal() -> void:
	await with_main(modal_engine(), func(main: Node):
		await open_home(main)
		var slot: Button = main.territory_view.slot_button(0)
		check(slot != null, "a free slot is a button")
		if slot == null:
			return
		eq(slot.text, "+ Build", "it reads + Build")
		slot.pressed.emit()
		await wait_frames()
		check(main.build_modal.is_open(), "it opens the Build modal")
		eq(main.build_modal.title, "Build on Homeland", "on that territory"))


# --- AC5: closing, blocked, empty ---

func test_esc_and_cancel_close_without_building() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		var before := card_ids(e.zone("tableau"))
		var modal: Object = await open_build(main)
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check(not modal.is_open(), "Esc closes it")
		(main.territory_view.build_button as Button).pressed.emit()
		await wait_frames()
		(modal.cancel_button as Button).pressed.emit()
		await wait_frames()
		check(not modal.is_open(), "Cancel closes it")
		eq(card_ids(e.zone("tableau")), before, "nothing built"))


func test_build_is_disabled_with_the_reason_while_a_decision_is_owed() -> void:
	await with_main(modal_engine(5, MENU, {"territory_deck": {"hills": 1, "grassland": 1}}), func(main: Node):
		var e := Game.engine
		await open_home(main)
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer: a territory choice is owed")
		e.changed.emit()
		await wait_frames()
		var key: Button = main.territory_view.build_button
		check(key.disabled, "Build… is disabled")
		eq(key.tooltip_text, e.call("build_menu_error"), "with the reason")
		var slot: Button = main.territory_view.slot_button(0)
		check(slot != null and slot.disabled, "the + Build slots too")
		if slot != null:
			eq(slot.tooltip_text, e.call("build_menu_error"), "with the reason"))


func test_an_empty_build_menu_hides_build_and_leaves_plain_outlines() -> void:
	await with_main(modal_engine(5, {}), func(main: Node):
		await open_home(main)
		check(not (main.territory_view.build_button as Button).visible, "no Build…")
		var slot: Button = main.territory_view.slot_button(0)
		check(slot == null or not slot.visible or slot.text != "+ Build", "outlines don't read + Build"))


# --- AC6: the Buy screen and Disband ---

func test_the_buy_screen_sells_no_buildings_or_units_on_the_real_data() -> void:
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var views: Array = main.supply.views()
	check(not views.is_empty(), "the supply is open")
	for v in views:
		eq(Game.engine.card_db[v.card_id].type, CardDef.ACTION, "%s is an action card" % v.card_id)
	close_main(main)


func test_a_recruited_units_disband_says_dismiss() -> void:
	await with_main(modal_engine(), func(main: Node):
		var e := Game.engine
		check(e.build("warriors", home_uid(e)), "recruit Warriors")
		e.changed.emit()
		await wait_frames()
		var warriors := uid_of(e.zone("tableau"), "warriors")
		main.details.open_card(e.zone("tableau").find(warriors))
		await wait_frames()
		var disband: Button = main.details.unit_buttons()[1]
		eq(disband.tooltip_text, "Dismiss it; its worker is freed.", "Disband's text"))


# --- Backlog 343: the Build modal as a ledger sheet (344: Modal.LEDGER_*) ---
# Hooks: card_view() (the CardView on the sheet, or null); the list's scroll area is list's parent.

## A building whose row is wider than the list column.
const LONG_HALL := {"id": "long_hall", "name": "The Great Hall of the Assembled Elders of the Realm", "type": "building",
	"cost": {"food": 2}}


## The modal's visible Refusal label, or null.
func refusal_label(modal: Object) -> Label:
	for l in (modal as Node).find_children("*", "Label", true, false):
		if (l as Label).theme_type_variation == &"Refusal" and (l as Label).is_visible_in_tree():
			return l
	return null


## The list's scroll area.
func list_column(modal: Object) -> ScrollContainer:
	return (modal.list as Control).get_parent() as ScrollContainer


func test_the_card_on_the_sheet_is_hand_size_for_every_row() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		for row in ["farm", "granary"]:
			(modal.list.row(row) as Button).pressed.emit()
			await wait_frames()
			var card: CardView = modal.card_view()
			eq(card.size, CardView.HAND_SIZE, "%s's card is hand size" % row)
			eq(card.slot.custom_minimum_size, CardView.HAND_SIZE, "%s's slot is hand size" % row))


func test_the_list_column_is_the_ledgers() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		eq(list_column(modal).custom_minimum_size, Vector2(Modal.LEDGER_LIST_WIDTH, Modal.LEDGER_LIST_HEIGHT),
			"384 × 480"))


func test_a_refusal_wraps_at_the_cards_width() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("well") as Button).pressed.emit()
		await wait_frames()
		var label := refusal_label(modal)
		check(label != null, "a refusal shows")
		if label != null:
			eq(label.custom_minimum_size.x, float(Modal.LEDGER_DETAIL_WIDTH), "wraps at 264"))


func test_the_modal_is_a_680_px_ledger_inside_the_window() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	window.size = Vector2i(1920, 1080)
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(30)
		var screen := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
		var sheet: Rect2 = (modal.panel as Control).get_global_rect()
		check(screen.encloses(sheet), "the sheet %s inside %s" % [sheet, screen])
		eq((modal.body as Control).size.x, float(Modal.LEDGER_WIDTH), "the body is the ledger's 680 px")
		eq(list_column(modal).size.x, float(Modal.LEDGER_LIST_WIDTH), "the list column, 384")
		var card: CardView = modal.card_view()
		eq(card.get_global_rect().position.x - list_column(modal).get_global_rect().end.x, float(Modal.LEDGER_GAP),
			"32 px between the list and the card"))
	window.size = before


func test_a_long_row_wraps_inside_the_list_column() -> void:
	await with_main(modal_engine(5, MENU.merged({"long_hall": {}})), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(5)
		check(modal.list.row("long_hall") != null, "the long row is listed")
		eq(list_column(modal).size.x, float(Modal.LEDGER_LIST_WIDTH), "the column stays 384 wide"))


func test_the_card_on_the_sheet_ignores_the_mouse() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		var card: CardView = modal.card_view()
		eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE, "display only"))


# --- 354: the selected entry's flavor on the sheet ---

const KILN := {"id": "kiln", "name": "Kiln", "type": "building", "cost": {"food": 1}, "flavor": "Mud brick, baked hard."}
const OVEN := {"id": "oven", "name": "Oven", "type": "building", "cost": {"food": 9},
	"flavor": "Bread for the whole street, when there is grain."}
## Near the longest flavor real data may have (147 of 150, 353) and the most preview lines: slots, three resources
## and housing.
const LORE_HALL := {"id": "lore_hall", "name": "Lore Hall", "type": "building", "cost": {"food": 1}, "housing": 1,
	"flavor": "Shelves of tablets and rolls hold the law, the stars and the price of barley, " +
		"and somewhere among them is an answer nobody has ever thought to ask.",
	"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"},
		{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"},
		{"op": "gain", "resource": "insight", "amount": 1, "trigger": "upkeep"}]}
const FLAVOR_MENU := {"kiln": {}, "oven": {}, "lore_hall": {}, "warriors": {}}


## The sheet's labels in the Flavor look, visible.
func flavor_labels(modal: Object) -> Array[Label]:
	var out: Array[Label] = []
	for l in (modal as Node).find_children("*", "Label", true, false):
		if (l as Label).theme_type_variation == &"Flavor" and (l as Label).is_visible_in_tree():
			out.append(l)
	return out


## The index among modal's labels (tree order) of the first whose text is text, or -1.
func label_index(modal: Object, text: String) -> int:
	var labels := (modal as Node).find_children("*", "Label", true, false)
	for i in labels.size():
		if (labels[i] as Label).text == text:
			return i
	return -1


func test_the_selected_buildings_flavor_shows_under_its_card() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		eq(modal.shown_card(), "kiln", "the Kiln is selected")
		eq(modal.flavor_text(), KILN.flavor, "its flavor")
		var labels := flavor_labels(modal)
		eq(labels.size(), 1, "one flavor line")
		if labels.size() == 1:
			eq(labels[0].text, KILN.flavor, "in the Flavor look")
			eq(labels[0].custom_minimum_size.x, float(Modal.LEDGER_DETAIL_WIDTH), "wrapping at the card's 264")
			check(labels[0].autowrap_mode != TextServer.AUTOWRAP_OFF, "it wraps")
			check(label_index(modal, KILN.flavor) < label_index(modal, "If built on Homeland"),
				"above the preview's heading")
		check(not modal.preview_lines().has(KILN.flavor), "the preview's lines stay the preview's"))


func test_the_flavor_follows_the_selection() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("lore_hall") as Button).pressed.emit()
		await wait_frames()
		eq(modal.flavor_text(), LORE_HALL.flavor, "a click shows the Lore Hall's")
		press_key(main, KEY_UP)
		await wait_frames()
		eq(modal.list.selected, "oven", "Up selects the Oven")
		eq(modal.flavor_text(), OVEN.flavor, "and its flavor")
		eq(flavor_labels(modal).map(func(l): return l.text), [OVEN.flavor], "only the Oven's"))


func test_a_refused_rows_flavor_shows_above_its_reason() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var e := Game.engine
		var modal: Object = await open_build(main)
		(modal.list.row("oven") as Button).pressed.emit()
		await wait_frames()
		var reason := e.build_error("oven", home_uid(e))
		check(reason != "", "the Oven (9 food) is refused")
		eq(modal.refusal_text(), reason, "its reason shows")
		eq(modal.flavor_text(), OVEN.flavor, "and its flavor")
		check(label_index(modal, OVEN.flavor) != -1 and label_index(modal, OVEN.flavor) < label_index(modal, reason),
			"the flavor above the reason"))


func test_a_card_without_flavor_shows_no_flavor_line() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("warriors") as Button).pressed.emit()
		await wait_frames()
		eq(modal.shown_card(), "warriors", "the Warriors' card")
		eq(modal.flavor_text(), "", "a unit has no flavor")
		eq(flavor_labels(modal).size(), 0, "no flavor line, and no empty one"))


func test_the_longest_flavor_keeps_the_modal_inside_the_window() -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	var before := window.size
	window.size = Vector2i(1920, 1080)
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("lore_hall") as Button).pressed.emit()
		await wait_frames(30)
		eq(modal.flavor_text(), LORE_HALL.flavor, "the Lore Hall's 147-character flavor")
		check(modal.preview_lines().size() >= 6, "with its preview: %s" % [modal.preview_lines()])
		var screen := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
		var sheet: Rect2 = (modal.panel as Control).get_global_rect()
		check(screen.encloses(sheet), "the sheet %s inside %s" % [sheet, screen]))
	window.size = before


# --- 356: the list glides, the sheet breathes ---

## A game like modal_engine's whose build menu also lists HALLS halls: more rows than the list column shows.
const HALLS := 14


func tall_engine() -> GameEngine:
	var halls := []
	var menu := MENU.duplicate()
	for i in HALLS:
		halls.append({"id": "hall_%d" % i, "name": "Hall %d" % i, "type": "building", "cost": {"food": 1}})
		menu["hall_%d" % i] = {}
	var o := {"build_menu": menu, "population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"starting": {"resources": {"food": 5, "wealth": 10, "insight": 0}, "tableau": ["capital"],
			"territory": "homeland", "government": "band"}}
	return tech_engine(["pottery"], {"scout": 10}, o, [WARRIORS] + halls + TEST_GOVS)


## The visible Label on modal reading text (a list heading as written, or a line on the sheet), or null.
func label_reading(modal: Object, text: String) -> Label:
	for l in (modal as Node).find_children("*", "Label", true, false):
		if (l as Label).text == text and (l as Label).is_visible_in_tree():
			return l
	return null


func test_the_build_list_scrolls_smoothly() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		check(list_column(modal) is SmoothScroll, "the list sits in a SmoothScroll"))


func test_down_scrolls_the_selected_row_into_view() -> void:
	await with_reduce_motion(false, func():
		await with_main(tall_engine(), func(main: Node):
			var modal: Object = await open_build(main)
			var last: String = modal.list.ids()[-1]
			var column := list_column(modal)
			check(not column.get_global_rect().encloses((modal.list.row(last) as Control).get_global_rect()),
				"the last row starts below the column")
			for i in modal.list.ids().size():
				press_key(main, KEY_DOWN)
				await wait_frames(1)
			eq(modal.list.selected, last, "Down reached the last row")
			await wait_frames(120)
			var row_rect := (modal.list.row(last) as Control).get_global_rect()
			check(column.get_global_rect().encloses(row_rect), "row %s inside the column %s" % [row_rect,
				column.get_global_rect()])))


func test_a_heading_after_rows_has_room_above_it() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(5)
		var buildings := label_reading(modal, "Buildings")
		var units := label_reading(modal, "Units")
		var granary := modal.list.row("granary") as Control
		var gap := units.get_global_rect().position.y - granary.get_global_rect().end.y
		check(gap >= Tokens.SPACE_5, "at least 24 px between the last building and Units: %s" % gap)
		var top := buildings.get_global_rect().position.y - (modal.list as Control).get_global_rect().position.y
		check(top <= Tokens.SPACE_2, "Buildings still opens the well: %s px down" % top))


func test_the_card_has_room_under_it() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(5)
		eq(modal.shown_card(), "farm", "Farm selected")
		var heading := label_reading(modal, "If built on Homeland")
		var card: CardView = modal.card_view()
		eq(heading.get_global_rect().position.y - card.get_global_rect().end.y, float(Tokens.SPACE_5),
			"24 px between the card and the lines under it"))


## The flavor, when the entry has one, is the first line under the card: SPACE_5 below it (356; 358 kept it there).
func test_the_flavor_has_room_under_the_card() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(5)
		eq(modal.shown_card(), "kiln", "the Kiln selected")
		var flavor := label_reading(modal, KILN.flavor)
		var card: CardView = modal.card_view()
		check(not card.is_ancestor_of(flavor), "under the card, not on it")
		eq(flavor.get_global_rect().position.y - card.get_global_rect().end.y, float(Tokens.SPACE_5),
			"24 px between the card and its flavor"))


# --- 360: room under the flavor ---

func test_the_preview_has_room_under_the_flavor() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		await wait_frames(5)
		eq(modal.shown_card(), "kiln", "the Kiln selected")
		var flavor := label_reading(modal, KILN.flavor)
		var heading := label_reading(modal, "If built on Homeland")
		eq(heading.get_global_rect().position.y - flavor.get_global_rect().end.y, float(Tokens.SPACE_5),
			"24 px between the flavor and the preview"))


func test_a_refusal_has_room_under_the_flavor() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var e := Game.engine
		var modal: Object = await open_build(main)
		(modal.list.row("oven") as Button).pressed.emit()
		await wait_frames(5)
		var flavor := label_reading(modal, OVEN.flavor)
		var reason := label_reading(modal, e.build_error("oven", home_uid(e)))
		eq(reason.get_global_rect().position.y - flavor.get_global_rect().end.y, float(Tokens.SPACE_5),
			"24 px between the flavor and the reason"))


func test_a_card_without_flavor_has_no_gap_for_one() -> void:
	await with_main(modal_engine(5, FLAVOR_MENU), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("warriors") as Button).pressed.emit()
		await wait_frames(5)
		var heading := label_reading(modal, "If built on Homeland")
		var card: CardView = modal.card_view()
		eq(heading.get_global_rect().position.y - card.get_global_rect().end.y, float(Tokens.SPACE_5),
			"the preview 24 px under the card, as without flavor before"))


func test_the_card_on_the_sheet_has_its_art_plate() -> void:
	await with_main(modal_engine(), func(main: Node):
		var modal: Object = await open_build(main)
		(modal.list.row("farm") as Button).pressed.emit()
		await wait_frames()
		check(art_plate(modal.card_view()) != null, "the Build modal's card has a plate (381)"))
