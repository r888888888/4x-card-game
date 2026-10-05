extends "res://tests/lib/tech_case.gd"
## The Gives row of a tech's details (289) in the real main scene: a compact card per card the tech gives with how you
## get it under it; a click, or Enter or I on a focused one, opens that card's details on a second modal on top.
## Hooks on main.details (CardDetailsModal): gives_ids(), gives_captions(), gives_card(i) and given_details (the
## modal a Gives card opens).

## Gives Granary (made and unlocked) and Silo (unlocked).
const MASONRY := {"id": "masonry", "name": "Masonry", "type": "tech", "cost": {"insight": 3}, "effects": [
	{"op": "create", "card": "granary", "zone": "discard"},
	{"op": "unlock", "card": "granary"},
	{"op": "unlock", "card": "silo"}]}


## A game with Masonry on top of the research deck, Granary and Silo locked in the supply.
func gives_engine() -> GameEngine:
	return tech_engine(["masonry", "pottery"], {"farm": 10}, {"supply": {
		"granary": {"price": 2, "count": 2, "locked": true}, "silo": {"price": 2, "count": 2, "locked": true}}},
		[MASONRY])


## Opens Masonry's details as the Knowledge screen does, with it to learn.
func open_masonry(main: Node) -> void:
	main.details.open_tech("masonry", uid_of(Game.engine.zone("research_deck"), "masonry"))
	await wait_frames()


# --- AC4: the Gives row ---

func test_a_techs_details_show_a_gives_row_of_its_cards_with_captions() -> void:
	await with_main(gives_engine(), func(main: Node):
		await open_masonry(main)
		var modal: Object = main.details
		eq(modal.gives_ids(), ["granary", "silo"], "Granary then Silo")
		eq(modal.gives_captions(), ["1 to your discard · in the supply", "in the supply"], "captions")
		check(modal.gives_card(0).is_visible_in_tree(), "the first Gives card shows"))


func test_a_card_that_gives_nothing_shows_no_gives_row() -> void:
	await with_main(gives_engine(), func(main: Node):
		main.details.open_tech("pottery", uid_of(Game.engine.zone("research_deck"), "pottery"))
		await wait_frames()
		var modal: Object = main.details
		eq(modal.gives_ids(), [], "Pottery gives nothing")
		check(modal.gives_card(0) == null, "no Gives card"))


# --- AC5: a Gives card opens its details on top ---

func test_clicking_a_gives_card_opens_its_details_on_top_and_esc_returns_to_the_tech() -> void:
	await with_main(gives_engine(), func(main: Node):
		await open_masonry(main)
		var modal: Object = main.details
		(modal.gives_card(0) as BaseButton).pressed.emit()
		await wait_frames()
		var given: Object = modal.given_details
		check(given != null and given.is_open(), "a second details modal is open")
		check(main.modals.top() == given, "on top")
		eq(given.shown().get("name"), "Granary", "Granary's details")
		eq(given.gives_ids(), [], "Granary gives nothing: no Gives row")
		for button in [given.play_button(), given.research_button(), given.buy_button()] + given.unit_buttons() \
				+ given.site_buttons():
			check(not button.visible, "no %s on a given card" % button.text)
		eq(modal.shown().get("name"), "Masonry", "Masonry's details stay open beneath")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check(not given.is_open(), "Esc closes the given card's details")
		check(main.modals.top() == modal, "Masonry's details are on top again")
		eq(modal.shown().get("name"), "Masonry", "still Masonry"))


func test_enter_or_i_on_a_focused_gives_card_opens_its_details() -> void:
	for key in [KEY_ENTER, KEY_I]:
		await with_main(gives_engine(), func(main: Node):
			await open_masonry(main)
			var modal: Object = main.details
			FocusRing.focus(modal.gives_card(1))
			press_key(main, key)
			await wait_frames()
			var given: Object = modal.given_details
			check(given != null and given.is_open(), "%s opens the focused card's details" % OS.get_keycode_string(key))
			if given != null:
				eq(given.shown().get("name"), "Silo", "Silo's details")
			eq(modal.shown().get("name"), "Masonry", "Masonry's details stay open"))
