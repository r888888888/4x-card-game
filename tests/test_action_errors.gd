extends "res://tests/lib/tech_case.gd"
## Error queries for the last actions without one (backlog 093): discard_error and choose_error (decline_research_error
## went with the reveal in 140), which their actions refuse through and the UI shows.


## A game on TEST_CARDS + TECHS with explorers to play and three territories to explore.
func action_engine() -> GameEngine:
	var e: GameEngine = tech_engine(["pottery", "writing"], {"farm": 10},
		{"territory_deck": {"hills": 1, "grassland": 1, "jungle": 1}})
	arrange(e.zone("territory_deck"), ["hills", "grassland", "jungle"])
	return e


## action_engine with an Explorer played: hills and grassland are revealed to choose from.
func action_explore_engine() -> GameEngine:
	var e := action_engine()
	check(e.play_card(put_in_hand(e, "explorer")), "play Explorer")
	return e


## A game with a hand-limit discard owed (hand 6, limit 5).
func owed_engine() -> GameEngine:
	var e: GameEngine = make_engine({"scout": 10}, {"hand_limit": 5})
	check(e.play_card(first_in_hand(e)), "play Scout")
	e.end_turn()
	check(e.discard_needed() == 1, "1 discard owed")
	return e


# --- AC1: discard_error ---

func test_discard_error() -> void:
	var e := action_engine()
	eq(e.discard_error(first_in_hand(e)), "", "a hand card, nothing pending")
	e = owed_engine()
	eq(e.discard_error(first_in_hand(e)), "", "a hand card while a discard is owed")
	eq(over_engine().discard_error(-1), "The game is over.", "game over comes first")
	e = action_explore_engine()
	eq(e.discard_error(first_in_hand(e)), "Choose a territory first.", "explore choice open")
	eq(e.discard_error(-1), "Choose a territory first.", "the choice comes before the hand check")
	e = action_engine()
	eq(e.discard_error(-1), "That card is not in your hand.", "a uid not in the hand")
	eq(e.discard_error(home_uid(e)), "That card is not in your hand.", "a tableau card")


# --- AC2: choose_error ---

func test_choose_error() -> void:
	var e := action_explore_engine()
	var options: Array = e.pending().options
	eq(e.choose_error(options[0]), "", "a revealed territory")
	eq(e.choose_error(-1), "That territory isn't an option.", "an unknown uid")
	eq(e.choose_error(first_in_hand(e)), "That territory isn't an option.", "a hand card")
	e = action_engine()
	eq(e.choose_error(-1), "There is no territory to choose.", "no explore choice open")


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

