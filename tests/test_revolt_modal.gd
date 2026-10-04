extends "res://tests/lib/test_case.gd"
## Revolt from the civilization modal (backlog 205) in the real main scene on the real data (seed 5, Sumer, Chiefdom):
## a "Revolt…" button ends the modal's government section, and a confirmation sheet (main.revolt_modal: keep_button,
## confirm_button, body_text()) stacked on it shows the Anarchy card's flavor and revolt_summary() before revolting.
## The board has no Revolt button any more.

## Main on seed 5 as Sumer with the civilization modal open. Free with close_main.
func open_identity() -> Node:
	var main := open_main()
	main.start_game(5, "sumer")
	await wait_frames()
	main.identity_modal.open()
	await wait_frames()
	return main


func gov_name() -> String:
	return Game.engine.zone("government").cards[0].def.name


# --- AC4: the button ---

func test_the_civilization_modal_ends_its_government_section_with_revolt() -> void:
	var main: Node = await open_identity()
	var revolt: Button = main.identity_modal.revolt_button
	eq(revolt.text, "Revolt…", "its text")
	check(revolt.is_visible_in_tree() and not revolt.disabled, "enabled while revolt is legal")
	check(main.identity_modal.body.is_ancestor_of(revolt), "in the modal's body, with the government")
	close_main(main)


func test_the_board_has_no_revolt_button() -> void:
	var main := open_main()
	main.start_game(5, "sumer")
	await wait_frames()
	var on_board := UIKit.buttons_in(main).filter(func(b): return b.is_visible_in_tree() and b.text.begins_with("Revolt"))
	eq(on_board.size(), 0, "no Revolt on the board")
	check(not main.has_method("revolt_button"), "main.revolt_button() went with it")
	close_main(main)


# --- AC5: the confirmation ---

func test_revolt_opens_a_confirmation_with_the_flavor_and_the_summary() -> void:
	var main: Node = await open_identity()
	main.identity_modal.revolt_button.pressed.emit()
	await wait_frames()
	var sheet: Object = main.revolt_modal
	eq(main.modals.top(), sheet, "stacked on the civilization modal")
	eq(main.modals.depth(), 2, "over it")
	eq(sheet.title, "Revolution", "its title")
	eq(sheet.context, "Turn %d · %s" % [Game.engine.turn, gov_name()], "its context")
	var anarchy: CardDef = Game.engine.card_db[Game.engine.config.unrest.anarchy]
	var text: String = sheet.body_text()
	check(anarchy.flavor != "" and text.contains(anarchy.flavor), "the Anarchy card's flavor: %s" % text)
	check(text.contains(anarchy.quote_text) and text.contains(anarchy.quote_by), "its quote, attributed: %s" % text)
	var at := -1
	for line in Game.engine.revolt_summary():
		var found := text.find(line)
		check(found > at, "the summary line '%s', in order" % line)
		at = found
	eq(sheet.footer.get_children().filter(func(b): return b is Button and b.visible).map(func(b): return b.text),
		["Keep %s" % gov_name(), "Revolt"], "Keep, then Revolt (primary) at the right")
	eq(accent_footer(sheet), ["Revolt"] as Array[String], "251: Revolt in the signal colour, Keep plain")
	close_main(main)


# --- AC6: revolting, or not ---

func test_revolt_in_the_confirmation_revolts_once_and_leaves_the_civilization_modal_open() -> void:
	var main: Node = await open_identity()
	var revolts := [0]
	Game.engine.revolted.connect(func(): revolts[0] += 1)
	main.identity_modal.revolt_button.pressed.emit()
	main.revolt_modal.confirm_button.pressed.emit()
	await wait_frames()
	eq(revolts[0], 1, "revolt() ran once")
	eq(Game.engine.revolt_error(), "A revolution is already under way.", "a revolution under way")
	eq(main.modals.top(), main.identity_modal, "the confirmation closed; the civilization modal stays")
	var revolt: Button = main.identity_modal.revolt_button
	check(revolt.disabled, "its Revolt… disabled")
	eq(revolt.tooltip_text, "A revolution is already under way.", "with the reason")
	close_main(main)


func test_keep_esc_or_a_click_outside_close_the_confirmation_without_revolting() -> void:
	for way in ["keep", "esc", "outside"]:
		var main: Node = await open_identity()
		main.identity_modal.revolt_button.pressed.emit()
		await wait_frames()
		match way:
			"keep":
				main.revolt_modal.keep_button.pressed.emit()
			"esc":
				press_key(main, KEY_ESCAPE)
			"outside":
				for pressed in [true, false]:
					var event := InputEventMouseButton.new()
					event.button_index = MOUSE_BUTTON_LEFT
					event.pressed = pressed
					event.position = Vector2(4, 4)
					event.global_position = Vector2(4, 4)
					main.get_viewport().push_input(event, true)
		await wait_frames()
		eq(Game.engine.revolt_error(), "", "%s: no revolution" % way)
		eq(main.modals.top(), main.identity_modal, "%s: back to the civilization modal" % way)
		close_main(main)


func test_with_revolt_refused_the_button_is_disabled_with_the_reason() -> void:
	var main := open_main()
	main.start_game(5, "sumer")
	Game.engine.revolt()
	await wait_frames()
	main.identity_modal.open()
	await wait_frames()
	var revolt: Button = main.identity_modal.revolt_button
	check(revolt.disabled, "disabled")
	eq(revolt.tooltip_text, Game.engine.revolt_error(), "the reason as its tooltip")
	close_main(main)
