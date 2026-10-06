extends "res://tests/lib/anarchy_case.gd"
## Admin unrest (backlog 319): a government administers up to N settled territories; the k-th territory past that cap
## adds k unrest at the start of upkeep (1, 3, 6, 10 in all). Techs and other cards raise the cap with the
## `administers` modifier. Fixtures, on top of anarchy_case's: Stewards (government, limit 20, administers 3), Overseers
## (limit 20, administers 3, tolerates Village), Census (tech, administers +2) and Office (building, administers +1).

const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
]
const STEWARDS := {"id": "stewards", "name": "Stewards", "type": "government", "unrest_limit": 20, "administers": 3}
const OVERSEERS := {"id": "overseers", "name": "Overseers", "type": "government", "unrest_limit": 20,
	"administers": 3, "tolerates": "village"}
const CENSUS := {"id": "census", "name": "Census", "type": "tech", "cost": {"insight": 1},
	"modifiers": {"administers": 2}}
const OFFICE := {"id": "office", "name": "Office", "type": "building", "modifiers": {"administers": 1}}
const ADMIN_FIXTURES := [STEWARDS, OVERSEERS, CENSUS, OFFICE]
## The territories settled after the Homeland, in order.
const LANDS := ["grassland", "grassland", "grassland", "hills", "hills", "jungle", "jungle", "river", "river"]


## An anarchy game with gov ruling ("" for none), unrest on hand, the Homeland plus territories − 1 more settled (pop 0
## each; the Homeland keeps 6), and the fixture tiers when tiers; overrides last.
func admin_engine(territories: int, gov := "stewards", unrest := 0, tiers := false, overrides := {}) -> GameEngine:
	var population: Dictionary = POP.duplicate()
	if tiers:
		population["tiers"] = TIERS
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"population": population, "starting": starting,
		"territory_deck": {"grassland": 3, "hills": 2, "jungle": 2, "river": 2}}
	o.merge(overrides, true)
	var e := anarchy_engine({}, o, ADMIN_FIXTURES)
	settle(e, LANDS.slice(0, territories - 1))
	for t in e.zone("tableau").cards:
		if t.def.type == CardDef.TERRITORY and t.uid != home_uid(e):
			t.pop = 0
	if e.unrest_on():
		e.resources["unrest"] = unrest
	return e


## {errors, warnings, cards} from loading TEST_CARDS, TEST_GOVS, anarchy_case's and the admin fixtures plus extra.
func admin_load(extra := []) -> Dictionary:
	return fixture_load(extra, [TEST_GOVS, FIXTURES, ADMIN_FIXTURES], RESOURCES)


# --- AC1: admin unrest at upkeep ---

func test_territories_within_the_cap_add_no_unrest() -> void:
	var e := admin_engine(3)
	eq(e.admin_unrest(), 0, "admin_unrest with 3 territories, cap 3")
	e.end_turn()
	eq(e.resources.unrest, 0, "unrest after upkeep")


func test_each_territory_past_the_cap_adds_one_more_unrest_than_the_last() -> void:
	for case in [[4, 1], [5, 3], [6, 6]]:
		var e := admin_engine(case[0])
		eq(e.admin_unrest(), case[1], "admin_unrest with %d territories, cap 3" % case[0])
		e.end_turn()
		eq(e.resources.unrest, case[1], "unrest after upkeep with %d territories" % case[0])


func test_frontier_territories_add_no_admin_unrest() -> void:
	var e := admin_engine(3)
	to_frontier(e, ["river", "river"])
	eq(e.admin_unrest(), 0, "admin_unrest: 3 settled, 2 on the frontier")


# --- AC2: the cap and its modifier ---

func test_the_cap_is_the_governments_administers() -> void:
	eq(admin_engine(1).admin_cap(), 3, "Stewards administers 3")


func test_a_researched_administers_modifier_raises_the_cap() -> void:
	var e := admin_engine(5)
	put_in(e, "census", "researched")
	eq([e.admin_cap(), e.admin_unrest()], [5, 0], "[admin_cap, admin_unrest] with Census, 5 territories")
	var six := admin_engine(6)
	put_in(six, "census", "researched")
	eq(six.admin_unrest(), 1, "admin_unrest with Census, 6 territories")


func test_only_a_working_building_raises_the_cap() -> void:
	var e := admin_engine(2)
	build_on(e, uid_of(e.zone("tableau"), "grassland"), ["office"])
	eq(e.admin_cap(), 3, "an idle Office (pop 0 there) adds nothing")
	build_on(e, home_uid(e), ["office"])
	eq(e.admin_cap(), 4, "a working Office on the Homeland adds 1")


func test_without_administers_there_is_no_cap() -> void:
	eq(admin_engine(1, "chiefs").admin_cap(), -1, "Chiefs sets no administers")
	eq(admin_engine(1, "").admin_cap(), -1, "no government rules")


# --- AC3: order and limit ---

func test_admin_unrest_stops_at_the_unrest_limit() -> void:
	var e := admin_engine(5, "stewards", 18)
	e.end_turn()
	eq(e.resources.unrest, 20, "18 + 3 stops at the limit 20")
	check(Anarchy.active(e) != null, "the turn falls into Anarchy")


func test_admin_unrest_comes_before_calming_upkeep() -> void:
	var e := admin_engine(4)
	build_on(e, home_uid(e), ["calm"])
	e.end_turn()
	eq(e.resources.unrest, 0, "0 + 1 admin − 1 Calm: calming applies after admin unrest is added")


func test_admin_unrest_adds_to_size_unrest() -> void:
	var e := admin_engine(5, "overseers", 0, true)
	e.zone("tableau").find(uid_of(e.zone("tableau"), "hills")).pop = 9
	eq([e.size_unrest(), e.admin_unrest()], [1, 3], "[size_unrest: one Town, admin_unrest: 2 past the cap]")
	e.end_turn()
	eq(e.resources.unrest, 4, "both are added at upkeep")


# --- AC4: when it doesn't apply ---

func test_a_government_without_administers_adds_no_admin_unrest() -> void:
	var e := admin_engine(10, "chiefs")
	eq(e.admin_unrest(), 0, "Chiefs administers any number")
	e.end_turn()
	eq(e.resources.unrest, 0, "unrest after upkeep")


func test_anarchy_adds_no_admin_unrest() -> void:
	var e := admin_engine(6, "stewards", 20)
	e.end_turn()
	check(Anarchy.active(e) != null, "precondition: Anarchy rules")
	eq(e.admin_unrest(), 0, "admin_unrest under Anarchy")
	var unrest: int = e.resources.unrest
	e.end_turn()
	check(e.resources.unrest <= unrest, "Anarchy's upkeep adds no admin unrest: %d → %d" % [unrest, e.resources.unrest])


func test_without_unrest_there_is_no_admin_unrest() -> void:
	var e := admin_engine(6, "stewards", 0, false, {"resources": ["food", "wealth", "insight"], "unrest": null})
	check(not e.unrest_on(), "precondition: unrest off")
	eq(e.admin_unrest(), 0, "admin_unrest with unrest off")
	e.end_turn()
	check(not e.resources.has("unrest"), "no unrest is added")


# --- AC5: the forecast ---

func test_the_forecast_counts_admin_unrest() -> void:
	var e := admin_engine(5)
	eq(e.upkeep_forecast().get(GameEngine.UNREST), 3, "forecast unrest, 2 past the cap")
	build_on(e, home_uid(e), ["calm"])
	eq(e.upkeep_forecast().get(GameEngine.UNREST), 2, "forecast: +3 admin, −1 Calm")


# --- AC6: loader and text ---

func test_administers_loads_and_shows_in_the_government_text() -> void:
	var r := admin_load()
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	var stewards: CardDef = r.cards.stewards
	eq(stewards.get("administers"), 3, "Stewards' administers")
	check(stewards.rules_text(r.cards).contains("Administers up to 3 territories."), "face: %s" % stewards.rules_text(r.cards))
	check(stewards.rules_tooltip(r.cards).contains("Administers up to 3 territories."),
		"tooltip: %s" % stewards.rules_tooltip(r.cards))
	check(not r.cards.chiefs.rules_text(r.cards).contains("Administers"), "Chiefs has no administers line")


func test_administers_on_the_wrong_type_is_a_load_warning() -> void:
	check_cases([
		["on a building", [{"id": "x", "name": "X", "type": "building", "administers": 3}],
			"'administers' only applies to governments (ignored)", "warning_only"],
	], admin_load)


func test_administers_must_be_at_least_1() -> void:
	for bad in [0, "lots"]:
		var r := admin_load([{"id": "x", "name": "X", "type": "government", "administers": bad}])
		check(r.errors.any(func(m): return m.contains("'x'") and m.contains("administers") and m.contains(str(bad))),
			"administers %s is an error naming the card, the field and the value: %s" % [bad, r.errors])


func test_the_administers_modifier_loads_with_its_text() -> void:
	var r := admin_load([{"id": "x", "name": "X", "type": "tech", "cost": {"insight": 1},
		"modifiers": {"administers": -1}}])
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	check(r.cards.census.rules_text(r.cards).contains("Administration cap +2"), "Census: %s" % r.cards.census.rules_text(r.cards))
	check(r.cards.x.rules_text(r.cards).contains("Administration cap −1"), "X: %s" % r.cards.x.rules_text(r.cards))
