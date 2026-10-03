extends "res://tests/lib/tech_case.gd"
## Civilization discounts (backlog 108): a civilization's `discounts` lowers what some cards cost while it's yours.
## A `type` or `tag` filter lowers a hand card's play_cost and a tech's tech_cost; `supply: true` lowers buy_price.
## Local fixtures (so other tests load while the field is missing): civilizations Scholars (techs −1 insight),
## Builders (wonders −3 wealth) and Traders (supply −1 wealth); buildings Obelisk (12 wealth, wonder) and Cairn
## (2 wealth + 1 food, wonder); tech Awl (1 insight). TECHS from tech_case: Loom 4, Iron 6.

const SCHOLARS := {"id": "scholars", "name": "Scholars", "type": "civilization", "discounts": [{"type": "tech", "insight": 1}]}
const BUILDERS := {"id": "builders", "name": "Builders", "type": "civilization", "discounts": [{"tag": "wonder", "wealth": 3}]}
const TRADERS := {"id": "traders", "name": "Traders", "type": "civilization", "discounts": [{"supply": true, "wealth": 1}]}
const OBELISK := {"id": "obelisk", "name": "Obelisk", "type": "building", "cost": {"wealth": 12}, "tags": ["wonder"]}
const CAIRN := {"id": "cairn", "name": "Cairn", "type": "building", "cost": {"wealth": 2, "food": 1}, "tags": ["wonder"]}
const AWL := {"id": "awl", "name": "Awl", "type": "tech", "cost": {"insight": 1}}
const FIXTURES := [SCHOLARS, BUILDERS, TRADERS, OBELISK, CAIRN, AWL]
const SUPPLY := {"supply": {"scout": {"price": 3, "count": 2}, "shrine": {"price": 1, "count": 1}}}


## A civilization "x" with discounts value.
func civ_with(value: Variant) -> Dictionary:
	return {"id": "x", "name": "X", "type": "civilization", "discounts": value}


## A game as civilization civ ("" for none) with Loom then Dye on the research deck, 20 wealth, 20 insight and the
## test supply.
func discount_game(civ: String) -> GameEngine:
	var starting := {"resources": {"food": 2, "wealth": 20, "insight": 20}, "tableau": ["capital"], "territory": "homeland"}
	if civ != "":
		starting["civilization"] = civ
	var o := {"starting": starting}
	o.merge(SUPPLY)
	return tech_engine(["loom", "dye"], {"farm": 10}, o, TEST_CIVS + FIXTURES)


# --- AC1: loading and text ---

func test_discounts_load() -> void:
	var r := fixture_load(FIXTURES, [TECHS, TEST_CIVS])
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_discounts_validation() -> void:
	check_cases([
		["unknown type", [civ_with([{"type": "wizard", "wealth": 1}])], ["card 'x'", "discounts"]],
		["unknown resource", [civ_with([{"tag": "wonder", "gold": 1}])], ["card 'x'", "discounts", "gold"]],
		["no filter", [civ_with([{"wealth": 1}])], ["card 'x'", "discounts"]],
		["two filters", [civ_with([{"type": "tech", "tag": "wonder", "wealth": 1}])], ["card 'x'", "discounts"]],
		["amount 0", [civ_with([{"type": "tech", "wealth": 0}])], ["card 'x'", "discounts"]],
		["no amount", [civ_with([{"type": "tech"}])], ["card 'x'", "discounts"]],
		["not a list", [civ_with({"type": "tech", "wealth": 1})], ["card 'x'", "discounts"]],
		["on a building", [{"id": "x", "name": "X", "type": "building", "discounts": [{"type": "tech", "wealth": 1}]}],
			"'discounts' only applies to civilizations", "warning_only"],
	], func(extra): return fixture_load(extra, [TECHS, TEST_CIVS]))


func test_discount_text() -> void:
	var cards: Dictionary = fixture_load(FIXTURES, [TECHS, TEST_CIVS]).cards
	for row in [["scholars", "Techs cost 1 less insight."], ["builders", "Wonders cost 3 less wealth."],
			["traders", "Supply cards cost 1 less wealth."]]:
		if not cards.has(row[0]):
			check(false, "%s should load" % row[0])
			continue
		eq(cards[row[0]].rules_text(cards), row[1], "%s's face" % row[0])
		eq(cards[row[0]].rules_tooltip(cards), row[1], "%s's tooltip" % row[0])


# --- AC2: techs ---

func test_a_tech_discount_lowers_tech_cost_and_what_buy_tech_charges() -> void:
	var e: GameEngine = discount_game("scholars")
	var loom := uid_of(e.zone("research_deck"), "loom")
	eq(e.tech_cost(loom), 3, "Loom 4 − 1")
	e.resources.insight = 3
	eq(e.buy_tech_error(loom), "", "3 insight is enough")
	check(e.buy_tech(loom), "buy Loom")
	eq(e.resources.insight, 0, "charged 3")


func test_a_tech_discount_never_takes_a_tech_below_1() -> void:
	var e: GameEngine = discount_game("scholars")
	e.create_card("iron", "research_deck", null)
	e.create_card("awl", "research_deck", null)
	eq(e.tech_cost(uid_of(e.zone("research_deck"), "iron")), 5, "Iron 6 − 1")
	eq(e.tech_cost(uid_of(e.zone("research_deck"), "awl")), 1, "Awl 1 − 1 stops at 1")


# --- AC3: playing from hand ---

func test_a_tag_discount_lowers_play_cost_and_what_a_play_charges() -> void:
	var e: GameEngine = discount_game("builders")
	var obelisk := put_in_hand(e, "obelisk")
	eq(e.play_cost(obelisk), {"wealth": 9}, "Obelisk 12 − 3")
	e.resources.wealth = 9
	eq(e.play_error(obelisk), "", "9 wealth is enough")
	check(e.play_card(obelisk), "play Obelisk")
	eq(e.resources.wealth, 0, "charged 9")


func test_a_discount_never_takes_a_cost_below_0_and_skips_other_cards() -> void:
	var e: GameEngine = discount_game("builders")
	var cairn := put_in_hand(e, "cairn")
	eq(e.play_cost(cairn).get("wealth"), 0, "Cairn's 2 wealth − 3 stops at 0")
	eq(e.play_cost(cairn).get("food"), 1, "its food is untouched")
	eq(e.play_cost(put_in_hand(e, "farm")), {"food": 2}, "a card without the tag")
	var s: GameEngine = discount_game("scholars")
	eq(s.play_cost(put_in_hand(s, "obelisk")), {"wealth": 12}, "a tech discount doesn't touch a building")


# --- AC4: the supply ---

func test_a_supply_discount_lowers_buy_price_and_what_buy_charges() -> void:
	var e: GameEngine = discount_game("traders")
	eq(e.buy_price("scout"), 2, "Scout 3 − 1")
	e.resources.wealth = 2
	check(e.buy("scout"), "buy a Scout: %s" % e.buy_error("scout"))
	eq(e.resources.wealth, 0, "charged 2")
	eq(e.buy_price("shrine"), 0, "Shrine 1 − 1")
	check(e.buy("shrine"), "a free Shrine: %s" % e.buy_error("shrine"))
	check(not e.buy("shrine"), "the pile of 1 is empty")


# --- AC5: no discount ---

func test_costs_are_unchanged_without_discounts() -> void:
	for civ in ["", "tribe"]:
		var e: GameEngine = discount_game(civ)
		eq(e.play_cost(put_in_hand(e, "obelisk")), {"wealth": 12}, "%s: play_cost" % civ)
		eq(e.buy_price("scout"), 3, "%s: buy_price" % civ)
		eq(e.tech_cost(uid_of(e.zone("research_deck"), "loom")), 4, "%s: tech_cost" % civ)


# --- 136: play_cost with no game ---

func test_bug_136_play_cost_is_empty_before_a_game_starts() -> void:
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", [] as Array[String], [] as Array[String], keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 10}), resources(), cards, "test", [] as Array[String], [] as Array[String])
	var e := GameEngine.new(cards, config)
	eq(e.play_cost(-1), {}, "no hand before new_game")


func test_bug_136_play_cost_is_empty_for_a_card_not_in_the_hand() -> void:
	var e := make_engine({"farm": 10})
	eq(e.play_cost(-1), {}, "uid -1 isn't in the hand")


# --- 232: a supply pile's play cost ---

## discount_game(civ) whose supply also sells Obelisk and Cairn.
func supply_cost_game(civ: String) -> Object:  # Object until supply_play_cost exists (red phase)
	var e := discount_game(civ)
	e.state.supply.merge({"obelisk": 2, "cairn": 2})
	return e


func test_a_supply_piles_play_cost_takes_off_the_civilizations_tag_discount() -> void:
	eq(supply_cost_game("builders").supply_play_cost("obelisk"), {"wealth": 9}, "Obelisk 12 − 3")
	eq(supply_cost_game("builders").supply_play_cost("cairn"), {"wealth": 0, "food": 1}, "Cairn: wealth floors at 0")
	eq(supply_cost_game("").supply_play_cost("obelisk"), {"wealth": 12}, "no civilization: the printed cost")


func test_a_supply_discount_lowers_the_buy_price_but_not_the_play_cost() -> void:
	var e := supply_cost_game("traders")
	eq(e.supply_play_cost("obelisk"), {"wealth": 12}, "the play cost is printed")
	eq(e.buy_price("scout"), 2, "the buy price is 3 − 1")


func test_a_card_with_no_supply_pile_has_no_supply_play_cost() -> void:
	var e := supply_cost_game("builders")
	eq(e.supply_play_cost("farm"), {}, "Farm has no pile")
	eq(e.supply_play_cost("nonsense"), {}, "no such card")
