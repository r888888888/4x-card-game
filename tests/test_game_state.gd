extends "res://tests/lib/test_case.gd"
## GameState (backlog 051): the engine's state copies itself deeply (GameState.copy, GameEngine.fork), and
## upkeep_forecast runs on a copy. Engines are held as Object while fork/state don't exist yet.

const POP_ON := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}


## Every zone's card ids, by zone name.
func zone_ids(e: Object) -> Dictionary:
	var out := {}
	for name in GameEngine.ZONES:
		out[name] = card_ids(e.zone(name))
	return out


func uids(z: Zone) -> Array:
	return z.cards.map(func(c): return c.uid)


# --- AC1: a deep copy ---

func test_changing_a_fork_leaves_the_original_unchanged() -> void:
	var e: Object = make_engine({"farm": 10}, POP_ON)
	var home := home_uid(e)
	var zones_before := zone_ids(e)
	var resources_before: Dictionary = e.resources.duplicate()
	var pop_before: int = e.pop(home)
	var f: Object = e.fork()
	var capital: CardInstance = f.zone("tableau").find(uid_of(f.zone("tableau"), "capital"))
	eq(f.draw(1), 1, "the fork draws")
	f.gain(GameEngine.FOOD, 3, capital)
	f.add_pop(home, 1, capital)
	eq(f.zone("hand").size(), 6, "fork hand")
	eq(f.resources.food, resources_before.food + 3, "fork food")
	eq(f.pop(home), pop_before + 1, "fork pop")
	eq(zone_ids(e), zones_before, "original zones")
	eq(e.resources, resources_before, "original resources")
	eq(e.pop(home), pop_before, "original pop")


func test_a_fork_starts_equal_to_the_original() -> void:
	var e: Object = make_engine({"farm": 10}, POP_ON)
	var f: Object = e.fork()
	eq(zone_ids(f), zone_ids(e), "zones")
	eq(uids(f.zone("hand")), uids(e.zone("hand")), "hand uids")
	eq(f.resources, e.resources, "resources")
	eq(f.turn, e.turn, "turn")
	eq(f.score(), e.score(), "score")
	eq(f.pop(home_uid(e)), e.pop(home_uid(e)), "pop")


func test_a_fork_shuffles_like_the_original_from_its_own_rng() -> void:
	var e: Object = make_engine({"farm": 10})
	var f: Object = e.fork()
	var a := range(20)
	var b := range(20)
	var c := range(20)
	e.rng.shuffle(a)
	f.rng.shuffle(b)
	f.rng.shuffle(c)
	eq(b, a, "same next shuffle")
	check(c != b, "the fork's rng moves on by itself")


func test_a_fork_resolves_a_pending_choice_without_touching_the_original() -> void:
	var e: Object = make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(first_in_hand(e)), "play Explorer")
	var pending: Dictionary = e.pending()
	var f: Object = e.fork()
	eq(f.pending(), pending, "the fork owes the same choice")
	check(f.choose(pending.options[0]), "the fork chooses")
	eq(f.zone("frontier").size(), 1, "fork frontier")
	eq(e.pending(), pending, "the original still owes the choice")
	eq(e.zone("frontier").size(), 0, "original frontier")


func test_game_state_copy_is_independent() -> void:
	var e: Object = make_engine({"farm": 10}, POP_ON)
	var s: Object = e.state.copy()
	s.resources[GameEngine.FOOD] = 99
	s.zones["hand"].cards[0].pop = 7
	s.zones["hand"].take_top()
	eq(e.resources.food, 2, "original food")
	eq(e.zone("hand").size(), 5, "original hand")
	eq(e.zone("hand").cards[0].pop, 0, "original card")


func test_a_fork_emits_and_logs_nothing_on_the_original() -> void:
	var e: Object = make_engine({"farm": 10})
	var events := []
	e.changed.connect(func(): events.append("changed"))
	var log_size: int = e.log_lines.size()
	var f: Object = e.fork()
	f.end_turn()
	eq(events, [], "no signals on the original")
	eq(e.log_lines.size(), log_size, "original log")
	eq(e.turn, 1, "original turn")


# --- AC2: the forecast doesn't disturb the game ---

func test_forecasting_does_not_change_the_next_hand() -> void:
	var hands := []
	for forecasts in [0, 3]:
		var e := make_engine({"farm": 7}, POP_ON)  # hand 5, deck 2
		for card in e.zone("hand").cards.duplicate():
			check(e.discard_card(card.uid), "discard")
		for i in forecasts:
			e.upkeep_forecast()
		e.end_turn()  # draws 2, then reshuffles the 5 discards
		eq(e.zone("deck").size(), 2, "reshuffled: 3 of the 5 discards drawn (%d forecasts)" % forecasts)
		hands.append(uids(e.zone("hand")))
	eq(hands[1], hands[0], "next hand with 3 forecasts vs none")
