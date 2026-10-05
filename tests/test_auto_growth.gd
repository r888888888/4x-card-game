extends "res://tests/lib/test_case.gd"
## Automatic growth (backlog 260): when a turn's upkeep nets at least population.growth_surplus food (made, less what
## pop eats), the settled territory with the most pop and room to grow gets +1 pop for free; one per turn. Replaces
## buying growth (010), whose grow / grow_error / grow_cost are gone.


## A TEST_CARDS game with population on (start pop 2, food_upkeep upkeep, growth_surplus surplus), Scouts in the deck
## and 10 food. The Capital makes 2 food each upkeep.
func growth_engine(surplus := 2, upkeep := 1, overrides := {}) -> GameEngine:
	var o := {"population": {"start": 2, "food_upkeep": upkeep, "vp_per_pop": 1, "growth_surplus": surplus}}
	o.merge(overrides, true)
	var e := make_engine({"scout": 10}, o)
	e.resources.food = 10
	return e


## A food_upkeep 0 growth_engine with Grassland (housing 4) settled after Homeland (housing 7), pops set:
## {e, home, grass}. The Capital alone nets +2.
func two_land_engine(home_pop: int, grass_pop: int) -> Dictionary:
	var e := growth_engine(2, 0, {"territory_deck": {"grassland": 1}})
	settle(e, ["grassland"])
	var home := home_uid(e)
	var grass := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(home).pop = home_pop
	e.zone("tableau").find(grass).pop = grass_pop
	return {"e": e, "home": home, "grass": grass}


# --- AC1: a surplus of growth_surplus grows 1 pop, free ---

func test_a_surplus_of_2_grows_the_territory_for_free() -> void:
	var e := growth_engine()
	var home := home_uid(e)
	build_on(e, home, ["farm", "farm"])  # Capital 2 + 2 Farms = 4 food; 2 pop eat 2: net +2
	e.end_turn()
	eq(e.pop(home), 3, "pop 2 + 1")
	eq(e.resources.food, 12, "10 + 4 made − 2 eaten: growing costs nothing")


# --- AC2: below the threshold nothing grows ---

func test_a_surplus_below_growth_surplus_grows_nothing() -> void:
	var e := growth_engine()
	var home := home_uid(e)
	build_on(e, home, ["farm"])  # 3 made − 2 eaten: net +1
	e.end_turn()
	eq(e.pop(home), 2, "net +1 < 2: no growth")
	eq(e.resources.food, 11, "10 + 1")


func test_growth_surplus_1_grows_on_a_surplus_of_1() -> void:
	var e := growth_engine(1)
	var home := home_uid(e)
	build_on(e, home, ["farm"])  # net +1
	e.end_turn()
	eq(e.pop(home), 3, "net +1 ≥ 1: grows")


# --- AC3: the largest grows first, one pop a turn ---

func test_the_largest_territory_grows_and_only_by_1() -> void:
	var g := two_land_engine(2, 3)
	var e: GameEngine = g.e
	build_on(e, g.grass, ["farm", "farm", "farm"])  # 2 + 3 = net +5 (no food upkeep)
	e.end_turn()
	eq(e.pop(g.grass), 4, "Grassland, the larger though settled later, grows")
	eq(e.pop(g.home), 2, "Homeland doesn't: one growth a turn")
	eq(e.total_pop(), 6, "5 + 1, whatever the surplus")


# --- AC4: territories at their housing are skipped; ties go to tableau order ---

func test_a_full_territory_is_skipped() -> void:
	var g := two_land_engine(2, 4)  # Grassland at its housing 4
	g.e.end_turn()  # Capital: net +2
	eq(g.e.pop(g.grass), 4, "Grassland is full")
	eq(g.e.pop(g.home), 3, "Homeland, the largest with room, grows")


func test_a_tie_goes_to_the_first_in_tableau_order() -> void:
	var g := two_land_engine(2, 2)
	g.e.end_turn()
	eq(g.e.pop(g.home), 3, "Homeland comes first")
	eq(g.e.pop(g.grass), 2, "Grassland waits")


func test_nothing_grows_when_every_territory_is_full() -> void:
	var g := two_land_engine(7, 4)
	g.e.end_turn()
	eq(g.e.total_pop(), 11, "7 + 4, unchanged")
	eq(g.e.turn, 2, "the turn started")


# --- AC5: population off (Anarchy: test_anarchy.gd) ---

func test_nothing_grows_with_population_off() -> void:
	var e := make_engine({"scout": 10})
	var recorded := record_messages(e)
	e.end_turn()
	eq(e.total_pop(), 0, "no pop")
	eq(notices_in(recorded).filter(func(n): return n.contains("grew")), [], "no growth notice")


# --- AC6: a notice names the territory and its new pop ---

func test_growing_logs_and_notices_the_territory_and_its_pop() -> void:
	var e := growth_engine(2, 0)
	var recorded := record_messages(e)
	e.end_turn()  # Capital: net +2
	check_noticed(recorded, "Homeland grew to 3 pop.", GameEngine.NOTICE_INFO)


func test_no_growth_no_notice() -> void:
	var e := growth_engine()  # Capital 2 − 2 eaten: net 0
	var recorded := record_messages(e)
	e.end_turn()
	eq(notices_in(recorded).filter(func(n): return n.contains("grew")), [], "no growth notice")


# --- AC7: config ---

func population_config(population: Dictionary) -> Array:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var raw := raw_config({"farm": 1})
	raw.population = population
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw, resources(), cards, "config.json", errors, warnings)
	return [config, errors, warnings]


func test_growth_surplus_defaults_to_2() -> void:
	var r := population_config({"start": 2, "food_upkeep": 1, "vp_per_pop": 1, "famine": FAMINE})
	eq(r[1], [] as Array[String], "errors")
	eq(r[2], [] as Array[String], "warnings")
	eq(r[0].population.get("growth_surplus"), 2, "default")


func test_growth_surplus_is_read() -> void:
	var r := population_config({"start": 2, "growth_surplus": 3, "famine": FAMINE})
	eq(r[2], [] as Array[String], "no unknown-field warning")
	eq(r[0].population.get("growth_surplus"), 3, "read")


func test_growth_surplus_must_be_an_integer_of_at_least_1() -> void:
	for bad in [0, -1, "two"]:
		var r := population_config({"start": 2, "growth_surplus": bad, "famine": FAMINE})
		has_msg(r[1], "'population.growth_surplus' must be an integer >= 1")


# --- AC8: the manual action is gone ---

func test_manual_growth_is_gone() -> void:
	var e := growth_engine()
	for method in ["grow", "grow_error", "grow_cost"]:
		check(not e.has_method(method), "GameEngine.%s is gone" % method)
	var view_vars: Array = (load("res://ui/territory_view.gd") as Script).get_script_property_list().map(
		func(p): return p.name)
	check(not view_vars.has("grow_button"), "the territory view has no Grow button")


func test_the_grow_op_still_adds_pop() -> void:
	var e := make_engine({"festival": 10}, {"population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}})
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e)), "play Festival")
	eq(e.pop(home), 3, "Festival's +1 pop")
