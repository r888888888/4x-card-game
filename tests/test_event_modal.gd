extends "res://tests/lib/test_case.gd"
## The drawn-event modal (backlog 079): the engine reports each drawn event with event_drawn(outcome), and the real
## main scene pops up a modal showing it. Hook: main.event_modal() is {uid, id, text, lasts, summary}, {} while
## closed. Fixture events: TEST_EVENTS (Windfall: +2 food; Omen: nothing) plus Toll (−1 wealth), local here.

const TOLL := {"id": "toll", "name": "Toll", "type": "event", "effects": [{"op": "lose", "resource": "wealth", "amount": 1}]}


## A game on TEST_CARDS + TEST_EVENTS + Toll with event_deck, top_first on top of it; overrides replace config keys.
func drawn_engine(event_deck: Dictionary, top_first: Array = [], overrides := {}) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_EVENTS + [TOLL]}, resources(), "cards.json",
		errors, warnings, keywords())
	var config := DataLoader.parse_config(raw_config({"scout": 10}, {"event_deck": event_deck}.merged(overrides, true)),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	e.new_game(1)
	if not top_first.is_empty():
		arrange(e.zone("event_deck"), top_first)
	return e


## Ends e's turn and returns the signals emitted meanwhile, in order: ["event_drawn", outcome] or ["changed"].
func end_turn_signals(e: GameEngine) -> Array:
	var seen := []
	var on_drawn := func(o): seen.append(["event_drawn", o])
	var on_changed := func(): seen.append(["changed"])
	e.event_drawn.connect(on_drawn)
	e.changed.connect(on_changed)
	e.end_turn()
	e.event_drawn.disconnect(on_drawn)
	e.changed.disconnect(on_changed)
	return seen


## The uid of event id in active_events or, once its turns ran out, event_discard (-1 if in neither).
func event_uid(e: GameEngine, id: String) -> int:
	var uid := uid_of(e.zone("active_events"), id)
	return uid if uid != -1 else uid_of(e.zone("event_discard"), id)


func drawn_outcomes(seen: Array) -> Array:
	return seen.filter(func(s): return s[0] == "event_drawn").map(func(s): return s[1])


# --- AC1: the engine signal ---

func test_event_drawn_reports_the_event_and_what_it_gave_before_changed() -> void:
	var e := drawn_engine({"windfall": 1, "omen": 1}, ["windfall"])
	var seen := end_turn_signals(e)
	var outcomes := drawn_outcomes(seen)
	eq(outcomes.size(), 1, "event_drawn emitted once")
	if outcomes.size() == 1:
		var o: Dictionary = outcomes[0]
		eq(o.uid, event_uid(e, "windfall"), "uid: Windfall's")
		eq(o.gained, {"food": 2}, "gained")
		eq([o.vp, Array(o.drawn), Array(o.created)], [0, [], []], "vp, drawn, created")
		eq(seen[0][0], "event_drawn", "emitted before changed")


# --- AC2: no effect, no event ---

func test_event_drawn_for_an_event_with_no_effect_reports_nothing_gained() -> void:
	var e := drawn_engine({"windfall": 1, "omen": 1}, ["omen"])
	var outcomes := drawn_outcomes(end_turn_signals(e))
	eq(outcomes.size(), 1, "event_drawn emitted once")
	if outcomes.size() == 1:
		var o: Dictionary = outcomes[0]
		eq(o.uid, event_uid(e, "omen"), "uid: Omen's")
		eq([o.gained, o.vp, Array(o.drawn), Array(o.created)], [{}, 0, [], []], "nothing gained")


func test_no_event_drawn_without_events() -> void:
	var e := drawn_engine({})
	eq(drawn_outcomes(end_turn_signals(e)), [], "no event_drawn with empty event piles")


# --- Losses (072) and the summary text ---

func test_event_drawn_reports_what_the_event_took() -> void:
	var e := drawn_engine({"toll": 1})
	e.resources.wealth = 3
	var outcomes := drawn_outcomes(end_turn_signals(e))
	eq(outcomes.size(), 1, "event_drawn emitted once")
	if outcomes.size() == 1:
		eq(outcomes[0].lost, {"wealth": 1}, "lost")


func test_outcome_summary_lists_gains_losses_vp_and_cards() -> void:
	var e := drawn_engine({})
	var none: Array[int] = []
	var two: Array[int] = [1, 2]
	var one: Array[int] = [3]
	eq(e.outcome_summary({"gained": {"food": 2}, "lost": {}, "vp": 0, "drawn": none, "created": none}), "+2 food", "a gain")
	eq(e.outcome_summary({"gained": {"food": 1}, "lost": {"wealth": 2}, "vp": 1, "drawn": two, "created": one}),
		"+1 food, −2 wealth, +1 VP, drew 2 cards, created 1 card", "everything")
	eq(e.outcome_summary({"gained": {}, "lost": {}, "vp": 0, "drawn": none, "created": none}), "", "nothing")


# --- AC3–AC6: the modal in the real main scene ---

## Opens main on with_event_engine's game (event_deck, overrides), starts it, puts top_first on top of the event
## deck, calls body(main), then closes main.
func with_modal_main(body: Callable, top_first: Array, event_deck := {"windfall": 1, "omen": 1}, overrides := {}) -> void:
	with_event_engine(func():
		var main := open_main()
		main.start_game(1)
		arrange(Game.engine.zone("event_deck"), top_first)
		# Guarded so the real engine is put back even before the hooks exist (red phase).
		if main.has_method("event_modal") and main.has_method("event_modal_ok_button"):
			body.call(main)
		else:
			check(false, "main has no event_modal() / event_modal_ok_button() hooks")
		close_main(main), event_deck, overrides)


func test_ending_the_turn_shows_the_drawn_event() -> void:
	with_modal_main(func(main: Node):
		Game.engine.end_turn()
		var modal: Dictionary = main.event_modal()
		var windfall: CardDef = Game.engine.card_db.windfall
		eq(modal.get("id", ""), "windfall", "Windfall shown")
		eq(modal.get("uid", -1), event_uid(Game.engine, "windfall"), "its uid")
		eq(modal.get("text", ""), windfall.rules_text(Game.engine.card_db), "its card text")
		eq(modal.get("lasts", ""), "Lasts 1 turn", "how long it lasts")
		var summary: String = modal.get("summary", "")
		check(summary.contains("+2") and summary.contains("food"), "summary says +2 food: %s" % summary), ["windfall"])


func test_an_event_with_no_effect_shows_no_immediate_effect() -> void:
	with_modal_main(func(main: Node):
		Game.engine.end_turn()
		eq(main.event_modal().get("id", ""), "omen", "Omen shown")
		eq(main.event_modal().get("summary", "?"), "No immediate effect", "summary"), ["omen"])


func test_esc_enter_ok_and_a_click_outside_close_the_modal() -> void:
	with_modal_main(func(main: Node):
		for way in ["esc", "enter", "ok", "outside"]:
			Game.engine.end_turn()
			check(not main.event_modal().is_empty(), "%s: the modal is open" % way)
			match way:
				"esc": press_key(main, KEY_ESCAPE)
				"enter": press_key(main, KEY_ENTER)
				"ok": main.event_modal_ok_button().pressed.emit()
				"outside":
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.pressed = true
					# The far corner: outside the panel, before and after the panel is laid out in the centre.
					click.position = main.get_viewport().get_visible_rect().end - Vector2(5, 5)
					click.global_position = click.position
					main.get_viewport().push_input(click, true)  # viewport coordinates, not the window's
			eq(main.event_modal(), {}, "%s closes it" % way), ["windfall"], {"windfall": 1, "omen": 1}, {"turn_limit": 10})


func test_keys_do_not_reach_the_board_while_the_modal_is_open() -> void:
	with_modal_main(func(main: Node):
		Game.engine.end_turn()
		check(not main.event_modal().is_empty(), "the modal is open")
		press_key(main, KEY_E)  # End turn
		eq(Game.engine.turn, 2, "still turn 2"), ["windfall"])


func test_the_hand_limit_discard_is_still_owed_after_the_modal() -> void:
	with_modal_main(func(main: Node):
		for i in 3:
			put_in_hand(Game.engine, "farm")  # hand 8, limit 7
		Game.engine.end_turn()
		check(not main.event_modal().is_empty(), "the modal shows first")
		press_key(main, KEY_ESCAPE)
		eq(main.pending_kind(), GameEngine.PENDING_DISCARD, "the discard is still owed"), ["windfall"])


func test_the_last_turn_shows_game_over_and_no_modal() -> void:
	with_modal_main(func(main: Node):
		Game.engine.end_turn()
		check(Game.engine.is_over, "the game is over")
		eq(main.event_modal(), {}, "no event modal")
		check(main.game_over_text() != "", "the game-over overlay shows"), ["windfall"], {"windfall": 1, "omen": 1},
		{"turn_limit": 1})
