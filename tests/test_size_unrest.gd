extends "res://tests/lib/anarchy_case.gd"
## Size unrest (backlog 282): a government tolerates territories up to a settlement tier (281); each settled territory
## above it adds +1 unrest per tier above, at the start of upkeep. Fixtures, on top of anarchy_case's: Elders
## (government, limit 10, tolerates Village), Plague (event, 2 turns, ⟳ −1 pop) and a Hall (building, no effect).

const TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
	{"id": "metropolis", "name": "Metropolis", "pop": 13, "slots": 3},
]
const ELDERS := {"id": "elders", "name": "Elders", "type": "government", "unrest_limit": 10, "tolerates": "village"}
const PLAGUE := {"id": "plague", "name": "Plague", "type": "event", "discard": {"turns": 2},
	"effects": [{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}]}
const SIZE_FIXTURES := [ELDERS, PLAGUE]
## The AC1 territories: Homeland (Hamlet), Grassland (Village), Hills (Town), River (Metropolis).
const AC1_POPS := {"homeland": 2, "grassland": 5, "hills": 9, "river": 13}


## An anarchy game with the fixture tiers (null for none), gov ruling ("" for none), unrest on hand, and Grassland,
## Hills and River settled; overrides last. Every territory starts at pop 0.
func size_engine(gov := "elders", unrest := 0, tiers: Variant = TIERS, overrides := {}) -> GameEngine:
	var population: Dictionary = POP.duplicate()
	if tiers != null:
		population["tiers"] = tiers
	var starting := {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
		"territory": "homeland"}
	if gov != "":
		starting["government"] = gov
	var o := {"population": population, "starting": starting,
		"territory_deck": {"grassland": 1, "hills": 1, "river": 1}}
	o.merge(overrides, true)
	var e := anarchy_engine({}, o, SIZE_FIXTURES)
	settle(e, ["grassland", "hills", "river"])
	for t in e.zone("tableau").cards:
		if t.def.type == CardDef.TERRITORY:
			t.pop = 0
	if e.unrest_on():
		e.resources["unrest"] = unrest
	return e


## Sets the pop of the settled territory with card id id.
func set_pop_of(e: GameEngine, id: String, n: int) -> void:
	e.zone("tableau").find(uid_of(e.zone("tableau"), id)).pop = n


func set_pops(e: GameEngine, pops: Dictionary) -> void:
	for id in pops:
		set_pop_of(e, id, pops[id])


## A size_engine with the AC1 territories.
func ac1_engine(gov := "elders", unrest := 0, tiers: Variant = TIERS, overrides := {}) -> GameEngine:
	var e := size_engine(gov, unrest, tiers, overrides)
	set_pops(e, AC1_POPS)
	return e


## {errors, warnings, cards} from loading TEST_CARDS, TEST_GOVS, anarchy_case's and the size fixtures plus extra, then
## a config with population (tiers: TIERS, or none when tiers is null) and Elders ruling.
func size_load(extra := [], tiers: Variant = TIERS) -> Dictionary:
	var r := fixture_load(extra, [TEST_GOVS, FIXTURES, SIZE_FIXTURES], RESOURCES)
	var errors: Array[String] = r.errors.duplicate()
	var warnings: Array[String] = r.warnings.duplicate()
	var population: Dictionary = POP.duplicate()
	if tiers != null:
		population["tiers"] = tiers
	var raw := anarchy_raw({}, {"population": population})
	var listed: Array[String] = []
	listed.assign(raw.resources)
	DataLoader.parse_config(raw, listed, r.cards, "config.json", errors, warnings)
	return {"errors": errors, "warnings": warnings, "cards": r.cards}


# --- AC1: size unrest at upkeep ---

func test_each_tier_above_the_tolerated_one_adds_1_unrest_at_upkeep() -> void:
	var e := ac1_engine()
	eq(e.size_unrest(), 3, "size_unrest: Hamlet 0 + Village 0 + Town 1 + Metropolis 2")
	e.end_turn()
	eq(e.resources.unrest, 3, "the next turn starts with unrest 3")


func test_a_lone_town_adds_1_unrest() -> void:
	var e := size_engine()
	set_pop_of(e, "hills", 9)
	eq(e.size_unrest(), 1, "size_unrest: one Town")
	e.end_turn()
	eq(e.resources.unrest, 1, "unrest after upkeep")


# --- AC2: the tier is read when upkeep starts ---

func test_size_unrest_counts_the_pop_before_upkeep_takes_any() -> void:
	var e := size_engine()
	set_pop_of(e, "grassland", 8)
	put_in(e, "plague", "active_events")
	e.end_turn()
	eq([e.pop(uid_of(e.zone("tableau"), "grassland")), e.resources.unrest], [7, 1],
		"[pop, unrest]: the Plague took 1 pop, but the Town was counted")
	e.end_turn()
	eq(e.resources.unrest, 1, "at pop 7 (a Village) the next upkeep adds nothing")


# --- AC3: it stops at the limit ---

func test_size_unrest_stops_at_the_unrest_limit() -> void:
	var e := ac1_engine("elders", 9)
	e.end_turn()
	eq(e.resources.unrest, 10, "9 + 3 stops at the limit 10")
	check(Anarchy.active(e) != null, "the turn falls into Anarchy")


# --- AC4: when it doesn't apply ---

func test_a_government_without_tolerates_adds_no_size_unrest() -> void:
	var e := ac1_engine("chiefs")
	eq(e.size_unrest(), 0, "Chiefs tolerates any size")
	e.end_turn()
	eq(e.resources.unrest, 0, "unrest after upkeep")


func test_no_government_adds_no_size_unrest() -> void:
	var e := ac1_engine("")
	eq([e.government(), e.size_unrest()], [-1, 0], "[government, size_unrest] with none ruling")
	e.end_turn()
	eq(e.resources.unrest, 0, "unrest after upkeep")


func test_anarchy_adds_no_size_unrest() -> void:
	var e := ac1_engine("elders", 10)
	e.end_turn()
	check(Anarchy.active(e) != null, "precondition: Anarchy rules")
	eq(e.size_unrest(), 0, "size_unrest under Anarchy")
	var unrest: int = e.resources.unrest
	e.end_turn()
	check(e.resources.unrest <= unrest, "Anarchy's upkeep adds no size unrest: %d → %d" % [unrest, e.resources.unrest])


func test_without_unrest_there_is_no_size_unrest() -> void:
	var e := ac1_engine("elders", 0, TIERS, {"resources": ["food", "wealth", "insight"], "unrest": null})
	check(not e.unrest_on(), "precondition: unrest off")
	eq(e.size_unrest(), 0, "size_unrest with unrest off")
	e.end_turn()
	check(not e.resources.has("unrest"), "no unrest is added")


func test_without_tiers_there_is_no_size_unrest() -> void:
	var e := ac1_engine("elders", 0, null)
	eq(e.size_unrest(), 0, "size_unrest with tiers off")
	e.end_turn()
	eq(e.resources.unrest, 0, "unrest after upkeep")


# --- AC5: the forecast ---

func test_the_forecast_counts_size_unrest() -> void:
	var e := ac1_engine()
	eq(e.upkeep_forecast().get(GameEngine.UNREST), 3, "forecast unrest")


func test_size_unrest_comes_before_calming_upkeep() -> void:
	var e := ac1_engine()
	build_on(e, home_uid(e), ["calm"])
	eq(e.upkeep_forecast().get(GameEngine.UNREST), 2, "forecast: +3 size, −1 Calm")
	e.end_turn()
	eq(e.resources.unrest, 2, "0 + 3 − 1: the Calm lowers what size added")


# --- AC6: loader and text ---

func test_tolerates_loads_and_shows_in_the_government_text() -> void:
	var r := size_load()
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	var elders: CardDef = r.cards.elders
	eq(elders.get("tolerates"), "village", "Elders' tolerates")
	check(elders.rules_text(r.cards).contains("Tolerates up to Village."), "face: %s" % elders.rules_text(r.cards))
	check(elders.rules_tooltip(r.cards).contains("Tolerates up to Village."), "tooltip: %s" % elders.rules_tooltip(r.cards))
	check(not r.cards.chiefs.rules_text(r.cards).contains("Tolerates"), "Chiefs has no tolerance line")


func test_tolerates_only_applies_to_governments() -> void:
	var r := size_load([{"id": "x", "name": "X", "type": "building", "tolerates": "village"}])
	eq(r.errors, [] as Array[String], "errors")
	has_msg(r.warnings, "'tolerates' only applies to governments (ignored)")


func test_tolerates_must_be_a_tier_id() -> void:
	var unknown := size_load([{"id": "x", "name": "X", "type": "government", "tolerates": "castle"}])
	check(unknown.errors.any(func(m): return m.contains("'x'") and m.contains("tolerates") and m.contains("castle")),
		"an unknown tier is an error naming the card, tolerates and the id: %s" % [unknown.errors])
	var not_text := size_load([{"id": "x", "name": "X", "type": "government", "tolerates": 2}])
	check(not_text.errors.any(func(m): return m.contains("'x'") and m.contains("tolerates")),
		"a non-string is an error: %s" % [not_text.errors])


func test_tolerates_with_tiers_off_is_a_warning() -> void:
	var r := size_load([], null)
	eq(r.errors, [] as Array[String], "errors")
	check(r.warnings.any(func(m): return m.contains("elders") and m.contains("tolerates") and m.contains("ignored")),
		"a warning naming the card and tolerates: %s" % [r.warnings])
