extends "res://tests/lib/test_case.gd"
## The recall op and the take decision (backlog 370): a card takes one card from the discard pile back into the hand.
## Several cards to take from are a take decision (`take(uid)`, `take_error(uid)`); one goes to the hand at once; an
## empty discard can't be recalled from. The fixture Recall (+1 action, recall) is RECALL_CARD in tests/lib, not in
## TEST_CARDS, so other tests load while the op is missing. Games are ruled by TEST_GOVS' Band (2 actions).

const NO_DISCARD := "There is no card in your discard pile to take back."


## A new game ruled by Band whose hand is a Shrine and a Recall and whose discard is new copies of discard_ids, the
## rest of the dealt cards in the deck: {e, recall, shrine, discard (uids, in discard_ids' order)}.
func recall_game(discard_ids: Array) -> Dictionary:
	var r := fixture_load([RECALL_CARD], [TEST_GOVS, TEST_CIVS])
	check(r.errors.is_empty(), "test data should load: %s" % [r.errors])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var starting := {"resources": {"food": 2}, "tableau": ["capital"], "territory": "homeland", "government": "band"}
	var config := DataLoader.parse_config(raw_config({"farm": 10}, {"starting": starting}), resources(), r.cards,
		"config.json", errors, warnings)
	check(errors.is_empty(), "config should load: %s" % [errors])
	var e := GameEngine.new(r.cards, config)
	e.new_game(1)
	for card in e.zone("hand").take_all():
		e.zone("deck").add(card)
	var discard: Array[int] = []
	for id in discard_ids:
		discard.append(put_in(e, id, "discard"))
	return {"e": e, "shrine": put_in_hand(e, "shrine"), "recall": put_in_hand(e, "recall"), "discard": discard}


func uids(z: Zone) -> Array:
	return z.cards.map(func(c): return c.uid)


# --- AC1: several cards in the discard: a take is owed ---

func test_recall_owes_a_take_of_each_discard_card() -> void:
	var g := recall_game(["farm", "scout", "temple"])
	var e: GameEngine = g.e
	check(e.play_card(g.recall), "play Recall: %s" % e.play_error(g.recall))
	var p := e.pending()
	eq(p.get("kind"), GameEngine.PENDING_TAKE, "a take is owed")
	eq(sorted(p.get("options", [])), sorted(g.discard), "the three discard cards are the options")
	check(not p.get("options", []).has(g.recall), "Recall itself is not an option")
	eq(uids(e.zone("hand")), [g.shrine], "the hand is otherwise unchanged")
	eq(e.actions_left(), 2, "one action used, one gained")


# --- AC2: taking one ---

func test_taking_an_option_moves_it_to_the_hand_and_leaves_the_rest_in_the_discard() -> void:
	var g := recall_game(["farm", "scout", "temple"])
	var e: GameEngine = g.e
	e.play_card(g.recall)
	var scout: int = g.discard[1]
	eq(e.take_error(scout), "", "take_error")
	check(e.take(scout), "take the Scout")
	eq(sorted(uids(e.zone("hand"))), sorted([g.shrine, scout]), "the Scout is in the hand")
	eq(sorted(uids(e.zone("discard"))), sorted([g.discard[0], g.discard[2], g.recall]),
		"the Farm, the Temple and Recall are in the discard")
	eq(e.pending(), {}, "nothing owed")


# --- AC3: one card in the discard goes to the hand at once ---

func test_a_lone_discard_card_goes_to_the_hand_at_once() -> void:
	var g := recall_game(["farm"])
	var e: GameEngine = g.e
	check(e.play_card(g.recall), "play Recall: %s" % e.play_error(g.recall))
	eq(sorted(uids(e.zone("hand"))), sorted([g.shrine, g.discard[0]]), "the Farm is in the hand")
	eq(uids(e.zone("discard")), [g.recall], "only Recall is in the discard")
	eq(e.pending(), {}, "nothing owed")


# --- AC4: an empty discard ---

func test_recall_with_an_empty_discard_is_refused() -> void:
	var g := recall_game([])
	var e: GameEngine = g.e
	var before := e.state.copy()
	eq(e.play_error(g.recall), NO_DISCARD, "play_error")
	check(not e.play_card(g.recall), "play_card refuses")
	eq(state_diff(e.state, before), "", "nothing changed")
	eq(e.actions_left(), 2, "no action used")


# --- AC5: take_error, legal_actions ---

func test_take_error_refuses_a_card_that_isnt_a_choice_or_when_no_take_is_owed() -> void:
	var g := recall_game(["farm", "scout"])
	var e: GameEngine = g.e
	eq(e.take_error(g.discard[0]), "There is no card to take.", "nothing owed")
	check(not e.take(g.discard[0]), "take refuses with nothing owed")
	e.play_card(g.recall)
	var before := e.state.copy()
	eq(e.take_error(g.shrine), "That card isn't one of the choices.", "a hand card")
	check(not e.take(g.shrine), "take refuses the Shrine")
	eq(state_diff(e.state, before), "", "nothing changed")


func test_a_take_lists_one_entry_per_option() -> void:
	var g := recall_game(["farm", "scout", "temple"])
	var e: GameEngine = g.e
	e.play_card(g.recall)
	var options: Array = e.pending().get("options", [])
	eq(e.legal_actions(), options.map(func(o): return ["take", o]), "one take per option")


# --- AC6: loading and text ---

func test_recall_loads() -> void:
	check_loads([
		["Recall", [RECALL_CARD], {}],
		["recall alone", [card_with("action", {"op": "recall"})], {}],
	], fixture_load)


func test_recall_validation() -> void:
	var prefix := "cards.json: card 'x': effects[0]: "
	check_cases([
		["on upkeep", [card_with("building", {"op": "recall", "trigger": "upkeep"})],
			prefix + "'recall' only works on play (got trigger 'upkeep')"],
		["on start", [card_with("civilization", {"op": "recall", "trigger": "start"})],
			prefix + "'recall' can't trigger on start"],
		["on an event", [card_with("event", {"op": "recall"})], prefix + "an event effect can't use 'recall' (it opens a choice)"],
	], fixture_load.bind([TEST_CIVS]))
	has_msg(fixture_load([card_with("action", {"op": "recall", "amount": 2})]).warnings,
		"unknown field 'amount' in 'recall' effect")


func test_recall_card_text() -> void:
	var cards: Dictionary = fixture_load([card_with("action", {"op": "recall"})]).cards
	if not cards.has("x"):
		check(false, "x should load")
		return
	eq(cards.x.rules_text(cards), "Take a card from your discard pile into your hand", "rules_text")


# --- AC7: the choice overlay ---

func test_the_take_overlay_shows_the_options_and_a_click_takes_one() -> void:
	await with_main(make_engine({"farm": 10}, {}, 1, [RECALL_CARD]), func(main: Node):
		var e := Game.engine
		var farm := put_in(e, "farm", "discard")
		var scout := put_in(e, "scout", "discard")
		var recall := put_in_hand(e, "recall")
		check(e.play_card(recall), "play Recall: %s" % e.play_error(recall))
		await wait_frames()
		var row: Node = main.choices.get("take_row")
		check(row != null and row.is_visible_in_tree(), "the take overlay is up")
		if row == null:
			return
		eq(sorted(main.views_in(row).map(func(v): return v.uid)), sorted([farm, scout]), "the options are its cards")
		main.card_actions.on_picked(main.views[scout])
		await wait_frames()
		check(e.zone("hand").find(scout) != null, "a click takes the Scout into the hand")
		check(not row.is_visible_in_tree(), "the overlay closes"))
