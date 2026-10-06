extends "res://tests/lib/tech_case.gd"
## The built signal (357): the engine's built(uid) for a building, unit or upgrade put into play from the build menu,
## emitted once before changed; never for a refused build, a hand card played, a create effect or a settled city.

const WARRIORS := {"id": "warriors", "name": "Warriors", "type": "unit", "cost": {"food": 2}, "strength": 2,
	"tags": ["military"]}
const PLOUGH := {"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "upgrade_of": "farm"}
const MENU := {"farm": {}, "warriors": {}, "plough": {}}


## A game with build_menu MENU, no government (unlimited actions), Homeland at 3 pop and food food; farms and Settlers
## in the deck.
func built_engine(food := 20) -> GameEngine:
	var o := {"build_menu": MENU, "population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"starting": {"resources": {"food": food, "wealth": 10, "insight": 0}, "tableau": ["capital"],
			"territory": "homeland"}}
	var e := tech_engine(["pottery"], {"farm": 5, "settler": 5}, o, [WARRIORS, PLOUGH])
	e.resources.food = food
	return e


## Records e's built signals as "built: <uid>" and its changed signals as "changed", in order.
func record_built(e: GameEngine) -> Array:
	var out := []
	e.built.connect(func(uid: int): out.append("built: %d" % uid))
	e.changed.connect(func(): out.append("changed"))
	return out


## The uids of the cards id in e's tableau.
func uids_of(e: GameEngine, id: String) -> Array:
	return e.zone("tableau").cards.filter(func(c): return c.def.id == id).map(func(c): return c.uid)


# --- AC1: a building or a unit ---

func test_building_emits_built_with_the_new_card_before_changed() -> void:
	var e := built_engine()
	var got := record_built(e)
	check(e.build("farm", home_uid(e)), "build a Farm on Homeland")
	var farms := uids_of(e, "farm")
	eq(farms.size(), 1, "one Farm built")
	if farms.size() == 1:
		eq(got, ["built: %d" % farms[0], "changed"], "built once with the Farm, then changed")


func test_recruiting_emits_built_with_the_unit() -> void:
	var e := built_engine()
	var got := record_built(e)
	check(e.build("warriors", home_uid(e)), "recruit Warriors on Homeland")
	var units := uids_of(e, "warriors")
	eq(units.size(), 1, "one Warriors recruited")
	if units.size() == 1:
		eq(got.filter(func(s): return s.begins_with("built")), ["built: %d" % units[0]], "built once with the unit")


func test_a_refused_build_emits_nothing() -> void:
	var e := built_engine(1)
	var got := record_built(e)
	check(not e.build("farm", home_uid(e)), "a Farm costs 2 food: refused with 1")
	eq(got, [], "no built, no changed")


func test_other_arrivals_emit_no_built() -> void:
	var e := built_engine()
	var got := record_built(e)
	check(e.play_card(uid_of(e.zone("hand"), "farm")), "play a Farm from the hand")
	check(e.play_card(uid_of(e.zone("hand"), "settler")), "a Settler creates a City")
	eq(got.filter(func(s): return s.begins_with("built")), [], "no built for a hand card or a create")


func test_settling_a_territory_emits_no_built() -> void:
	var e := make_engine({"pioneer": 10}, {"territory_deck": {"hills": 1}})
	to_frontier(e, ["hills"])
	e.resources.food = 3
	var got := record_built(e)
	check(e.play_card(first_in_hand(e)), "a Pioneer settles the Hills")
	eq(got.filter(func(s): return s.begins_with("built")), [], "a city settled is no build")


# --- AC2: an upgrade ---

func test_building_an_upgrade_emits_built_with_the_upgrade() -> void:
	var e := built_engine()
	check(e.build("farm", home_uid(e)), "build a Farm")
	var farm: int = uids_of(e, "farm")[0]
	var got := record_built(e)
	check(e.build("plough", farm), "build a Plough on the Farm")
	var ploughs := uids_of(e, "plough")
	eq(ploughs.size(), 1, "one Plough")
	if ploughs.size() == 1:
		eq(got, ["built: %d" % ploughs[0], "changed"], "built once with the Plough, then changed")
		eq(e.upgrade_base(ploughs[0]), farm, "on the Farm")
