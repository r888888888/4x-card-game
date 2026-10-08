extends "res://tests/lib/test_case.gd"
## Building upkeep (405): each working base building pays its upkeep in wealth after pop eats, the config's
## building_upkeep unless the card sets its own upkeep; upgrades, projects, idle and fallen-back buildings pay none. The
## unpaid remainder is added to unrest (capped by the limit). Covers the forecast, the loader and the card text.
## Fixtures: Hut and Shed (nothing), Mint Hut (⟳ +2 wealth), Big Hall (upkeep 2), Free Shed (upkeep 0), Hut Loft (an
## upgrade on Hut), Colossus (a 10-wealth project) and Steward (a government, unrest limit 8).

const RESOURCES: Array[String] = ["food", "wealth", "insight", "unrest"]
const HUT := {"id": "hut", "name": "Hut", "type": "building", "cost": {"food": 1}}
const SHED := {"id": "shed", "name": "Shed", "type": "building", "cost": {"food": 1}}
const MINT_HUT := {"id": "mint_hut", "name": "Mint Hut", "type": "building", "cost": {"food": 1},
	"effects": [{"op": "gain", "resource": "wealth", "amount": 2, "trigger": "upkeep"}]}
const BIG_HALL := {"id": "big_hall", "name": "Big Hall", "type": "building", "cost": {"food": 1}, "upkeep": 2}
const FREE_SHED := {"id": "free_shed", "name": "Free Shed", "type": "building", "cost": {"food": 1}, "upkeep": 0}
const HUT_LOFT := {"id": "hut_loft", "name": "Hut Loft", "type": "building", "cost": {"food": 1}, "upgrade_of": "hut"}
const COLOSSUS := {"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 10}, "vp": 5,
	"tags": ["wonder"], "project": true}
const STEWARD := {"id": "steward", "name": "Steward", "type": "government", "unrest_limit": 8}
const FIXTURES := [HUT, SHED, MINT_HUT, BIG_HALL, FREE_SHED, HUT_LOFT, COLOSSUS, STEWARD]
const UPKEEP_LINE := "⟳ Upkeep %d wealth"


## A game on TEST_CARDS + FIXTURES with unrest on, Steward ruling, population on (3 pop on Homeland, no food upkeep),
## Grassland in the territory deck and the config's building_upkeep (null: left out). Turn 1's upkeep has run with
## nothing built.
func upkeep_engine(building_upkeep: Variant = 1) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + FIXTURES}, RESOURCES, "cards.json", errors,
		warnings, keywords())
	var o := {
		"resources": RESOURCES,
		"territory_deck": {"grassland": 1},
		"population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"starting": {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland",
			"government": "steward"},
	}
	if building_upkeep != null:
		o["building_upkeep"] = building_upkeep
	var config := DataLoader.parse_config(raw_config({"scout": 10}, o), RESOURCES, cards, "config.json", errors,
		warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	return e


## Puts ids straight on Homeland, sets wealth and unrest, and returns e.
func with_built(e: GameEngine, ids: Array, wealth: int, unrest := 0) -> GameEngine:
	build_on(e, home_uid(e), ids)
	e.resources.wealth = wealth
	e.resources.unrest = unrest
	return e


## Ends the turn, so the next turn's upkeep runs.
func run_upkeep(e: GameEngine) -> void:
	var turn := e.turn
	e.end_turn()
	eq(e.turn, turn + 1, "the next turn started")


## A copy of card id on Homeland whose base is base_uid (an upgrade built on it): its uid.
func upgrade_on(e: GameEngine, id: String, base_uid: int) -> int:
	var card: CardInstance = e.create_card(id, "tableau", null)
	card.territory_uid = home_uid(e)
	card.base_uid = base_uid
	return card.uid


# --- AC1: the config's default upkeep ---

func test_each_working_building_pays_the_default_upkeep_in_wealth() -> void:
	var e := with_built(upkeep_engine(), ["hut", "shed"], 5)
	run_upkeep(e)
	eq(e.resources.wealth, 3, "5 − Hut 1 − Shed 1")
	eq(e.resources.unrest, 0, "paid in full: no unrest")


# --- AC2: a card's own upkeep ---

func test_a_cards_own_upkeep_replaces_the_default() -> void:
	var e := with_built(upkeep_engine(), ["hut", "big_hall", "free_shed"], 5)
	eq(e.building_upkeep_due(), 3, "due: Hut 1 + Big Hall 2 + Free Shed 0")
	run_upkeep(e)
	eq(e.resources.wealth, 2, "5 − 1 − 2 − 0")


# --- AC3: who doesn't pay ---

func test_upgrades_projects_idle_buildings_and_the_capital_pay_nothing() -> void:
	var e := upkeep_engine()
	var home := home_uid(e)
	build_on(e, home, ["hut"])
	var hut: int = e.zone("tableau").cards.back().uid
	upgrade_on(e, "hut_loft", hut)
	build_on(e, home, ["colossus", "colossus"])
	e.zone("tableau").cards.back().progress = 10  # the second Colossus is complete; the first is a site
	settle(e, ["grassland"])  # 0 pop: a Hut there has no worker
	build_on(e, uid_of(e.zone("tableau"), "grassland"), ["hut"])
	e.resources.wealth = 5
	eq(e.building_upkeep_due(), 1, "due: the working Hut alone")
	run_upkeep(e)
	eq(e.resources.wealth, 4, "5 − the working Hut 1")


func test_without_building_upkeep_in_the_config_nothing_pays() -> void:
	var e := with_built(upkeep_engine(null), ["hut", "shed"], 5)
	eq(e.building_upkeep_due(), 0, "rules off: nothing due")
	run_upkeep(e)
	eq(e.resources.wealth, 5, "nothing paid")


# --- AC4: production comes first ---

func test_upkeep_production_pays_before_the_buildings_upkeep() -> void:
	var e := with_built(upkeep_engine(), ["mint_hut"], 0)
	run_upkeep(e)
	eq(e.resources.wealth, 1, "0 + Mint Hut 2 − its upkeep 1")
	eq(e.resources.unrest, 0, "paid in full: no unrest")


# --- AC5: a shortfall adds unrest ---

func test_an_upkeep_shortfall_adds_the_unpaid_wealth_as_unrest() -> void:
	var e := with_built(upkeep_engine(), ["hut", "shed", "big_hall"], 1)
	run_upkeep(e)
	eq(e.resources.wealth, 0, "1 paid of 4 owed")
	eq(e.resources.unrest, 3, "0 + 3 unpaid")


func test_shortfall_unrest_stops_at_the_limit() -> void:
	var e := with_built(upkeep_engine(), ["hut", "shed", "big_hall"], 1, 7)
	run_upkeep(e)
	eq(e.resources.wealth, 0, "1 paid of 4 owed")
	eq(e.resources.unrest, 8, "7 + 3 unpaid, capped at Steward's limit 8")


# --- AC6: the forecast ---

## Checks that both forecasts of e give wealth and unrest, change nothing, and match what upkeep then does.
func check_forecast(e: GameEngine, wealth: int, unrest: int, what: String) -> void:
	var before := state_dump([e.state, e.resources, e.zones])
	var forecast := e.upkeep_forecast()
	var turn := e.turn_forecast()
	eq([forecast.get("wealth"), forecast.get("unrest")], [wealth, unrest], "%s: upkeep_forecast" % what)
	eq([turn.get("wealth"), turn.get("unrest")], [wealth, unrest], "%s: turn_forecast" % what)
	eq(state_dump([e.state, e.resources, e.zones]), before, "%s: forecasting changes nothing" % what)
	var held := [e.resources.wealth, e.resources.unrest]
	run_upkeep(e)
	eq([e.resources.wealth - held[0], e.resources.unrest - held[1]], [wealth, unrest], "%s: upkeep did that" % what)


func test_the_forecast_includes_the_buildings_upkeep() -> void:
	check_forecast(with_built(upkeep_engine(), ["hut", "shed"], 5), -2, 0, "AC1")


func test_the_forecast_includes_a_shortfalls_unrest() -> void:
	check_forecast(with_built(upkeep_engine(), ["hut", "shed", "big_hall"], 1), -1, 3, "AC5")


# --- AC7: the loader ---

func test_the_config_resolves_each_base_buildings_upkeep() -> void:
	var on := upkeep_engine()
	var ids := ["hut", "big_hall", "free_shed", "hut_loft", "colossus"]
	eq(ids.map(func(id: String) -> int: return on.card_db[id].upkeep), [1, 2, 0, 0, 0],
		"building_upkeep 1: the default, Big Hall's 2, Free Shed's 0, an upgrade and a project 0")
	var off := upkeep_engine(null)
	eq(off.config.get("building_upkeep"), 0, "building_upkeep defaults to 0")
	eq(ids.map(func(id: String) -> int: return off.card_db[id].upkeep), [0, 2, 0, 0, 0],
		"no building_upkeep: only Big Hall's own")


func test_bad_upkeep_fields_are_load_errors() -> void:
	check_cases([
		["upkeep not an int", {"id": "x", "name": "X", "type": "building", "upkeep": "big"},
			"cards.json: card 'x': 'upkeep' must be an integer >= 0"],
		["upkeep on an upgrade", {"id": "x", "name": "X", "type": "building", "upgrade_of": "farm", "upkeep": 1},
			"cards.json: card 'x': upkeep: an upgrade pays no upkeep (its base does)"],
		["upkeep on a project", {"id": "x", "name": "X", "type": "building", "cost": {"wealth": 4}, "project": true,
			"upkeep": 1}, "cards.json: card 'x': upkeep: a project pays no upkeep"],
		["upkeep on an action", {"id": "x", "name": "X", "type": "action", "upkeep": 1},
			"'upkeep' only applies to buildings (ignored)", "warning_only"],
	], card_load)


func test_a_bad_building_upkeep_in_the_config_is_a_load_error() -> void:
	check_cases([
		["below 0", {"building_upkeep": -1}, "config.json: 'building_upkeep' must be an integer >= 0"],
		["not an int", {"building_upkeep": "some"}, "config.json: 'building_upkeep' must be an integer >= 0"],
	], func(o: Dictionary) -> Array[String]: return config_errors_for(fixture_db(), o))


# --- AC8: the card text ---

func test_a_paying_buildings_text_ends_with_its_upkeep_line() -> void:
	var e := upkeep_engine()
	eq(Array(e.card_db.hut.rules_text(e.card_db).split("\n")).back(), UPKEEP_LINE % 1, "Hut: the default")
	eq(Array(e.card_db.big_hall.rules_text(e.card_db).split("\n")).back(), UPKEEP_LINE % 2, "Big Hall: its own")


func test_buildings_that_pay_nothing_have_no_upkeep_line() -> void:
	var e := upkeep_engine()
	for id in ["free_shed", "hut_loft", "colossus"]:
		check(not e.card_db[id].rules_text(e.card_db).contains("Upkeep"), "%s: no upkeep line" % id)
