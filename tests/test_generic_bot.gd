extends "res://tests/lib/anarchy_case.gd"
## The generic bot (313): it tries each of legal_actions() on a sample fork, values the result with one function and
## does the best, stopping when nothing beats doing nothing. Fixture games of a few turns (tests/lib/anarchy_case.gd:
## unrest on, home pop 6), with Lone ruling (1 action, unrest limit 5), no supply and no research deck. The bot is loaded
## untyped so this file parses before it exists.

var BOT: Variant = load("res://sim/generic_bot.gd")
const LONE := {"id": "lone", "name": "Lone", "type": "government", "actions": 1, "unrest_limit": 5}
## Riot: +3 food and +2 unrest. Gift: a choice event, +1 food or +3 food.
const RIOT := {"id": "riot", "name": "Riot", "type": "action", "effects": [
	{"op": "gain", "resource": "food", "amount": 3}, {"op": "gain", "resource": "unrest", "amount": 2}]}
const GIFT := {"id": "gift", "name": "Gift", "type": "event", "choices": [
	{"effects": [{"op": "gain", "resource": "food", "amount": 1}]},
	{"effects": [{"op": "gain", "resource": "food", "amount": 3}]}]}
const EXTRA := [LONE, RIOT, GIFT]


## A fixture game at turn 1 of turn_limit, government ruling, with exactly hand in the hand and deck in the deck (ids;
## the dealt cards removed), 10 food, wealth and insight, no supply and no research deck; overrides last.
func bot_game(hand: Array, deck: Array, turn_limit := 11, government := "lone", overrides := {}) -> GameEngine:
	var o := {"turn_limit": turn_limit, "supply": {}, "research_deck": {},
		"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1},
		"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": government}}
	var e := anarchy_engine({}, o.merged(overrides, true), EXTRA)
	for z in ["hand", "deck"]:
		for card in e.zone(z).take_all():
			e.zone("removed").add(card)
	for id in hand:
		put_in(e, id, "hand")
	for id in deck:
		put_in(e, id, "deck")
	return e


## The card ids played or built during call, in order.
func played(e: GameEngine, call: Callable) -> Array[String]:
	var out: Array[String] = []
	var record := func(outcome: Dictionary):
		var uid: int = outcome.get("uid", -1)
		var z := e.zone_of(uid)
		out.append(e.zone(z).find(uid).def.id if z != "" else "?")
	e.card_played.connect(record)
	call.call()
	e.card_played.disconnect(record)
	return out


## The bot's take_turn on e with the generic strategy.
func take_turn(e: GameEngine) -> void:
	check(BOT != null, "sim/generic_bot.gd exists")
	if BOT != null:
		BOT.take_turn(e, "generic")


## Every zone's [uid, id] lists, resources and pending: what valuing must not change.
func snapshot(e: GameEngine) -> Array:
	var zones := {}
	for name in GameEngine.ZONES:
		zones[name] = e.zone(name).cards.map(func(c): return [c.uid, c.def.id, c.pop])
	return [zones, e.resources.duplicate(), e.pending(), e.turn, e.log_lines.size()]


# --- AC1: income over the turns ahead ---

func test_with_10_turns_left_it_plays_the_temple_that_scores_every_turn() -> void:
	var e := bot_game(["shrine", "temple"], [])
	eq(played(e, func(): take_turn(e)), ["temple"], "Temple (⟳ +1 for 10 turns) over Shrine (+1 now)")


func test_on_the_last_turn_it_plays_the_shrine() -> void:
	var e := bot_game(["shrine", "temple"], [], 1)
	eq(played(e, func(): take_turn(e)), ["shrine"], "no upkeep left: the free +1 over the Temple's +1 for 1 food")


# --- AC2: nothing worth doing ---

func test_it_plays_nothing_when_nothing_helps() -> void:
	var e := bot_game(["guildhall"], [], 11, "lone", {"starting": {"resources": {"food": 10, "wealth": 10},
		"tableau": ["capital"], "territory": "homeland", "government": "lone"}})
	eq(e.play_error(first_in_hand(e), home_uid(e)), "", "the Guildhall could be played")
	eq(played(e, func(): take_turn(e)), [], "a Guildhall costs food and wealth and does nothing")
	eq(e.turn, 1, "the turn is left for play to end")


# --- AC3: a draw is worth what it lets you play ---

func test_it_plays_a_draw_first_when_it_draws_something_better() -> void:
	var e := bot_game(["scout", "shrine"], ["temple", "temple", "temple", "temple"], 11, "band")
	eq(played(e, func(): take_turn(e)), ["scout", "temple"], "Scout draws Temples, one is played")


# --- AC4: exploring is worth what it gives a settler ---

func test_it_explores_when_a_settler_would_gain_a_target() -> void:
	var e := bot_game(["explorer", "forager"], ["pioneer"])
	eq(played(e, func(): take_turn(e)).slice(0, 1), ["explorer"], "Explorer first: the Pioneer gains a target")


func test_without_a_settler_it_forages_instead_of_exploring() -> void:
	var e := bot_game(["explorer", "forager"], ["shrine"])
	eq(played(e, func(): take_turn(e)), ["forager"], "nothing to settle with: +1 food")


# --- AC5: an owed decision ---

func test_it_answers_an_event_choice_with_the_option_that_values_most() -> void:
	var e := bot_game(["shrine"], ["shrine", "shrine", "shrine", "shrine", "shrine"], 11, "lone",
		{"event_deck": {"gift": 1, "fleeting": 1}})
	arrange(e.zone("event_deck"), ["gift"])
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_EVENT_CHOICE, "Gift's choice owed")
	var food: int = e.resources.food
	take_turn(e)
	eq(e.pending().get("kind", ""), "", "answered")
	eq(e.resources.food - food, 3, "+3 food, not +1")


# --- AC6: unrest, legality, no side effects, repeatable ---

func test_it_stays_clear_of_the_unrest_limit() -> void:
	var near := bot_game(["riot", "forager"], [])
	near.resources["unrest"] = 3
	eq(played(near, func(): take_turn(near)), ["forager"], "Riot would take unrest 3 → 5, the limit")
	var calm := bot_game(["riot", "forager"], [])
	eq(played(calm, func(): take_turn(calm)), ["riot"], "far from the limit, Riot's +3 food wins")


func test_it_only_does_what_legal_actions_lists_and_valuing_changes_nothing() -> void:
	check(BOT != null, "sim/generic_bot.gd exists")
	if BOT == null:
		return
	var e := bot_game(["explorer", "forager", "temple"], ["pioneer", "shrine", "scout"], 11, "band")
	for step in 8:
		var before := snapshot(e)
		var best: Array = BOT.best_action(e, "generic")
		eq(snapshot(e), before, "step %d: choosing changed nothing" % step)
		if best.is_empty():
			break
		check(e.legal_actions().has(best), "step %d: %s is legal" % [step, best])
		e.callv(best[0], best.slice(1))


func test_the_same_seed_plays_the_same_game() -> void:
	check(BOT != null, "sim/generic_bot.gd exists")
	if BOT == null:
		return
	var games := []
	for i in 2:
		var e := bot_game(["explorer", "forager", "temple"], ["pioneer", "shrine", "scout", "temple"], 5, "band")
		check(BOT.play(e, "generic"), "the game ends")
		games.append([e.score(), snapshot(e)[0]])
	eq(games[1], games[0], "score and zones")


# --- The sim runs it as the strategy generic ---

func test_sim_stats_plays_the_generic_strategy() -> void:
	var e := bot_game([], [], 3, "lone", {"deck": {"shrine": 10}})  # SimStats deals from the config's deck
	var start := e.score()
	var stats: Dictionary = SimStats.run(e.card_db, e.config, [1], "generic")
	check(stats.get("score", {}).get("min", 0) >= start + 2, "Shrines played over 3 turns: %s from %d" % [stats.get("score"), start])


# --- 314 AC1: the strategies ---

func test_the_bot_plays_generic_wide_and_tall() -> void:
	check(BOT != null, "sim/generic_bot.gd exists")
	if BOT != null:
		eq(BOT.get_script_constant_map().get("STRATEGIES"), ["generic", "wide", "tall"], "GenericBot.STRATEGIES")


func test_sim_stats_plays_every_strategy_for_all_and_refuses_others() -> void:
	var jobs: Array = SimStats.job_list({"civilizations": []}, 1, "all", "")
	eq(jobs.map(func(j): return j[1]), ["generic", "wide", "tall"], "all: one job per strategy")
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 1, "baseline", {})
	check(out.get("code", 0) == 1 and str(out.get("lines", [])).contains("unknown strategy 'baseline'"),
		"baseline is gone: %s" % [out.get("lines")])


# --- 314 AC2: tall stops at 2 territories, wide likes land ---

## A Lone game (1 action, 10 turns left) with Hills settled, Grassland in the frontier and hand in the hand.
func land_game(hand: Array) -> GameEngine:
	var e := bot_game(hand, [])
	settle(e, ["hills"])
	to_frontier(e, ["grassland"])
	return e


func test_tall_never_settles_a_third_territory_and_generic_does() -> void:
	var tall := land_game(["pioneer"])
	eq(tall.play_error(first_in_hand(tall), uid_of(tall.zone("frontier"), "grassland")), "", "the Pioneer could settle")
	if BOT != null:
		BOT.take_turn(tall, "tall")
	eq(tall.zone("frontier").size(), 1, "tall: Grassland stays in the frontier")
	var generic := land_game(["pioneer"])
	take_turn(generic)
	eq(generic.zone("frontier").size(), 0, "generic: Grassland settled")


func test_wide_settles_where_generic_builds_a_temple() -> void:
	var generic := land_game(["pioneer", "temple"])
	eq(played(generic, func(): take_turn(generic)), ["temple"], "generic: the Temple's 10 turns of score")
	var wide := land_game(["pioneer", "temple"])
	var wide_turn := func():
		if BOT != null:
			BOT.take_turn(wide, "wide")
	eq(played(wide, wide_turn), ["pioneer"], "wide: a third territory")


# --- 314 AC5: ScriptedBot is gone ---

func test_scripted_bot_is_gone() -> void:
	check(not ResourceLoader.exists("res://sim/bot.gd"), "sim/bot.gd removed")
