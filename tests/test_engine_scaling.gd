extends "res://tests/lib/tech_case.gd"
## How engine queries scale with the tableau (backlog 150): which cards work (Modifiers.working_cards, behind
## modifier(), upkeep and the forecast) is one pass over the tableau, and a eureka check stops once its count is met.
## Scaling is a ratio of two best_time_usec timings, so it holds on any machine. Local fixture: Mill, a building with
## +1 hand_size and +1 food on upkeep.

const MILL := {"id": "mill", "name": "Mill", "type": "building", "modifiers": {"hand_size": 1},
	"effects": [{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
const POP := {"start": 1, "food_upkeep": 0, "vp_per_pop": 0}


## A game with Mill loaded, Hills in the territory deck and population as given ({} for off).
func mill_engine(population: Dictionary) -> GameEngine:
	var o := {"territory_deck": {"hills": 1}}
	if not population.is_empty():
		o["population"] = population
	return tech_engine(["pottery"], {"farm": 10}, o, [MILL])


## Settles Hills, then places Mills in the order A1, B1, A2, B2, B3 (A the home territory with pop 1, B Hills with
## pop 2 when population is on). Returns the Mills' uids in that order.
func interleaved_mills(e: GameEngine) -> Array[int]:
	settle(e, ["hills"])
	var a := home_uid(e)
	var b := uid_of(e.zone("tableau"), "hills")
	if e.population_on():
		e.zone("tableau").find(a).pop = 1
		e.zone("tableau").find(b).pop = 2
	var uids: Array[int] = []
	for t in [a, b, a, b, b]:
		build_on(e, t, ["mill"])
		uids.append(e.zone("tableau").cards[-1].uid)
	return uids


## A game with n more settled territories (Grassland, pop 1 with population on), each with one Mill.
func wide_engine(n: int) -> GameEngine:
	var e := mill_engine(POP)
	for i in n:
		var land: CardInstance = e.create_card("grassland", "tableau", null)
		land.pop = 1
		build_on(e, land.uid, ["mill"])
	return e


# --- AC1, AC2: which cards work is unchanged ---

func test_buildings_past_their_territorys_pop_are_idle_when_interleaved() -> void:
	var e := mill_engine(POP)
	var mills := interleaved_mills(e)
	eq(mills.map(func(uid): return e.is_idle(uid)), [false, false, true, false, true], "A1, B1, A2, B2, B3 idle")
	eq(e.modifier("hand_size"), 3, "A1, B1 and B2's modifiers")
	eq(e.upkeep_forecast().get("food"), 2 + 3, "the Capital and A1, B1, B2")


func test_with_population_off_every_building_works() -> void:
	var e := mill_engine({})
	var mills := interleaved_mills(e)
	eq(mills.map(func(uid): return e.is_idle(uid)), [false, false, false, false, false], "none idle")
	eq(e.modifier("hand_size"), 5, "all five Mills")
	eq(e.upkeep_forecast().get("food"), 2 + 5, "the Capital and five Mills")


# --- AC3: modifier() is linear in the tableau ---

func test_modifiers_scale_linearly_with_the_tableau() -> void:
	var small := wide_engine(50)
	var large := wide_engine(400)
	eq(small.modifier("hand_size"), 50, "every Mill works (small)")
	eq(large.modifier("hand_size"), 400, "every Mill works (large)")
	var ratio := float(best_time_usec(func(): large.modifier("actions"))) / best_time_usec(func(): small.modifier("actions"))
	check(ratio < 16.0, "8× the tableau costs %.1f× the time (linear ~8, quadratic ~64)" % ratio)


# --- AC4: a eureka check stops at its count ---

func test_a_met_eureka_check_does_not_grow_with_the_tableau() -> void:
	var lore := {"id": "lore", "name": "Lore", "type": "tech", "cost": {"insight": 3},
		"eureka": {"card": "farm", "count": 1, "off": 1}}
	var engines := []
	for extra in [50, 400]:
		var e: GameEngine = tech_engine(["lore"], {"farm": 10}, {}, [lore])
		var tableau: Zone = e.zone("tableau")
		var farm: CardInstance = e.create_card("farm", "tableau", null)
		tableau.cards.erase(farm)
		tableau.cards.insert(0, farm)
		for i in extra:
			e.create_card("village", "tableau", null)
		eq(e.tech_cost(uid_of(e.zone("research_deck"), "lore")), 2, "the eureka is met (+%d cards)" % extra)
		engines.append(e)
	var lore_of := func(e: GameEngine) -> int: return uid_of(e.zone("research_deck"), "lore")
	var small: GameEngine = engines[0]
	var large: GameEngine = engines[1]
	var small_uid: int = lore_of.call(small)
	var large_uid: int = lore_of.call(large)
	var ratio := float(best_time_usec(func(): large.tech_cost(large_uid))) / best_time_usec(func(): small.tech_cost(small_uid))
	check(ratio < 3.0, "8× the cards after the Farm cost %.1f× the time (the check should stop at the Farm)" % ratio)
