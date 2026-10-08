extends "res://tests/lib/test_case.gd"
## The fallen-back cards in one pass (backlog 408): `fallen_uids(e)` holds exactly the tableau cards whose
## `fallen_back_reason` is non-empty, and the queries that test every tableau card (`score()`, `score_breakdown()`,
## `housing()`, `Population.smallest_with_room`) give the answers the per-card rules give. Fixtures: Shed (vp 1, housing 1) →
## Loft (needs a Village, vp 1) → Spire (vp 2), Hut (needs a Town, vp 1, housing 2), Obelisk (a project,
## 12 wealth, vp 5); tiers Hamlet 0, Village 4, Town 8.

const SHED := {"id": "shed", "name": "Shed", "type": "building", "vp": 1, "housing": 1}
const LOFT := {"id": "loft", "name": "Loft", "type": "building", "upgrade_of": "shed", "tier": "village", "vp": 1}
const SPIRE := {"id": "spire", "name": "Spire", "type": "building", "upgrade_of": "loft", "vp": 2}
const HUT := {"id": "hut", "name": "Hut", "type": "building", "tier": "town", "vp": 1, "housing": 2}
const OBELISK := {"id": "obelisk", "name": "Obelisk", "type": "building", "cost": {"wealth": 12}, "vp": 5,
	"project": true}
const PASS_CARDS := [SHED, LOFT, SPIRE, HUT, OBELISK]
const PASS_TIERS := [
	{"id": "hamlet", "name": "Hamlet", "pop": 0, "slots": 0},
	{"id": "village", "name": "Village", "pop": 4, "slots": 1},
	{"id": "town", "name": "Town", "pop": 8, "slots": 2},
]
## What each position builds, territory by territory, in order (an upgrade goes on the card before it).
const HOME_CARDS := ["hut", "shed", "loft", "spire", "obelisk", "shed", "shed"]
const GRASS_CARDS := ["shed", "loft", "spire", "shed", "loft"]


## A game on TEST_CARDS + PASS_CARDS with HOME_CARDS on Homeland (pop 4, a Village) and GRASS_CARDS on a settled
## Grassland (pop 1, a Hamlet), no bonus score. population: "tiers" (vp_per_pop 1, PASS_TIERS), "no_tiers" or "off".
## Upgrades go on the card before them (base_uid).
func pass_engine(population: String) -> GameEngine:
	var o := {"territory_deck": {"grassland": 1}}
	if population != "off":
		o["population"] = {"start": 2, "food_upkeep": 0, "vp_per_pop": 1}
		if population == "tiers":
			o.population["tiers"] = PASS_TIERS
	var e := make_engine({"scout": 10}, o, 1, PASS_CARDS)
	settle(e, ["grassland"])
	var home := home_uid(e)
	var grass := uid_of(e.zone("tableau"), "grassland")
	if population != "off":
		set_home_pop(e, 4)
		e.zone("tableau").find(grass).pop = 1
	place(e, home, HOME_CARDS)
	place(e, grass, GRASS_CARDS)
	e.bonus_score = 0
	return e


## Builds ids on territory in order, each upgrade (a def with upgrade_of) on the card placed just before it.
func place(e: GameEngine, territory: int, ids: Array) -> void:
	var last: CardInstance = null
	for id in ids:
		var card: CardInstance = e.create_card(id, "tableau", null)
		card.territory_uid = territory
		if (e.card_db[id] as CardDef).upgrade_of != "" and last != null:
			card.base_uid = last.uid
		last = card


## The tableau uids whose fallen_back_reason is non-empty: the per-card rule fallen_uids must match.
func fallen_by_reason(e: GameEngine) -> Dictionary:
	var out := {}
	for card in e.zone("tableau").cards:
		if e.fallen_back_reason(card.uid) != "":
			out[card.uid] = true
	return out


## The reasons of the tableau cards with id, in tableau order.
func reasons(e: GameEngine, id: String) -> Array:
	var out := []
	for card in e.zone("tableau").cards:
		if card.def.id == id:
			out.append(e.fallen_back_reason(card.uid))
	return out


## The score as the rule states it: printed VP of every tableau and always-on card neither fallen back nor an
## unfinished site, plus bonus score, plus pop × vp_per_pop.
func score_by_rule(e: GameEngine) -> int:
	var total := e.bonus_score
	for z in ["tableau"] + GameEngine.ALWAYS_ON_ZONES:
		for card in e.zone(z).cards:
			if z == "tableau" and (e.fallen_back_reason(card.uid) != "" or Sites.unfinished(e, card)):
				continue
			total += card.def.vp
	if e.population_on():
		total += e.total_pop() * e.config.population.vp_per_pop
	return total


## Fallback.fallen_uids(e), called dynamically until it exists.
func fallen_uids(e: GameEngine) -> Dictionary:
	var fallback = load("res://engine/fallback.gd")
	return fallback.fallen_uids(e)


## Settled territory t's housing as the rule states it: its own plus every building on it that hasn't fallen back
## (idle ones too), at least 1. The fixtures have no housing modifier.
func housing_by_rule(e: GameEngine, t: int) -> int:
	var total: int = e.zone("tableau").find(t).def.housing
	for card in e.zone("tableau").cards:
		if card.def.type == CardDef.BUILDING and card.territory_uid == t and e.fallen_back_reason(card.uid) == "":
			total += card.def.housing
	return maxi(1, total)


## The settled territories whose pop is under housing_by_rule, smallest pop first (ties: tableau order).
func room_by_rule(e: GameEngine) -> Array:
	var out := e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY \
		and c.pop < housing_by_rule(e, c.uid))
	out.sort_custom(func(a, b): return a.pop < b.pop)
	return out.map(func(c): return c.uid)


func breakdown_sum(e: GameEngine) -> int:
	var total := 0
	for row in e.score_breakdown():
		total += row.amount
	return total


# --- AC1: the set matches the per-card rule ---

func test_the_positions_cover_every_cause() -> void:
	var e := pass_engine("tiers")
	eq(reasons(e, "hut"), ["Needs a Town."], "below its own tier")
	eq(reasons(e, "loft"), ["", "Needs a Village.", "Its Shed is idle."], "a Loft that works, one below its tier, one on an idle Shed")
	eq(reasons(e, "spire"), ["", "Its Loft has fallen back."], "a Spire on a fallen Loft")
	var idle_sheds := e.zone("tableau").cards.filter(func(c): return c.def.id == "shed" and e.is_idle(c.uid))
	eq(idle_sheds.size(), 2, "two idle Sheds: Homeland's last (5 workers on 4 pop) and Grassland's second")
	eq(idle_sheds.map(func(c): return e.fallen_back_reason(c.uid)), ["", ""], "idle, not fallen back")


func test_fallen_uids_is_the_cards_with_a_reason() -> void:
	for population in ["tiers", "no_tiers", "off"]:
		var e := pass_engine(population)
		eq(fallen_uids(e), fallen_by_reason(e), population)


func test_fallen_uids_with_tiers_off_holds_only_the_idle_bases_upgrades() -> void:
	var e := pass_engine("no_tiers")
	eq(reasons(e, "loft"), ["", "", "Its Shed is idle."], "tiers off: only the idle Shed's Loft")
	eq(fallen_uids(e).size(), 1, "one card")


func test_fallen_uids_is_empty_with_population_off() -> void:
	eq(fallen_uids(pass_engine("off")), {}, "nothing idle, nothing below a tier")


# --- AC2: the score ---

func test_score_counts_what_the_rule_counts() -> void:
	for population in ["tiers", "no_tiers", "off"]:
		var e := pass_engine(population)
		e.bonus_score = 3
		eq([e.score(), breakdown_sum(e)], [score_by_rule(e), score_by_rule(e)], population)


func test_score_in_the_mixed_position() -> void:
	var e := pass_engine("tiers")
	# Capital 2; Homeland: Shed 1, Loft 1, Spire 2, Shed 1, the idle Shed 1 (Hut fallen, Obelisk unfinished);
	# Grassland: Shed 1 and the idle Shed 1 (both Lofts and the Spire fallen); 5 pop × 1.
	eq(e.score(), 15, "the score")
	eq(breakdown_sum(e), 15, "the breakdown")


# --- AC3: housing ---

func test_housing_and_room_count_what_the_rule_counts() -> void:
	for population in ["tiers", "no_tiers"]:
		var e := pass_engine(population)
		for t in [home_uid(e), uid_of(e.zone("tableau"), "grassland")]:
			eq(e.housing(t), housing_by_rule(e, t), "%s: housing of %d" % [population, t])
		eq(Population.smallest_with_room(e).map(func(c): return c.uid), room_by_rule(e), "%s: room" % population)


func test_a_fallen_buildings_housing_returns_with_its_tier() -> void:
	var e := pass_engine("tiers")
	var home := home_uid(e)
	var housing := e.housing(home)
	set_home_pop(e, 8)
	eq(e.housing(home), housing + 2, "the Hut works at a Town: its 2 housing counts")


# --- AC4: nothing changes ---

func test_the_queries_change_nothing() -> void:
	var e := pass_engine("tiers")
	var before := state_dump(e.state)
	var emitted := []
	e.changed.connect(func(): emitted.append(true))
	e.score()
	e.score_breakdown()
	fallen_uids(e)
	e.housing(home_uid(e))
	Population.smallest_with_room(e)
	eq(state_dump(e.state), before, "the state")
	eq(emitted, [], "nothing emitted")
