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


func test_renewal_grows_with_anarchys_turn() -> void:
	var e := renewal_engine(["farm", "scout", "shrine", "farm"])
	e.renew(e.pending().options[0])
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
	e.renew(e.pending().options[0])
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

func test_renewing_trashes_a_hand_or_deck_card_and_keeps_the_deck_order() -> void:
	var e := renewal_engine(["scout"], {"renewal": 2})
	var lib := set_library(e, ["shrine"], ["farm", "scout", "calm"], [])
	e.resources["unrest"] = 4
	check(e.renew(lib.hand[0]), "renew the hand's Shrine: %s" % e.renew_error(lib.hand[0]))
	check(e.renew(lib.deck[1]), "renew the deck's Scout: %s" % e.renew_error(lib.deck[1]))
	eq(card_ids(e.zone("trashed")), ["shrine", "scout"] as Array[String], "both trashed")
	eq(e.zone("hand").size(), 0, "the hand lost the Shrine")
	eq(e.zone("deck").cards.map(func(c): return c.uid), [lib.deck[0], lib.deck[2]], "Farm, Calm: the order kept")
	eq(e.resources.get("unrest"), 2, "4 − 2")
	eq(e.pending(), {}, "paid")


func test_renewing_trashes_the_card_and_calms_1_unrest() -> void:
	var e := renewal_engine(["farm", "scout"], {"renewal": 2})
	e.resources["unrest"] = 4
	var farm := uid_of(e.zone("discard"), "farm")
	check(e.renew(farm), "renew: %s" % e.renew_error(farm))
	check(e.zone("trashed").find(farm) != null, "Farm is trashed")
	eq(e.resources.get("unrest"), 3, "4 − 1")
	eq(e.pending().get("count"), 1, "1 left")
	check(e.renew(uid_of(e.zone("discard"), "scout")), "renew the Scout")
	eq(e.pending(), {}, "nothing pending")


# --- AC3: renew_error ---

func test_renew_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var e := renewal_engine(["farm", "kings"])
	var wrong := "Trash a card from your hand, deck or discard (not a government)."
	var kings := uid_of(e.zone("discard"), "kings")
	eq(e.renew_error(kings), wrong, "a government in the discard")
	eq(e.renew_error(put_in(e, "kings", "hand")), wrong, "a government in the hand")
	eq(e.renew_error(home_uid(e)), wrong, "a tableau card")
	eq(e.renew_error(9999), wrong, "an unknown uid")
	eq(e.renew_error(e.zone("hand").cards[0].uid), "", "a hand card may be trashed (255)")
	var before := e.state.copy()
	check(not e.renew(kings), "renew refuses")
	eq(state_diff(e.state, before), "", "a refusal changes nothing")
	e.renew(uid_of(e.zone("discard"), "farm"))
	eq(e.renew_error(kings), "Nothing to renew.", "not pending")


# --- AC4: renewal comes first ---

func test_renewal_blocks_everything_else() -> void:
	var e := renewal_engine(["farm", "scout"], {"renewal": 2})
	var message := "Anarchy: trash 2 cards from your hand, deck or discard first."
	var hand: int = e.zone("hand").cards[0].uid
	eq(e.play_error(put_in_hand(e, "feast")), message, "play")
	eq(e.grow_error(home_uid(e)), message, "grow")
	eq(e.buy_error("farm"), message, "buy")
	eq(e.discard_error(hand), message, "discard")
	eq(e.end_turn_error(), message, "end turn")
	e.renew(e.pending().options[0])
	eq(e.end_turn_error(), "Anarchy: trash 1 card from your hand, deck or discard first.", "one left")


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


# --- The Renewal overlay (Design notes) ---

func test_the_renewal_overlay_shows_the_options_in_order_with_the_hand_in_it() -> void:
	await with_main(anarchy_engine(RENEWAL), func(main: Node):
		var e := Game.engine
		e.create_card("scout", "discard", null)
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		var row: Node = main.choices.get("renewal_row")
		check(row != null and row.is_visible_in_tree(), "the Renewal overlay is up")
		if row == null:
			return
		eq(main.views_in(row).map(func(v): return v.uid), e.pending().get("options"), "the options, in their order")
		eq(main.views_in(main.hand).size(), 0, "the hand's cards are in the row")
		main.on_picked(main.views[uid_of(e.zone("discard"), "scout")])
		await wait_frames()
		check(not row.is_visible_in_tree(), "the overlay closes when done")
		eq(main.views_in(main.hand).size(), e.zone("hand").size(), "the hand is back"))


func test_the_renewal_overlay_shows_the_discard_and_a_click_trashes() -> void:
	await with_main(anarchy_engine(RENEWAL), func(main: Node):
		var e := Game.engine
		e.create_card("farm", "discard", null)
		put_in(e, "kings", "discard")
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		var row: Node = main.choices.get("renewal_row")
		check(row != null and row.is_visible_in_tree(), "the Renewal overlay is up")
		if row == null:
			return
		var farm := uid_of(e.zone("discard"), "farm")
		var kings := uid_of(e.zone("discard"), "kings")
		var in_row: Array = main.views_in(row).map(func(v): return v.uid)
		check(in_row.has(farm) and not in_row.has(kings), "the discard's Farm, not the government (255)")
		main.on_picked(main.views[kings])
		check(e.zone("discard").find(kings) != null, "a government refuses")
		main.on_picked(main.views[farm])
		check(e.zone("trashed").find(farm) != null, "a click trashes the Farm")
		await wait_frames()
		check(not row.is_visible_in_tree(), "the overlay closes when done"))


# --- AC6: the bot ---

func test_the_bot_renews_the_card_worth_least_to_keep() -> void:
	var e := renewal_engine(["farm", "scout", "kings"])
	ScriptedBot.take_turn(e, "baseline")
	eq(card_ids(e.zone("trashed")), ["scout"] as Array[String], "Scout (0) before Farm (2 food + 4 building)")


func test_the_bot_breaks_renewal_ties_by_name_order() -> void:
	var e := renewal_engine(["shrine", "scout"])
	ScriptedBot.take_turn(e, "baseline")
	eq(card_ids(e.zone("trashed")), ["scout"] as Array[String], "Shrine and Scout both 0: Scout, first by name (255)")


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
