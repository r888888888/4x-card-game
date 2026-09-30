extends "res://tests/lib/tech_case.gd"
## Error queries for the last actions without one (backlog 093): discard_error, choose_error and
## decline_research_error, which their actions refuse through and the UI shows.


## A game on TEST_CARDS + TECHS with explorers and research cards to play, and three territories to explore.
func action_engine() -> GameEngine:
	var e: GameEngine = tech_engine(["pottery", "writing"], {"farm": 10},
		{"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}})
	arrange(e.zone("territory_deck"), ["hills", "grassland", "jungle"])
	return e


## action_engine with an Explorer played: hills and grassland are revealed to choose from.
func explore_engine() -> GameEngine:
	var e := action_engine()
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	return e


## action_engine with Research played: pottery and writing are revealed.
func reveal_engine() -> GameEngine:
	var e := action_engine()
	check(play_research(e), "research should open")
	return e


## A game with a hand-limit discard owed (hand 6, limit 5).
func owed_engine() -> GameEngine:
	var e: GameEngine = make_engine({"scout": 10}, {"hand_limit": 5})
	check(e.play_card(first_in_hand(e)), "play Scout")
	e.end_turn()
	check(e.discard_needed() == 1, "1 discard owed")
	return e


## A finished game.
func over_engine() -> GameEngine:
	var e: GameEngine = make_engine({"farm": 10}, {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "the game is over")
	return e


# --- AC1: discard_error ---

func test_discard_error() -> void:
	var e := action_engine()
	eq(e.discard_error(first_in_hand(e)), "", "a hand card, nothing pending")
	e = owed_engine()
	eq(e.discard_error(first_in_hand(e)), "", "a hand card while a discard is owed")
	eq(over_engine().discard_error(-1), "The game is over.", "game over comes first")
	e = explore_engine()
	eq(e.discard_error(first_in_hand(e)), "Choose a territory first.", "explore choice open")
	eq(e.discard_error(-1), "Choose a territory first.", "the choice comes before the hand check")
	e = reveal_engine()
	eq(e.discard_error(first_in_hand(e)), "Buy a tech or decline first.", "techs revealed")
	e = action_engine()
	eq(e.discard_error(-1), "That card is not in your hand.", "a uid not in the hand")
	eq(e.discard_error(home_uid(e)), "That card is not in your hand.", "a tableau card")


# --- AC2: choose_error ---

func test_choose_error() -> void:
	var e := explore_engine()
	var options: Array = e.pending().options
	eq(e.choose_error(options[0]), "", "a revealed territory")
	eq(e.choose_error(-1), "That territory isn't an option.", "an unknown uid")
	eq(e.choose_error(first_in_hand(e)), "That territory isn't an option.", "a hand card")
	e = action_engine()
	eq(e.choose_error(-1), "There is no territory to choose.", "no explore choice open")


# --- AC3: decline_research_error ---

func test_decline_research_error() -> void:
	var e := reveal_engine()
	eq(e.decline_research_error(), "", "techs revealed")
	check(e.decline_research(), "decline")
	eq(e.decline_research_error(), "No techs are revealed.", "after declining")
	eq(action_engine().decline_research_error(), "No techs are revealed.", "nothing played")


# --- AC5, AC6: the real main scene shows the reasons ---

## Runs body(main) on the real main scene, started on seed 1 with Game.engine swapped for action_engine's game, then
## puts the real engine back.
func with_action_main(body: Callable) -> void:
	var real := Game.engine
	Game.engine = action_engine()
	var main := open_main()
	main.start_game(1)
	body.call(main)
	close_main(main)
	Game.engine = real


## The log as plain text (in the log drawer since 115).
func log_text(main: Node) -> String:
	return main.log_drawer.text()


func decline_button(main: Node) -> Button:
	for b in main.find_children("*", "Button", true, false):
		if b.text == "Decline":
			return b
	return null


func test_discarding_during_an_explore_choice_logs_why() -> void:
	with_action_main(func(main: Node):
		var e := Game.engine
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
		var hand := card_ids(e.zone("hand"))
		main.discard(main.views[first_in_hand(e)])
		eq(card_ids(e.zone("hand")), hand, "hand unchanged")
		check(log_text(main).contains("Choose a territory first."), "the log says why: %s" % log_text(main)))


func test_picking_a_card_that_isnt_an_option_logs_why() -> void:
	with_action_main(func(main: Node):
		var e := Game.engine
		check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
		main.on_picked(main.views[first_in_hand(e)])
		eq(e.pending().get("kind", ""), GameEngine.PENDING_EXPLORE, "the choice is still open")
		check(log_text(main).contains("That territory isn't an option."), "the log says why: %s" % log_text(main)))


func test_decline_is_disabled_with_the_reason_when_no_techs_are_revealed() -> void:
	with_action_main(func(main: Node):
		var e := Game.engine
		var button := decline_button(main)
		check(button != null, "a Decline button")
		if button == null:
			return
		check(button.disabled, "disabled with nothing revealed")
		eq(button.tooltip_text, "No techs are revealed.", "tooltip is the reason")
		check(play_research(e), "research should open")
		check(not button.disabled, "enabled while techs are revealed")
		eq(button.tooltip_text, "", "no reason while enabled"))
