extends "res://tests/lib/test_case.gd"
## An upgrade that frees its base's worker (415, `frees_worker`): a building with one built on it uses no worker, so it
## works with no pop and that pop can staff another building, but it still takes its slot. Covers the loader and the
## card text. Fixtures: Hut and Shed (nothing) and Yoke (an upgrade of Farm, cost 1 wealth, frees_worker).

const HUT := {"id": "hut", "name": "Hut", "type": "building", "cost": {"wealth": 1}}
const SHED := {"id": "shed", "name": "Shed", "type": "building", "cost": {"wealth": 1}}
const YOKE := {"id": "yoke", "name": "Yoke", "type": "building", "cost": {"wealth": 1}, "upgrade_of": "farm",
	"frees_worker": true}
const MENU := {"farm": {}, "hut": {}, "shed": {}, "yoke": {}}
const RULE := "Frees its Farm's worker."


## A game with population on (no food upkeep), the build menu MENU, 20 food and 20 wealth, and Homeland at pop.
func yoke_engine(pop := 2) -> GameEngine:
	var starting := {"resources": {"food": 20, "wealth": 20}, "tableau": ["capital"], "territory": "homeland"}
	var o := {"build_menu": MENU, "population": {"start": pop, "food_upkeep": 0, "vp_per_pop": 0}, "starting": starting,
		"territory_deck": {"grassland": 1}}
	var e := make_engine({"scout": 10}, o, 1, [HUT, SHED, YOKE])
	set_home_pop(e, pop)
	return e


## Builds id from the menu on target (a territory, or a base for an upgrade), failing the test if it refuses: its uid.
func built(e: GameEngine, id: String, target: int) -> int:
	check(e.build(id, target), "build %s on %d: %s" % [id, target, e.build_error(id, target)])
	return e.zone("tableau").cards.back().uid


## Whether each of uids is idle in e.
func idle(e: GameEngine, uids: Array) -> Array:
	return uids.map(func(uid: int) -> bool: return e.is_idle(uid))


## Checks that upkeep_forecast's food and wealth match what the next upkeep does in e.
func check_forecast_holds(e: GameEngine, what: String) -> void:
	var forecast := e.upkeep_forecast()
	var held := [e.resources.food, e.resources.wealth]
	e.end_turn()
	eq([e.resources.food - held[0], e.resources.wealth - held[1]], [forecast.food, forecast.wealth],
		"%s: upkeep did what the forecast said" % what)


# --- AC1: it frees the worker ---

func test_a_yoke_frees_its_farms_worker_for_another_building() -> void:
	var e := yoke_engine()
	var home := home_uid(e)
	var farm := built(e, "farm", home)
	var hut := built(e, "hut", home)
	eq(e.free_workers(home), 0, "2 pop: Farm and Hut")
	built(e, "yoke", farm)
	eq(e.free_workers(home), 1, "the ploughed Farm uses none")
	var shed := built(e, "shed", home)
	eq(idle(e, [farm, hut, shed]), [false, false, false], "all three work")


# --- AC2: it works with no pop ---

func test_a_ploughed_farm_works_with_no_pop() -> void:
	var e := yoke_engine()
	var home := home_uid(e)
	var farm := built(e, "farm", home)
	var yoke := built(e, "yoke", farm)
	var bare := built(e, "farm", home)
	set_home_pop(e, 0)
	eq(idle(e, [farm, bare]), [false, true], "the ploughed Farm works; the bare one is idle")
	eq(e.fallen_back_reason(yoke), "", "the Yoke works")
	var food: int = e.resources.food
	e.end_turn()
	eq(e.resources.food - food, 1 + 2, "the ploughed Farm 1 + Capital 2")


func test_workers_skip_the_ploughed_farm() -> void:
	var e := yoke_engine()
	var home := home_uid(e)
	var farm := built(e, "farm", home)
	built(e, "yoke", farm)
	var hut := built(e, "hut", home)
	var shed := built(e, "shed", home)
	set_home_pop(e, 1)
	eq(idle(e, [farm, hut, shed]), [false, false, true], "1 pop goes to the Hut; the Shed is idle")


# --- AC3: it still takes a slot ---

func test_a_ploughed_farm_past_the_slots_is_idle_and_its_yoke_falls_back() -> void:
	var e := yoke_engine()
	settle(e, ["grassland"])  # 2 slots
	var grassland := uid_of(e.zone("tableau"), "grassland")
	e.zone("tableau").find(grassland).pop = 3
	build_on(e, grassland, ["hut", "shed", "farm"])
	var farm: int = e.zone("tableau").cards.back().uid
	var yoke := upgrade_on(e, "yoke", farm)
	check(e.is_idle(farm), "the Farm is past Grassland's 2 slots")
	eq(e.fallen_back_reason(yoke), "Its Farm is idle.", "the Yoke falls back")
	eq(e.free_slots(grassland), 0, "no room made")


# --- AC4: taking it away ---

func test_abandoning_the_yoke_takes_the_worker_back() -> void:
	var e := yoke_engine()
	var home := home_uid(e)
	var farm := built(e, "farm", home)
	var hut := built(e, "hut", home)
	var yoke := built(e, "yoke", farm)
	var shed := built(e, "shed", home)
	check_forecast_holds(e, "ploughed")
	check(e.abandon(yoke), "abandon the Yoke: %s" % e.abandon_error(yoke))
	eq(e.free_workers(home), 0, "the Farm uses a worker again")
	eq(idle(e, [farm, hut, shed]), [false, false, true], "the last in tableau order is idle")
	check_forecast_holds(e, "unploughed")


# --- AC5: the loader ---

func test_frees_worker_loads_on_an_upgrade() -> void:
	check_loads([
		["an upgrade that frees a worker", YOKE.merged({"id": "x"}, true), {"cards.x.frees_worker": true}],
		["a building without it", {"id": "x", "name": "X", "type": "building"}, {"cards.x.frees_worker": false}],
	], card_load)


func test_bad_frees_worker_fields_are_load_errors() -> void:
	var upgrade := {"id": "x", "name": "X", "type": "building", "upgrade_of": "farm"}
	check_cases([
		["not a bool", upgrade.merged({"frees_worker": "yes"}), "cards.json: card 'x': 'frees_worker' must be true or false"],
		["not an upgrade", {"id": "x", "name": "X", "type": "building", "frees_worker": true},
			"cards.json: card 'x': frees_worker: only an upgrade can free its base's worker"],
		["with a tier", upgrade.merged({"tier": "village", "frees_worker": true}),
			"cards.json: card 'x': frees_worker: an upgrade that frees a worker can't need a tier"],
		["on an action", {"id": "x", "name": "X", "type": "action", "frees_worker": true},
			"'frees_worker' only applies to buildings (ignored)", "warning_only"],
	], card_load)
	check_cases([
		["on an upgrade's upgrade", {"id": "x", "name": "X", "type": "building", "upgrade_of": "yoke",
			"frees_worker": true}, "cards.json: card 'x': frees_worker: 'yoke' is an upgrade and uses no worker"],
	], func(card: Dictionary) -> Dictionary: return card_load(card, [[YOKE.merged({"frees_worker": false}, true)]]))


# --- AC6: the card text ---

func test_a_yoke_says_it_frees_its_farms_worker() -> void:
	var e := yoke_engine()
	var d: Dictionary = e.def_details("yoke")
	check(d.get("rules", []).has(RULE), "Yoke's rules have '%s': %s" % [RULE, d.get("rules")])
	eq(term_text(d, "Frees a worker"),
		"Its Farm needs no worker: it works with no pop there, and that pop can work another building.", "its term")
	check(not e.def_details("farm").get("rules", []).has(RULE), "a Farm reads as today")
	check(not term_names(e.def_details("farm")).has("Frees a worker"), "and has no such term")
