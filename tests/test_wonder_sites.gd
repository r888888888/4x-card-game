extends "res://tests/lib/test_case.gd"
## Wonders built over turns (backlog 286): a building with `project: true` is played for just the action as an
## unfinished site that takes a slot and a worker and does nothing; wealth goes in with contribute, at most 1 per pop on
## its territory each turn, until its (discounted) wealth cost is paid and it completes. abandon sends a site to the
## discard. Fixtures: Colossus (project, 12 wealth, 5 VP, +1 hand size, ⟳ +2 insight, play: +3 food), the civilization
## Builders (wonders −3 wealth), TEST_GOVS (Court: 3 actions). The bot script is loaded untyped.

const COLOSSUS := {"id": "colossus", "name": "Colossus", "type": "building", "cost": {"wealth": 12}, "vp": 5,
	"tags": ["wonder"], "project": true, "modifiers": {"hand_size": 1},
	"effects": [{"op": "gain", "resource": "insight", "amount": 2, "trigger": "upkeep"},
		{"op": "gain", "resource": "food", "amount": 3}]}
const BUILDERS := {"id": "builders", "name": "Builders", "type": "civilization",
	"discounts": [{"tag": "wonder", "wealth": 3}]}
const SITE_FIXTURES := [COLOSSUS, BUILDERS]
const BUILT_TEXT := "Built over turns: up to 1 wealth per pop here each turn."

var BOT: Variant = load("res://sim/bot.gd")


## A game with population on (no food upkeep, no pop VP), Court ruling (3 actions), civilization civ ("" for none),
## wealth on hand and 20 food; the Homeland at pop 4. overrides replace config keys.
func site_engine(wealth := 0, deck := {"farm": 20}, civ := "", overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := cards_of(fixture_load(SITE_FIXTURES, [TEST_GOVS]), errors, warnings)
	var starting := {"resources": {"food": 20, "wealth": wealth}, "tableau": ["capital"], "territory": "homeland",
		"government": "court"}
	if civ != "":
		starting["civilization"] = civ
	var o := {"starting": starting, "population": {"start": 2, "food_upkeep": 0, "vp_per_pop": 0}}
	o.merge(overrides, true)
	var config := DataLoader.parse_config(raw_config(deck, o), resources(), cards, "config.json", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	set_home_pop(e, 4)
	return e


## Puts a Colossus in hand and plays it on the Homeland; returns its uid.
func place(e: Object) -> int:
	var uid := put_in_hand(e, "colossus")
	check(e.play_card(uid, home_uid(e)), "play Colossus: %s" % e.play_error(uid, home_uid(e)))
	return uid


## A placed Colossus with progress already paid in (set directly).
func site_at(e: Object, progress: int) -> int:
	var uid := place(e)
	e.zone("tableau").find(uid).progress = progress
	return uid


## The zone card uid is in, or "".
func zone_of(e: Object, uid: int) -> String:
	for z in GameEngine.ZONES:
		if e.zone(z).find(uid) != null:
			return z
	return ""


## [wealth, progress, zone] of card uid in e: what a refused contribute must leave unchanged.
func snapshot(e: Object, uid: int) -> Array:
	return [e.resources.wealth, e.site_progress(uid), zone_of(e, uid)]


# --- AC1: playing places a site ---

func test_a_project_costs_nothing_to_play_and_is_placed_as_a_site() -> void:
	var e: Object = site_engine(0)
	var home := home_uid(e)
	var uid := put_in_hand(e, "colossus")
	eq([e.play_cost(uid), e.play_error(uid, home)], [{}, ""], "[play_cost, play_error] with 0 wealth")
	var slots: int = e.free_slots(home)
	var workers: int = e.free_workers(home)
	var actions: int = e.actions_left()
	check(e.play_card(uid, home), "play Colossus")
	eq(e.actions_left(), actions - 1, "1 action used")
	eq(e.resources.wealth, 0, "wealth")
	var card: CardInstance = e.zone("tableau").find(uid)
	check(card != null and card.territory_uid == home, "Colossus is on the tableau on the Homeland")
	eq([e.is_site(uid), e.site_progress(uid), e.site_cost(uid)], [true, 0, 12], "[is_site, site_progress, site_cost]")
	eq([e.free_slots(home), e.free_workers(home)], [slots - 1, workers - 1], "[free slots, free workers]")


func test_a_site_cost_is_the_discounted_wealth_cost() -> void:
	var e: Object = site_engine(0, {"farm": 20}, "builders")
	eq(e.site_cost(place(e)), 9, "12 − Builders' 3")


func test_a_building_that_isnt_a_project_is_paid_on_play() -> void:
	var e: Object = site_engine(0)
	var uid := put_in_hand(e, "farm")
	var food: int = e.resources.food
	check(e.play_card(uid, home_uid(e)), "play Farm")
	eq([e.is_site(uid), e.resources.food], [false, food - 2], "[is_site, food]")


# --- AC2: an unfinished site does nothing ---

func test_an_unfinished_site_resolves_no_play_effect_and_scores_nothing() -> void:
	var e: Object = site_engine(0)
	var food: int = e.resources.food
	var score: int = e.score()
	place(e)
	eq(e.resources.food, food, "no +3 food on play")
	eq(e.score(), score, "no 5 VP")


func test_an_unfinished_site_scores_nothing_at_the_end() -> void:
	var e: Object = site_engine(0, {"farm": 20}, "", {"turn_limit": 1})
	place(e)
	var score: int = e.score()
	e.end_turn()
	check(e.is_over, "precondition: the game is over")
	eq(e.score(), score, "the final score leaves out the unfinished Colossus")


func test_an_unfinished_site_has_no_upkeep_and_no_modifiers() -> void:
	var e: Object = site_engine(0)
	place(e)
	var insight: int = e.resources.insight
	e.end_turn()
	eq(e.resources.insight, insight, "no ⟳ +2 insight")
	eq([e.hand_size(), e.zone("hand").size()], [5, 5], "[hand_size, hand]: no +1")


func test_an_unfinished_site_still_uses_a_worker() -> void:
	var e: Object = site_engine(0)
	set_home_pop(e, 2)
	build_on(e, home_uid(e), ["farm"])
	place(e)
	build_on(e, home_uid(e), ["farm"])
	var last: int = e.zone("tableau").cards[-1].uid
	check(e.is_idle(last), "the Farm placed after the site has no worker")


# --- AC3: contributing ---

func test_contributing_puts_in_wealth_up_to_the_pop_each_turn() -> void:
	var e: Object = site_engine(10)
	var uid := place(e)
	eq(e.contribute_limit(uid), 4, "limit: Homeland pop 4")
	var actions: int = e.actions_left()
	check(e.contribute(uid, 3), "contribute 3: %s" % e.contribute_error(uid, 3))
	eq([e.resources.wealth, e.site_progress(uid), e.actions_left(), e.contribute_limit(uid)], [7, 3, actions, 1],
		"[wealth, progress, actions left, limit]")
	check(e.contribute(uid, 1), "contribute 1")
	eq(e.contribute_limit(uid), 0, "limit after 4 in this turn")
	e.end_turn()
	eq(e.contribute_limit(uid), 4, "a new turn: 4 again")


func test_the_contribute_limit_is_the_least_of_pop_cost_left_and_wealth() -> void:
	var poor: Object = site_engine(2)
	eq(poor.contribute_limit(place(poor)), 2, "2 wealth held")
	var nearly: Object = site_engine(10)
	eq(nearly.contribute_limit(site_at(nearly, 10)), 2, "10 of 12 paid")


func test_a_fork_and_a_copy_keep_progress_and_this_turns_contributions() -> void:
	var e: Object = site_engine(10)
	var uid := place(e)
	e.contribute(uid, 3)
	var f: Object = e.fork()
	eq([f.site_progress(uid), f.contribute_limit(uid)], [3, 1], "fork: [progress, limit]")
	var c: CardInstance = e.state.copy().zones.tableau.find(uid)
	eq([c.get("progress"), c.get("given_this_turn")], [3, 3], "GameState.copy: [progress, given this turn]")


# --- AC4: refused contributions ---

func check_refused(e: Object, uid: int, amount: int, what: String, fragment := "") -> void:
	var before := snapshot(e, uid)
	var error: String = e.contribute_error(uid, amount)
	check(error != "", "%s: contribute_error is non-empty" % what)
	if fragment != "":
		check(error.contains(fragment), "%s: '%s' contains '%s'" % [what, error, fragment])
	check(not e.contribute(uid, amount), "%s: contribute refuses" % what)
	eq(snapshot(e, uid), before, "%s: nothing changed" % what)


func test_contributing_below_1_or_past_wealth_or_the_limit_is_refused() -> void:
	var e: Object = site_engine(10)
	var uid := place(e)
	check_refused(e, uid, 0, "amount 0")
	var poor: Object = site_engine(2)
	check_refused(poor, place(poor), 5, "more than the wealth held", "needs 5 wealth (you have 2)")
	e.contribute(uid, 4)
	check_refused(e, uid, 1, "past the limit (4 in this turn)")


func test_contributing_to_a_card_that_isnt_an_unfinished_site_is_refused() -> void:
	var e: Object = site_engine(10)
	build_on(e, home_uid(e), ["farm"])
	check_refused(e, e.zone("tableau").cards[-1].uid, 1, "a Farm")
	check_refused(e, site_at(e, 12), 1, "a completed Colossus")
	check_refused(e, put_in_hand(e, "colossus"), 1, "a Colossus in hand")


func test_contributing_to_an_idle_site_is_refused() -> void:
	var e: Object = site_engine(10)
	build_on(e, home_uid(e), ["farm", "farm"])
	var uid := place(e)
	set_home_pop(e, 2)
	check(e.is_idle(uid), "precondition: the site is past the pop")
	eq(e.contribute_limit(uid), 0, "limit")
	check_refused(e, uid, 1, "an idle site")


func test_contributing_is_refused_while_a_decision_is_owed_or_the_game_is_over() -> void:
	var e: Object = site_engine(10)
	var uid := place(e)
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}
	check_refused(e, uid, 1, "a decision owed", "Choose a government first.")
	var over: Object = site_engine(10, {"farm": 20}, "", {"turn_limit": 1})
	var site := place(over)
	over.end_turn()
	check_refused(over, site, 1, "the game over", "The game is over.")


# --- AC5: completion ---

func test_paying_the_last_wealth_completes_the_site() -> void:
	var e: Object = site_engine(10)
	var uid := site_at(e, 8)
	var food: int = e.resources.food
	var score: int = e.score()
	var messages := record_messages(e)
	var changes := [0]
	e.changed.connect(func(): changes[0] += 1)
	check(e.contribute(uid, 4), "contribute 4: %s" % e.contribute_error(uid, 4))
	eq([e.is_site(uid), e.resources.food - food, e.score() - score, e.contribute_limit(uid)], [false, 3, 5, 0],
		"[is_site, food gained, score gained, limit]")
	has_msg(messages, "Completed Colossus.")
	check(changes[0] > 0, "changed emitted")
	var insight: int = e.resources.insight
	e.end_turn()
	eq(e.resources.insight - insight, 2, "⟳ +2 insight")
	eq([e.hand_size(), e.zone("hand").size()], [6, 6], "[hand_size, hand]: +1")


# --- AC6: data and text ---

func test_project_loads_on_a_building_with_its_text() -> void:
	var r := fixture_load([COLOSSUS])
	eq([r.errors, r.warnings], [[], []], "[errors, warnings]")
	var colossus: CardDef = r.cards.colossus
	eq(colossus.get("project"), true, "project")
	check(colossus.rules_text(r.cards).contains(BUILT_TEXT), "face: %s" % colossus.rules_text(r.cards))
	check(colossus.rules_tooltip(r.cards).contains(BUILT_TEXT), "tooltip: %s" % colossus.rules_tooltip(r.cards))
	check(not r.cards.farm.rules_text(r.cards).contains("Built over turns"), "a Farm has no such line")


func test_project_validation() -> void:
	check_cases([
		["on an action", [{"id": "x", "name": "X", "type": "action", "project": true}],
			"'project' only applies to buildings (ignored)", "warning_only"],
		["not a bool", [{"id": "x", "name": "X", "type": "building", "cost": {"wealth": 10}, "project": 1}],
			["card 'x'", "project"]],
		["a cost with food", [{"id": "x", "name": "X", "type": "building", "cost": {"food": 1, "wealth": 10},
			"project": true}], ["card 'x'", "project", "cost"]],
		["no cost", [{"id": "x", "name": "X", "type": "building", "project": true}], ["card 'x'", "project", "cost"]],
	], func(extra): return fixture_load(extra))


# --- AC7: the bot ---

## A bot game: a Colossus site placed on the Homeland (pop 4) on turn 1, the hand Shrines (free, no wealth), wealth
## set after.
func bot_site_game(wealth: int) -> Array:
	var e: Object = site_engine(0, {"shrine": 20})
	var uid := place(e)
	e.resources.wealth = wealth
	return [e, uid]


func test_the_bot_contributes_down_to_its_reserve_at_the_end_of_its_turn() -> void:
	eq(BOT.SITE_RESERVE, 3, "SITE_RESERVE")
	for case in [[10, 4, 6], [5, 2, 3], [3, 0, 3], [1, 0, 1]]:
		var game := bot_site_game(case[0])
		var e: Object = game[0]
		BOT.take_turn(e, "baseline")
		eq([e.site_progress(game[1]), e.resources.wealth], [case[1], case[2]], "with %d wealth: [in, kept]" % case[0])


func test_the_bot_plays_a_wonder_and_never_abandons_its_site() -> void:
	var e: Object = site_engine(0, {"shrine": 20})
	var uid := put_in_hand(e, "colossus")
	BOT.take_turn(e, "baseline")
	check(e.zone("tableau").find(uid) != null and e.is_site(uid), "the bot placed the Colossus as a site")
	for turn in 2:
		e.end_turn()
		BOT.take_turn(e, "baseline")
	check(e.zone("tableau").find(uid) != null, "the site is still on the tableau")


# --- AC8: abandoning ---

func test_abandoning_a_site_discards_it_and_frees_its_slot_and_worker() -> void:
	var e: Object = site_engine(2)
	var home := home_uid(e)
	set_home_pop(e, 1)
	var slots: int = e.free_slots(home)
	var uid := site_at(e, 7)
	build_on(e, home, ["farm"])
	var farm: int = e.zone("tableau").cards[-1].uid
	check(e.is_idle(farm), "precondition: the Farm is idle behind the site (pop 1)")
	var messages := record_messages(e)
	var actions: int = e.actions_left()
	check(e.abandon(uid), "abandon: %s" % e.abandon_error(uid))
	eq([e.actions_left(), e.resources.wealth, zone_of(e, uid)], [actions, 2, "discard"], "[actions left, wealth, zone]")
	check(not e.is_idle(farm), "the Farm works now")
	eq([e.free_slots(home), e.free_workers(home)], [slots - 1, 0], "only the Farm takes a slot and the 1 worker")
	has_msg(messages, "Abandoned Colossus.")


func test_a_site_played_again_after_abandoning_starts_over() -> void:
	var e: Object = site_engine(10)
	var uid := site_at(e, 7)
	e.contribute(uid, 2)
	check(e.abandon(uid), "abandon")
	var card: CardInstance = e.zone("discard").find(uid)
	e.zone("discard").remove(card)
	e.zone("hand").add(card)
	check(e.play_card(uid, home_uid(e)), "play it again: %s" % e.play_error(uid, home_uid(e)))
	eq([e.site_progress(uid), e.contribute_limit(uid)], [0, 4], "[progress, limit]: a new site, nothing in this turn")


func test_abandoning_is_refused_for_a_card_that_isnt_an_unfinished_site() -> void:
	var e: Object = site_engine(10)
	build_on(e, home_uid(e), ["farm"])
	var farm: int = e.zone("tableau").cards[-1].uid
	var done := site_at(e, 12)
	var held := put_in_hand(e, "colossus")
	for case in [[farm, "a Farm", "tableau"], [done, "a completed Colossus", "tableau"], [held, "a Colossus in hand", "hand"]]:
		check(e.abandon_error(case[0]) != "", "%s: abandon_error" % case[1])
		check(not e.abandon(case[0]), "%s: abandon refuses" % case[1])
		eq(zone_of(e, case[0]), case[2], "%s: not moved" % case[1])


func test_abandoning_is_refused_while_a_decision_is_owed_or_the_game_is_over() -> void:
	var e: Object = site_engine(10)
	var uid := place(e)
	e.state.pending = {"kind": GameEngine.PENDING_GOVERNMENT}
	eq(e.abandon_error(uid), "Choose a government first.", "a decision owed")
	check(not e.abandon(uid) and e.zone("tableau").find(uid) != null, "the site stays")
	var over: Object = site_engine(10, {"farm": 20}, "", {"turn_limit": 1})
	var site := place(over)
	over.end_turn()
	eq(over.abandon_error(site), "The game is over.", "the game over")
	check(not over.abandon(site) and over.zone("tableau").find(site) != null, "the site stays")
