extends "res://tests/lib/anarchy_case.gd"
## Upkeep breakdowns (backlog 379): `upkeep_breakdown(resource)` lists where next upkeep's change of a resource comes
## from, as rows {label, count, amount} that sum to `upkeep_forecast()`; `unrest_limit_breakdown()` lists the unrest
## limit's government and modifiers. Clicking a top-bar resource counter opens a popover that shows them.

## Riot: a building that gains 1 unrest at upkeep. Unease: an event that does too. Sage, Dull, Duller: buildings with
## insight_per_gain +1, −1 and −2. Scriptorium and Copyist: buildings that gain 2 and 1 insight at upkeep. Senate: a
## government with unrest limit 4. Bastion and Mob: buildings with unrest_limit +2 and −10. Wardens: a government
## (limit 20) that tolerates Villages and administers 3 territories.
const RIOT := {"id": "riot", "name": "Riot", "type": "building",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const UNEASE := {"id": "unease", "name": "Unease", "type": "event", "discard": {"turns": 2},
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1, "trigger": "upkeep"}]}
const SAGE := {"id": "sage", "name": "Sage", "type": "building", "modifiers": {"insight_per_gain": 1}}
const DULL := {"id": "dull", "name": "Dull", "type": "building", "modifiers": {"insight_per_gain": -1}}
const DULLER := {"id": "duller", "name": "Duller", "type": "building", "modifiers": {"insight_per_gain": -2}}
const SCRIPTORIUM := {"id": "scriptorium", "name": "Scriptorium", "type": "building",
	"effects": [{"op": "gain", "resource": "insight", "amount": 2, "trigger": "upkeep"}]}
const COPYIST := {"id": "copyist", "name": "Copyist", "type": "building",
	"effects": [{"op": "gain", "resource": "insight", "amount": 1, "trigger": "upkeep"}]}
const SENATE := {"id": "senate", "name": "Senate", "type": "government", "unrest_limit": 4}
const BASTION := {"id": "bastion", "name": "Bastion", "type": "building", "modifiers": {"unrest_limit": 2}}
const MOB := {"id": "mob", "name": "Mob", "type": "building", "modifiers": {"unrest_limit": -10}}
const WARDENS := {"id": "wardens", "name": "Wardens", "type": "government", "unrest_limit": 20, "administers": 3,
	"tolerates": "village"}
const BREAKDOWN_FIXTURES := [RIOT, UNEASE, SAGE, DULL, DULLER, SCRIPTORIUM, COPYIST, SENATE, BASTION, MOB, WARDENS]
const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
]


## A row as upkeep_breakdown returns it.
func row(label: String, count: int, amount: int) -> Dictionary:
	return {"label": label, "count": count, "amount": amount}


## A TEST_CARDS game with population on (start 2, food upkeep 1), Homeland at pop and Capital in play, plus
## card_ids built on Homeland in order.
func pop_engine(pop: int, card_ids: Array = [], overrides := {}) -> GameEngine:
	var o := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 0}}
	o.merge(overrides, true)
	var e := make_engine({"scout": 10}, o)
	set_home_pop(e, pop)
	build_on(e, home_uid(e), card_ids)
	return e


## An anarchy game (Chiefs ruling, limit 5, unrest on, home pop 6, no food upkeep) with BREAKDOWN_FIXTURES loaded,
## overrides last, and card_ids built on Homeland in order.
func unrest_engine(card_ids: Array = [], unrest := {}, overrides := {}) -> GameEngine:
	var e := anarchy_engine(unrest, overrides, BREAKDOWN_FIXTURES)
	build_on(e, home_uid(e), card_ids)
	return e


## Checks that, for every resource, e's breakdown rows sum to its upkeep forecast (AC2).
func check_sums(e: GameEngine, label: String) -> void:
	var forecast := e.upkeep_forecast()
	for r in e.resources:
		var total := 0
		for each in e.upkeep_breakdown(r):
			total += each.amount
		eq(total, forecast.get(r, 0), "%s: %s rows sum to the forecast" % [label, r])


# --- AC1: rows by source, in upkeep order ---

func test_breakdown_groups_copies_and_ends_with_what_pop_eats() -> void:
	var e := pop_engine(3, ["farm", "farm", "stall"])
	eq(e.upkeep_breakdown("food"), [row("Capital", 1, 2), row("Farm", 2, 2), row("Pop eats", 1, -3)], "food")
	eq(e.upkeep_breakdown("wealth"), [row("Stall", 1, 1)], "wealth")
	eq(e.upkeep_breakdown("insight"), [], "nothing changes insight: no rows")
	check_sums(e, "farms and a stall")


func test_breakdown_changes_nothing() -> void:
	var e := pop_engine(3, ["farm", "granary"])
	var changes := []
	e.changed.connect(func(): changes.append(true))
	var logged := e.log_lines.size()
	var resources := e.resources.duplicate()
	var pop := e.total_pop()
	for r in e.resources:
		e.upkeep_breakdown(r)
	eq(e.resources, resources, "resources")
	eq(e.total_pop(), pop, "pop")
	eq(e.log_lines.size(), logged, "nothing logged")
	eq(changes, [], "nothing emitted")


# --- AC2: the rows always sum to the forecast ---

func test_pop_grown_at_upkeep_eats_in_the_pop_row() -> void:
	var e := pop_engine(2, ["granary"])
	eq(e.upkeep_breakdown("food"), [row("Capital", 1, 2), row("Pop eats", 1, -3)], "Granary grows a pop, which eats")
	check_sums(e, "Granary")


func test_unrest_held_back_by_the_limit_gives_no_row() -> void:
	var e := unrest_engine(["riot"])
	eq(e.upkeep_breakdown("unrest"), [row("Riot", 1, 1)], "below the limit")
	e.resources["unrest"] = 5
	eq(e.upkeep_breakdown("unrest"), [], "at the limit (5): the Riot adds nothing")
	check_sums(e, "at the limit")


func test_no_breakdown_on_the_last_turn_or_after_game_over() -> void:
	var last := pop_engine(3, ["farm"], {"turn_limit": 1})
	eq(last.upkeep_breakdown("food"), [], "the last turn")
	var over := pop_engine(3, ["farm"])
	over.is_over = true
	eq(over.upkeep_breakdown("food"), [], "game over")


# --- AC3: crowding, overextension and events ---

func test_unrest_rows_for_crowding_overextension_and_an_event() -> void:
	var population: Dictionary = POP.duplicate()
	population["tiers"] = TIERS
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland", "government": "wardens"}
	var e := unrest_engine([], {}, {"population": population, "starting": starting,
		"territory_deck": {"grassland": 2, "hills": 1, "jungle": 1}})
	settle(e, ["grassland", "grassland", "hills", "jungle"])
	for t in e.zone("tableau").cards:
		if t.def.type == CardDef.TERRITORY:
			t.pop = 0
	set_home_pop(e, 8)
	e.resources["unrest"] = 0
	var unease: CardInstance = e.create_card("unease", "active_events", null)
	unease.turns_left = 2
	eq([e.size_unrest(), e.admin_unrest()], [1, 3], "a Town past Villages; 5 territories, 2 past the cap of 3")
	eq(e.upkeep_breakdown("unrest"), [row("Crowded territories", 1, 1), row("Overextended realm", 1, 3),
		row("Unease", 1, 1)], "unrest")
	check_sums(e, "crowding")


# --- AC4: insight_per_gain ---

func test_insight_per_gain_has_its_own_row() -> void:
	var e := unrest_engine(["sage", "scriptorium", "scriptorium"])
	var rows: Array = e.upkeep_breakdown("insight")
	check(rows.has(row("Scriptorium", 2, 4)), "the Scriptoria's printed +4: %s" % [rows])
	check(rows.has(row("Sage", 1, 2)), "the Sage's +1 per gain, 2 gains: %s" % [rows])
	eq(rows.size(), 2, "two rows")
	eq(e.upkeep_forecast().insight, 6, "the forecast")
	check_sums(e, "Sage")


func test_a_negative_insight_per_gain_has_a_negative_row() -> void:
	var e := unrest_engine(["dull", "copyist"])
	var rows: Array = e.upkeep_breakdown("insight")
	check(rows.has(row("Copyist", 1, 1)) and rows.has(row("Dull", 1, -1)), "+1 and −1: %s" % [rows])
	check_sums(e, "Dull")


func test_where_the_floor_bites_the_gaining_card_absorbs_it() -> void:
	var e := unrest_engine(["duller", "copyist"])
	var rows: Array = e.upkeep_breakdown("insight")
	check(rows.has(row("Duller", 1, -2)), "the Duller's −2: %s" % [rows])
	check(rows.has(row("Copyist", 1, 2)), "the Copyist's row absorbs the floor (gain 1 − 2 stops at 0): %s" % [rows])
	check_sums(e, "Duller")


# --- AC5: Anarchy's drain ---

func test_anarchy_drain_is_the_last_row() -> void:
	var e := unrest_engine([], {"drain_pct": 20})
	e.resources["unrest"] = 2
	check(e.revolt(), "a revolution declared: %s" % e.revolt_error())
	var rows: Array = e.upkeep_breakdown("food")
	check(not rows.is_empty(), "food rows")
	if rows.is_empty():
		return
	eq(rows[-1].label, "Anarchy", "the last row is Anarchy")
	check(rows[-1].amount < 0, "its drain takes food: %s" % [rows])
	check_sums(e, "the drain")


# --- AC6: the unrest limit ---

func test_unrest_limit_breakdown_lists_the_government_then_its_modifiers() -> void:
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland", "government": "senate"}
	var e := unrest_engine(["altar", "bastion"], {}, {"starting": starting})
	eq(e.unrest_limit_breakdown(), [row("Senate", 1, 4), row("Altar", 1, 1), row("Bastion", 1, 2)], "rows")
	eq(e.unrest_limit(), 7, "4 + 1 + 2")


func test_unrest_limit_rows_sum_to_the_floored_limit() -> void:
	var e := unrest_engine(["mob"])
	var rows: Array = e.unrest_limit_breakdown()
	check(rows.has(row("Mob", 1, -10)), "the Mob's −10: %s" % [rows])
	var total := 0
	for each in rows:
		total += each.amount
	eq([total, e.unrest_limit()], [0, 0], "the rows sum to the limit, floored at 0")


func test_no_unrest_limit_breakdown_without_a_limit() -> void:
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland", "government": "council"}
	var e := unrest_engine([], {}, {"starting": starting})
	eq(e.unrest_limit(), -1, "Council sets no limit")
	eq(e.unrest_limit_breakdown(), [], "no rows")


# --- AC7: the popover ---

func test_clicking_a_counter_opens_its_breakdown_and_clicking_again_closes_it() -> void:
	await with_main(unrest_engine(), func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["scriptorium", "scriptorium"])
		e.changed.emit()
		await wait_frames()
		eq(main.breakdown_key(), "", "closed at first")
		click_control(main, main.counter("insight"))
		await wait_frames()
		eq(main.breakdown_key(), "insight", "Insight's popover open")
		eq(main.breakdown_rows(), [["Scriptorium ×2", "+4"], ["Net", "+4"]], "its rows and the net")
		click_control(main, main.counter("wealth"))
		await wait_frames()
		eq(main.breakdown_key(), "wealth", "clicking Wealth swaps to its popover")
		click_control(main, main.counter("wealth"))
		await wait_frames()
		eq(main.breakdown_key(), "", "clicking it again closes it"))


func test_the_popover_closes_on_esc_and_an_outside_click() -> void:
	await with_main(unrest_engine(), func(main: Node):
		click_control(main, main.counter("food"))
		await wait_frames()
		eq(main.breakdown_key(), "food", "open")
		check(main.breakdown_rows().has(["Capital", "+2"]), "Capital's +2: %s" % [main.breakdown_rows()])
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		eq(main.breakdown_key(), "", "Esc closes it")
		check(not main.modals.is_open(), "and doesn't open the menu")
		click_control(main, main.counter("food"))
		await wait_frames()
		click_point(main, Vector2(2, 2))
		await wait_frames()
		eq(main.breakdown_key(), "", "a click outside closes it"))


func test_enter_on_a_focused_counter_opens_it() -> void:
	await with_main(unrest_engine(), func(main: Node):
		FocusRing.focus(main.counter("food"))
		press_key(main, KEY_ENTER)
		await wait_frames()
		eq(main.breakdown_key(), "food", "Enter opens the focused counter's popover")
		press_key(main, KEY_ESCAPE)
		await wait_frames())


func test_the_unrest_popover_adds_the_limit() -> void:
	await with_main(unrest_engine(), func(main: Node):
		var e := Game.engine
		build_on(e, home_uid(e), ["altar"])
		e.changed.emit()
		await wait_frames()
		click_control(main, main.counter("unrest"))
		await wait_frames()
		var rows: Array = main.breakdown_rows()
		check(rows.has(["Chiefs", "5"]) and rows.has(["Altar", "+1"]), "the limit's rows: %s" % [rows])
		check(rows.has(["Limit", "6"]), "and their total: %s" % [rows])
		press_key(main, KEY_ESCAPE)
		await wait_frames())


func test_on_the_last_turn_the_popover_says_there_is_no_next_upkeep() -> void:
	await with_main(pop_engine(3, [], {"turn_limit": 1}), func(main: Node):
		click_control(main, main.counter("food"))
		await wait_frames()
		eq(main.breakdown_rows(), [["No next upkeep: this is the last turn.", ""]], "the popover's only line")
		press_key(main, KEY_ESCAPE)
		await wait_frames())
