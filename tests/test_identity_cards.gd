extends "res://tests/lib/anarchy_case.gd"
## The civilization modal as two cards on the desk (backlog 231): the civilization and the government as two card
## panels side by side (name, type band, type line, rules, live state, flavor at the foot), a click on either opening
## its card details on top, Revolt… at the foot of the government card, and the government deck as a row of tabs.
## Hooks on main.identity_modal: cards() (the card buttons, civilization first), card_lines(i) (card i's text, top to
## bottom), band_color(i), deck_text() (the deck row's caption and "empty"), deck_tabs() (one button per card).
## Real data on seed 5 as Sumer (Chiefdom ruling), or the anarchy fixtures (Chiefs ruling, Kings in the deck).


## Main on seed 5 as Sumer with the civilization modal open. Free with close_main.
func open_sumer() -> Node:
	var main := open_main()
	main.start_game(5, "sumer")
	await wait_frames()
	main.identity_modal.open()
	await wait_frames(4)
	return main


## What card_details of the card in zone_name says, as the lines a card shows: name, type line, rules, state, flavor.
func expected_lines(zone_name: String) -> Array[String]:
	var e := Game.engine
	var d := e.card_details(e.zone(zone_name).cards[0].uid)
	var lines: Array[String] = [d.name, d.type]
	lines.append_array(d.rules)
	lines.append_array(d.state)
	if d.flavor != "":
		lines.append(d.flavor)
	return lines


# --- AC3: two cards side by side ---

func test_the_civilization_and_government_lie_side_by_side_as_cards() -> void:
	var main: Node = await open_sumer()
	var modal: Object = main.identity_modal
	var cards: Array = modal.cards()
	eq(cards.size(), 2, "two cards")
	if cards.size() != 2:
		close_main(main)
		return
	var civ: Rect2 = (cards[0] as Control).get_global_rect()
	var gov: Rect2 = (cards[1] as Control).get_global_rect()
	check(civ.end.x <= gov.position.x, "the civilization on the left, the government on the right: %s %s" % [civ, gov])
	eq(civ.position.y, gov.position.y, "level tops")
	eq(civ.size.y, gov.size.y, "the same height")
	eq(modal.card_lines(0), expected_lines("civilization"), "the civilization's lines")
	eq(modal.card_lines(1), expected_lines("government"), "the government's lines, with its unrest now")
	eq(modal.shown(), ["Sumer", "Chiefdom"], "shown() is unchanged")
	var quote: Dictionary = Game.engine.def_details("sumer").quote
	check(not modal.body_text().contains(quote.text), "no quote on the cards: %s" % modal.body_text())
	var revolt: Button = modal.revolt_button
	check((cards[1] as Control).is_ancestor_of(revolt), "Revolt… is on the government card")
	check(revolt.get_global_rect().position.y >= (cards[1] as Control).get_global_rect().position.y
		+ (cards[1] as Control).size.y / 2, "at its foot")
	close_main(main)


# --- AC4: a click opens the card's details ---

func test_a_click_on_a_card_opens_its_details_on_top() -> void:
	var main: Node = await open_sumer()
	var modal: Object = main.identity_modal
	var cards: Array = modal.cards()
	if cards.size() != 2:
		check(false, "two cards: %d" % cards.size())
		close_main(main)
		return
	(cards[0] as Button).pressed.emit()
	await wait_frames()
	eq(main.modals.top(), main.details, "the civilization's details on top")
	eq(main.modals.depth(), 2, "over the modal")
	var quote: Dictionary = Game.engine.def_details("sumer").quote
	var text: String = main.details.body_text()
	check(text.contains(quote.text) and text.contains(quote.by), "the quote is in the details: %s" % text)
	main.details.close()
	await wait_frames()
	eq(main.modals.top(), modal, "closing them leaves the civilization modal")
	(cards[1] as Button).pressed.emit()
	await wait_frames()
	eq(main.modals.top(), main.details, "the government's details on top")
	var state: Array = Game.engine.card_details(Game.engine.government()).state
	check(not state.is_empty() and main.details.body_text().contains(state[0]), "its live state: %s" % main.details.body_text())
	close_main(main)


func test_a_click_on_revolt_opens_the_confirmation_not_the_details() -> void:
	var main: Node = await open_sumer()
	click_control(main, main.identity_modal.revolt_button)
	await wait_frames()
	eq(main.modals.top(), main.revolt_modal, "the revolution's confirmation")
	eq(main.modals.depth(), 2, "and nothing else")
	close_main(main)


# --- AC5: the government deck as tabs ---

func test_the_government_deck_is_a_row_of_tabs_that_open_details() -> void:
	await with_main(anarchy_engine(), func(main: Node):
		var e := Game.engine
		e.create_card("kings", "discard", null)  # into the government deck (154)
		main.identity_modal.open()
		await wait_frames()
		var modal: Object = main.identity_modal
		eq(modal.deck_text(), "Government deck", "the caption")
		var tabs: Array = modal.deck_tabs()
		eq(tabs.map(func(b): return b.text), ["Kings"], "one tab per card")
		if tabs.size() != 1:
			return
		check(not (modal.cards() as Array).any(func(c): return c.is_ancestor_of(tabs[0])), "under the cards, not on one")
		(tabs[0] as Button).pressed.emit()
		await wait_frames()
		eq(main.modals.top(), main.details, "Kings's details on top")
		eq(main.details.shown().get("name"), "Kings", "Kings's details"))


func test_an_empty_government_deck_says_so_with_no_tabs() -> void:
	await with_main(anarchy_engine(), func(main: Node):
		main.identity_modal.open()
		await wait_frames()
		eq(main.identity_modal.deck_text(), "Government deck empty", "caption and 'empty'")
		eq(main.identity_modal.deck_tabs().size(), 0, "no tabs"))


# --- AC6: the bands' colours ---

func test_civilization_and_government_have_their_own_band_colours() -> void:
	var palette: Script = load("res://ui/palette.gd")
	for set_name in ["NIGHT", "DAY"]:
		var colours: Dictionary = palette.get(set_name)
		for role in ["CIVILIZATION", "GOVERNMENT"]:
			check(colours.has(role), "%s has %s" % [set_name, role])
		if colours.has("CIVILIZATION") and colours.has("GOVERNMENT"):
			var planes := ["ACTION", "BUILDING", "CITY", "TERRITORY", "TECH", "EVENT"].map(func(p): return colours[p])
			check(colours.CIVILIZATION != colours.GOVERNMENT, "%s: the two differ" % set_name)
			check(not colours.CIVILIZATION in planes and not colours.GOVERNMENT in planes,
				"%s: neither is a card plane's colour" % set_name)
	eq(CardView.type_color(CardDef.CIVILIZATION), palette.get("CIVILIZATION"), "type_color(civilization)")
	eq(CardView.type_color(CardDef.GOVERNMENT), palette.get("GOVERNMENT"), "type_color(government)")


func test_the_bands_follow_day_mode_while_open() -> void:
	await with_temp_settings(func():
		var main: Node = await open_sumer()
		var modal: Object = main.identity_modal
		var palette: Script = load("res://ui/palette.gd")
		eq(modal.band_color(0), palette.get("CIVILIZATION"), "the civilization's band")
		eq(modal.band_color(1), palette.get("GOVERNMENT"), "the government's band")
		Settings.call("set_day_mode", true)
		await wait_frames()
		var day: Dictionary = palette.get("DAY")
		eq(modal.band_color(0), day.get("CIVILIZATION"), "Day: the civilization's band")
		eq(modal.band_color(1), day.get("GOVERNMENT"), "Day: the government's band")
		close_main(main))
