extends "res://tests/lib/test_case.gd"
## GameState (backlog 051): the engine's state copies itself deeply (GameState.copy, GameEngine.fork), and
## upkeep_forecast runs on a copy.

const POP_ON := {"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 1}}


## Every zone's card ids, by zone name.
func zone_ids(e: GameEngine) -> Dictionary:
	var out := {}
	for name in GameEngine.ZONES:
		out[name] = card_ids(e.zone(name))
	return out


func uids(z: Zone) -> Array:
	return z.cards.map(func(c): return c.uid)


# --- AC1: a deep copy ---

func test_changing_a_fork_leaves_the_original_unchanged() -> void:
	var e: GameEngine = make_engine({"farm": 10}, POP_ON)
	var home := home_uid(e)
	var zones_before := zone_ids(e)
	var resources_before: Dictionary = e.resources.duplicate()
	var pop_before: int = e.pop(home)
	var f: GameEngine = e.fork()
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
	var e: GameEngine = make_engine({"farm": 10}, POP_ON)
	var f: GameEngine = e.fork()
	eq(zone_ids(f), zone_ids(e), "zones")
	eq(uids(f.zone("hand")), uids(e.zone("hand")), "hand uids")
	eq(f.resources, e.resources, "resources")
	eq(f.turn, e.turn, "turn")
	eq(f.score(), e.score(), "score")
	eq(f.pop(home_uid(e)), e.pop(home_uid(e)), "pop")


func test_a_fork_shuffles_like_the_original_from_its_own_rng() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var f: GameEngine = e.fork()
	var a := range(20)
	var b := range(20)
	var c := range(20)
	e.rng.shuffle(a)
	f.rng.shuffle(b)
	f.rng.shuffle(c)
	eq(b, a, "same next shuffle")
	check(c != b, "the fork's rng moves on by itself")


func test_a_fork_resolves_a_pending_choice_without_touching_the_original() -> void:
	var e: GameEngine = make_engine({"explorer": 10}, {"territory_deck": {"hills": 1, "grassland": 1}})
	check(e.play_card(first_in_hand(e)), "play Explorer")
	var pending: Dictionary = e.pending()
	var f: GameEngine = e.fork()
	eq(f.pending(), pending, "the fork owes the same choice")
	check(f.choose(pending.options[0]), "the fork chooses")
	eq(f.zone("frontier").size(), 1, "fork frontier")
	eq(e.pending(), pending, "the original still owes the choice")
	eq(e.zone("frontier").size(), 0, "original frontier")


func test_game_state_copy_is_independent() -> void:
	var e: GameEngine = make_engine({"farm": 10}, POP_ON)
	var s: Object = e.state.copy()
	s.resources[GameEngine.FOOD] = 99
	s.zones["hand"].cards[0].pop = 7
	s.zones["hand"].take_top()
	eq(e.resources.food, 2, "original food")
	eq(e.zone("hand").size(), 5, "original hand")
	eq(e.zone("hand").cards[0].pop, 0, "original card")


func test_a_fork_emits_and_logs_nothing_on_the_original() -> void:
	var e: GameEngine = make_engine({"farm": 10})
	var events := []
	e.changed.connect(func(): events.append("changed"))
	var log_size: int = e.log_lines.size()
	var f: GameEngine = e.fork()
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


# --- 311: a sample fork reshuffles what the player can't see ---

## A game on TEST_CARDS + TEST_EVENTS with 10 cards in the deck (15 Farms, 5 in hand), 10 events and 10 territories.
func hidden_game(seed_value := 1) -> GameEngine:
	return make_engine({"farm": 15}, {"event_deck": {"omen": 4, "windfall": 3, "harvest": 3},
		"territory_deck": {"hills": 3, "grassland": 3, "jungle": 2, "river": 2}}, seed_value, TEST_EVENTS)


## e.sample_fork(s), held as Object until the method exists (red phase).
func sample(e: GameEngine, s: int) -> GameEngine:
	var o: Object = e
	return o.call("sample_fork", s)


## A zone's cards as [uid, id, pop, territory_uid, turns_left], in order.
func cards_of_zone(z: Zone) -> Array:
	return z.cards.map(func(c): return [c.uid, c.def.id, c.pop, c.territory_uid, c.turns_left])


## Whether the zone_name order of samples from seeds 1 to 20 differs from e's at least once, the same seed giving the
## same order twice, and the cards always the same.
func check_reshuffled(e: GameEngine, zone_name: String) -> void:
	var game_order := uids(e.zone(zone_name))
	check(game_order.size() >= 10, "%s holds %d cards" % [zone_name, game_order.size()])
	var differs := false
	for s in range(1, 21):
		var order := uids(sample(e, s).zone(zone_name))
		var sorted_order := order.duplicate()
		sorted_order.sort()
		var sorted_game := game_order.duplicate()
		sorted_game.sort()
		eq(sorted_order, sorted_game, "%s seed %d: the same cards" % [zone_name, s])
		eq(uids(sample(e, s).zone(zone_name)), order, "%s seed %d twice: the same order" % [zone_name, s])
		differs = differs or order != game_order
	check(differs, "%s: some seed in 1–20 reorders it" % zone_name)


func test_a_sample_fork_reshuffles_the_deck_from_its_seed() -> void:
	check_reshuffled(hidden_game(), "deck")


func test_a_sample_fork_reshuffles_the_event_and_territory_decks() -> void:
	var e := hidden_game()
	check_reshuffled(e, "event_deck")
	check_reshuffled(e, "territory_deck")


func test_everything_the_player_sees_is_the_same_in_a_sample() -> void:
	var e := make_engine({"explorer": 10}, {"event_deck": {"omen": 4, "windfall": 3, "harvest": 3},
		"territory_deck": {"hills": 3, "grassland": 3, "jungle": 2, "river": 2},
		"supply": {"farm": {"price": 1, "count": 3}}}, 1, TEST_EVENTS)
	e.end_turn()  # an event active, the hand redrawn
	check(e.play_card(first_in_hand(e)), "play Explorer")
	check(e.choose(e.pending().options[0]), "a territory into the frontier")
	check(e.play_card(first_in_hand(e)), "play another Explorer: a choice owed")
	check(not e.zone("active_events").is_empty(), "an event active")
	check(not e.zone("frontier").is_empty(), "a frontier territory")
	check(not e.zone("discard").is_empty(), "cards in the discard")
	var f := sample(e, 7)
	for zone_name in GameEngine.ZONES:
		if zone_name in ["deck", "event_deck", "territory_deck"]:
			continue
		eq(cards_of_zone(f.zone(zone_name)), cards_of_zone(e.zone(zone_name)), "zone %s" % zone_name)
	eq(f.resources, e.resources, "resources")
	eq(f.turn, e.turn, "turn")
	eq(f.pending(), e.pending(), "the owed explore choice, with its options")
	eq(f.supply(), e.supply(), "supply")
	eq(f.score(), e.score(), "score")


func test_a_samples_later_shuffles_come_from_its_seed_not_the_games_rng() -> void:
	var draws := func(f: GameEngine) -> Array:
		var a := range(20)
		f.rng.shuffle(a)
		return a
	var e1 := hidden_game(1)
	var e2 := hidden_game(2)
	eq(draws.call(sample(e1, 7)), draws.call(sample(e2, 7)), "seed 7 draws alike whatever the game's seed")
	eq(draws.call(sample(e1, 7)), draws.call(sample(e1, 7)), "seed 7 twice")
	check(draws.call(sample(e1, 7)) != draws.call(sample(e1, 8)), "seeds 7 and 8 draw differently")


func test_a_sample_leaves_the_game_untouched() -> void:
	var e := hidden_game()
	var twin := e.fork()
	var before := {}
	for zone_name in GameEngine.ZONES:
		before[zone_name] = uids(e.zone(zone_name))
	for s in range(1, 6):
		sample(e, s)
	for zone_name in GameEngine.ZONES:
		eq(uids(e.zone(zone_name)), before[zone_name], "zone %s" % zone_name)
	var a := range(20)
	var b := range(20)
	e.rng.shuffle(a)
	twin.rng.shuffle(b)
	eq(a, b, "the game's next shuffle as without the samples")
