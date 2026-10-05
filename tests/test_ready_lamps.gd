extends "res://tests/lib/tech_case.gd"
## Ready lamps (288): ready_techs / ready_supply (what can be learned or bought now), and tech_lamp / supply_lamp, lit
## while one of them holds an id not seen at the last see_techs / see_supply. Fixture techs from tech_case: Pottery 2,
## Writing 3, Bronze Working 5, Iron Working 6 (prereq Bronze).

## Guilds (tech, 2 insight) unlocks the locked Guildhall pile.
const GUILDS := {"id": "guilds", "name": "Guilds", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "unlock", "card": "guildhall"}]}
const SUPPLY := {"scout": {"price": 2, "count": 2}, "guildhall": {"price": 2, "count": 2, "locked": true}}


## A game with the research deck order_top_first, SUPPLY, and the given insight and wealth; overrides last. Typed
## Object for the red phase (the lamp methods don't exist yet).
func lamp_engine(order_top_first: Array, insight: int, wealth := 0, deck := {"farm": 10}, overrides := {}) -> Object:
	var o := {"supply": SUPPLY, "starting": {"resources": {"food": 2, "wealth": wealth, "insight": insight},
		"tableau": ["capital"], "territory": "homeland"}}
	o.merge(overrides, true)
	return tech_engine(order_top_first, deck, o, [GUILDS])


# --- AC1: a tech becoming learnable lights the lamp ---

func test_a_tech_becoming_learnable_lights_the_tech_lamp() -> void:
	var e := lamp_engine(["pottery", "writing", "bronze"], 0)
	eq(e.ready_techs(), [] as Array[String], "nothing learnable")
	check(not e.tech_lamp(), "dark while nothing is learnable")
	e.resources.insight = 2
	eq(e.ready_techs(), ["pottery"] as Array[String], "only Pottery is learnable")
	check(e.tech_lamp(), "lit once Pottery is learnable")


func test_ready_techs_are_in_research_deck_order() -> void:
	var e := lamp_engine(["writing", "bronze", "pottery"], 5)
	eq(e.ready_techs(), ["writing", "bronze", "pottery"] as Array[String], "research deck order")


# --- AC2: seeing puts it out while the same techs stay learnable ---

func test_seeing_the_techs_puts_the_lamp_out_while_nothing_new_is_learnable() -> void:
	var e := lamp_engine(["pottery", "bronze"], 2)
	check(e.tech_lamp(), "lit: Pottery is learnable")
	e.see_techs()
	check(not e.tech_lamp(), "out once seen")
	e.resources.insight = 4
	check(not e.tech_lamp(), "more insight, still only Pottery: out")
	e.end_turn()
	e.resources.insight = 4
	eq(e.ready_techs(), ["pottery"] as Array[String], "still only Pottery")
	check(not e.tech_lamp(), "out after end_turn")
	e.resources.insight = 0
	check(not e.tech_lamp(), "out while nothing is learnable")
	e.resources.insight = 2
	check(not e.tech_lamp(), "Pottery learnable again, but seen: out")


# --- AC3: something new relights it ---

func test_a_tech_not_learnable_when_seen_relights_the_lamp() -> void:
	var e := lamp_engine(["pottery", "bronze"], 2)
	e.see_techs()
	e.resources.insight = 5
	check(e.tech_lamp(), "Bronze Working is new: lit")


func test_after_seeing_nothing_any_learnable_tech_lights_the_lamp() -> void:
	var e := lamp_engine(["pottery", "bronze"], 0)
	e.see_techs()
	check(not e.tech_lamp(), "dark")
	e.resources.insight = 2
	check(e.tech_lamp(), "Pottery is new: lit")


# --- AC4: a tech that can't be learned lights nothing ---

func test_a_tech_whose_prereq_is_missing_lights_nothing_until_it_is_met() -> void:
	var e := lamp_engine(["iron", "bronze"], 6)
	eq(e.ready_techs(), ["bronze"] as Array[String], "Iron Working needs Bronze Working")
	e.see_techs()
	check(e.buy_tech(uid_of(e.zone("research_deck"), "bronze")), "learn Bronze Working")
	e.resources.insight = 6
	eq(e.ready_techs(), ["iron"] as Array[String], "Iron Working is learnable now")
	check(e.tech_lamp(), "unseen Iron Working: lit")


func test_a_pending_choice_keeps_the_lamps_dark_until_it_is_made() -> void:
	var e := lamp_engine(["pottery"], 2, 2, {"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(first_in_hand(e)), "play Explorer")
	check(not e.pending().is_empty(), "an explore choice is owed")
	eq(e.ready_techs(), [] as Array[String], "no tech while a choice is owed")
	eq(e.ready_supply(), [] as Array[String], "no pile while a choice is owed")
	check(not e.tech_lamp(), "tech lamp dark")
	check(not e.supply_lamp(), "supply lamp dark")
	check(e.choose(e.pending().options[0]), "choose a territory")
	check(e.tech_lamp(), "the block lifted, Pottery unseen: lit")
	check(e.supply_lamp(), "the block lifted, Scout unseen: lit")


func test_a_finished_game_lights_nothing() -> void:
	var e := lamp_engine(["pottery"], 2, 2, {"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "the game is over")
	e.resources.insight = 2
	e.resources.wealth = 2
	eq(e.ready_techs(), [] as Array[String], "no tech once the game is over")
	eq(e.ready_supply(), [] as Array[String], "no pile once the game is over")
	check(not e.tech_lamp(), "tech lamp dark")
	check(not e.supply_lamp(), "supply lamp dark")


# --- AC5: the supply works the same way ---

func test_a_pile_becoming_buyable_lights_the_supply_lamp() -> void:
	var e := lamp_engine(["pottery"], 0, 0)
	eq(e.ready_supply(), [] as Array[String], "nothing buyable")
	check(not e.supply_lamp(), "dark")
	e.resources.wealth = 2
	eq(e.ready_supply(), ["scout"] as Array[String], "Scout buyable; Guildhall locked")
	check(e.supply_lamp(), "lit")


func test_seeing_the_supply_puts_the_lamp_out_until_a_new_pile_is_buyable() -> void:
	var e := lamp_engine(["guilds"], 0, 2)
	e.see_supply()
	check(not e.supply_lamp(), "out once seen")
	e.resources.wealth = 0
	e.resources.wealth = 5
	check(not e.supply_lamp(), "Scout again, seen: out")
	e.resources.insight = 2
	check(e.buy_tech(uid_of(e.zone("research_deck"), "guilds")), "learn Guilds: the Guildhall pile unlocks")
	eq(e.ready_supply(), ["scout", "guildhall"] as Array[String], "config order")
	check(e.supply_lamp(), "Guildhall is new: lit")


func test_a_sold_out_or_locked_pile_lights_nothing() -> void:
	var e := lamp_engine(["pottery"], 0, 10)
	check(e.buy("scout") and e.buy("scout"), "buy both Scouts")
	eq(e.ready_supply(), [] as Array[String], "Scout sold out, Guildhall locked")
	check(not e.supply_lamp(), "dark")


# --- AC6: the seen sets are game state ---

func test_a_copy_reports_the_same_lamps_and_seeing_on_it_leaves_the_original() -> void:
	var e := lamp_engine(["pottery"], 2, 2)
	var f: Object = e.fork()
	check(f.tech_lamp() and f.supply_lamp(), "the copy's lamps are lit too")
	f.see_techs()
	f.see_supply()
	check(not f.tech_lamp() and not f.supply_lamp(), "seen on the copy: out")
	check(e.tech_lamp() and e.supply_lamp(), "the original's lamps still lit")
	e.see_techs()
	check(not e.fork().tech_lamp(), "a copy made after seeing keeps it seen")


func test_a_new_game_starts_with_nothing_seen() -> void:
	var e := lamp_engine(["pottery"], 2, 2)
	e.see_techs()
	e.see_supply()
	e.new_game(1)
	eq(e.state.seen_techs, [] as Array[String], "seen techs empty")
	eq(e.state.seen_supply, [] as Array[String], "seen supply empty")
	check(e.tech_lamp(), "Pottery learnable at once: lit")
	check(e.supply_lamp(), "Scout buyable at once: lit")


func test_seeing_changes_no_resource_log_or_zone() -> void:
	var e := lamp_engine(["pottery"], 2, 2)
	var before := [e.resources.duplicate(), e.log_lines.size(), card_ids(e.zone("hand")), e.score()]
	e.see_techs()
	e.see_supply()
	eq([e.resources, e.log_lines.size(), card_ids(e.zone("hand")), e.score()], before, "unchanged")
