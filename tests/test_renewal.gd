extends "res://tests/lib/anarchy_case.gd"
## Renewal (backlogs 147, 155): each turn that starts under Anarchy, after the draw, owes renewal: trash 1 + (Anarchy's
## turn − 1) + the renewal modifier cards (config unrest.renewal is the base) from the discard, governments aside; each calms 1 unrest.
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


# --- AC1: renewal is owed after the draw ---

func test_renewal_is_owed_the_turn_anarchy_falls() -> void:
	var e := renewal_engine(["farm", "kings", "scout"])
	eq(ruling(e), "anarchy", "in Anarchy")
	var p: Dictionary = e.pending()
	eq(p.get("kind"), GameEngine.PENDING_RENEWAL, "kind")
	eq(p.get("count"), 1, "1 + its first turn − 1")
	var discard: Zone = e.zone("discard")
	eq(p.get("options"), [uid_of(discard, "farm"), uid_of(discard, "scout")], "the discard but the government, in order")


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
	eq([ruling(e), e.anarchy_counters(), e.pending().get("count")], ["anarchy", 4, 1], "its first turn, 4 counters: 1")
	e.renew(e.pending().options[0])
	e.end_turn()
	eq(e.anarchy_counters(), 3, "3 counters left")
	eq(e.pending().get("count"), 2, "its second turn: 1 + 1")


func test_renewal_is_capped_at_the_options() -> void:
	var e := renewal_engine(["farm"], {"renewal": 3})
	eq(e.pending().get("count"), 1, "3 asked, 1 card in the discard")


func test_nothing_is_owed_with_an_empty_discard_or_renewal_0() -> void:
	eq(renewal_engine([]).pending(), {}, "empty discard")
	eq(renewal_engine(["farm"], {}).pending(), {}, "unrest.renewal defaults to 0")


func test_unrest_renewal_validation() -> void:
	check_cases([
		["-1", anarchy_raw({"renewal": -1}), "config.json: unrest.renewal: must be an integer >= 0"],
		["not an integer", anarchy_raw({"renewal": "one"}), "config.json: unrest.renewal: must be an integer >= 0"],
	], raw_config_errors)


# --- AC2: renewing ---

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
	var wrong := "Trash a card from your discard (not a government)."
	var kings := uid_of(e.zone("discard"), "kings")
	eq(e.renew_error(kings), wrong, "a government in the discard")
	eq(e.renew_error(e.zone("hand").cards[0].uid), wrong, "a hand card")
	eq(e.renew_error(9999), wrong, "an unknown uid")
	check(not e.renew(kings), "renew refuses")
	eq([e.zone("discard").size(), e.zone("trashed").size(), e.resources.get("unrest")], [2, 0, 5], "unchanged")
	e.renew(uid_of(e.zone("discard"), "farm"))
	eq(e.renew_error(kings), "Nothing to renew.", "not pending")


# --- AC4: renewal comes first ---

func test_renewal_blocks_everything_else() -> void:
	var e := renewal_engine(["farm", "scout"], {"renewal": 2})
	var message := "Anarchy: trash 2 cards from your discard first."
	var hand: int = e.zone("hand").cards[0].uid
	eq(e.play_error(put_in_hand(e, "feast")), message, "play")
	eq(e.grow_error(home_uid(e)), message, "grow")
	eq(e.buy_error("farm"), message, "buy")
	eq(e.discard_error(hand), message, "discard")
	eq(e.end_turn_error(), message, "end turn")
	e.renew(e.pending().options[0])
	eq(e.end_turn_error(), "Anarchy: trash 1 card from your discard first.", "one left")


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
		eq(sorted(in_row), sorted([farm, kings]), "the discard pile's cards")
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


func test_the_bot_breaks_renewal_ties_by_discard_order() -> void:
	var e := renewal_engine(["shrine", "scout"])
	ScriptedBot.take_turn(e, "baseline")
	eq(card_ids(e.zone("trashed")), ["shrine"] as Array[String], "Shrine and Scout both 0: the first")


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
