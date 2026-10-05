extends "res://tests/lib/anarchy_case.gd"
## The event modal for a choice event (backlog 269) in the real main scene: the options as buttons in place of OK, not
## dismissable while the choice is owed; a refused option disabled with the engine's reason as its tooltip; choosing
## closes it with a notice of what the option did; under Anarchy the renewal comes first. Hooks: main.event_modal()
## ({…, options: option texts}), main.event_option_buttons(). Fixtures: tests/lib/anarchy_case.gd (Envoys).


## Runs body(main) on a real main scene whose game drew Envoys at turn 2's start with wealth at the draw, the turn
## ended on setup(e) first. Use with await.
func with_choice(wealth: int, body: Callable, setup := func(_e): pass, unrest := {}) -> void:
	await with_main(choice_engine(["envoys"], {"envoys": 1, "fleeting": 1}, unrest), func(main: Node):
		var e := Game.engine
		e.resources["wealth"] = wealth
		setup.call(e)
		e.end_turn()
		await wait_frames()
		if not main.has_method("event_option_buttons"):
			check(false, "main has no event_option_buttons() hook")
			return
		await body.call(main))


func test_a_choice_event_shows_its_options_in_place_of_ok() -> void:
	await with_choice(3, func(main: Node):
		eq(main.event_modal().get("id"), "envoys", "Envoys shown")
		eq(main.event_modal().get("options"), ["Pay 2 wealth: +1 VP", "+1 unrest"], "the options")
		eq(main.event_option_buttons().map(func(b): return b.text), ["Pay 2 wealth: +1 VP", "+1 unrest"],
			"a button each")
		check(not main.event_modal_ok_button().visible, "no OK"))


func test_the_choice_modal_cant_be_dismissed() -> void:
	await with_choice(3, func(main: Node):
		press_key(main, KEY_ESCAPE)
		press_key(main, KEY_ENTER)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = Vector2(4, 4)
			event.global_position = Vector2(4, 4)
			main.get_viewport().push_input(event, true)
		await wait_frames()
		eq(main.event_modal().get("id"), "envoys", "Esc, Enter and a click outside leave it open"))


func test_a_refused_option_is_disabled_with_the_reason_as_its_tooltip() -> void:
	await with_choice(1, func(main: Node):
		var buttons: Array = main.event_option_buttons()
		check(buttons[0].disabled, "the pay option is disabled")
		eq(buttons[0].tooltip_text, Game.engine.call("choose_option_error", 0), "its tooltip is the reason")
		check(not buttons[1].disabled, "the free option isn't"))


func test_choosing_closes_the_modal_and_notices_what_the_option_did() -> void:
	await with_choice(3, func(main: Node):
		main.event_option_buttons()[1].pressed.emit()
		await wait_frames()
		eq(Game.engine.pending(), {}, "chosen")
		eq(main.event_modal(), {}, "closed")
		var texts: Array = main.toasts.texts()
		check(texts.any(func(t: String): return t.contains("+1 unrest")), "a notice says +1 unrest: %s" % [texts]))


func test_under_anarchy_the_renewal_comes_first_then_the_choice() -> void:
	var fall := func(e: GameEngine):
		put_in(e, "farm", "discard")
		e.resources["unrest"] = 5
	await with_choice(3, func(main: Node):
		var e := Game.engine
		check(main.renewal_modal.is_open(), "the renewal modal is open")
		eq(main.event_modal(), {}, "the choice waits")
		check(e.renew([e.pending().options[0]]), "renew")
		await wait_frames()
		eq(main.event_modal().get("id"), "envoys", "then the event shows")
		eq(main.event_option_buttons().size(), 2, "with its options"), fall, {"renewal": 1})
