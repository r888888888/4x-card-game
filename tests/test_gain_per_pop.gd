extends "res://tests/lib/anarchy_case.gd"
## The gain_per_pop op (backlog 304): gains amount × ⌊pop on the card's own territory / per⌋. Fixtures are local (not in
## TEST_CARDS) so other tests load while the op is missing: Counting House (building, ⟳ +1 wealth per 3 pop here) and
## Tally (building, ⟳ +1 wealth per pop here, amount and per left out).

const COUNT := {"op": "gain_per_pop", "resource": "wealth", "amount": 1, "per": 3, "trigger": "upkeep"}
const COUNTING_HOUSE := {"id": "counting_house", "name": "Counting House", "type": "building", "effects": [COUNT]}
const TALLY := {"id": "tally", "name": "Tally", "type": "building",
	"effects": [{"op": "gain_per_pop", "resource": "wealth", "trigger": "upkeep"}]}
const PER_POP := {"op": "gain_per_pop", "resource": "wealth"}  # on play, amount and per left out


## A make_engine game with the fixtures and extra, population on (no food upkeep, no pop VP) unless population is
## false, Grassland settled with pop 5, Homeland set to home_pop and 0 wealth.
func pop_engine(home_pop: int, population := true, extra := []) -> GameEngine:
	var o := {"territory_deck": {"grassland": 1}}
	if population:
		o["population"] = {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}
	var e := make_engine({"farm": 10}, o, 1, [COUNTING_HOUSE, TALLY] + extra)
	settle(e, ["grassland"])
	e.zone("tableau").find(uid_of(e.zone("tableau"), "grassland")).pop = 5
	set_home_pop(e, home_pop)
	e.resources.food = 50
	e.resources.wealth = 0
	return e


## The wealth one upkeep adds in a pop_engine game with buildings on Homeland (in order, the last idle first):
## [forecast, actual].
func upkeep_wealth(home_pop: int, buildings: Array, population := true) -> Array:
	var e := pop_engine(home_pop, population)
	var base: int = e.upkeep_forecast().wealth  # what Homeland's other cards make, without the buildings
	build_on(e, home_uid(e), buildings)
	var forecast: int = e.upkeep_forecast().wealth - base
	e.end_turn()
	return [forecast, e.resources.wealth - base]


## Loader result for one card x of type with effect (and extra fields).
func load_card(type: String, effect: Dictionary, fields := {}) -> Dictionary:
	var card := card_with(type, effect)
	card.merge(fields)
	return fixture_load([card], [TEST_GOVS], RESOURCES)


## COUNT with key set to value (or removed when value is null).
func count_with(key: String, value: Variant) -> Dictionary:
	var effect := COUNT.duplicate(true)
	if value == null:
		effect.erase(key)
	else:
		effect[key] = value
	return effect


# --- AC1: amount × ⌊pop here / per⌋, at upkeep and in the forecast ---

func test_gains_per_pop_on_its_own_territory_at_upkeep() -> void:
	eq(upkeep_wealth(7, ["counting_house"]), [2, 2], "pop 7: 1 × ⌊7 / 3⌋ (forecast, upkeep)")
	eq(upkeep_wealth(2, ["counting_house"]), [0, 0], "pop 2: ⌊2 / 3⌋ = 0")
	eq(upkeep_wealth(9, ["counting_house"]), [3, 3], "pop 9: ⌊9 / 3⌋ = 3")


func test_pop_on_other_territories_does_not_count() -> void:
	var e := pop_engine(2)
	var grassland := uid_of(e.zone("tableau"), "grassland")
	var base: int = e.upkeep_forecast().wealth
	build_on(e, home_uid(e), ["tally"])
	eq(e.upkeep_forecast().wealth - base, 2, "Tally on Homeland (pop 2) ignores Grassland's 5")
	build_on(e, grassland, ["tally"])
	eq(e.upkeep_forecast().wealth - base, 7, "and a Tally on Grassland counts its 5")


# --- AC2: defaults, validation, unrest ---

func test_gain_per_pop_loads_with_defaults() -> void:
	var r := load_card("building", {"op": "gain_per_pop", "resource": "food", "trigger": "upkeep"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")
	if r.cards.has("x"):
		eq(r.cards.x.effects[0].get("amount"), 1, "amount defaults to 1")
		eq(r.cards.x.effects[0].get("per"), 1, "per defaults to 1")
	eq(upkeep_wealth(4, ["tally"]), [4, 4], "per 1: 1 wealth per pop")


func test_gain_per_pop_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["missing resource", count_with("resource", null), prefix + "missing 'resource'"],
		["unknown resource", count_with("resource", "gold"), [prefix, "'resource'"]],
		["amount 0", count_with("amount", 0), prefix + "'amount' must be an integer >= 1"],
		["amount not an integer", count_with("amount", 1.5), prefix + "'amount' must be an integer >= 1"],
		["per 0", count_with("per", 0), prefix + "'per' must be an integer >= 1"],
		["per not an integer", count_with("per", 2.5), prefix + "'per' must be an integer >= 1"],
	], func(effect): return load_card("building", effect).errors)


func test_gaining_unrest_per_pop_stops_at_the_unrest_limit() -> void:
	var riot := {"id": "riot", "name": "Riot", "type": "building",
		"effects": [{"op": "gain_per_pop", "resource": "unrest", "trigger": "upkeep"}]}
	var e := anarchy_engine({}, {}, [riot])  # Chiefs: unrest limit 5; Homeland pop 6
	e.resources.unrest = 3
	build_on(e, home_uid(e), ["riot"])
	e.end_turn()
	eq(e.resources.unrest, 5, "3 + 6 stops at the limit 5")


# --- AC3: needs its own territory ---

func test_gain_per_pop_on_a_card_with_no_territory_is_a_load_error() -> void:
	check_cases([
		["tech", ["tech", {"cost": {"insight": 2}}], ["card 'x'", "can't act on its own territory"]],
		["event", ["event", {}], ["card 'x'", "can't act on its own territory"]],
		["government", ["government", {"unrest_limit": 5}], ["card 'x'", "can't act on its own territory"]],
		["unit", ["unit", {"strength": 1}], ["card 'x'", "a unit effect can't act on its own territory"]],
	], func(args): return load_card(args[0], PER_POP, args[1]).errors)


func test_an_action_with_no_territory_gains_nothing() -> void:
	var e := pop_engine(7, true, [card_with("action", PER_POP)])
	var uid := put_in_hand(e, "x")
	check(e.play_card(uid), "play x: %s" % e.play_error(uid))
	eq(e.resources.wealth, 0, "no territory: no pop to count")


func test_gains_nothing_with_population_off() -> void:
	eq(upkeep_wealth(7, ["tally"], false), [0, 0], "population off, Homeland pop set to 7 anyway")


# --- AC4: upkeep-safe; idle gains nothing ---

func test_gain_per_pop_may_trigger_on_upkeep() -> void:
	var r := load_card("building", COUNT)
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_an_idle_building_gains_nothing() -> void:
	eq(upkeep_wealth(1, ["farm", "tally"]), [0, 0], "pop 1 works the Farm; the Tally is idle")


# --- AC5: card text ---

func test_gain_per_pop_card_text() -> void:
	var cards: Dictionary = load_card("action", count_with("trigger", null)).cards
	var per_one: Dictionary = load_card("action", {"op": "gain_per_pop", "resource": "food"}).cards
	if not cards.has("x") or not per_one.has("x"):
		check(false, "x should load")
		return
	eq(cards.x.rules_text(cards), "+1 wealth per 3 pop here", "rules_text")
	eq(cards.x.rules_tooltip(cards), "+1 wealth for every 3 pop on this territory", "rules_tooltip")
	eq(per_one.x.rules_text(per_one), "+1 food per pop here", "rules_text, per 1")
	eq(per_one.x.rules_tooltip(per_one), "+1 food for every pop on this territory", "rules_tooltip, per 1")
