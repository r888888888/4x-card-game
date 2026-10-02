extends "res://tests/lib/tech_case.gd"
## Insight (backlog 139): a third built-in resource that pays for techs. Techs cost insight only; buying one spends
## insight and leaves wealth alone; civilization tech discounts take insight; the forecast and the top bar show it.
## Local fixtures: Sages (civilization, techs −1 insight), Scriptorium (building, ⟳ +1 insight) and Optics (era 2 tech).

const SAGES := {"id": "sages", "name": "Sages", "type": "civilization", "discounts": [{"type": "tech", "insight": 1}]}
const SCRIPTORIUM := {"id": "scriptorium", "name": "Scriptorium", "type": "building",
	"effects": [{"op": "gain", "resource": "insight", "amount": 1, "trigger": "upkeep"}]}
const OPTICS := {"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}
const FIXTURES := [SAGES, SCRIPTORIUM, OPTICS]


## Loads a tech 'x' with the given cost next to the fixture cards; returns the loader errors.
func tech_errors(cost: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	tech_db([{"id": "x", "name": "X", "type": "tech", "cost": cost}], errors, warnings)
	return errors


## tech_engine with Pottery then Writing on the research deck (Optics in era 2) and starting resources res;
## civ is the starting civilization ("" for none).
func civ_insight_engine(res: Dictionary, civ := "") -> GameEngine:
	var starting := {"resources": res, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var counts := {"research_deck": {"pottery": 1, "writing": 1, "optics": 1}, "starting": starting}
	var e := tech_engine(["pottery", "writing"], {"farm": 10}, counts, TEST_CIVS + FIXTURES)
	return e


# --- AC1: techs cost insight only ---

func test_a_tech_costing_insight_loads() -> void:
	eq(tech_errors({"insight": 2}), [] as Array[String], "loader errors")


func test_a_tech_must_cost_insight_only() -> void:
	var message := "cards.json: card 'x': cost: a tech must cost insight only, at least 1 (like {\"insight\": 2})"
	for cost in [{"wealth": 2}, {}, {"insight": 0}, {"insight": 2, "wealth": 1}]:
		eq(tech_errors(cost), [message] as Array[String], "cost %s" % [cost])


# --- AC2: buying spends insight, not wealth ---

func test_buying_a_tech_spends_insight_and_leaves_wealth() -> void:
	var e := civ_insight_engine({"food": 2, "wealth": 20, "insight": 2})
	var pottery := uid_of(e.zone("research_deck"), "pottery")
	check(e.buy_tech(pottery), "buy Pottery: %s" % e.buy_tech_error(pottery))
	eq(e.resources.get("insight"), 0, "insight 2 − 2")
	eq(e.resources.get("wealth"), 20, "wealth untouched")
	eq(card_ids(e.zone("researched")), ["pottery"], "researched")


# --- AC3: not enough insight ---

func test_a_tech_needs_enough_insight() -> void:
	var e := civ_insight_engine({"food": 2, "wealth": 20, "insight": 1})
	var pottery := uid_of(e.zone("research_deck"), "pottery")
	eq(e.buy_tech_error(pottery), "Pottery needs 2 insight (you have 1).", "buy_tech_error")
	check(not e.buy_tech(pottery), "buy_tech refuses")
	eq([e.resources.get("insight"), e.resources.get("wealth")], [1, 20], "insight and wealth unchanged")
	eq(e.zone("researched").size(), 0, "nothing researched")
	eq(e.zone("research_deck").size(), 2, "both techs still on offer")


# --- AC4: discounts, the tree and the details speak insight ---

func test_a_civilization_tech_discount_takes_insight() -> void:
	var e := civ_insight_engine({"food": 2, "insight": 20}, "sages")
	eq(e.tech_cost(uid_of(e.zone("research_deck"), "writing")), 2, "Writing 3 − 1")


func test_the_tech_tree_reports_costs_in_insight() -> void:
	var e := civ_insight_engine({"food": 2, "insight": 20}, "sages")
	var costs := {}
	for t in e.tech_tree():
		costs[t.id] = t.cost
	eq(costs, {"pottery": 1, "writing": 2, "optics": 4}, "revealed techs at their price now, Optics (era 2) printed")


func test_a_techs_details_name_its_insight_price_and_the_civilization_discount() -> void:
	var e := civ_insight_engine({"food": 2, "insight": 20}, "sages")
	var d: Dictionary = e.card_details(uid_of(e.zone("research_deck"), "writing"))
	check(d.get("state", []).has("Costs 2 insight now (printed 3, −1 civilization)"), "state: %s" % [d.get("state")])


# --- AC5: the forecast and the top bar ---

func test_the_forecast_includes_insight() -> void:
	var e := civ_insight_engine({"food": 2, "insight": 0})
	e.create_card("scriptorium", "tableau", null)
	eq(e.upkeep_forecast().get("insight"), 1, "Scriptorium ⟳ +1 insight")


## The one visible label under root whose text starts with prefix, or null.
func shown_label(root: Node, prefix: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		var label := node as Label
		if label.is_visible_in_tree() and label.text.begins_with(prefix):
			return label
	return null


func test_the_top_bar_shows_insight_with_its_forecast_and_floats_its_change() -> void:
	var real := Game.engine
	Game.engine = tech_engine(["pottery", "writing"], {"farm": 10},
		{"starting": {"resources": {"food": 2, "insight": 0}, "tableau": ["capital", "scriptorium"], "territory": "homeland"}},
		FIXTURES)
	var main := open_main()
	main.start_game(1)
	Game.engine.resources["insight"] = 0
	Game.engine.changed.emit()
	await wait_frames()
	var counter: Control = main.counter(GameEngine.INSIGHT)
	check(counter != null and counter.is_visible_in_tree(), "an Insight counter in the top bar")
	eq(main.counter_text(GameEngine.INSIGHT), "Insight: 0 (+1)", "insight and its forecast")
	Game.engine.resources["insight"] = 3
	Game.engine.changed.emit()
	await wait_frames()
	check(shown_label(main, "+3 insight") != null, "a +3 insight token floats up")
	close_main(main)
	Game.engine = real
