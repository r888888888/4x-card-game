extends "res://tests/lib/anarchy_case.gd"
## legal_actions (312): every action the engine would allow now, as [action, args…], in a fixed order: an owed
## decision's options, then play_card, build, buy, buy_tech, contribute, move_unit, discard_card, relieve_famine,
## restore_order, revolt, abandon, disband, end_turn. A coverage table fails the suite when an action with an error
## query can't be listed. Games from tests/lib/anarchy_case.gd (Chiefs ruling, unrest, a research deck with Lore, Farms
## in the supply, 10 food, wealth and insight, home pop 6), with a unit (Levy) and a wonder (Colossus) added.

const LEVY := {"id": "levy", "name": "Levy", "type": "unit", "cost": {"food": 1}, "strength": 2}
const COLOSSUS := {"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 12}, "vp": 5,
	"tags": ["wonder"], "project": true}
## Actions whose error query isn't named <action>_error: the engine's table (312).
const ERROR_OF := LegalActions.ERROR_OF
## Names with an error query that legal_actions never lists: starting a game, naming a territory, and supply (the
## Supply screen's query, not an action).
const NEVER_LISTED := ["new_game", "rename_territory", "supply"]
const HILLS_DECK := {"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}}


## An anarchy game with LEVY and COLOSSUS loaded and overrides merged (Hills, Grassland, Jungle to explore).
func game(unrest := {}, overrides := {}) -> GameEngine:
	return anarchy_engine(unrest, HILLS_DECK.merged(overrides, true), [LEVY, COLOSSUS])


## The entries of list whose action is name.
func of_kind(list: Array, name: String) -> Array:
	return list.filter(func(entry): return entry[0] == name)


## The error query's answer for entry on e: "" when the entry is legal.
func entry_error(e: GameEngine, entry: Array) -> String:
	if entry[0] == "renew":
		return e.renew_error(entry[1].slice(0, entry[2]))
	return e.callv(ERROR_OF.get(entry[0], entry[0] + "_error"), entry.slice(1))


# --- AC1: what is listed with nothing owed ---

func test_with_nothing_owed_every_allowed_action_is_listed_in_order() -> void:
	var e := game({}, {"build_menu": {"temple": {}}})
	var home := home_uid(e)
	var hand: Array = e.zone("hand").cards.map(func(c): return c.uid)
	var lore := uid_of(e.zone("research_deck"), "lore")
	eq(e.play_error(hand[0], home), "", "a Farm can be played on the home")
	eq(e.build_error("temple", home), "", "a Temple can be built on the home")
	eq(e.buy_error("farm"), "", "a Farm can be bought")
	eq(e.buy_tech_error(lore), "", "Lore can be learned")
	eq(e.revolt_error(), "", "a revolt can be declared")
	var expected := []
	for uid in hand:
		expected.append(["play_card", uid, home])
	expected.append_array([["build", "temple", home], ["buy", "farm"], ["buy_tech", lore]])
	for uid in hand:
		expected.append(["discard_card", uid])
	expected.append_array([["revolt"], ["end_turn"]])
	eq(e.legal_actions(), expected, "plays, build, buy, tech, discards, revolt, end turn")


func test_a_card_that_needs_no_target_is_listed_with_target_minus_1() -> void:
	var e := game()
	var feast := put_in_hand(e, "feast")
	check(of_kind(e.legal_actions(), "play_card").has(["play_card", feast, -1]), "Feast with target -1")


func test_units_and_sites_list_their_moves_contributions_disbands_and_abandons() -> void:
	var e := game()
	settle(e, ["hills"])
	var hills := uid_of(e.zone("tableau"), "hills")
	var levy := put_in_hand(e, "levy")
	check(e.play_card(levy, home_uid(e)), "Levy recruited on the home: %s" % e.play_error(levy, home_uid(e)))
	var colossus := put_in_hand(e, "colossus")
	check(e.play_card(colossus, home_uid(e)), "Colossus placed as a site: %s" % e.play_error(colossus, home_uid(e)))
	var limit := e.contribute_limit(colossus)
	check(limit > 0, "the site can take wealth: %d" % limit)
	var list := e.legal_actions()
	eq(of_kind(list, "contribute"), [["contribute", colossus, limit]], "one contribution, at the limit")
	eq(of_kind(list, "move_unit"), [["move_unit", levy, hills]] if e.move_targets(levy) == [hills] else [],
		"the Levy's moves are its move_targets")
	eq(of_kind(list, "disband"), [["disband", levy]], "disband the Levy")
	eq(of_kind(list, "abandon"), [["abandon", colossus]], "abandon the site")


# --- AC2: every entry is legal ---

func test_every_entry_is_legal_and_nothing_unaffordable_is_listed() -> void:
	var e := game({}, {"build_menu": {"temple": {}}})
	for entry in e.legal_actions():
		eq(entry_error(e, entry), "", "%s" % [entry])
	e.resources["food"] = 0
	e.resources["wealth"] = 0
	var list := e.legal_actions()
	check(not list.is_empty(), "something is still listed")
	eq(of_kind(list, "play_card"), [], "no Farm play with 0 food (it costs 2)")
	eq(of_kind(list, "build"), [], "no Temple build with 0 food (it costs 1)")
	eq(of_kind(list, "buy"), [], "no buy with 0 wealth")
	for entry in list:
		eq(entry_error(e, entry), "", "%s" % [entry])


# --- AC3: an owed decision ---

func test_an_explore_choice_lists_only_its_options() -> void:
	var e := game()
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	var options: Array = e.pending().options
	eq(e.legal_actions(), options.map(func(o): return ["choose", o]), "one choose per revealed territory")


func test_an_event_choice_lists_the_options_it_allows() -> void:
	var envoys := choice_engine()
	envoys.end_turn()
	eq(envoys.legal_actions(), [["choose_option", 0], ["choose_option", 1]], "Envoys: both options")
	var dear := choice_engine(["dear"], {"dear": 1, "fleeting": 1})
	dear.end_turn()
	eq(dear.legal_actions(), [["choose_option", 1]], "Dear: 50 wealth is too dear, only the free option")


func test_the_government_choice_lists_each_government() -> void:
	var e := game()
	e.resources["unrest"] = 5
	e.end_turn()
	e.end_turn()
	e.resources["wealth"] = 30
	check(e.restore_order(), "restore order: the government choice is owed")
	var options: Array = e.pending().options
	check(not options.is_empty(), "governments to choose from")
	eq(e.legal_actions(), options.map(func(o): return ["choose_government", o]), "one entry per government")


func test_a_hand_limit_discard_lists_each_hand_card_and_what_it_still_allows() -> void:
	var e := game({}, {"hand_limit": 5})
	for i in 2:
		put_in_hand(e, "farm")
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_DISCARD, "a discard owed")
	var expected := [["buy_tech", uid_of(e.zone("research_deck"), "lore")]]
	for card in e.zone("hand").cards:
		expected.append(["discard_card", card.uid])
	eq(e.legal_actions(), expected, "research stays allowed (_DISCARD_ALLOWS), then a discard per hand card")


func test_a_renewal_is_one_entry_choose_count_of_the_options() -> void:
	var e := game({"renewal": 1})
	put_in(e, "farm", "discard")
	e.resources["unrest"] = 5
	e.end_turn()
	var p := e.pending()
	eq(p.get("kind"), GameEngine.PENDING_RENEWAL, "renewal owed")
	eq(e.legal_actions(), [["renew", p.options, p.count]], "one entry: choose count of options")


# --- AC4 and AC5: game over, order, nothing changes ---

func test_nothing_is_listed_after_game_over() -> void:
	eq(over_engine().legal_actions(), [], "game over")


func test_the_list_is_the_same_twice_and_on_a_fork_and_changes_nothing() -> void:
	var e := game({}, {"build_menu": {"temple": {}}})
	var zones := {}
	for name in GameEngine.ZONES:
		zones[name] = e.zone(name).cards.map(func(c): return c.uid)
	var resources_before: Dictionary = e.resources.duplicate()
	var first := e.legal_actions()
	check(not first.is_empty(), "something listed")
	eq(e.legal_actions(), first, "twice")
	eq(e.fork().legal_actions(), first, "on a fork")
	for name in GameEngine.ZONES:
		eq(e.zone(name).cards.map(func(c): return c.uid), zones[name], "zone %s" % name)
	eq(e.resources, resources_before, "resources")


# --- AC6: every action can be listed ---

## Each action legal_actions lists, with a game where it is listed.
func coverage() -> Dictionary:
	return {
		"play_card": func(): return game(),
		"build": func(): return game({}, {"build_menu": {"temple": {}}}),
		"buy": func(): return game(),
		"buy_tech": func(): return game(),
		"end_turn": func(): return game(),
		"discard_card": func(): return game(),
		"revolt": func(): return game(),
		"choose": func():
			var e := game()
			e.play_card(put_in_hand(e, "explorer"))
			return e,
		"choose_option": func():
			var e := choice_engine()
			e.end_turn()
			return e,
		"choose_government": func():
			var e := game()
			e.resources["unrest"] = 5
			e.end_turn()
			e.end_turn()
			e.resources["wealth"] = 30
			e.restore_order()
			return e,
		"restore_order": func(): return second_turn_engine(5),
		"renew": func():
			var e := game({"renewal": 1})
			put_in(e, "farm", "discard")
			e.resources["unrest"] = 5
			e.end_turn()
			return e,
		"relieve_famine": func():
			var e := game({}, {"population": {"start": 4, "food_upkeep": 1, "vp_per_pop": 0,
				"famine": FAMINE.merged({"relief": {"wealth": 5}})}})
			e.resources["food"] = 0
			e.end_turn()
			e.resources["wealth"] = 10
			return e,
		"move_unit": func():
			var e := game()
			settle(e, ["hills"])
			e.play_card(put_in_hand(e, "levy"), home_uid(e))
			return e,
		"disband": func():
			var e := game()
			e.play_card(put_in_hand(e, "levy"), home_uid(e))
			return e,
		"contribute": func():
			var e := game()
			e.play_card(put_in_hand(e, "colossus"), home_uid(e))
			return e,
		"abandon": func():
			var e := game()
			e.play_card(put_in_hand(e, "colossus"), home_uid(e))
			return e,
	}


func test_every_action_with_an_error_query_has_a_coverage_row() -> void:
	var methods: Array[String] = []
	for m in (GameEngine as Script).get_script_method_list():
		methods.append(m.name)
	var expected: Array[String] = []
	for name in methods:
		if name.ends_with("_error") or name.begins_with("_") or expected.has(name) or NEVER_LISTED.has(name):
			continue
		if methods.has(ERROR_OF.get(name, name + "_error")):
			expected.append(name)
	expected.sort()
	var rows: Array = coverage().keys()
	rows.sort()
	eq(rows, expected, "a coverage row per action with an error query (but %s)" % [NEVER_LISTED])


func test_each_coverage_game_lists_its_action() -> void:
	var rows := coverage()
	for name in rows:
		var e: GameEngine = rows[name].call()
		var kinds: Array = e.legal_actions().map(func(entry): return entry[0])
		check(kinds.has(name), "%s listed: %s" % [name, kinds])
