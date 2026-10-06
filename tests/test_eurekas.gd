extends "res://tests/lib/tech_case.gd"
## Eurekas (backlog 141): a tech's `eureka` ({card | tag, count, off}) takes `off` insight off its price while the
## tableau holds `count` matching cards. Local fixture: Lore, a 3-insight tech given whichever eureka a test needs.

const FARMS := {"card": "farm", "count": 2, "off": 2}
const CITIES := {"tag": "city", "count": 2, "off": 2}
const POP := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}


## Lore (3 insight) with the given eureka.
func lore(eureka: Dictionary) -> Dictionary:
	return {"id": "lore", "name": "Lore", "type": "tech", "cost": {"insight": 3}, "eureka": eureka}


## Loads the fixture cards plus a card 'x' of type with fields; returns {cards, errors, warnings}.
func load_x(fields: Dictionary, type := "tech") -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type, "cost": {"insight": 2} if type == "tech" else {"wealth": 2}}
	x.merge(fields, true)
	var cards := tech_db([x], errors, warnings)
	return {"cards": cards, "errors": errors, "warnings": warnings}


## A game with Lore (eureka as given) and Pottery in the research deck, 20 food and a deck of Farms.
func lore_engine(eureka: Dictionary, overrides := {}) -> GameEngine:
	var o := {"starting": {"resources": {"food": 20, "wealth": 20, "insight": 20}, "tableau": ["capital"],
		"territory": "homeland"}}
	o.merge(overrides, true)
	return tech_engine(["lore", "pottery"], {"farm": 10}, o, [lore(eureka)])


func lore_uid(e: GameEngine) -> int:
	return uid_of(e.zone("research_deck"), "lore")


## Plays n Farms from the hand onto the home territory.
func build_farms(e: GameEngine, n: int) -> void:
	for i in n:
		var farm := put_in_hand(e, "farm")
		check(e.play_card(farm, home_uid(e)), "Farm %d: %s" % [i + 1, e.play_error(farm, home_uid(e))])


## The tech_tree() entry for id ({} if missing).
func entry(e: GameEngine, id: String) -> Dictionary:
	for t in e.tech_tree():
		if t.id == id:
			return t
	return {}


# --- AC1: loading ---

func test_card_and_tag_eurekas_load() -> void:
	for eureka in [FARMS, CITIES]:
		var r := load_x({"eureka": eureka})
		eq(r.errors, [] as Array[String], "%s: errors" % [eureka])
		eq(r.warnings, [] as Array[String], "%s: warnings" % [eureka])


func test_eureka_validation() -> void:
	var at := "cards.json: card 'x': eureka"
	check_cases([
		["both tag and card", [{"eureka": {"tag": "city", "card": "farm", "count": 2, "off": 2}}, "tech"], at],
		["neither tag nor card", [{"eureka": {"count": 2, "off": 2}}, "tech"], at],
		["no count", [{"eureka": {"card": "farm", "off": 2}}, "tech"], at],
		["count 0", [{"eureka": {"card": "farm", "count": 0, "off": 2}}, "tech"], at],
		["no off", [{"eureka": {"card": "farm", "count": 2}}, "tech"], at],
		["off 0", [{"eureka": {"card": "farm", "count": 2, "off": 0}}, "tech"], at],
		["not an object", [{"eureka": "farm"}, "tech"], at],
		["unknown card", [{"eureka": {"card": "dragon", "count": 1, "off": 2}}, "tech"],
			"cards.json: card 'x': eureka: unknown card 'dragon'"],
		["on a building", [{"eureka": FARMS}, "building"], "cards.json: card 'x': 'eureka' only applies to techs (ignored)",
			"warning_only"],
	], func(args): return load_x(args[0], args[1]))


# --- AC2: a card eureka counts the tableau ---

func test_a_card_eureka_needs_its_count_of_cards_in_the_tableau() -> void:
	var e := lore_engine(FARMS)
	e.create_card("farm", "discard", null)
	build_farms(e, 1)
	eq(e.tech_cost(lore_uid(e)), 3, "1 Farm in the tableau (more in hand, deck and discard): no eureka")
	build_farms(e, 1)
	eq(e.tech_cost(lore_uid(e)), 1, "2 Farms: 3 − 2")


func test_an_idle_card_still_counts_for_a_eureka() -> void:
	var e := lore_engine(FARMS, POP)
	build_farms(e, 2)
	e.zone("tableau").find(home_uid(e)).pop = 1
	var farms: Array = e.zone("tableau").cards.filter(func(c): return c.def.id == "farm")
	check(farms.any(func(c): return e.is_idle(c.uid)), "a Farm is idle")
	eq(e.tech_cost(lore_uid(e)), 1, "both Farms count")


# --- AC3: a tag eureka, and the floor ---

func test_a_tag_eureka_counts_tableau_cards_with_the_tag() -> void:
	var e := lore_engine(CITIES)
	eq(e.tech_cost(lore_uid(e)), 3, "the Capital alone")
	e.create_card("city", "tableau", null)
	eq(e.tech_cost(lore_uid(e)), 1, "the Capital and a City: 3 − 2")


func test_a_eureka_never_takes_a_tech_below_1() -> void:
	var e := lore_engine({"tag": "city", "count": 1, "off": 5})
	eq(e.tech_cost(lore_uid(e)), 1, "3 − 5 stops at 1")


# --- AC4: the tree, card text and details ---

func test_tech_tree_entries_say_whether_the_eureka_is_met() -> void:
	var e := lore_engine(FARMS)
	eq(entry(e, "lore").get("eureka"), false, "no Farms yet")
	eq(entry(e, "pottery").get("eureka"), false, "Pottery has no eureka")
	build_farms(e, 2)
	eq(entry(e, "lore").get("eureka"), true, "2 Farms")


func test_eureka_card_text() -> void:
	var db := tech_db([lore(FARMS)])
	check(db.lore.rules_text(db).split("\n").has("Eureka: -2 insight with 2 Farms"), "short: %s" % db.lore.rules_text(db))
	check(db.lore.rules_tooltip(db).split("\n").has("Eureka: -2 insight with 2 Farms."), "tooltip: %s" % db.lore.rules_tooltip(db))
	db = tech_db([lore(CITIES)])
	check(db.lore.rules_text(db).split("\n").has("Eureka: -2 insight with 2 city cards"), "tag form: %s" % db.lore.rules_text(db))


func test_a_met_eureka_shows_in_the_price_details() -> void:
	var e := lore_engine(FARMS)
	build_farms(e, 2)
	var d: Dictionary = e.card_details(lore_uid(e))
	check(d.get("state", []).has("Costs 1 insight now (printed 3, −2 eureka)"), "state: %s" % [d.get("state")])


# --- AC5: the Knowledge screen (222: the tile shows a met eureka, its tooltip the eureka text) ---

func test_the_tree_shows_a_eureka_and_ticks_it_when_met() -> void:
	var real := Game.engine
	Game.engine = lore_engine(FARMS)
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_T)
	var screen: KnowledgeScreen = main.knowledge
	var t: Button = screen.tile("Lore")
	check(t.tooltip_text.split("\n").has("Eureka: -2 insight with 2 Farms"), "unmet: the tooltip: %s" % t.tooltip_text)
	check(not screen.tile_texts("Lore").has("✔ Eureka"), "unmet: not on the tile: %s" % [screen.tile_texts("Lore")])
	press_key(main, KEY_T)
	build_farms(Game.engine, 2)
	press_key(main, KEY_T)
	check(screen.tile_texts("Lore").has("✔ Eureka"), "met: on the tile: %s" % [screen.tile_texts("Lore")])
	press_key(main, KEY_T)
	check(Game.engine.buy_tech(lore_uid(Game.engine)), "learn Lore")
	press_key(main, KEY_T)
	check(not screen.tile_texts("Lore").has("✔ Eureka"), "a researched tech shows no eureka: %s" % [screen.tile_texts("Lore")])
	close_main(main)
	Game.engine = real


# --- Backlog 325: affordable at the cost now ---

func test_a_eureka_makes_a_tech_affordable_at_its_cost_now() -> void:
	var e := lore_engine(FARMS)
	e.resources[GameEngine.INSIGHT] = 1
	eq(entry(e, "lore").get("affordable"), false, "1 insight is short of 3")
	build_farms(e, 2)
	eq(entry(e, "lore").get("cost"), 1, "precondition: the eureka takes it to 1")
	eq(entry(e, "lore").get("affordable"), true, "1 insight covers the cost now")
