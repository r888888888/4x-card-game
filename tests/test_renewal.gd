extends "res://tests/lib/anarchy_case.gd"
## Renewal (backlogs 147, 255, 385): during Anarchy you may trash up to unrest.renewal + the renewal modifier cards each
## turn (renewals_left()), from the hand, deck or discard (255), governments aside, offered in name order
## (renewal_options()). It is an action, not a decision: nothing waits for it, it uses no action and leaves unrest as it
## is; unused renewals don't carry over. Fixtures: tests/lib/anarchy_case.gd, plus Rites (a tech, renewal +1).

const RITES := {"id": "rites", "name": "Rites", "type": "tech", "cost": {"insight": 1}, "modifiers": {"renewal": 1}}
const RENEWAL := {"renewal": 1}


## A renewal game (unrest.renewal 1 unless block says otherwise) whose discard holds discard_ids when it falls into
## Anarchy at the start of turn 2.
func renewal_engine(discard_ids: Array, block := RENEWAL, extra := []) -> GameEngine:
	var e := anarchy_engine(block, {}, extra)
	for id in discard_ids:
		put_in(e, id, "discard")
	e.resources["unrest"] = 5
	e.end_turn()
	return e


## Replaces engine e's hand, deck and discard with new copies of hand_ids, deck_ids and discard_ids (in that order in
## each zone); the old cards go to removed. Returns {zone: [uids]}.
func set_library(e: GameEngine, hand_ids: Array, deck_ids: Array, discard_ids: Array) -> Dictionary:
	var out := {}
	for pair in [["hand", hand_ids], ["deck", deck_ids], ["discard", discard_ids]]:
		for card in e.zone(pair[0]).take_all():
			e.zone("removed").add(card)
		out[pair[0]] = pair[1].map(func(id): return put_in(e, id, pair[0]))
	return out


# --- 385 AC1: an action, not a decision ---

func test_renewal_is_an_action_that_owes_nothing() -> void:
	var e := renewal_engine(["scout"])
	check(e.anarchy() != -1, "in Anarchy")
	e.set_unrest(3)
	eq(e.pending(), {}, "no decision is owed")
	eq(e.renewals_left(), 1, "1 renewal this turn")
	var actions := e.actions_left()
	var card: int = first_in_hand(e)
	check(e.renew([card]), "renew a hand card: %s" % e.renew_error([card]))
	check(e.zone("trashed").find(card) != null, "trashed")
	eq(e.resources.unrest, 3, "unrest unchanged")
	eq(e.renewals_left(), 0, "none left")
	eq(e.actions_left(), actions, "no action used")


# --- 255: the options are the hand, deck and discard, in name order ---

func test_renewal_offers_the_hand_deck_and_discard_in_name_order() -> void:
	var e := renewal_engine(["scout"])
	var lib := set_library(e, ["shrine", "farm"], ["scout", "kings", "farm"], ["calm"])
	var hand: Array = lib.hand
	var deck: Array = lib.deck
	var discard: Array = lib.discard
	# names: Calm, Farm (hand, uid lower), Farm (deck), Scout, Shrine; Kings is a government
	eq(e.renewal_options(), [discard[0], hand[1], deck[2], deck[0], hand[0]],
		"Calm, Farm, Farm (by uid), Scout, Shrine; never Kings")


func test_renewing_keeps_the_deck_order() -> void:
	var e := renewal_engine(["scout"], {"renewal": 2})
	var lib := set_library(e, ["shrine"], ["farm", "scout", "calm"], [])
	var chosen := [lib.hand[0], lib.deck[1]]
	check(e.renew(chosen), "renew the hand's Shrine and the deck's Scout: %s" % e.renew_error(chosen))
	eq(card_ids(e.zone("trashed")), ["shrine", "scout"] as Array[String], "both trashed")
	eq(e.zone("hand").size(), 0, "the hand lost the Shrine")
	eq(e.zone("deck").cards.map(func(c): return c.uid), [lib.deck[0], lib.deck[2]], "Farm, Calm: the order kept")


func test_unrest_renewal_validation() -> void:
	check_cases([
		["-1", anarchy_raw({"renewal": -1}), "config.json: unrest.renewal: must be an integer >= 0"],
		["not an integer", anarchy_raw({"renewal": "one"}), "config.json: unrest.renewal: must be an integer >= 0"],
	], raw_config_load)


# --- 385 AC2: a flat count per turn ---

func test_the_count_is_flat_and_unused_renewals_dont_carry_over() -> void:
	var e := renewal_engine(["farm", "scout", "shrine"])
	e.end_turn()  # its first turn ends with its renewal unused
	eq(e.renewals_left(), 1, "its second turn: 1, no ramp")
	var farm := uid_of(e.zone("discard"), "farm")
	check(e.renew([farm]), "renew a discard card: %s" % e.renew_error([farm]))
	var scout := uid_of(e.zone("discard"), "scout")
	eq(e.renew_error([scout]), "No renewals left this turn.", "a second is refused")
	var before := e.state.copy()
	check(not e.renew([scout]), "renew refuses")
	eq(state_diff(e.state, before), "", "and changes nothing")
	e.end_turn()
	eq(e.renewals_left(), 1, "its third turn: 1 again")


# --- 385 AC3: the modifier raises the cap ---

func test_a_renewal_modifier_raises_the_count_each_anarchy_turn() -> void:
	var e := anarchy_engine(RENEWAL, {}, [RITES])
	e.create_card("rites", "researched", null)
	for id in ["farm", "scout", "shrine", "farm"]:
		e.create_card(id, "discard", null)
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.renewals_left(), 2, "its first turn: 1 + Rites 1")
	var two: Array = e.renewal_options().slice(0, 2)
	check(e.renew(two), "one renew of two cards: %s" % e.renew_error(two))
	e.end_turn()
	eq(e.renewals_left(), 2, "its second turn: 2 again")


func test_without_renewal_in_the_config_there_is_none() -> void:
	var e := renewal_engine(["farm"], {})
	eq(e.renewals_left(), 0, "unrest.renewal absent")
	var farm := uid_of(e.zone("discard"), "farm")
	check(e.renew_error([farm]) != "", "renew_error says no")
	check(not e.renew([farm]), "renew refuses")


func test_the_renewal_modifier_loads_with_its_text() -> void:
	var cards := anarchy_db([RITES, {"id": "x", "name": "X", "type": "tech", "cost": {"insight": 1},
		"modifiers": {"renewal": -1}}])
	eq(cards.rites.rules_text(cards), "Renew up to 1 more card each Anarchy turn", "Rites")
	eq(cards.x.rules_text(cards), "Renew up to 1 fewer card each Anarchy turn", "a negative modifier")


# --- 385 AC4: rejections ---

func test_renew_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var e := renewal_engine(["farm", "kings", "scout"], {"renewal": 2})
	var wrong := "Trash a card from your hand, deck or discard (not a government)."
	var kings := uid_of(e.zone("discard"), "kings")
	var farm := uid_of(e.zone("discard"), "farm")
	var scout := uid_of(e.zone("discard"), "scout")
	var hand: int = first_in_hand(e)
	var rows := [
		["none chosen", [], "Choose a card to trash."],
		["a government in the discard", [kings], wrong],
		["a government in the hand", [put_in(e, "kings", "hand")], wrong],
		["a tableau card", [home_uid(e)], wrong],
		["an unknown uid", [9999], wrong],
		["the same card twice", [farm, farm], "Each card can be trashed once."],
		["more than are left", [farm, scout, hand], "Trash at most 2 cards this turn."],
	]
	for row in rows:
		eq(e.renew_error(row[1]), row[2], row[0])
		var before := e.state.copy()
		check(not e.renew(row[1]), "%s: renew refuses" % row[0])
		eq(state_diff(e.state, before), "", "%s: a refusal changes nothing" % row[0])
	eq(e.renew_error([farm, hand]), "", "a discard and a hand card (255)")


func test_renew_is_refused_outside_anarchy() -> void:
	var e := anarchy_engine(RENEWAL)
	var farm := put_in(e, "farm", "discard")
	eq(e.renewals_left(), 0, "no Anarchy: none")
	eq(e.renew_error([farm]), "Renewal is only possible during Anarchy.", "renew_error")
	check(not e.renew([farm]), "renew refuses")


func test_renew_is_refused_while_a_decision_is_owed_or_the_game_is_over() -> void:
	var e := renewal_engine(["farm"])
	var farm := uid_of(e.zone("discard"), "farm")
	for i in e.config.hand_limit + 1 - e.zone("hand").size():
		put_in_hand(e, "scout")
	e.end_turn()  # a discard is owed
	eq(e.renew_error([farm]), "Discard down to %d cards first." % e.config.hand_limit, "a discard owed")
	var over := renewal_engine(["farm"])
	over.is_over = true
	eq(over.renew_error([uid_of(over.zone("discard"), "farm")]), "The game is over.", "game over")


# --- 385 AC6: legal actions ---

func test_renewal_is_one_legal_entry_while_renewals_are_left() -> void:
	var e := renewal_engine(["farm", "scout"])
	var entry := ["renew", e.renewal_options(), e.renewals_left()]
	check(e.legal_actions().has(entry), "one entry, choose renewals_left() of renewal_options(): %s" % [entry])
	eq(e.renew_error([e.renewal_options()[0]]), "", "its first card passes renew_error")
	check(e.renew([e.renewal_options()[0]]), "renew")
	check(not e.legal_actions().any(func(a): return a[0] == "renew"), "no renewals left: no entry")
	var calm := anarchy_engine(RENEWAL)
	check(not calm.legal_actions().any(func(a): return a[0] == "renew"), "no Anarchy: no entry")


# --- 385: the state is copied ---

func test_a_copy_keeps_the_renewals_used() -> void:
	var e := renewal_engine(["farm", "scout"])
	check(e.renew([e.renewal_options()[0]]), "renew")
	eq(e.fork().renewals_left(), 0, "the fork has none left either")
