extends "res://tests/lib/anarchy_case.gd"
## Renewal (backlogs 147, 155, 255): each turn that starts under Anarchy, after the draw, owes renewal: trash 1 +
## (Anarchy's turn − 1) + the renewal modifier cards (config unrest.renewal is the base) from the hand, deck or discard
## (255), governments aside, offered in name order; each calms 1 unrest.
## Nothing else can be done until it is paid. Fixtures: tests/lib/anarchy_case.gd, plus Rites (a tech, renewal +1).

const RITES := {"id": "rites", "name": "Rites", "type": "tech", "cost": {"insight": 1}, "modifiers": {"renewal": 1}}
const RENEWAL := {"renewal": 1}


## A renewal game (unrest.renewal 1) whose discard holds discard_ids when it falls into Anarchy at the start of turn 2.
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


# --- AC1: renewal is owed after the draw ---

func test_renewal_is_owed_the_turn_anarchy_falls() -> void:
	var e := renewal_engine(["scout"])
	check(e.anarchy() != -1, "in Anarchy")
	var p: Dictionary = e.pending()
	eq(p.get("kind"), GameEngine.PENDING_RENEWAL, "kind")
	eq(p.get("count"), 1, "1 + its first turn − 1")


# --- 255 AC1, AC2: the options are the hand, deck and discard, in name order ---

func test_renewal_offers_the_hand_deck_and_discard_in_name_order() -> void:
	var e := renewal_engine(["scout"])
	var lib := set_library(e, ["shrine", "farm"], ["scout", "kings", "farm"], ["calm"])
	var hand: Array = lib.hand
	var deck: Array = lib.deck
	var discard: Array = lib.discard
	# names: Calm, Farm (hand, uid lower), Farm (deck), Scout, Shrine; Kings is a government
	eq(e.pending().get("options"), [discard[0], hand[1], deck[2], deck[0], hand[0]],
		"Calm, Farm, Farm (by uid), Scout, Shrine; never Kings")
	eq(e.pending().get("count"), 1, "the count is unchanged")


## Pays the renewal owed with the first options (255: one call for the whole count).
func pay_renewal(e: GameEngine) -> void:
	var p: Dictionary = e.pending()
	check(e.renew(p.options.slice(0, p.count)), "renew: %s" % e.renew_error(p.options.slice(0, p.count)))


func test_renewal_grows_with_anarchys_turn() -> void:
	var e := renewal_engine(["farm", "scout", "shrine", "farm"])
	pay_renewal(e)
	e.end_turn()
	eq(e.pending().get("count"), 2, "1 + Anarchy's 2nd turn − 1")


func test_renewal_counts_anarchys_turn_not_its_counters_left() -> void:
	var e := anarchy_engine(RENEWAL)
	for id in ["farm", "scout", "shrine", "farm", "scout", "shrine"]:
		put_in(e, id, "discard")
	e.resources["unrest"] = 5
	check(e.revolt(), "revolt: %s" % e.revolt_error())
	e.end_turn()
	eq([e.anarchy() != -1, e.anarchy_counters(), e.pending().get("count")], [true, 4, 1], "its first turn, 4 counters: 1")
	pay_renewal(e)
	e.end_turn()
	eq(e.anarchy_counters(), 3, "3 counters left")
	eq(e.pending().get("count"), 2, "its second turn: 1 + 1")


## A renewal game with block as the unrest block whose hand and discard are emptied and deck cut to deck_size Farms
## before it falls into Anarchy at turn 2 (the draw then takes them all into the hand).
func small_library_engine(deck_size: int, block: Dictionary) -> GameEngine:
	var e := anarchy_engine(block)
	var deck_ids := []
	deck_ids.resize(deck_size)
	deck_ids.fill("farm")
	set_library(e, [], deck_ids, [])
	e.resources["unrest"] = 5
	e.end_turn()
	return e


func test_renewal_is_capped_at_the_options() -> void:
	var e := small_library_engine(2, {"renewal": 3})
	eq(e.pending().get("count"), 2, "3 asked, 2 cards in hand, deck and discard (255)")


func test_nothing_is_owed_with_an_empty_library_or_renewal_0() -> void:
	eq(small_library_engine(0, RENEWAL).pending(), {}, "no cards in hand, deck or discard (255)")
	eq(renewal_engine(["farm"], {}).pending(), {}, "unrest.renewal defaults to 0")


func test_unrest_renewal_validation() -> void:
	check_cases([
		["-1", anarchy_raw({"renewal": -1}), "config.json: unrest.renewal: must be an integer >= 0"],
		["not an integer", anarchy_raw({"renewal": "one"}), "config.json: unrest.renewal: must be an integer >= 0"],
	], raw_config_errors)


# --- AC2: renewing ---

func test_renewing_trashes_the_chosen_cards_at_once_and_keeps_the_deck_order() -> void:
	var e := renewal_engine(["scout"], {"renewal": 2})
	var lib := set_library(e, ["shrine"], ["farm", "scout", "calm"], [])
	e.resources["unrest"] = 4
	var chosen := [lib.hand[0], lib.deck[1]]
	check(e.renew(chosen), "renew the hand's Shrine and the deck's Scout: %s" % e.renew_error(chosen))
	eq(card_ids(e.zone("trashed")), ["shrine", "scout"] as Array[String], "both trashed")
	eq(e.zone("hand").size(), 0, "the hand lost the Shrine")
	eq(e.zone("deck").cards.map(func(c): return c.uid), [lib.deck[0], lib.deck[2]], "Farm, Calm: the order kept")
	eq(e.resources.get("unrest"), 2, "4 − 2")
	eq(e.pending(), {}, "paid")


func test_renewing_one_card_calms_1_unrest() -> void:
	var e := renewal_engine(["farm", "scout"])
	e.resources["unrest"] = 4
	var farm := uid_of(e.zone("discard"), "farm")
	check(e.renew([farm]), "renew: %s" % e.renew_error([farm]))
	check(e.zone("trashed").find(farm) != null, "Farm is trashed")
	eq(e.resources.get("unrest"), 3, "4 − 1")
	eq(e.pending(), {}, "nothing pending")


# --- AC3: renew_error ---

func test_renew_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var e := renewal_engine(["farm", "kings"], {"renewal": 2})
	var wrong := "Trash a card from your hand, deck or discard (not a government)."
	var kings := uid_of(e.zone("discard"), "kings")
	var farm := uid_of(e.zone("discard"), "farm")
	var hand: int = e.zone("hand").cards[0].uid
	eq(e.renew_error([kings, farm]), wrong, "a government in the discard")
	eq(e.renew_error([put_in(e, "kings", "hand"), farm]), wrong, "a government in the hand")
	eq(e.renew_error([home_uid(e), farm]), wrong, "a tableau card")
	eq(e.renew_error([9999, farm]), wrong, "an unknown uid")
	eq(e.renew_error([farm, farm]), "Each card can be trashed once.", "the same card twice")
	eq(e.renew_error([farm]), "Choose 2 cards to trash.", "too few")
	eq(e.renew_error([farm, hand, e.zone("deck").cards[0].uid]), "Choose 2 cards to trash.", "too many")
	eq(e.renew_error([farm, hand]), "", "a discard and a hand card (255)")
	var before := e.state.copy()
	check(not e.renew([kings, farm]), "renew refuses")
	check(not e.renew([farm]), "renew refuses too few")
	eq(state_diff(e.state, before), "", "a refusal changes nothing")
	e.renew([farm, hand])
	eq(e.renew_error([kings]), "Nothing to renew.", "not pending")


func test_renew_error_says_1_card_when_1_is_owed() -> void:
	var e := renewal_engine(["farm", "scout"])
	eq(e.renew_error([]), "Choose 1 card to trash.", "none chosen")


# --- AC4: renewal comes first ---

func test_renewal_blocks_everything_else() -> void:
	var e := renewal_engine(["farm", "scout"], {"renewal": 2})
	var message := "Anarchy: trash 2 cards from your hand, deck or discard first."
	var hand: int = e.zone("hand").cards[0].uid
	eq(e.play_error(put_in_hand(e, "feast")), message, "play")
	eq(e.buy_error("farm"), message, "buy")
	eq(e.discard_error(hand), message, "discard")
	eq(e.end_turn_error(), message, "end turn")
	var one := renewal_engine(["farm"])
	eq(one.end_turn_error(), "Anarchy: trash 1 card from your hand, deck or discard first.", "one owed")


# --- AC5: the renewal modifier ---

func test_the_renewal_modifier_loads_with_its_text() -> void:
	var cards := anarchy_db([RITES, {"id": "x", "name": "X", "type": "tech", "cost": {"insight": 1},
		"modifiers": {"renewal": -1}}])
	if not cards.has("rites"):
		return
	eq(cards.rites.rules_text(cards), "Renewal trashes 1 more card", "Rites")
	eq(cards.x.rules_text(cards), "Renewal trashes 1 fewer card", "a negative modifier")


func test_a_researched_renewal_tech_raises_the_count() -> void:
	var e := anarchy_engine(RENEWAL, {}, [RITES])
	e.create_card("rites", "researched", null)
	for id in ["farm", "scout", "shrine"]:
		e.create_card(id, "discard", null)
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.pending().get("count"), 2, "1 + 0 + Rites 1")


# --- AC6: the bot ---

# --- 175 AC1: no hand card can be picked up while renewal is owed ---

func test_a_hand_card_cant_be_dragged_while_renewal_is_owed() -> void:
	await with_main(anarchy_engine(RENEWAL), func(main: Node):
		var e := Game.engine
		e.create_card("farm", "discard", null)
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		eq(e.pending().get("kind"), GameEngine.PENDING_RENEWAL, "renewal owed")
		var view: CardView = main.views[first_in_hand(e)]
		view.drag_requested.emit(view, Vector2.ZERO)
		check(main.drag.dragging == null, "no drag started"))
