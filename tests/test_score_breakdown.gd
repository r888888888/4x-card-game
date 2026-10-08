extends "res://tests/lib/test_case.gd"
## Score and pop breakdowns (backlog 380): `score_breakdown()` lists what makes up `score()` (each card's VP grouped by
## name, the VP effects added, the VP from pop) and `pop_breakdown()` each settled territory's pop, as 379's rows
## {label, count, amount}; clicking the Score or Pop counter opens them in 379's popover.

## Forum: a building that needs a Town (301), 1 VP. Colossus: a project (286), 12 wealth, 5 VP.
const FORUM := {"id": "forum", "name": "Forum", "type": "building", "tier": "town", "vp": 1}
const COLOSSUS := {"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 12}, "vp": 5,
	"project": true}
const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 4},
]


## A row as the breakdowns return it.
func row(label: String, count: int, amount: int) -> Dictionary:
	return {"label": label, "count": count, "amount": amount}


## A TEST_CARDS game with population {start 2, food_upkeep 1, vp_per_pop 1}, Nomads as the civilization, Homeland at
## pop 2 with Capital, plus card_ids built on Homeland; overrides last.
func score_engine(card_ids: Array = [], overrides := {}) -> GameEngine:
	var o := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1},
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland",
			"civilization": "nomads"},
		"territory_deck": {"grassland": 2}}
	o.merge(overrides, true)
	var e := make_engine({"scout": 10}, o, 1, TEST_CIVS + [FORUM, COLOSSUS])
	set_home_pop(e, 2)
	build_on(e, home_uid(e), card_ids)
	return e


func sum(rows: Array) -> int:
	var total := 0
	for each in rows:
		total += each.amount
	return total


# --- AC1: cards, effects, pop ---

func test_score_breakdown_lists_cards_then_effects_then_pop() -> void:
	var e: Object = score_engine(["temple", "temple"])
	e.bonus_score = 3
	eq(e.score_breakdown(), [row("Capital", 1, 2), row("Temple", 2, 2), row("Nomads", 1, 1), row("Effects", 1, 3),
		row("Pop", 2, 2)], "rows")
	eq([sum(e.score_breakdown()), e.score()], [10, 10], "they sum to the score")


func test_no_effects_or_pop_row_without_them() -> void:
	var e: Object = score_engine([], {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 0}})
	eq(e.score_breakdown(), [row("Capital", 1, 2), row("Nomads", 1, 1)], "no bonus score, no pop VP: no rows")
	var off: Object = make_engine({"scout": 10}, {"starting": {"resources": {"food": 2}, "tableau": ["capital", "temple"],
		"territory": "homeland"}})
	off.bonus_score = 0
	eq(off.score_breakdown(), [row("Capital", 1, 2), row("Temple", 1, 1)], "population off: no pop row")
	eq(sum(off.score_breakdown()), off.score(), "the sum")


# --- AC2: cards that don't count ---

func test_fallen_back_cards_and_unfinished_sites_have_no_row() -> void:
	var population := {"start": 2, "food_upkeep": 1, "vp_per_pop": 1, "tiers": TIERS}
	var e: Object = score_engine(["forum", "colossus"], {"population": population})
	set_home_pop(e, 4)  # a Village: the Forum, which needs a Town, has fallen back
	eq(e.score(), 7, "precondition: Capital 2, Nomads 1 and 4 pop; neither the Forum nor the Colossus counts")
	var labels := []
	for each in e.score_breakdown():
		labels.append(each.label)
	check(not labels.has("Forum"), "the fallen-back Forum: %s" % [labels])
	check(not labels.has("Colossus"), "the unfinished Colossus: %s" % [labels])
	eq(sum(e.score_breakdown()), e.score(), "the sum")


# --- AC3: pop by territory ---

func test_pop_breakdown_lists_each_territory_in_tableau_order() -> void:
	var e: Object = score_engine()
	settle(e, ["grassland"])
	var home := home_uid(e)
	var grass := uid_of(e.zone("tableau"), "grassland")
	set_home_pop(e, 3)
	e.zone("tableau").find(grass).pop = 1
	eq(e.pop_breakdown(), [row(e.territory_name(home), 1, 3), row(e.territory_name(grass), 1, 1)], "rows")
	eq(sum(e.pop_breakdown()), e.total_pop(), "the sum")
	check(e.rename_territory(grass, "Green Acre"), "rename: %s" % e.rename_territory_error(grass, "Green Acre"))
	eq(e.pop_breakdown()[1].label, "Green Acre", "a renamed territory shows its new name")


func test_no_pop_breakdown_with_population_off() -> void:
	var off: Object = make_engine({"scout": 10})
	eq(off.pop_breakdown(), [], "population off")


# --- AC4: the popover ---

func test_clicking_score_opens_its_breakdown() -> void:
	await with_main(score_engine(["temple"]), func(main: Node):
		click_control(main, MainProbe.counter(main, TopBar.SCORE))
		await wait_frames()
		eq(MainProbe.breakdown_key(main), TopBar.SCORE, "Score's popover open")
		var rows: Array = MainProbe.breakdown_rows(main)
		check(rows.has(["Capital", "2"]) and rows.has(["Temple", "1"]), "card rows: %s" % [rows])
		eq(rows.back(), ["Total", str(Game.engine.score())], "the total last")
		click_control(main, MainProbe.counter(main, TopBar.POP))
		await wait_frames()
		eq(MainProbe.breakdown_key(main), TopBar.POP, "clicking Pop swaps to its popover")
		eq(MainProbe.breakdown_rows(main).back(), ["Total", str(Game.engine.total_pop())], "Pop's total")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		eq(MainProbe.breakdown_key(main), "", "Esc closes it"))


func test_enter_on_focused_pop_opens_it() -> void:
	await with_main(score_engine(), func(main: Node):
		FocusRing.focus(MainProbe.counter(main, TopBar.POP))
		press_key(main, KEY_ENTER)
		await wait_frames()
		eq(MainProbe.breakdown_key(main), TopBar.POP, "Enter opens Pop's popover")
		var home := Game.engine.territory_name(home_uid(Game.engine))
		check(MainProbe.breakdown_rows(main).has([home, "2"]), "the Homeland's pop: %s" % [MainProbe.breakdown_rows(main)])
		press_key(main, KEY_ESCAPE)
		await wait_frames())
