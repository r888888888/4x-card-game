extends "res://tests/lib/anarchy_case.gd"
## The government deck (backlog 154): a created government goes to the `governments` zone, once per id; a fallen
## government goes there too; when Anarchy ends (burning out or restore_order) the player chooses one from it
## (PENDING_GOVERNMENT, choose_government), and unrest drops to at most half its limit. The Government overlay, the
## identity modal's deck line, and the bot's choice. Fixtures: tests/lib/anarchy_case.gd plus Charter (an action that
## creates Kings in the discard); TEST_GOVS' Kingdom (cost 2 food, play +1 wealth), Band (2 actions), Court (3).

const CHARTER := {"id": "charter", "name": "Charter", "type": "action",
	"effects": [{"op": "create", "card": "kings", "zone": "discard"}]}
const CHOOSE_FIRST := "Choose a government first."


## An anarchy game (Charter in the card db).
func deck_engine(unrest := {}) -> GameEngine:
	return anarchy_engine(unrest, {}, [CHARTER])


## A game whose Anarchy has just burnt out, Chiefs having fallen into the government deck and govs created there
## after it; the government choice is owed.
func choosing_engine(govs: Array[String] = ["kings"]) -> GameEngine:
	var e := anarchy_engine({}, {}, [CHARTER])
	e.resources["unrest"] = 5
	e.end_turn()  # falls into Anarchy at turn 2's start
	for id in govs:
		e.create_card(id, "discard", null)
	for i in 4:
		e.end_turn()  # 4 counters: burns out
	return e


## The outcome of playing hand card uid.
func play_outcome(e: GameEngine, uid: int) -> Dictionary:
	var outcomes: Array = []
	e.card_played.connect(func(o): outcomes.append(o))
	check(e.play_card(uid), "play: %s" % e.play_error(uid))
	return outcomes[0] if outcomes.size() == 1 else {}


# --- AC1: created governments go to the government deck, once each ---

func test_a_created_government_goes_to_the_government_deck() -> void:
	var e := deck_engine()
	var outcome := play_outcome(e, put_in_hand(e, "charter"))
	var kings := uid_of(e.zone("governments"), "kings")
	check(kings != -1, "Kings is in the government deck: %s" % [card_ids(e.zone("governments"))])
	eq(uid_of(e.zone("discard"), "kings"), -1, "not in the discard")
	eq(outcome.get("created", []), [kings], "the outcome lists it")


func test_a_known_government_isnt_created_again() -> void:
	var e := deck_engine()
	play_outcome(e, put_in_hand(e, "charter"))
	var again := play_outcome(e, put_in_hand(e, "charter"))
	eq(card_ids(e.zone("governments")), ["kings"] as Array[String], "one Kings")
	eq(again.get("created", []), [], "the second Charter creates nothing")
	e.create_card("chiefs", "hand", null)
	eq(card_ids(e.zone("governments")), ["kings"] as Array[String], "the ruling Chiefs isn't created")
	eq(uid_of(e.zone("hand"), "chiefs"), -1, "nor put in the hand")


# --- AC3: the end of Anarchy owes the choice ---

func test_burning_out_owes_the_government_choice() -> void:
	var e := choosing_engine()
	var chiefs := uid_of(e.zone("governments"), "chiefs")
	var kings := uid_of(e.zone("governments"), "kings")
	eq(ruling(e), "", "no government rules")
	eq(e.anarchy(), -1, "no Anarchy")
	eq(card_ids(e.zone("removed")), ["anarchy"] as Array[String], "the Anarchy card is removed")
	eq(e.pending(), {"kind": GameEngine.PENDING_GOVERNMENT, "options": [chiefs, kings]}, "the choice is owed")


func test_while_the_choice_is_owed_everything_else_refuses() -> void:
	var e := choosing_engine()
	var farm := put_in_hand(e, "farm")
	var lore := uid_of(e.zone("research_deck"), "lore")
	e.create_card("farm", "discard", null)
	eq(e.play_error(farm), CHOOSE_FIRST, "play")
	eq(e.grow_error(home_uid(e)), CHOOSE_FIRST, "grow")
	eq(e.buy_error("farm"), CHOOSE_FIRST, "buy")
	eq(e.buy_tech_error(lore), CHOOSE_FIRST, "research")
	eq(e.renew_error(uid_of(e.zone("discard"), "farm")), CHOOSE_FIRST, "renew")
	eq(e.revolt_error(), CHOOSE_FIRST, "revolt")
	eq(e.restore_order_error(), CHOOSE_FIRST, "restore order")
	eq(e.end_turn_error(), CHOOSE_FIRST, "end turn")


# --- AC4: choosing ---

func test_choosing_a_government_rules_it_and_calms_unrest() -> void:
	var e := choosing_engine()
	var kings := uid_of(e.zone("governments"), "kings")
	e.resources["unrest"] = 6
	check(e.choose_government(kings), "choose Kings: %s" % e.choose_government_error(kings))
	eq(ruling(e), "kings", "Kings rules")
	eq(card_ids(e.zone("governments")), ["chiefs"] as Array[String], "Chiefs stays in the deck")
	eq(e.pending(), {}, "nothing owed")
	eq(e.resources.get("unrest"), 3, "at most half of 7")


func test_the_unrest_limit_modifier_counts_before_halving_a_chosen_government() -> void:
	var e := choosing_engine()
	build_on(e, home_uid(e), ["altar"])
	e.resources["unrest"] = 6
	e.choose_government(uid_of(e.zone("governments"), "kings"))
	eq(e.resources.get("unrest"), 4, "at most (7 + 1) / 2")


func test_a_chosen_government_resolves_its_play_effects_without_paying() -> void:
	var e := choosing_engine(["kingdom"])
	var food: int = e.resources.food
	var wealth: int = e.resources.wealth
	e.resources["unrest"] = 6
	check(e.choose_government(uid_of(e.zone("governments"), "kingdom")), "choose Kingdom")
	eq(e.resources.wealth, wealth + 1, "Kingdom's play +1 wealth")
	eq(e.resources.food, food + 3, "its 2 food cost isn't paid; the next turn's upkeep: Capital +2, Kingdom +1 (155)")
	eq(e.resources.get("unrest"), 6, "no limit: unrest unchanged")


# --- AC5: errors ---

func test_choose_government_error_names_each_reason_and_a_refusal_changes_nothing() -> void:
	var quiet := deck_engine()
	play_outcome(quiet, put_in_hand(quiet, "charter"))
	var kings := uid_of(quiet.zone("governments"), "kings")
	eq(quiet.choose_government_error(kings), "No government to choose.", "no choice owed")
	check(not quiet.choose_government(kings), "choose_government refuses")
	eq(ruling(quiet), "chiefs", "Chiefs still rules")
	var e := choosing_engine()
	var farm := put_in_hand(e, "farm")
	eq(e.choose_government_error(farm), "That government isn't in your government deck.", "not in the deck")
	check(not e.choose_government(farm), "refuses")
	eq([ruling(e), e.pending().get("kind")], ["", GameEngine.PENDING_GOVERNMENT], "still owed")
	eq(e.choose_government_error(uid_of(e.zone("governments"), "kings")), "", "Kings can be chosen")


func test_choosing_uses_no_action() -> void:
	var e := choosing_engine(["court"])
	e.choose_government(uid_of(e.zone("governments"), "court"))
	eq(e.actions_left(), 3, "Court's 3 actions, none used")


# --- AC6: the UI ---

func test_the_government_overlay_shows_the_deck_and_a_click_chooses() -> void:
	await with_main(deck_engine(), func(main: Node):
		var e := Game.engine
		e.resources["unrest"] = 5
		e.end_turn()
		e.create_card("kings", "discard", null)
		for i in 4:
			e.end_turn()
		await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout  # behind the cabinet doors (209)
		var row: Node = main.choices.get("government_row")
		check(row != null and row.is_visible_in_tree(), "the Government overlay is up")
		if row == null:
			return
		var kings := uid_of(e.zone("governments"), "kings")
		var chiefs := uid_of(e.zone("governments"), "chiefs")
		var in_row: Array = main.views_in(row).map(func(v): return v.uid)
		eq(sorted(in_row), sorted([chiefs, kings]), "the government deck's cards")
		check(main.choices.get("government_heading").text == "Order returns: choose your government.", "heading")
		main.on_picked(main.views[kings])
		eq(ruling(e), "kings", "a click chooses Kings")
		await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout  # behind the doors again (209)
		check(not row.is_visible_in_tree(), "the overlay closes"))


func test_the_identity_modal_lists_the_government_deck() -> void:
	await with_main(deck_engine(), func(main: Node):
		var e := Game.engine
		e.create_card("kings", "discard", null)
		main.sidebar.government_button.pressed.emit()
		var tabs: Array = main.identity_modal.deck_tabs()  # a row of tabs since 231
		eq(tabs.map(func(b): return b.text), ["Kings"], "the deck's tabs")
		eq(main.identity_modal.deck_text(), "Government deck", "under its caption"))


# --- 175 AC3: a pick in the government overlay is refused with choose_government_error's reason ---

func test_a_stale_government_pick_is_refused_with_its_reason() -> void:
	await with_main(deck_engine(), func(main: Node):
		var e := Game.engine
		e.resources["unrest"] = 5
		e.end_turn()
		e.create_card("kings", "discard", null)
		for i in 4:
			e.end_turn()
		await wait_frames()
		var kings := uid_of(e.zone("governments"), "kings")
		var stale: CardView = main.views.get(uid_of(e.zone("governments"), "chiefs"))
		main.on_picked(main.views[kings])
		eq(ruling(e), "kings", "Kings chosen")
		var before := e.state.copy()
		main.on_picked(stale)
		check(main.log_drawer.text().contains("No government to choose."), "the refusal's reason in the log")
		eq(state_diff(e.state, before), "", "a stale pick changes nothing; changed"))
