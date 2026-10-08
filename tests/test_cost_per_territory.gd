extends "res://tests/lib/test_case.gd"
## Cost per territory (backlog 320): a card's `cost_per_territory` adds to its cost once per settled territory, before
## the civilization's discounts. Local fixtures: Colonist (action, 5 food + 1 food per territory, tag expand, settles a
## City), and civilizations Claimants (expand cards −2 food) and Landed (expand cards −20 food).

const COLONIST := {"id": "colonist", "name": "Colonist", "type": "action", "cost": {"food": 5},
	"cost_per_territory": {"food": 1}, "tags": ["expand"], "effects": [{"op": "settle", "card": "city"}]}
const CLAIMANTS := {"id": "claimants", "name": "Claimants", "type": "civilization",
	"discounts": [{"tag": "expand", "food": 2}]}
const LANDED := {"id": "landed", "name": "Landed", "type": "civilization", "discounts": [{"tag": "expand", "food": 20}]}
const FIXTURES := [COLONIST, CLAIMANTS, LANDED]
const WITH_UNREST: Array[String] = ["food", "wealth", "insight", "unrest"]
## The territories settled after the Homeland, in order; the frontier gets the two Rivers.
const LANDS := ["grassland", "grassland", "hills", "hills", "jungle"]


## A game with a hand of Colonists (Pioneers when pioneers), the Homeland plus territories − 1 more settled, both
## Rivers on the frontier, food food and civilization civ ("" for none); a Colonist supply pile.
func colonist_engine(territories: int, food := 20, civ := "", pioneers := false) -> GameEngine:
	var starting := {"resources": {}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var o := {"starting": starting, "supply": {"colonist": {"price": 1, "count": 2}},
		"territory_deck": {"grassland": 2, "hills": 2, "jungle": 1, "river": 2}}
	var e := make_engine({"pioneer" if pioneers else "colonist": 10}, o, 1, FIXTURES)
	settle(e, LANDS.slice(0, territories - 1))
	to_frontier(e, ["river", "river"])
	e.resources.food = food  # after the first turn's upkeep
	return e


## The first frontier territory's uid.
func frontier_uid(e: GameEngine) -> int:
	return e.zone("frontier").cards[0].uid


func territories_in(e: GameEngine) -> int:
	return e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size()


# --- AC1: the price grows with the realm ---

func test_the_cost_grows_by_the_step_for_each_settled_territory() -> void:
	var one := colonist_engine(1)
	eq(one.play_cost(first_in_hand(one)), {"food": 6}, "play_cost with 1 territory: 5 + 1")
	var three := colonist_engine(3)
	eq(three.play_cost(first_in_hand(three)), {"food": 8}, "play_cost with 3 territories (2 more on the frontier)")


func test_a_card_without_cost_per_territory_costs_its_printed_cost() -> void:
	var e := colonist_engine(3, 20, "", true)
	eq(e.play_cost(first_in_hand(e)), {"food": 3}, "a Pioneer's play_cost with 3 territories")


# --- AC2: paying it ---

func test_playing_it_pays_the_grown_cost() -> void:
	var e := colonist_engine(3, 8)
	check(e.play_card(first_in_hand(e), frontier_uid(e)), "play: %s" % e.play_error(first_in_hand(e)))
	eq([e.resources.food, territories_in(e)], [0, 4], "[food, territories]: paid 8 and settled a 4th")


func test_it_cant_be_played_short_of_the_grown_cost() -> void:
	var e := colonist_engine(3, 7)
	var uid := first_in_hand(e)
	eq(e.play_error(uid), "Colonist needs 8 food (you have 7).", "play_error")
	check(not e.play_card(uid, frontier_uid(e)), "the play is refused")
	eq([e.resources.food, territories_in(e), e.zone("hand").size()], [7, 3, 5], "[food, territories, hand]: unchanged")


# --- AC3: it counts at once ---

func test_a_new_territory_raises_the_next_cost_at_once() -> void:
	var e := colonist_engine(1, 13)
	check(e.play_card(first_in_hand(e), frontier_uid(e)), "first play: %s" % e.play_error(first_in_hand(e)))
	eq(e.resources.food, 7, "the first paid 6")
	eq(e.play_cost(first_in_hand(e)), {"food": 7}, "the second's play_cost with 2 territories")


# --- AC4: discounts and the supply ---

func test_discounts_come_off_after_the_surcharge() -> void:
	var e := colonist_engine(3, 20, "claimants")
	eq(e.play_cost(first_in_hand(e)), {"food": 6}, "5 + 3 − 2")
	var landed := colonist_engine(3, 20, "landed")
	eq(landed.play_cost(first_in_hand(landed)), {"food": 0}, "never below 0")


func test_the_supply_pile_shows_the_grown_cost() -> void:
	var e := colonist_engine(3)
	eq(e.supply_play_cost("colonist"), {"food": 8}, "supply_play_cost with 3 territories")
	eq(e.supply_play_cost("colonist"), e.play_cost(first_in_hand(e)), "the same as a copy in hand")


# --- AC5: loader and text ---

func test_cost_per_territory_loads_with_its_text() -> void:
	var r := fixture_load(FIXTURES, [], WITH_UNREST)
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	var colonist: CardDef = r.cards.colonist
	eq(colonist.get("cost_per_territory"), {"food": 1}, "Colonist's cost_per_territory")
	check(colonist.rules_text(r.cards).contains("Costs 1 more food for each territory you hold."),
		"face: %s" % colonist.rules_text(r.cards))
	check(colonist.rules_tooltip(r.cards).contains("Costs 1 more food for each territory you hold."),
		"tooltip: %s" % colonist.rules_tooltip(r.cards))


func test_cost_per_territory_validation() -> void:
	var with_step := func(step: Variant) -> Array:
		return [{"id": "x", "name": "X", "type": "action", "cost": {"food": 5}, "cost_per_territory": step}]
	check_cases([
		["unknown resource", with_step.call({"gold": 1}), ["card 'x'", "cost_per_territory", "gold"]],
		["0", with_step.call({"food": 0}), ["card 'x'", "cost_per_territory", "food"]],
		["not a number", with_step.call({"food": "lots"}), ["card 'x'", "cost_per_territory", "food"]],
		["not an object", with_step.call(2), ["card 'x'", "cost_per_territory"]],
		["unrest", with_step.call({"unrest": 1}), ["card 'x'", "cost_per_territory", "unrest can't be paid"]],
		["on a project", [{"id": "x", "name": "X", "type": "building", "cost": {"wealth": 10}, "project": true,
			"cost_per_territory": {"wealth": 1}}], ["card 'x'", "cost_per_territory", "project"]],
	], fixture_load.bind([], WITH_UNREST))
