extends "res://tests/lib/test_case.gd"
## Upgrades on screen (302) in the real main scene: the territory view draws a building's upgrades as ribbons at the
## foot of its card (a fallen-back one hatched with its reason), a "+ Upgrade" chip on a building that could take one
## opens the Build modal on it, the modal lists upgrades under their own heading, and an upgrade's card face names its
## base and tier. Hooks on CardView: ribbons() ({uid, name, rules, reason, hatched} per ribbon), upgrade_chip; on
## BuildModal: upgrade_row_id(card_id, base) (static), face_text(). 354: an upgrade row's flavor is its own.

const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
	{"id": "metropolis", "name": "Metropolis", "pop": 13, "slots": 3},
]
const PLOUGH := {"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "vp": 1,
	"upgrade_of": "farm", "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
const DITCH := {"id": "ditch", "name": "Ditch", "type": "building", "cost": {"food": 1}, "upgrade_of": "farm",
	"housing": 1, "effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep", "keyword": "flood_plain"}]}
const CHAPEL := {"id": "chapel", "name": "Chapel", "type": "building", "cost": {"food": 1},
	"flavor": "A bench, a lamp, a quiet hour."}
const SANCTUM := {"id": "sanctum", "name": "Sanctum", "type": "building", "cost": {"food": 1}, "upgrade_of": "chapel",
	"tier": "village", "modifiers": {"hand_size": 1}, "flavor": "The inner room, where only the keepers go."}
const CATHEDRAL := {"id": "cathedral", "name": "Cathedral", "type": "building", "cost": {"food": 1},
	"upgrade_of": "sanctum", "tier": "town", "vp": 2}
const FORUM := {"id": "forum", "name": "Forum", "type": "building", "cost": {"food": 1}, "tier": "town", "vp": 1,
	"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
const CARDS := [PLOUGH, DITCH, CHAPEL, SANCTUM, CATHEDRAL, FORUM]
const MENU := {"farm": {}, "chapel": {}, "forum": {}, "plough": {}, "ditch": {}, "sanctum": {}, "cathedral": {}}


## A game with the fixture tiers, build_menu MENU, no government (unlimited actions) and plenty of food; Hills and
## Grassland in the territory deck for an explore. with_main starts it afresh: set the pop with home_at inside the body.
func ribbon_engine(overrides := {}) -> GameEngine:
	var o := {"build_menu": MENU, "population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0, "tiers": TIERS},
		"starting": {"resources": {"food": 50}, "tableau": ["capital"], "territory": "homeland"},
		"territory_deck": {"hills": 1, "grassland": 1}}
	o.merge(overrides, true)
	return make_engine({"scout": 10}, o, 1, CARDS)


## Game.engine with Homeland at pop and plenty of food: the game the body plays.
func home_at(pop: int) -> GameEngine:
	var e := Game.engine
	set_home_pop(e, pop)
	e.resources.food = 50
	return e


## A new copy of building id straight on Homeland, unpaid: its uid.
func put_home(e: GameEngine, id: String) -> int:
	build_on(e, home_uid(e), [id])
	return e.zone("tableau").cards.back().uid


## Builds id on target, failing the test if it refuses: the new card's uid.
func build_it(e: GameEngine, id: String, target: int) -> int:
	check(e.build(id, target), "build %s: %s" % [id, e.build_error(id, target)])
	return e.zone("tableau").cards.back().uid


## Lets the board show the engine's state, then opens Homeland's view.
func open_home(main: Node) -> void:
	Game.engine.changed.emit()
	await wait_frames()
	main.territory_view.open(home_uid(Game.engine))
	await wait_frames()


## Redraws the board after a change made straight on the engine.
func refresh(main: Node) -> void:
	Game.engine.changed.emit()
	await wait_frames()


## Card uid's view.
func view_of(main: Node, uid: int) -> CardView:
	return main.views[uid]


## The Build modal's list id for upgrade card_id on base.
func row_id(_main: Node, card_id: String, base: int) -> String:
	return BuildModal.upgrade_row_id(card_id, base)


func ribbon_names(main: Node, base: int) -> Array:
	return view_of(main, base).ribbons().map(func(r): return r.name)


# --- AC1: ribbons ---

func test_upgrades_show_as_ribbons_on_their_base_not_as_cards() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		var plough := build_it(e, "plough", farm)
		var ditch := build_it(e, "ditch", farm)
		var chapel := put_home(e, "chapel")
		var sanctum := build_it(e, "sanctum", chapel)
		var cathedral := build_it(e, "cathedral", sanctum)
		await open_home(main)
		var shown: Array[int] = main.territory_view.card_uids()
		for uid in [plough, ditch, sanctum, cathedral]:
			check(not shown.has(uid) and not main.views.has(uid), "no card for upgrade %d" % uid)
		check(shown.has(farm) and shown.has(chapel), "the bases have cards")
		eq(ribbon_names(main, farm), ["Plough", "Ditch"], "the Farm's ribbons, in upgrades_on order")
		eq(view_of(main, farm).ribbons().map(func(r): return r.rules),
			[e.upgrade_rules_text("plough"), e.upgrade_rules_text("ditch")], "each reads its rules")
		eq(ribbon_names(main, chapel), ["Sanctum", "Cathedral"], "a chain on its first base")
		eq(main.territory_view.free_slot_count(), e.free_slots(home_uid(e)), "the outlines count the free slots"))


func test_a_building_without_upgrades_has_no_ribbons() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var farm := put_home(home_at(8), "farm")
		await open_home(main)
		eq(view_of(main, farm).ribbons(), [], "no ribbons"))


# --- 345: one height ---

## The heights of the view's cards (its row and units row) and free-slot outlines.
func view_heights(main: Node) -> Array[float]:
	var out: Array[float] = []
	for row in [main.territory_view.row, main.territory_view.units_row]:
		for v: CardView in main.views_in(row):
			out.append(v.size.y)
	for outline: Panel in main.territory_view.outlines():
		out.append(outline.size.y)
	return out


func test_the_view_s_cards_and_outlines_share_the_tallest_height() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		build_it(e, "plough", farm)
		build_it(e, "ditch", farm)
		put_home(e, "chapel")
		await open_home(main)
		check(main.territory_view.free_slot_count() > 0, "a free slot to compare")
		var tall := view_of(main, farm).size.y
		check(tall > CardView.TABLEAU_SIZE.y, "two ribbons make the Farm taller than the nominal card")
		for h in view_heights(main):
			eq(h, tall, "every card and outline is the tallest's height"))


func test_the_view_s_cards_shrink_back_when_the_tallest_goes() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		build_it(e, "plough", farm)
		build_it(e, "ditch", farm)
		await open_home(main)
		var tall := view_of(main, farm).size.y
		for c in e.zone("tableau").cards.duplicate():
			if c.def.id in ["plough", "ditch"]:
				e.zone("tableau").remove(c)
		await refresh(main)
		var tallest := CardView.TABLEAU_SIZE.y
		for v: CardView in main.views_in(main.territory_view.row):
			tallest = maxf(tallest, v.get_combined_minimum_size().y)
		check(tallest < tall, "the ribbons were the tallest")
		for h in view_heights(main):
			eq(h, tallest, "back to the new tallest's height"))


# --- AC2: fallen back ---

func test_a_fallen_back_ribbon_is_hatched_with_its_reason_until_it_works_again() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var chapel := put_home(e, "chapel")
		build_it(e, "cathedral", build_it(e, "sanctum", chapel))
		await open_home(main)
		var view := view_of(main, chapel)
		eq(view.ribbons().map(func(r): return [r.hatched, r.reason]), [[false, ""], [false, ""]], "both work at a Town")
		set_home_pop(e, 3)
		await refresh(main)
		eq(view.ribbons().map(func(r): return [r.hatched, r.reason]),
			[[true, "Needs a Village."], [true, "Its Sanctum has fallen back."]], "hatched at a Hamlet, with reasons")
		set_home_pop(e, 8)
		await refresh(main)
		eq(view.ribbons().map(func(r): return [r.hatched, r.reason]), [[false, ""], [false, ""]], "plain again"))


# --- AC3: the chip ---

func test_a_building_that_could_take_an_upgrade_shows_the_chip() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(3)
		var farm := put_home(e, "farm")
		var chapel := put_home(e, "chapel")
		await open_home(main)
		check(chip_shown(main, farm), "the Farm can take a Plough or a Ditch")
		if view_of(main, farm).upgrade_chip != null:
			eq(view_of(main, farm).upgrade_chip.text, "+ Upgrade", "the chip's text")
		check(not chip_shown(main, chapel), "a Sanctum needs a Village: no chip on the Chapel")
		build_it(e, "plough", farm)
		build_it(e, "ditch", farm)
		await refresh(main)
		check(not chip_shown(main, farm), "the Farm carries both")
		set_home_pop(e, 4)
		await refresh(main)
		check(chip_shown(main, chapel), "at a Village the Chapel takes a Sanctum"))


## Whether card uid's view shows its "+ Upgrade" chip.
func chip_shown(main: Node, uid: int) -> bool:
	var chip: Button = view_of(main, uid).upgrade_chip
	return chip != null and chip.is_visible_in_tree()


func test_the_chip_opens_the_build_modal_on_the_first_upgrade_it_could_take() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		build_it(e, "plough", farm)
		await open_home(main)
		(view_of(main, farm).upgrade_chip as Button).pressed.emit()
		await wait_frames()
		var modal: Object = main.build_modal
		check(modal.is_open(), "the Build modal opens")
		eq(modal.title, "Build on Homeland", "on the territory")
		eq(modal.list.selected, row_id(main, "ditch", farm), "the Ditch on this Farm selected")
		eq(modal.shown_card(), "ditch", "and shown"))


func test_the_chip_on_a_chain_selects_its_next_link() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var chapel := put_home(e, "chapel")
		var sanctum := build_it(e, "sanctum", chapel)
		await open_home(main)
		(view_of(main, chapel).upgrade_chip as Button).pressed.emit()
		await wait_frames()
		eq(main.build_modal.list.selected, row_id(main, "cathedral", sanctum),
			"the Cathedral on the Sanctum, from the Chapel's card"))


func test_the_chip_is_disabled_while_a_decision_is_owed() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		await open_home(main)
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer: a territory choice is owed")
		await wait_frames()
		var chip: Button = view_of(main, farm).upgrade_chip
		check(chip != null and chip.disabled, "the chip is disabled")
		if chip != null:
			eq(chip.tooltip_text, e.build_menu_error(), "with the reason"))


# --- AC4: the Build modal ---

## Opens Homeland's view, then the Build modal from Build…; returns the modal.
func open_build(main: Node) -> Object:
	await open_home(main)
	(main.territory_view.build_button as Button).pressed.emit()
	await wait_frames()
	return main.build_modal


## Selects list row id in modal, as a click does.
func choose(modal: Object, id: String) -> void:
	modal.list.select(id)
	modal.list.chosen.emit(id)
	await wait_frames()


func test_the_build_modal_lists_upgrades_under_their_own_heading() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(3)
		var farm := put_home(e, "farm")
		var chapel := put_home(e, "chapel")
		var modal: Object = await open_build(main)
		eq(modal.headings(), ["Buildings", "Upgrades"], "headings")
		var plough := row_id(main, "plough", farm)
		var sanctum := row_id(main, "sanctum", chapel)
		eq(modal.list.ids(), ["farm", "chapel", "forum", plough, row_id(main, "ditch", farm), sanctum],
			"the buildings, then each upgrade on each building here")
		var text: String = modal.row_text(plough)
		check(text.contains("Plough") and text.contains("on Farm") and text.contains("1 food"),
			"name, base and cost: %s" % text)
		eq([modal.row_dimmed(plough), modal.row_reason(plough)], [false, ""], "the Plough can be built")
		eq([modal.row_dimmed(sanctum), modal.row_reason(sanctum)],
			[true, "Sanctum needs a Village (Homeland is a Hamlet)."], "below its tier: dimmed with the reason"))


func test_the_upgrades_heading_is_hidden_with_no_rows() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		home_at(8)
		var modal: Object = await open_build(main)
		eq(modal.headings(), ["Buildings"], "no building here takes an upgrade"))


func test_an_upgrade_row_previews_it_on_its_base_and_builds_it() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		var modal: Object = await open_build(main)
		await choose(modal, row_id(main, "ditch", farm))
		eq(modal.shown_card(), "ditch", "the Ditch's card")
		var preview: Dictionary = e.build_preview("ditch", farm)
		var expected: Array[String] = ["If built on Farm"]
		for line in preview.get("lines", []):
			expected.append(BuildModal.line_text(line))
		expected.append("Costs %s" % CardFace.cost_text(preview.get("cost", {})))
		eq(modal.preview_lines(), expected, "the preview on the Farm")
		eq(modal.build_button.text, "Build Ditch", "the key")
		press_key(main, KEY_ENTER)
		await wait_frames()
		eq(e.upgrades_on(farm).size(), 1, "Enter built it on the Farm")
		eq(ribbon_names(main, farm), ["Ditch"], "the view shows its ribbon"))


func test_an_upgrade_rows_flavor_is_its_own_not_its_bases() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(4)
		var chapel := put_home(e, "chapel")
		var modal: Object = await open_build(main)
		await choose(modal, row_id(main, "sanctum", chapel))
		eq(modal.shown_card(), "sanctum", "the Sanctum's card")
		eq(modal.flavor_text(), SANCTUM.flavor, "the Sanctum's own flavor, not the Chapel's"))


# --- AC5: the upgrade's face ---

## The face text of a new card view of card_id at rest (not in the hand), drawn in main.
func face_of(main: Node, card_id: String) -> String:
	var view := CardView.new()
	view.setup(CardInstance.new(-1, Game.engine.card_db[card_id]), Game.engine.card_db, false)
	main.add_child(view)
	var text := view.face_text()
	view.free()
	return text


func test_an_upgrades_face_names_its_base_and_its_tier() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var sanctum := face_of(main, "sanctum")
		check(sanctum.contains("Upgrade · Chapel"), "the type line: %s" % sanctum)
		check(sanctum.contains("Also Draw up to 1 more card each turn"), "its rules led by Also: %s" % sanctum)
		check(not sanctum.contains("Builds on") and not sanctum.contains("Needs a"), "no header lines: %s" % sanctum)
		check(sanctum.contains("Village"), "a stamp naming its tier: %s" % sanctum)
		var plough := face_of(main, "plough")
		check(plough.contains("Upgrade · Farm") and plough.contains("Also ⟳ +1 food"), "the Plough: %s" % plough)
		check(not plough.contains("Village") and not plough.contains("Town"), "no stamp without a tier: %s" % plough)
		var farm := face_of(main, "farm")
		check(farm.contains("Building") and not farm.contains("Upgrade") and not farm.contains("Also"),
			"a building's face unchanged: %s" % farm)
		var chapel := put_home(e, "chapel")
		var modal: Object = await open_build(main)
		await choose(modal, row_id(main, "sanctum", chapel))
		check(String(modal.face_text()).contains("Upgrade · Chapel"), "the Build modal's sheet shows the upgrade face"))


# --- 387: a building's details list its upgrades and build them ---

## The details' Upgrades rows: {name, rules, status, button} each (button null when a row has none). Red phase: the
## hook is new in 387.
func detail_rows(main: Node) -> Array:
	return (main.details as Object).call("upgrade_rows")  # scaffolding: upgrade_rows is new in 387


## Whether the details show their Upgrades section.
func upgrades_shown(main: Node) -> bool:
	return (main.details as Object).call("upgrades_shown")  # scaffolding: upgrades_shown is new in 387


## Opens the live details of tableau card uid, as a click on it does.
func open_card_details(main: Node, uid: int) -> void:
	main.details.open_card(Game.engine.zone("tableau").find(uid))
	await wait_frames()


func test_a_buildings_details_list_its_upgrades_built_or_to_build() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		build_it(e, "plough", farm)
		await open_card_details(main, farm)
		check(upgrades_shown(main), "an Upgrades section")
		var rows := detail_rows(main)
		eq(rows.map(func(r): return [r.name, r.rules]),
			[["Plough", e.upgrade_rules_text("plough")], ["Ditch", e.upgrade_rules_text("ditch")]], "a row each, in order")
		if rows.size() == 2:
			eq([rows[0].status, rows[0].button], ["Built", null], "the Plough: built, no button")
			var button: Button = rows[1].button
			check(button != null and button.visible and not button.disabled, "the Ditch: an Upgrade button")
			if button != null:
				check(button.text.begins_with("Upgrade") and button.text.contains(Fields.amounts_text(e.build_cost("ditch"))),
					"with its cost: %s" % button.text))


func test_a_fallen_back_row_reads_its_reason_and_a_refused_one_its_error() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var chapel := put_home(e, "chapel")
		var sanctum := build_it(e, "sanctum", chapel)
		set_home_pop(e, 3)
		await open_card_details(main, chapel)
		var rows := detail_rows(main)
		eq(rows.map(func(r): return r.name), ["Sanctum", "Cathedral"], "the Sanctum, then the Cathedral on it")
		if rows.size() == 2:
			eq(rows[0].status, e.fallen_back_reason(sanctum), "the Sanctum: why it has fallen back")
			eq([rows[1].status, rows[1].button], [e.build_error("cathedral", sanctum), null], "the Cathedral: refused, no button")
			check(rows[1].status != "", "a reason: %s" % rows[1].status))


func test_no_upgrades_section_where_there_is_nothing_to_upgrade() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var forum := put_home(e, "forum")
		await open_card_details(main, forum)
		check(not upgrades_shown(main), "a Forum: nothing upgrades it")
		var farm := put_in_hand(e, "farm")
		await refresh(main)
		main.details.open(main.views[farm])
		await wait_frames()
		check(not upgrades_shown(main), "a hand card")
		main.details.open_def("farm")
		await wait_frames()
		check(not upgrades_shown(main), "a definition's details")
		main.details.open_def("explorer")
		await wait_frames()
		check(not upgrades_shown(main), "an action's definition"))


func test_upgrade_builds_it_closes_the_details_and_plays_the_ceremony() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		await open_home(main)
		await open_card_details(main, farm)
		var food: int = e.resources.food
		var ditch: Dictionary = detail_rows(main).filter(func(r): return r.name == "Ditch").front()
		(ditch.button as Button).pressed.emit()
		await wait_frames()
		eq(e.resources.food, food - e.build_cost("ditch").get("food", 0), "the cost paid")
		eq(e.upgrades_on(farm).map(func(u): return e.zone("tableau").find(u).def.id), ["ditch"], "a Ditch on the Farm")
		eq(main.details.shown(), {}, "the details closed")
		eq(MainProbe.build_ceremonies(main).map(func(c): return c.view), [view_of(main, farm)], "the ceremony on the Farm"))


func test_while_a_decision_is_owed_each_upgrade_button_is_disabled_with_why() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer: a territory choice is owed")
		await open_card_details(main, farm)
		var buttons: Array = detail_rows(main).map(func(r): return r.button).filter(func(b): return b != null)
		eq(buttons.size(), 2, "the Plough and the Ditch keep their buttons")
		for b: Button in buttons:
			eq([b.disabled, b.tooltip_text], [true, e.build_menu_error()], "disabled, with why"))


func test_a_row_short_of_its_cost_reads_why_with_no_button() -> void:
	await with_main(ribbon_engine(), func(main: Node):
		var e := home_at(8)
		var farm := put_home(e, "farm")
		e.resources.food = 0
		await open_card_details(main, farm)
		var rows := detail_rows(main)
		eq(rows.map(func(r): return [r.status, r.button]),
			[[e.build_error("plough", farm), null], [e.build_error("ditch", farm), null]], "can't afford: why, no button")
		check(e.build_error("ditch", farm).contains("food"), "the reason is the food: %s" % e.build_error("ditch", farm)))
