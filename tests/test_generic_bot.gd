extends "res://tests/lib/anarchy_case.gd"
## The generic bot (313): it tries each of legal_actions() on a sample fork, values the result with one function and
## does the best, stopping when nothing beats doing nothing. Fixture games of a few turns (tests/lib/anarchy_case.gd:
## unrest on, home pop 6), with Lone ruling (1 action, unrest limit 5), no supply and no research deck.
## In detail (from docs/testing.md, 331): The generic bot (313) on fixture games (Lone: 1 action, unrest limit 5; no
## supply or research): Temple over Shrine with turns left, Shrine on the last turn, nothing when nothing helps, a draw
## first when it draws better, exploring when a settler gains a target, the better event option, clear of the unrest
## limit, only legal actions and no side effects while valuing, the same game from the same seed, SimStats playing
## `generic`; expansion costs (321): unrest coming in costs, wide's land weight stops at the admin cap, settling stops
## past it; a card worth 0 still dilutes the deck, and renewal trashes the least valuable cards (373); the deck's worth
## is the best plays of a drawn hand (376); tall settles up to 3 territories, only when nothing else is worth doing (390)

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


# --- 314 AC2: wide likes land ---

## A game of government (Lone: 1 action), 10 turns left, with Hills settled, Grassland in the frontier and hand in the hand.
func land_game(hand: Array, government := "lone") -> GameEngine:
	var e := bot_game(hand, [], 11, government)
	settle(e, ["hills"])
	to_frontier(e, ["grassland"])
	return e


func test_wide_settles_where_generic_builds_a_temple() -> void:
	var generic := land_game(["pioneer", "temple"])
	eq(played(generic, func(): take_turn(generic)), ["temple"], "generic: the Temple's 10 turns of score")
	var wide := land_game(["pioneer", "temple"])
	var wide_turn := func():
		GenericBot.take_turn(wide, "wide")
	eq(played(wide, wide_turn), ["pioneer"], "wide: a third territory")


# --- 390: tall settles up to 3 territories, after everything else ---

## The land_game with Grassland settled too and Jungle in the frontier: 3 territories settled.
func third_land_game(hand: Array) -> GameEngine:
	var e := bot_game(hand, [])
	settle(e, ["hills", "grassland"])
	to_frontier(e, ["jungle"])
	return e


## The ids played by strategy's take_turn on e.
func played_by(e: GameEngine, strategy: String) -> Array[String]:
	return played(e, func(): GenericBot.take_turn(e, strategy))


func test_tall_settles_a_third_territory() -> void:
	var e := land_game(["pioneer"])
	eq(e.play_error(first_in_hand(e), uid_of(e.zone("frontier"), "grassland")), "", "the Pioneer could settle")
	eq(played_by(e, "tall"), ["pioneer"], "tall: the Pioneer played")
	eq(e.zone("frontier").size(), 0, "Grassland settled")
	eq(Territories.count_settled(e), 3, "3 territories settled")


func test_tall_never_settles_a_fourth_territory_and_generic_does() -> void:
	var tall := third_land_game(["pioneer"])
	eq(tall.play_error(first_in_hand(tall), uid_of(tall.zone("frontier"), "jungle")), "", "the Pioneer could settle")
	GenericBot.take_turn(tall, "tall")
	eq(tall.zone("frontier").size(), 1, "tall: Jungle stays in the frontier")
	var generic := third_land_game(["pioneer"])
	take_turn(generic)
	eq(generic.zone("frontier").size(), 0, "generic: Jungle settled")


## A Lone game (1 action, 10 turns left) with only the Homeland settled, Hills in the frontier and hand in the hand.
func first_land_game(hand: Array) -> GameEngine:
	var e := bot_game(hand, [])
	to_frontier(e, ["hills"])
	return e


func test_tall_plays_anything_worthwhile_before_settling() -> void:
	var generic := first_land_game(["pioneer", "shrine"])
	eq(played_by(generic, "generic"), ["pioneer"], "generic: the City is worth more than the Shrine's +1")
	var tall := first_land_game(["pioneer", "shrine"])
	eq(played_by(tall, "tall"), ["shrine"], "tall, 1 action: the Shrine, and no settling")
	eq(tall.zone("frontier").size(), 1, "Hills stays in the frontier")


func test_tall_settles_once_nothing_else_is_worth_doing() -> void:
	var e := land_game(["pioneer", "shrine"], "stewards")
	eq(e.actions_left(), -1, "Stewards: unlimited actions")
	eq(played_by(e, "tall"), ["shrine", "pioneer"], "tall: the Shrine first, then the Pioneer")
	eq(e.zone("frontier").size(), 0, "Grassland settled")


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


# --- 373: renewal trashes the least valuable cards ---

## Augury: an order card (playable under Anarchy) that gains 2 food.
const AUGURY := {"id": "augury", "name": "Augury", "type": "action", "tags": ["order"],
	"effects": [{"op": "gain", "resource": "food", "amount": 2}]}


## GenericBot.value of a bot_game with nothing in the hand, deck in the deck and government ruling.
func deck_value(deck: Array, government := "lone") -> float:
	return value_of(bot_game([], deck, 11, government), "generic")


## Rewritten by 376 (the user, 2026-10-06): 3 Temples were fewer than a hand, so every card was drawn each turn. With
## more cards than a hand and a turn that plays the whole hand (Stewards), a dead card takes a play's place.
func test_a_card_worth_0_still_dilutes_the_draws() -> void:
	var diluted := deck_value(["temple", "temple", "temple", "temple", "temple", "temple", "pioneer"], "stewards")
	var pure := deck_value(["temple", "temple", "temple", "temple", "temple", "temple"], "stewards")
	check(diluted < pure, "6 Temples and a dead Pioneer %.3f < 6 Temples %.3f" % [diluted, pure])


## A game fallen into Anarchy (turn 2) with renewal 2 owed: 5 Auguries in the hand, 5 in the deck and 2 Guildhalls in
## the discard, listed last among the options (by name, 255).
func renewal_game() -> GameEngine:
	var e := anarchy_engine({"renewal": 2}, {"turn_limit": 11, "supply": {}, "research_deck": {},
		"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10}, "tableau": ["capital"],
			"territory": "homeland", "government": "lone"}}, EXTRA + [AUGURY])
	for z in ["hand", "deck", "discard"]:
		for card in e.zone(z).take_all():
			e.zone("removed").add(card)
	for i in 5:
		put_in(e, "augury", "hand")
		put_in(e, "augury", "deck")
	for i in 2:
		put_in(e, "guildhall", "discard")
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.pending().get("kind"), GameEngine.PENDING_RENEWAL, "precondition: renewal owed")
	eq(e.pending().get("count"), 2, "precondition: 2 to renew")
	eq(e.pending().get("options", []).slice(-2).map(func(uid): return e.zone(e.zone_of(uid)).find(uid).def.id),
		["guildhall", "guildhall"], "precondition: the Guildhalls are listed last")
	return e


## The ids in e's trashed zone, sorted.
func trashed_ids(e: GameEngine) -> Array:
	var ids: Array = e.zone("trashed").cards.map(func(c): return c.def.id)
	ids.sort()
	return ids


func test_renewal_trashes_the_least_valuable_cards_even_when_listed_last() -> void:
	var e := renewal_game()
	var ctx := GenericBot.Context.new("generic")
	ctx.card_values = {"augury": [1, 1.0], "guildhall": [1, -1.0]}  # as measured on turn 1
	GenericBot.take_turn(e, "generic", ctx)
	eq(e.pending().get("kind", ""), "", "renewal answered")
	eq(trashed_ids(e), ["guildhall", "guildhall"], "the 2 Guildhalls, no Augury")


func test_a_rollout_still_answers_a_renewal() -> void:
	var e := renewal_game()
	var ctx := GenericBot.Context.new("generic")
	ctx.rollout = true
	GenericBot.take_turn(e, "generic", ctx)
	eq(e.pending().get("kind", ""), "", "renewal answered")
	eq(e.zone("trashed").size(), 2, "2 cards trashed")


# --- 376: the deck's worth is what a turn's plays from a drawn hand are worth ---

## Expected sum of the best plays of hand cards drawn from values (each floored at 0), by trying every hand.
func best_plays_by_enumeration(values: Array, hand: int, plays: int) -> float:
	var hands := all_hands(range(values.size()), mini(hand, values.size()))
	var total := 0.0
	for h in hands:
		var drawn: Array = h.map(func(i): return maxf(0.0, values[i]))
		drawn.sort()
		drawn.reverse()
		for v in drawn.slice(0, plays):
			total += v
	return total / hands.size()


## Every k-element subset of items.
func all_hands(items: Array, k: int) -> Array:
	if k == 0:
		return [[]]
	if items.size() < k:
		return []
	var out := []
	for rest in all_hands(items.slice(1), k - 1):
		out.append([items[0]] + rest)
	out.append_array(all_hands(items.slice(1), k))
	return out


func test_a_card_worth_less_than_nothing_counts_as_a_dead_card() -> void:
	var temples := ["temple", "temple", "temple", "temple", "temple", "temple"]
	var negative := deck_value(temples + ["guildhall"])
	var dead := deck_value(temples + ["pioneer"])
	check(absf(negative - dead) < 0.001, "6 Temples and a Guildhall %.3f = 6 Temples and a dead Pioneer %.3f"
		% [negative, dead])


func test_adding_a_card_worth_0_or_less_never_raises_the_decks_worth() -> void:
	var guildhalls := ["guildhall", "guildhall", "guildhall"]
	var with_dead := deck_value(guildhalls + ["pioneer"])
	var without := deck_value(guildhalls)
	check(with_dead <= without + 0.001, "3 Guildhalls and a dead Pioneer %.3f ≤ 3 Guildhalls %.3f"
		% [with_dead, without])
	var with_negative := deck_value(guildhalls + ["guildhall"])
	check(with_negative <= without + 0.001, "4 Guildhalls %.3f ≤ 3 Guildhalls %.3f" % [with_negative, without])


func test_trashing_a_dead_card_pays_when_a_hand_can_come_up_short() -> void:
	var thin := deck_value(["temple", "pioneer", "pioneer", "pioneer", "pioneer"])
	var thick := deck_value(["temple", "pioneer", "pioneer", "pioneer", "pioneer", "pioneer"])
	check(thin > thick, "a Temple and 4 dead Pioneers %.3f > with 5 (the Temple can miss the hand) %.3f"
		% [thin, thick])


func test_trashing_a_dead_card_never_lowers_the_decks_worth() -> void:
	var temples := ["temple", "temple", "temple", "temple", "temple", "temple"]
	var thinned := deck_value(temples)
	var dead := deck_value(temples + ["pioneer"])
	check(thinned >= dead - 0.001, "6 Temples %.3f ≥ 6 Temples and a dead Pioneer %.3f" % [thinned, dead])


func test_thinning_below_a_turns_plays_loses_value() -> void:
	var two := deck_value(["temple", "temple"], "band")
	var one := deck_value(["temple"], "band")
	check(two > one, "2 plays a turn (Band): 2 Temples %.3f > 1 Temple %.3f" % [two, one])


func test_an_empty_deck_is_worth_less_than_one_with_a_card_worth_something() -> void:
	var empty := deck_value([])
	var weak := deck_value(["temple", "guildhall", "guildhall", "guildhall"])
	check(empty < weak, "no cards %.3f < a Temple and 3 Guildhalls %.3f" % [empty, weak])


func test_a_card_a_turn_never_plays_adds_nothing() -> void:
	var two := deck_value(["temple", "temple"])
	var one := deck_value(["temple"])
	check(absf(two - one) < 0.001, "1 play a turn (Lone), both drawn: 2 Temples %.3f = 1 Temple %.3f" % [two, one])


func test_turn_worth_counts_the_best_plays_of_a_drawn_hand() -> void:
	eq(GenericBot.turn_worth([3.0, 1.0], 5, 1), 3.0, "both drawn, the better played")
	eq(GenericBot.turn_worth([3.0, 2.0, 1.0], 5, 2), 5.0, "all drawn, the best 2 played")
	eq(GenericBot.turn_worth([3.0, -5.0], 5, 1), 3.0, "a negative card counts as 0")
	eq(GenericBot.turn_worth([], 5, 2), 0.0, "no cards")
	check(absf(GenericBot.turn_worth([3.0, 1.0, 0.0, 0.0, 0.0, 0.0], 5, 1) - (2.5 + 1.0 / 6)) < 0.0001,
		"the 3 in 5 of 6 hands; the 1 only in the hand without the 3: 2.5 + 1/6, got %.4f"
		% GenericBot.turn_worth([3.0, 1.0, 0.0, 0.0, 0.0, 0.0], 5, 1))


func test_turn_worth_matches_every_hand_tried() -> void:
	var cases := [[[4.0, 3.0, 2.0, 1.0, 0.0, 0.0, -2.0], 5, 2], [[3.0, 3.0, 2.0, 2.0, 1.5, 1.0, 1.0, 0.5], 5, 3],
		[[5.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], 5, 1], [[2.0, 4.0, 1.0, 3.0, 0.5, 6.0], 3, 2]]
	for c in cases:
		var want := best_plays_by_enumeration(c[0], c[1], c[2])
		var got: float = GenericBot.turn_worth(c[0], c[1], c[2])
		check(absf(got - want) < 0.0001, "%s, hand %d, %d plays: %.4f, every hand gives %.4f"
			% [c[0], c[1], c[2], got, want])
