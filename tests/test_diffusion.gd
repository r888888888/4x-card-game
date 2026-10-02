extends "res://tests/lib/tech_case.gd"
## Diffusion (backlog 142): a tech costs 1 insight less for each era the game has added past its own, together with
## civilization discounts and eurekas, never below 1. Local fixtures: Astronomy (era 2, 5), Philosophy (era 3, 6),
## Brine (era 1, 4, eureka −2 with 1 city card) and Sages (civilization, techs −1 insight).

const ASTRONOMY := {"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2}
const PHILOSOPHY := {"id": "philosophy", "name": "Philosophy", "type": "tech", "cost": {"insight": 6}, "era": 3}
const BRINE := {"id": "brine", "name": "Brine", "type": "tech", "cost": {"insight": 4},
	"eureka": {"tag": "city", "count": 1, "off": 2}}
const SAGES := {"id": "sages", "name": "Sages", "type": "civilization", "discounts": [{"type": "tech", "insight": 1}]}
const FIXTURES := [ASTRONOMY, PHILOSOPHY, BRINE, SAGES]


## A game with Loom, Brine and Pottery in era 1, Astronomy in era 2 and Philosophy in era 3; civ as given ("" none).
func diffusion_engine(civ := "") -> GameEngine:
	var starting := {"resources": {"food": 2, "insight": 20}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var o := {"starting": starting,
		"research_deck": {"loom": 1, "brine": 1, "pottery": 1, "astronomy": 1, "philosophy": 1}}
	return tech_engine(["loom", "brine", "pottery"], {"farm": 10}, o, TEST_CIVS + FIXTURES)


## tech_cost of tech id in the research deck.
func cost_of(e: GameEngine, id: String) -> int:
	return e.tech_cost(uid_of(e.zone("research_deck"), id))


## The tech_tree() entry for id ({} if missing).
func entry(e: GameEngine, id: String) -> Dictionary:
	for t in e.tech_tree():
		if t.id == id:
			return t
	return {}


# --- AC1: an era-1 tech gets cheaper each era ---

func test_an_era_1_tech_costs_1_less_per_later_era() -> void:
	var e := diffusion_engine()
	eq(cost_of(e, "loom"), 4, "era 1")
	e.add_era(2)
	eq(cost_of(e, "loom"), 3, "era 2: 4 − 1")
	e.add_era(3)
	eq(cost_of(e, "loom"), 2, "era 3: 4 − 2")
	eq(entry(e, "loom").get("cost"), 2, "the tree shows the price now")


# --- AC2: no diffusion in a tech's own era ---

func test_a_tech_has_no_diffusion_in_its_own_era() -> void:
	var e := diffusion_engine()
	e.add_era(2)
	eq(cost_of(e, "astronomy"), 5, "era 2 tech in era 2")
	e.add_era(3)
	eq(cost_of(e, "astronomy"), 4, "era 2 tech in era 3: 5 − 1")


# --- AC3: with discounts and eurekas, never below 1 ---

func test_diffusion_stacks_with_discounts_and_eurekas_but_never_below_1() -> void:
	var e := diffusion_engine("sages")
	eq(cost_of(e, "brine"), 1, "era 1: 4 − 1 civilization − 2 eureka")
	e.add_era(2)
	e.add_era(3)
	eq(cost_of(e, "brine"), 1, "era 3: 4 − 1 − 2 − 2 stops at 1")


# --- AC4: future techs and the details ---

func test_a_future_tech_keeps_its_printed_cost_in_the_tree() -> void:
	var e := diffusion_engine()
	e.add_era(2)
	eq(entry(e, "philosophy").get("state"), GameEngine.TECH_FUTURE, "Philosophy waits for era 3")
	eq(entry(e, "philosophy").get("cost"), 6, "printed")


func test_the_details_list_the_older_era_discount() -> void:
	var e := diffusion_engine()
	e.add_era(2)
	e.add_era(3)
	var d: Dictionary = e.card_details(uid_of(e.zone("research_deck"), "loom"))
	check(d.get("state", []).has("Costs 2 insight now (printed 4, −2 older era)"), "state: %s" % [d.get("state")])
