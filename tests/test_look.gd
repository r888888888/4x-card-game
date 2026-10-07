extends "res://tests/lib/test_case.gd"
## The look op (backlog 371): a card takes the top cards of the deck (reshuffling the discard in, as a draw does) and
## owes a take (370) of one into the hand; the rest go to the discard. One card goes to the hand at once; none, and
## nothing happens. The fixture Gaze (look 3) is local, not in TEST_CARDS, so other tests load while the op is missing.

const GAZE := {"id": "gaze", "name": "Gaze", "type": "action", "effects": [{"op": "look", "count": 3}]}


## A new game whose deck is new copies of deck_top_first (top first), whose discard is new copies of discard_ids and
## whose hand is a Caravan and a Gaze: {e, gaze, caravan, deck (uids, top first), discard (uids)}.
func look_game(deck_top_first: Array, discard_ids: Array) -> Dictionary:
	var e := make_engine({"farm": 10}, {}, 1, [GAZE])
	e.zone("hand").take_all()
	e.zone("deck").take_all()
	var deck: Array[int] = []
	for i in range(deck_top_first.size() - 1, -1, -1):  # bottom first: the top is the last added
		deck.push_front(put_in(e, deck_top_first[i], "deck"))
	var discard: Array[int] = []
	for id in discard_ids:
		discard.append(put_in(e, id, "discard"))
	return {"e": e, "caravan": put_in_hand(e, "caravan"), "gaze": put_in_hand(e, "gaze"), "deck": deck,
		"discard": discard}


func uids(z: Zone) -> Array:
	return z.cards.map(func(c): return c.uid)


## z's uids, top first.
func top_first(z: Zone) -> Array:
	var out := uids(z)
	out.reverse()
	return out


# --- AC1: the top 3 are the options ---

func test_look_owes_a_take_of_the_top_three_cards() -> void:
	var g := look_game(["farm", "scout", "temple", "shrine", "settler"], [])
	var e: GameEngine = g.e
	check(e.play_card(g.gaze), "play Gaze: %s" % e.play_error(g.gaze))
	var p := e.pending()
	eq(p.get("kind"), GameEngine.PENDING_TAKE, "a take is owed")
	eq(p.get("options", []), g.deck.slice(0, 3), "the top 3, top first")
	eq(top_first(e.zone("deck")), g.deck.slice(3), "they left the deck")
	eq(uids(e.zone("hand")), [g.caravan], "the hand is otherwise unchanged")


# --- AC2: one to the hand, the rest to the discard ---

func test_taking_one_sends_the_rest_to_the_discard() -> void:
	var g := look_game(["farm", "scout", "temple", "shrine", "settler"], [])
	var e: GameEngine = g.e
	e.play_card(g.gaze)
	var scout: int = g.deck[1]
	check(e.take(scout), "take the Scout: %s" % e.take_error(scout))
	eq(sorted(uids(e.zone("hand"))), sorted([g.caravan, scout]), "the Scout is in the hand")
	eq(sorted(uids(e.zone("discard"))), sorted([g.deck[0], g.deck[2], g.gaze]), "the Farm, the Temple and Gaze are discarded")
	eq(top_first(e.zone("deck")), g.deck.slice(3), "the deck holds the two below, in order")
	eq(e.pending(), {}, "nothing owed")


# --- AC3: a short deck reshuffles the discard in ---

func test_a_short_deck_reshuffles_the_discard_in() -> void:
	var g := look_game(["farm"], ["scout", "temple", "shrine", "settler"])
	var e: GameEngine = g.e
	check(e.play_card(g.gaze), "play Gaze: %s" % e.play_error(g.gaze))
	var options: Array = e.pending().get("options", [])
	eq(options.size(), 3, "three options")
	if options.size() != 3:
		return
	eq(options[0], g.deck[0], "the deck's card first")
	for uid in options.slice(1):
		check(g.discard.has(uid), "option %d came from the reshuffled discard" % uid)
	check(not options.has(g.gaze), "Gaze itself is not an option")
	eq(e.zone("deck").size(), 2, "the other two reshuffled cards are in the deck")


# --- AC4: one card or none ---

func test_a_lone_card_goes_to_the_hand_at_once() -> void:
	for setup in [[["farm"], []], [[], ["farm"]]]:
		var g := look_game(setup[0], setup[1])
		var e: GameEngine = g.e
		var farm: int = (g.deck + g.discard)[0]
		check(e.play_card(g.gaze), "play Gaze: %s" % e.play_error(g.gaze))
		eq(sorted(uids(e.zone("hand"))), sorted([g.caravan, farm]), "%s: the Farm is in the hand" % [setup])
		eq(e.pending(), {}, "%s: nothing owed" % [setup])


func test_with_no_cards_to_look_at_nothing_happens() -> void:
	var g := look_game([], [])
	var e: GameEngine = g.e
	check(e.play_card(g.gaze), "Gaze plays: %s" % e.play_error(g.gaze))
	eq(uids(e.zone("hand")), [g.caravan], "hand")
	eq(uids(e.zone("discard")), [g.gaze], "only Gaze is discarded")
	eq(e.pending(), {}, "nothing owed")


# --- AC5: loading and text ---

func test_look_loads() -> void:
	check_loads([
		["count 3", [GAZE], {"cards.gaze.effects.0.count": 3}],
		["count left out", [card_with("action", {"op": "look"})], {"cards.x.effects.0.count": 3}],
		["count 2", [card_with("action", {"op": "look", "count": 2})], {"cards.x.effects.0.count": 2}],
		["count 5", [card_with("action", {"op": "look", "count": 5})], {"cards.x.effects.0.count": 5}],
	], fixture_load)


func test_look_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["count 1", [card_with("action", {"op": "look", "count": 1})], [prefix, "'count'"]],
		["count 6", [card_with("action", {"op": "look", "count": 6})], [prefix, "'count'"]],
		["count not an int", [card_with("action", {"op": "look", "count": "three"})], [prefix, "'count'"]],
		["on upkeep", [card_with("building", {"op": "look", "trigger": "upkeep"})],
			prefix + "'look' only works on play (got trigger 'upkeep')"],
		["on start", [card_with("civilization", {"op": "look", "trigger": "start"})], prefix + "'look' can't trigger on start"],
		["on an event", [card_with("event", {"op": "look"})], prefix + "an event effect can't use 'look' (it opens a choice)"],
	], fixture_load.bind([TEST_CIVS]))


func test_look_card_text() -> void:
	var cards: Dictionary = fixture_load([GAZE]).cards
	if not cards.has("gaze"):
		check(false, "gaze should load")
		return
	eq(cards.gaze.rules_text(cards), "Look at the top 3 cards of your deck: take 1 into your hand, discard the rest",
		"rules_text")


# --- AC6: the cards looked at are copied with the state ---

func test_the_cards_looked_at_are_in_a_copied_zone_and_a_fork_pays_the_take_alike() -> void:
	var g := look_game(["farm", "scout", "temple", "shrine", "settler"], [])
	var e: GameEngine = g.e
	e.play_card(g.gaze)
	var options: Array = e.pending().get("options", [])
	for uid in options:
		var zone_name := e.zone_of(uid)
		check(GameEngine.ZONES.has(zone_name), "option %d is in a zone (%s)" % [uid, zone_name])
	var held := e.zone_of(g.deck[0])
	var f := e.fork()
	if held != "":
		eq(sorted(uids(f.zone(held))), sorted(uids(e.zone(held))), "the fork holds the same cards there")
	var scout: int = g.deck[1]
	check(f.take(scout), "the fork takes the Scout")
	eq(sorted(uids(f.zone("hand"))), sorted([g.caravan, scout]), "the fork's hand")
	eq(sorted(uids(f.zone("discard"))), sorted([g.deck[0], g.deck[2], g.gaze]), "the fork's discard")
	eq(e.pending().get("kind"), GameEngine.PENDING_TAKE, "this game still owes its take")
