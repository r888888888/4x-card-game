extends "res://tests/lib/anarchy_case.gd"
## The generic bot (313): it tries each of legal_actions() on a sample fork, values the result with one function and
## does the best, stopping when nothing beats doing nothing. Fixture games of a few turns (tests/lib/anarchy_case.gd:
## unrest on, home pop 6), with Lone ruling (1 action, unrest limit 5), no supply and no research deck. The bot is loaded
## untyped so this file parses before it exists.
## In detail (from docs/testing.md, 331): The generic bot (313) on fixture games (Lone: 1 action, unrest limit 5; no
## supply or research): Temple over Shrine with turns left, Shrine on the last turn, nothing when nothing helps, a draw
## first when it draws better, exploring when a settler gains a target, the better event option, clear of the unrest
## limit, only legal actions and no side effects while valuing, the same game from the same seed, SimStats playing
## `generic`; expansion costs (321): unrest coming in costs, wide's land weight stops at the admin cap, settling stops
## past it

const LONE := {"id": "lone", "name": "Lone", "type": "government", "actions": 1, "unrest_limit": 5}
## Riot: +3 food and +2 unrest. Gift: a choice event, +1 food or +3 food.
const RIOT := {"id": "riot", "name": "Riot", "type": "action", "effects": [
	{"op": "gain", "resource": "food", "amount": 3}, {"op": "gain", "resource": "unrest", "amount": 2}]}
const GIFT := {"id": "gift", "name": "Gift", "type": "event", "choices": [
	{"effects": [{"op": "gain", "resource": "food", "amount": 1}]},
	{"effects": [{"op": "gain", "resource": "food", "amount": 3}]}]}
## 321: Stewards (unlimited actions, unrest limit 20, administers 3); Colonist (5 food + 1 per territory, settles a
## City); Grumble (building, ⟳ +3 unrest) and Plinth (building, no effect).
const STEWARDS := {"id": "stewards", "name": "Stewards", "type": "government", "unrest_limit": 20, "administers": 3}
const COLONIST := {"id": "colonist", "name": "Colonist", "type": "action", "cost": {"food": 5},
	"cost_per_territory": {"food": 1}, "effects": [{"op": "settle", "card": "city"}]}
const GRUMBLE := {"id": "grumble", "name": "Grumble", "type": "building",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 3, "trigger": "upkeep"}]}
const PLINTH := {"id": "plinth", "name": "Plinth", "type": "building"}
const EXTRA := [LONE, RIOT, GIFT, STEWARDS, COLONIST, GRUMBLE, PLINTH]
## The territories an expansion game settles after the Homeland, then puts on the frontier, in order.
const LANDS := ["grassland", "grassland", "grassland", "hills", "hills", "hills", "jungle", "jungle", "jungle", "jungle"]


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
	GenericBot.take_turn(e, "generic")


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
	var e := bot_game(["explorer", "forager", "temple"], ["pioneer", "shrine", "scout"], 11, "band")
	for step in 8:
		var before := snapshot(e)
		var best: Array = GenericBot.best_action(e, "generic")
		eq(snapshot(e), before, "step %d: choosing changed nothing" % step)
		if best.is_empty():
			break
		check(e.legal_actions().has(best), "step %d: %s is legal" % [step, best])
		e.callv(best[0], best.slice(1))


func test_the_same_seed_plays_the_same_game() -> void:
	var games := []
	for i in 2:
		var e := bot_game(["explorer", "forager", "temple"], ["pioneer", "shrine", "scout", "temple"], 5, "band")
		check(GenericBot.play(e, "generic"), "the game ends")
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
	eq(GenericBot.STRATEGIES, ["generic", "wide", "tall"], "GenericBot.STRATEGIES")


func test_sim_stats_plays_every_strategy_for_all_and_refuses_others() -> void:
	var jobs: Array = SimStats.job_list({"civilizations": []}, 1, "all", "")
	eq(jobs.map(func(j): return j[1]), ["generic", "wide", "tall"], "all: one job per strategy")
	var out: Dictionary = SimStats.run_files("res://data/cards.json", "res://data/config.json", 1, "baseline", {})
	check(out.get("code", 0) == 1 and out.get("lines", [""])[0].contains("unknown strategy 'baseline'"),
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
	GenericBot.take_turn(tall, "tall")
	eq(tall.zone("frontier").size(), 1, "tall: Grassland stays in the frontier")
	var generic := land_game(["pioneer"])
	take_turn(generic)
	eq(generic.zone("frontier").size(), 0, "generic: Grassland settled")


func test_wide_settles_where_generic_builds_a_temple() -> void:
	var generic := land_game(["pioneer", "temple"])
	eq(played(generic, func(): take_turn(generic)), ["temple"], "generic: the Temple's 10 turns of score")
	var wide := land_game(["pioneer", "temple"])
	var wide_turn := func():
		GenericBot.take_turn(wide, "wide")
	eq(played(wide, wide_turn), ["pioneer"], "wide: a third territory")


# --- 314 AC5: ScriptedBot is gone ---

func test_scripted_bot_is_gone() -> void:
	check(not ResourceLoader.exists("res://sim/bot.gd"), "sim/bot.gd removed")


# --- 321: the bot weighs the rising cost of expansion ---

## A game at turn 1 of 11 with government ruling, the Homeland plus territories − 1 more settled, frontier more on the
## frontier, 40 food and exactly hand in the hand (nothing in the deck).
func expansion_game(territories: int, frontier: int, hand: Array, government := "stewards") -> GameEngine:
	var e := bot_game(hand, [], 11, government, {"territory_deck": {"grassland": 3, "hills": 3, "jungle": 4},
		"starting": {"resources": {"food": 40, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": government}})
	settle(e, LANDS.slice(0, territories - 1))
	to_frontier(e, LANDS.slice(territories - 1, territories - 1 + frontier))
	e.resources.food = 40
	return e


## GenericBot.value of e for strategy.
func value_of(e: GameEngine, strategy: String) -> float:
	return GenericBot.value(e, GenericBot.Context.new(strategy))


## How much more wide values n territories than n − 1 than generic does (all else equal): the land weight it adds.
func wide_land_step(n: int, government := "stewards") -> float:
	var more := expansion_game(n, 0, [], government)
	var fewer := expansion_game(n - 1, 0, [], government)
	return (value_of(more, "wide") - value_of(fewer, "wide")) - (value_of(more, "generic") - value_of(fewer, "generic"))


func territories_in(e: GameEngine) -> int:
	return e.zone("tableau").cards.filter(func(c): return c.def.type == CardDef.TERRITORY).size()


func test_wides_land_weight_stops_at_the_admin_cap() -> void:
	var land: float = GenericBot.WEIGHTS.wide.land
	check(absf(wide_land_step(3) - land) < 0.01, "2 → 3 territories (cap 3): + the land weight %.1f, got %.2f"
		% [land, wide_land_step(3)])
	check(absf(wide_land_step(4)) < 0.01, "3 → 4 territories (past the cap): + nothing, got %.2f" % wide_land_step(4))
	check(absf(wide_land_step(4, "lone") - land) < 0.01, "3 → 4 with no cap (Lone): + the land weight, got %.2f"
		% wide_land_step(4, "lone"))


func test_unrest_coming_in_each_turn_costs_far_from_the_limit() -> void:
	for strategy in ["generic", "wide", "tall"]:
		var calm := expansion_game(1, 0, [])
		build_on(calm, home_uid(calm), ["plinth"])
		var restless := expansion_game(1, 0, [])
		build_on(restless, home_uid(restless), ["grumble"])
		eq(restless.upkeep_forecast().get(GameEngine.UNREST), 3, "precondition: Grumble adds 3 a turn")
		check(value_of(restless, strategy) < value_of(calm, strategy),
			"%s: +3 unrest a turn (unrest 0, limit 20) values less: %.2f vs %.2f"
			% [strategy, value_of(restless, strategy), value_of(calm, strategy)])


func test_calming_unrest_each_turn_is_worth_something() -> void:
	for strategy in ["generic", "wide", "tall"]:
		var idle := expansion_game(1, 0, [])
		build_on(idle, home_uid(idle), ["plinth"])
		idle.resources["unrest"] = 5
		var calming := expansion_game(1, 0, [])
		build_on(calming, home_uid(calming), ["calm"])
		calming.resources["unrest"] = 5
		check(value_of(calming, strategy) > value_of(idle, strategy),
			"%s: −1 unrest a turn from 5 values more: %.2f vs %.2f"
			% [strategy, value_of(calming, strategy), value_of(idle, strategy)])


func test_the_generic_bot_settles_within_the_cap_but_not_further_past_it() -> void:
	var within := expansion_game(2, 2, ["colonist"])  # a spare frontier territory keeps the Colonist's worth (321)
	take_turn(within)
	eq(territories_in(within), 3, "2 → 3 territories: within the cap, settled")
	var past := expansion_game(4, 2, ["colonist"])
	eq(past.admin_unrest(), 1, "precondition: 1 past the cap")
	take_turn(past)
	eq(territories_in(past), 4, "a 5th would make it +3 unrest a turn: not settled")


func test_wide_expands_to_the_cap_and_not_past_it() -> void:
	var e := expansion_game(1, 5, ["colonist", "colonist", "colonist", "colonist"])
	GenericBot.take_turn(e, "wide")
	var held := territories_in(e)
	check(held >= 3 and held <= 4, "wide holds 3 or 4 territories (cap 3), not %d" % held)


func test_the_settlers_rising_price_lowers_its_value() -> void:
	var few := expansion_game(2, 1, [], "lone")
	var many := expansion_game(6, 1, [], "lone")
	var few_value: float = GenericBot.card_value(few, "colonist", GenericBot.Context.new("generic"))
	var many_value: float = GenericBot.card_value(many, "colonist", GenericBot.Context.new("generic"))
	check(many_value < few_value, "Colonist at 7 food (2 held) %.2f > at 11 food (6 held) %.2f" % [few_value, many_value])
