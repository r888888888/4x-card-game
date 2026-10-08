extends "res://tests/lib/tech_case.gd"
## Card details (backlog 056): def_details(card_id) and card_details(uid) give a card's full rules, its live state
## and an explanation of every mechanic it uses.
## In detail (from docs/testing.md, 331): `def_details` / `card_details`: rules, live state (pop, slots, idle, tech
## price now), terms and generated keyword terms; a tech's `gives` and its rules without the given lines (289)

## A tech with a prerequisite and the default discount (2): printed 5 wealth.
const CHARIOT := {"id": "chariot", "name": "Chariot", "type": "tech", "cost": {"insight": 5}, "prereq": "bronze"}


## Population on (start pop, no food upkeep or pop VP), a hand of Farms and 20 food.
func pop_engine(start: int) -> GameEngine:
	var e: GameEngine = make_engine({"farm": 10}, {"population": {"start": start, "food_upkeep": 0, "vp_per_pop": 0}})
	e.resources.food = 20
	return e


# --- AC1: a building's details ---

func test_farm_details_have_name_type_cost_rules_and_terms() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var d: Dictionary = e.def_details("farm")
	eq(d.get("name"), "Farm", "name")
	eq(d.get("type"), "Building", "type")
	eq(d.get("cost"), "2 food", "cost")
	eq(d.get("vp"), 0, "vp")
	eq(d.get("rules"), ["Each upkeep: +1 food"] as Array[String], "rules")
	eq(d.get("state"), [] as Array[String], "no state for a definition")
	eq(term_names(d), ["Workers"] as Array[String], "terms in first-use order, without the basic ones (112)")
	for term in term_names(d):
		check(term_text(d, term) != "", "%s has text" % term)


func test_card_details_of_a_hand_card_match_its_definition() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var d: Dictionary = e.card_details(first_in_hand(e))
	eq(d.get("name"), "Farm", "name")
	eq(d.get("rules"), ["Each upkeep: +1 food"] as Array[String], "rules")
	eq(d.get("state"), [] as Array[String], "nothing to report in the hand")


func test_action_effects_explain_their_mechanics() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	check(term_names(e.def_details("explorer")).has("Explore"), "Explorer explains Explore")
	check(term_names(e.def_details("pioneer")).has("Settle"), "Pioneer explains Settle")
	check(term_names(e.def_details("festival")).has("Grow"), "Festival explains Grow")


# --- AC2: keyword terms come from the card data ---

func test_keyword_terms_name_the_cards_that_use_the_keyword() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var well: Dictionary = e.def_details("well")
	eq(term_names(well), ["Requires", "Fresh Water", "Workers"] as Array[String], "Well terms")
	var fresh := term_text(well, "Fresh Water")
	check("Well" in fresh, "Fresh Water names Well, which needs it: '%s'" % fresh)
	check(not "Paddy" in fresh, "Fresh Water doesn't name Paddy: '%s'" % fresh)
	var flood := term_text(e.def_details("paddy"), "Flood Plain")
	check("Paddy" in flood, "Flood Plain names Paddy, which gets a bonus on it: '%s'" % flood)


# --- AC3: a territory in play ---

func test_territory_details_show_pop_slots_and_workers() -> void:
	var e := pop_engine(2)
	var home := home_uid(e)
	check(e.play_card(first_in_hand(e), home), "Farm on Homeland")
	var d: Dictionary = e.card_details(home)
	eq(d.get("state"), ["Pop 2 / housing 7", "Slots 1 / 5 used", "Free workers 1"] as Array[String], "state")
	check(term_names(d).has("Housing"), "term Housing in %s" % [term_names(d)])


func test_rolled_resource_keyword_shows_in_rules_and_terms() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var resource_keywords: Array[String] = ["gold"]
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + [
		{"id": "mint", "name": "Mint", "type": "building", "requires": ["gold"]}]},
		resources(), "t", errors, warnings, keywords(), resource_keywords)
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {
		"resource_keywords": ["gold"],
		"territory_resources": {"hills": [{"keywords": ["gold"], "weight": 1}]},
		"territory_deck": {"hills": 1},
	}), resources(), cards, "t", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e: GameEngine = GameEngine.new(cards, config)
	e.new_game(1)
	settle(e, ["hills"])
	var d: Dictionary = e.card_details(uid_of(e.zone("tableau"), "hills"))
	check(d.get("rules", []).any(func(line): return "Gold" in line), "rules mention Gold: %s" % [d.get("rules")])
	check(term_names(d).has("Gold"), "term Gold in %s" % [term_names(d)])
	check("Mint" in term_text(d, "Gold"), "Gold names Mint")


# --- AC4: an idle building ---

func test_idle_building_says_it_has_no_worker() -> void:
	var e := pop_engine(2)
	var home := home_uid(e)
	var first := first_in_hand(e)
	check(e.play_card(first, home), "Farm 1")
	var second := first_in_hand(e)
	check(e.play_card(second, home), "Farm 2")
	e.zone("tableau").find(home).pop = 1
	check(e.is_idle(second), "the newer Farm is idle")
	var idle := "Idle: no free worker (skips upkeep)"
	check(e.card_details(second).get("state", []).has(idle), "idle Farm: %s" % [e.card_details(second).get("state")])
	check(not e.card_details(first).get("state", []).has(idle), "working Farm isn't idle")
	check(e.card_details(first).get("state", []).has("On Homeland"), "a building names its territory")


# --- AC5: a tech's price now ---

func test_a_tech_in_the_research_deck_explains_its_price_now() -> void:
	var e := tech_engine(["chariot", "bronze"], {"farm": 10}, {}, [CHARIOT])
	check(e.buy_tech(uid_of(e.zone("research_deck"), "bronze")), "learn Bronze Working")
	var d: Dictionary = e.card_details(uid_of(e.zone("research_deck"), "chariot"))
	check(d.get("state", []).has("Costs 5 insight now (printed 5)"), "state: %s" % [d.get("state")])
	check(not term_names(d).has("Passes"), "no term Passes (140) in %s" % [term_names(d)])
	check(term_names(d).has("Prerequisite"), "term Prerequisite in %s" % [term_names(d)])


# --- AC6: unknown cards ---

func test_unknown_cards_have_no_details() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	eq(e.card_details(-1), {}, "card_details(-1)")
	eq(e.def_details("nope"), {}, "def_details(\"nope\")")


## Backlog 107 (AC13, bug): before any game starts (the new game screen), a card's details are {} with no error, and a
## definition's details still work.
func test_bug_107_card_details_before_a_game_starts() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards(TEST_CARDS, resources(), "test", errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"farm": 10}), resources(), cards, "test", errors, warnings)
	var e: GameEngine = GameEngine.new(cards, config)  # no new_game: no zones yet
	eq(e.card_details(-1), {}, "no card has live details before a game")
	eq(e.def_details("farm").get("name", ""), "Farm", "a definition's details work before a game")


# --- 112: the basic terms are left out ---

func test_basic_terms_are_upkeep_slots_and_pop() -> void:
	eq(Glossary.BASIC, ["Upkeep", "Slots", "Pop"] as Array[String], "Glossary.BASIC")


func test_no_card_lists_a_basic_term() -> void:
	var e := pop_engine(2)
	var basic := ["Upkeep", "Slots", "Pop"]
	for id in e.card_db:
		for term in term_names(e.def_details(id)):
			check(not basic.has(term), "%s lists basic term %s" % [id, term])
	for term in term_names(e.card_details(home_uid(e))):
		check(not basic.has(term), "the home territory in play lists basic term %s" % term)


func test_a_card_with_only_basic_terms_has_none() -> void:
	var e := pop_engine(2)
	eq(e.def_details("capital").get("terms"), [] as Array[Dictionary], "Capital (upkeep and slots only) has no terms")


# --- Backlog 289: what a tech gives ---

## A tech that gains food each upkeep, needs Bronze Working, has a eureka, and gives Granary (made and unlocked) and
## Silo (unlocked). MASONRY_PLAIN is the same tech without its create and unlock effects.
const MASONRY := {"id": "masonry", "name": "Masonry", "type": "tech", "cost": {"insight": 3}, "prereq": "bronze",
	"eureka": {"card": "farm", "count": 1, "off": 1}, "effects": [
		{"op": "create", "card": "granary", "zone": "discard"},
		{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"},
		{"op": "unlock", "card": "granary"},
		{"op": "unlock", "card": "silo"}]}
const MASONRY_PLAIN := {"id": "masonry_plain", "name": "Masonry", "type": "tech", "cost": {"insight": 3},
	"prereq": "bronze", "eureka": {"card": "farm", "count": 1, "off": 1}, "effects": [
		{"op": "gain", "resource": "food", "amount": 1, "trigger": "upkeep"}]}
## Two Granaries made, nothing unlocked.
const GRANARIES := {"id": "granaries", "name": "Granaries", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "create", "card": "granary", "zone": "discard"}, {"op": "create", "card": "granary", "zone": "discard"}]}
## Non-techs that make a card: an action, and a civilization at the start.
const BUILDERS := {"id": "builders", "name": "Builders", "type": "action", "effects": [
	{"op": "create", "card": "granary", "zone": "discard"}]}
const FOUNDERS := {"id": "founders", "name": "Founders", "type": "civilization", "effects": [
	{"op": "create", "card": "granary", "zone": "discard", "trigger": "start"}]}


## A game with MASONRY and GRANARIES in the research deck (Masonry on top), Granary and Silo locked in the supply.
func gives_engine() -> GameEngine:
	return tech_engine(["masonry", "granaries", "bronze"], {"farm": 10}, {"supply": {
		"granary": {"price": 2, "count": 2, "locked": true}, "silo": {"price": 2, "count": 2, "locked": true}}},
		[MASONRY, MASONRY_PLAIN, GRANARIES, BUILDERS, FOUNDERS])


func test_a_techs_details_list_each_card_it_gives_with_how_you_get_it() -> void:
	var e := gives_engine()
	eq(e.def_details("masonry").get("gives"), [
		{"card_id": "granary", "how": "1 to your discard · in the supply"},
		{"card_id": "silo", "how": "in the supply"}], "Masonry's gives, in first-effect order")
	eq(e.def_details("granaries").get("gives"), [{"card_id": "granary", "how": "2 to your discard"}],
		"two creates of one card")


func test_a_techs_rules_leave_out_the_lines_of_what_it_gives() -> void:
	var e := gives_engine()
	var rules: Array = e.def_details("masonry").get("rules", [])
	var plain: Array = e.def_details("masonry_plain").get("rules", [])
	check(plain.size() >= 3, "the plain tech has its gain, prerequisite and eureka lines: %s" % [plain])
	eq(rules, plain, "Masonry's rules are the plain tech's")
	var live: Dictionary = e.card_details(uid_of(e.zone("research_deck"), "masonry"))
	eq(live.get("gives"), e.def_details("masonry").get("gives"), "a live copy's gives")
	eq(live.get("rules"), plain, "a live copy's rules")
	var def: CardDef = e.card_db["masonry"]
	eq(def.rules_tooltip(e.card_db).split("\n").size(), plain.size() + 3, "the card's own text keeps every line")


func test_cards_that_give_nothing_or_are_not_techs_have_no_gives() -> void:
	var e := gives_engine()
	for id in ["bronze", "farm", "builders", "founders"]:
		eq(e.def_details(id).get("gives"), [], "%s gives nothing" % id)
	var full: String = (e.card_db["builders"] as CardDef).rules_tooltip(e.card_db)
	eq(e.def_details("builders").get("rules"), Array(full.split("\n")), "an action keeps its create line")
	full = (e.card_db["founders"] as CardDef).rules_tooltip(e.card_db)
	eq(e.def_details("founders").get("rules"), Array(full.split("\n")), "a civilization keeps its create line")
