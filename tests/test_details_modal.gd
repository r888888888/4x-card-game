extends "res://tests/lib/test_case.gd"
## The card details modal in the real main scene (backlog 056): I opens it for the focused card, Esc closes it, it
## blocks the board's keys while open, and supply piles show their definition. Hook: main.details.shown() is the
## details on show ({} while hidden).
## In detail (from docs/testing.md, 331): The details modal in the real `main.tscn`: I opens it for the focused card,
## Esc closes it, board keys blocked, supply piles, Play on a hand card's details (225), no Learn outside the Knowledge
## screen (229), no Buy outside a supply pile (259); uses `main.details.shown()`, `play_button()` and
## `research_button()` (Move… and Disband, 163, are in `test_unit_moves.gd`: `unit_buttons()`,
## `main.move_modal.target_buttons()`)


func test_i_opens_details_for_the_focused_card_and_esc_closes_them() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_RIGHT)
	var focused: CardView = main.focus.focused
	check(focused != null, "Right focuses the first hand card")
	press_key(main, KEY_I)
	var name: String = Game.engine.zone("hand").find(focused.uid).def.name if focused != null else "?"
	eq(main.details.shown().get("name", ""), name, "details of the focused card")
	press_key(main, KEY_ESCAPE)
	eq(main.details.shown(), {}, "Esc closes the details")
	check(main.focus.focused == focused, "the focus stays on the card")
	close_main(main)


func test_open_details_block_the_board_keys() -> void:
	var main := open_main()
	main.start_game(1)
	press_key(main, KEY_RIGHT)
	press_key(main, KEY_I)
	var turn := Game.engine.turn
	press_key(main, KEY_E)
	eq(Game.engine.turn, turn, "E doesn't end the turn under the details")
	check(not main.details.shown().is_empty(), "details still open")
	close_main(main)


func test_supply_pile_details_come_from_its_definition() -> void:
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var piles: Array = main.supply.views()
	check(not piles.is_empty(), "the supply is open with piles")
	if not piles.is_empty():
		main.details.open(piles[0])
		check(main.details.shown().get("name", "") != "", "a pile's details have its name")
		eq(main.details.shown().get("state"), [] as Array[String], "a pile has no live state")
	close_main(main)


# --- Backlog 225: Play from a hand card's details. Hook: main.details.play_button() (hidden unless a hand card). ---

## Puts card id in the hand with food food and refreshes the board; returns its uid.
func hand_card(id: String, food := 5) -> int:
	var uid := put_in_hand(Game.engine, id)
	Game.engine.resources.food = food
	Game.engine.changed.emit()  # put_in_hand bypasses the actions that refresh the board
	return uid


func test_play_button_plays_a_playable_hand_card_and_closes_the_details() -> void:
	await with_main(gov_engine("band"), func(main: Node):  # Band: 2 actions a turn, so a play visibly uses one
		var e := Game.engine
		var study := hand_card("study")
		var actions: int = e.actions_left()
		check(actions > 0, "Band limits the actions")
		main.details.open(main.views[study])
		var play: Button = main.details.play_button()
		check(play.visible, "Play shows for a hand card")
		check(not play.disabled, "Play is enabled for a playable card")
		check(play.get_parent() == main.details.footer, "Play sits in the footer")
		play.pressed.emit()
		await wait_frames()
		eq(main.details.shown(), {}, "the details closed")
		check(e.zone("hand").find(study) == null, "the card left the hand")
		eq(e.actions_left(), actions - 1, "it took an action"))


func test_play_button_is_hidden_for_board_and_tech_details() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		main.details.open(main.views[home_uid(e)])
		check(not main.details.play_button().visible, "no Play for a board card")
		main.details.close()
		main.details.open_def("study")
		check(not main.details.play_button().visible, "no Play for a definition"))


func test_play_button_is_hidden_for_supply_pile_details() -> void:
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var piles: Array = main.supply.views()
	check(not piles.is_empty(), "the supply is open with piles")
	if not piles.is_empty():
		main.details.open(piles[0])
		check(not main.details.play_button().visible, "no Play for a supply pile")
	close_main(main)


func test_play_button_is_disabled_with_the_reason_for_an_unplayable_hand_card() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var farm := hand_card("farm", 0)
		main.details.open(main.views[farm])
		var play: Button = main.details.play_button()
		check(play.visible, "Play shows for a hand card")
		check(play.disabled, "Play is disabled when the card can't be played")
		check(e.playable_error(farm) != "", "the farm is unaffordable")
		eq(play.tooltip_text, e.playable_error(farm), "the tooltip says why")
		eq(play.theme_type_variation, &"AccentButton", "251: still the primary key")
		var box := play.get_theme_stylebox("disabled") as StyleBoxFlat
		check(box != null and not box.bg_color.is_equal_approx(Palette.ACCENT), "251: disabled, no ACCENT fill"))


func test_play_button_begins_targeting_for_a_card_with_several_targets() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var temple := hand_card("temple")
		check(e.needs_target_choice(temple), "Temple could go on either territory")
		main.details.open(main.views[temple])
		main.details.play_button().pressed.emit()
		await wait_frames()
		eq(main.details.shown(), {}, "the details closed")
		check(main.drag.targeting == main.views[temple], "targeting the Temple")
		check(e.zone("hand").find(temple) != null, "nothing played yet"))


func test_play_button_goes_when_the_details_reopen_for_a_board_card() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var study := hand_card("study")
		main.details.open(main.views[study])
		check(main.details.play_button().visible, "Play shows for the hand card")
		main.details.open(main.views[home_uid(e)])
		check(not main.details.play_button().visible, "Play is gone for the board card"))


func test_play_button_is_disabled_while_a_decision_blocks_the_hand() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var study := hand_card("study")
		e.play_card(put_in_hand(e, "explorer"))  # reveals territories: an explore choice is owed
		await wait_frames()
		eq(e.pending().get("kind", ""), GameEngine.PENDING_EXPLORE, "an explore choice is owed")
		check(e.hand_input_error() != "", "the hand is blocked")
		main.details.open(main.views[study])
		var play: Button = main.details.play_button()
		check(play.disabled, "Play is disabled")
		eq(play.tooltip_text, e.playable_error(study), "the tooltip gives the reason"))


# --- Backlog 229: Research shows only for a tech opened from the Knowledge screen. ---

func test_research_button_is_hidden_outside_the_knowledge_screen() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		var study := hand_card("study")
		main.details.open(main.views[study])
		check(not main.details.research_button().visible, "no Research for a hand card")
		main.details.open(main.views[home_uid(e)])
		check(not main.details.research_button().visible, "no Research for a board card")
		main.details.open_def("study")
		check(not main.details.research_button().visible, "no Research for a definition"))


func test_research_button_is_hidden_for_supply_pile_details() -> void:
	var main := open_main()
	main.start_game(1)
	main.open_supply()
	var piles: Array = main.supply.views()
	check(not piles.is_empty(), "the supply is open with piles")
	if not piles.is_empty():
		main.details.open(piles[0])
		check(not main.details.research_button().visible, "no Research for a supply pile")
	close_main(main)


# --- Backlog 259: Buy, its reason and the pile's tag show only for a supply pile's details. ---

## Asserts main's details offer no Buy, no reason, and no price tag or count; what names the details.
func assert_no_buy(main: Node, what: String) -> void:
	var d = main.details
	check(not d.buy_button().visible, "no Buy for " + what)
	check(not d.buy_reason().visible, "no reason for " + what)
	check(d.pile_tag() == null and d.pile_left() == null, "no tag or count for " + what)


func test_buy_and_the_pile_tag_are_absent_outside_a_supply_pile() -> void:
	await with_territories_main(func(main: Node):
		var e := Game.engine
		main.details.open(main.views[hand_card("study")])
		assert_no_buy(main, "a hand card")
		main.details.open(main.views[home_uid(e)])
		assert_no_buy(main, "a Realm card")
		main.details.open_tech("study", -1)
		assert_no_buy(main, "a tech"))
