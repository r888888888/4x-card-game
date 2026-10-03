extends "res://tests/lib/anarchy_case.gd"
## The bot spends before Anarchy's drain (backlog 239): when Anarchy will fall at the next turn's start, a seeded coin
## (ScriptedBot.spends_before_drain) decides whether the bot buys supply cards down to SPEND_RESERVE (6) wealth instead
## of letting the drain (156) take 20% each turn. Fixtures: tests/lib/anarchy_case.gd (Chiefs ruling, unrest limit 5).
## The bot script is loaded untyped so this file parses before the new API exists.

var BOT: Variant = load("res://sim/bot.gd")


## An anarchy game with supply, a revolution declared and wealth, on the first seed whose coin on turn 1 is spend.
func revolution_game(spend: bool, supply: Dictionary, wealth := 20) -> GameEngine:
	var e := anarchy_engine({}, {"supply": supply})
	for s in range(1, 41):
		e.new_game(s)
		if BOT.spends_before_drain(e) == spend:
			break
	eq(BOT.spends_before_drain(e), spend, "a seed with the coin wanted")
	check(e.revolt(), "revolution declared")
	e.resources["wealth"] = wealth
	return e


# --- AC3: the coin ---

func test_the_coin_is_the_same_for_the_same_seed_and_turn_and_on_a_fork() -> void:
	var e := make_engine({"shrine": 10}, {}, 7)
	var first: bool = BOT.spends_before_drain(e)
	eq(BOT.spends_before_drain(e), first, "asked again")
	eq(BOT.spends_before_drain(e.fork()), first, "on a fork")
	eq(BOT.spends_before_drain(make_engine({"shrine": 10}, {}, 7)), first, "in a new game with the seed")


func test_the_coin_falls_both_ways_over_seeds_1_to_20() -> void:
	var seen := {}
	for s in range(1, 21):
		seen[BOT.spends_before_drain(make_engine({"shrine": 10}, {}, s))] = true
	check(seen.has(true) and seen.has(false), "both answers over 20 seeds: %s" % [seen.keys()])


func test_the_coin_changes_nothing_in_the_game() -> void:
	var deck := {"shrine": 4, "farm": 4, "scout": 4}
	var tossed := make_engine(deck, {}, 3)
	var twin := make_engine(deck, {}, 3)
	for turn in 4:
		for i in 3:
			BOT.spends_before_drain(tossed)
		tossed.end_turn()
		twin.end_turn()
		eq(card_ids(tossed.zone("hand")), card_ids(twin.zone("hand")), "turn %d: the same hand" % tossed.turn)


# --- AC4: spending down to the reserve ---

func test_with_a_revolution_declared_and_the_coin_on_spend_the_bot_buys_down_to_6_wealth() -> void:
	var e := revolution_game(true, {"farm": {"price": 2, "count": 10}})
	BOT.take_turn(e, "baseline")
	eq(e.supply_left("farm"), 3, "7 Farms bought")
	eq(e.resources["wealth"], 6, "20 − 7 × 2")


func test_the_bot_spends_on_its_preferred_cards_then_on_the_cheapest_of_any() -> void:
	var e := revolution_game(true, {"farm": {"price": 5, "count": 5}, "scout": {"price": 1, "count": 5}}, 13)
	BOT.take_turn(e, "growth")
	# Growth's usual buy takes a Farm (13 → 8); another would leave 3 < 6, so it buys Scouts down to 6.
	eq(e.supply_left("farm"), 4, "one Farm")
	eq(e.supply_left("scout"), 3, "two Scouts")
	eq(e.resources["wealth"], 6, "13 − 5 − 1 − 1")


func test_with_anarchy_ahead_from_unrest_the_bot_spends_too() -> void:
	var e := revolution_game(true, {"farm": {"price": 2, "count": 10}})
	var calm := anarchy_engine({}, {"supply": {"farm": {"price": 2, "count": 10}}})
	calm.new_game(e.seed_value)  # the same coin, no revolution: unrest at the limit instead
	calm.resources["unrest"] = 5
	calm.resources["wealth"] = 20
	check(calm.anarchy_ahead(), "Anarchy falls next turn")
	BOT.take_turn(calm, "baseline")
	eq(calm.resources["wealth"], 6, "spent down to 6")


# --- AC5: the coin on keep ---

func test_with_the_coin_on_keep_the_bot_buys_nothing_extra() -> void:
	var e := revolution_game(false, {"farm": {"price": 2, "count": 10}})
	BOT.take_turn(e, "baseline")
	eq(e.supply_left("farm"), 10, "no Farm bought")
	eq(e.resources["wealth"], 20, "wealth kept")


# --- AC6: under Anarchy nothing can be bought ---

func test_under_anarchy_the_bot_buys_nothing() -> void:
	var e := revolution_game(true, {"farm": {"price": 2, "count": 10}})
	e.end_turn()
	check(e.anarchy() != -1, "Anarchy rules")
	var wealth: int = e.resources["wealth"]
	BOT.take_turn(e, "baseline")
	eq(e.supply_left("farm"), 10, "no Farm bought")
	eq(e.resources["wealth"], wealth, "on Anarchy's first turn order can't be bought either")
