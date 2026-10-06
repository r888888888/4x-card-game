extends "res://tests/lib/tech_case.gd"
## The supply screen's pile cards (232): each shows its play cost after discounts in its title row, like a hand card,
## and its buy price on a tag below the card ("Buy", the wealth glyph, the price) with the copies left under it.
## Local fixtures: civilization Builders (wonders −3 wealth) and building Obelisk (12 wealth, wonder).
## In detail (from docs/testing.md, 331): The Supply screen's pile cards in the real `main.tscn` (232): the play cost
## after discounts in the title row, the buy price on a tag below the card (`price_tag`), the copies left under it
## (`copies_left`), the tag dimming with an unbuyable pile; a click or Enter opening the pile's details, whose Buy
## (`main.details.buy_button()`, `buy_reason()`, `pile_tag()`, `pile_left()`) buys through `supply.buy` (259)

const BUILDERS := {"id": "builders", "name": "Builders", "type": "civilization", "discounts": [{"tag": "wonder", "wealth": 3}]}
const OBELISK := {"id": "obelisk", "name": "Obelisk", "type": "building", "cost": {"wealth": 12}, "tags": ["wonder"]}
## Obelisk (price 3, 6 copies), then Scout (no play cost; price 2, 1 copy).
const SUPPLY := {"obelisk": {"price": 3, "count": 6}, "scout": {"price": 2, "count": 1}}


## A game as Builders selling SUPPLY, with wealth set to the given amount.
func supply_game(wealth: int) -> GameEngine:
	var starting := {"resources": {"food": 2, "wealth": wealth, "insight": 0}, "tableau": ["capital"],
		"territory": "homeland", "civilization": "builders"}
	return tech_engine(["loom"], {"farm": 10}, {"starting": starting, "supply": SUPPLY}, [BUILDERS, OBELISK])


## The pile cards and the screen, open on e in a real main scene; body(main, views) runs while it's open.
func with_supply(e: GameEngine, body: Callable) -> void:
	await with_main(e, func(main: Node):
		main.supply.open(Game.engine)
		await wait_frames()
		await body.call(main, main.supply.views()))


## The figures of view's title-row Cost row, {resource: text}.
func cost_figures(view: CardView) -> Dictionary:
	var row := view.find_child("Cost", true, false)
	check(row != null, "the card has a Cost row")
	var out := {}
	if row != null:
		for entry in row.get_children():
			out[String(entry.name)] = (entry.get_child(entry.get_child_count() - 1) as Label).text
	return out


## The texts of the Labels under node, in tree order.
func label_texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(l: Label): return l.text)


# --- AC4: the play cost in the title row ---

func test_a_pile_card_shows_its_discounted_play_cost_in_its_title_row() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		eq(cost_figures(views[0]), {"wealth": "9"}, "Obelisk: 12 − 3 wealth")
		eq(cost_figures(views[1]), {}, "Scout costs nothing to play"))


# --- AC5: the buy price on a tag below the card ---

func test_the_buy_price_is_on_a_tag_below_the_card_with_the_copies_left_under_it() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		var obelisk: CardView = views[0]
		check(not label_texts(obelisk).any(func(t: String): return "left" in t or "Buy" in t),
			"the card face has no price or count: %s" % [label_texts(obelisk)])
		var tag: Control = main.supply.price_tag(obelisk)
		eq(label_texts(tag), ["Buy", "3"], "the tag's text")
		var glyphs := tag.find_children("*", "TextureRect", true, false)
		eq(glyphs.size(), 1, "one glyph on the tag")
		if glyphs.size() == 1:
			eq((glyphs[0] as TextureRect).texture, Icons.RESOURCES[GameEngine.WEALTH], "the wealth glyph")
		check(tag.get_global_rect().position.y >= obelisk.get_global_rect().end.y - 1.0, "the tag hangs below the card")
		var left: Label = main.supply.copies_left(obelisk)
		eq(left.text, "6 left", "copies left")
		check(left.get_global_rect().position.y >= tag.get_global_rect().end.y - 1.0, "the count sits under the tag"))


func test_the_tag_and_count_follow_a_buy() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.supply.buy(views[0])
		main.supply.refresh(Game.engine)
		eq(label_texts(main.supply.price_tag(views[0])), ["Buy", "3"], "same price")
		eq(main.supply.copies_left(views[0]).text, "5 left", "one fewer copy"))


# --- AC6: a pile that can't be bought dims its tag ---

func test_a_pile_that_cant_be_bought_dims_its_tag_too() -> void:
	await with_supply(supply_game(2), func(main: Node, views: Array[CardView]):
		var obelisk: CardView = views[0]
		var scout: CardView = views[1]
		check(obelisk.tooltip_text.begins_with(Game.engine.buy_error("obelisk")), "the reason leads the tooltip")
		check(main.supply.price_tag(obelisk).modulate.a < 1.0, "price 3 with 2 wealth: the tag dims")
		eq(main.supply.price_tag(scout).modulate.a, 1.0, "price 2 with 2 wealth: the tag doesn't")
		main.supply.buy(scout)
		main.supply.refresh(Game.engine)
		check(main.supply.price_tag(scout).modulate.a < 1.0, "sold out: the tag dims"))


# --- Fixed height: the pile cards stand one height ---

func test_pile_cards_share_the_height_of_the_tallest() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		views[0].set_buy_error("A long reason this pile can't be bought right now, long enough to wrap across several lines of the card")
		await wait_frames()
		await wait_frames()
		var tallest := maxf(views[0].size.y, views[1].size.y)
		eq(views[0].size.y, tallest, "the first card")
		eq(views[1].size.y, tallest, "the second card"))


# --- 258: a click outside the panel closes the screen ---

## The far corner of main's viewport, outside any panel.
func corner(main: Node) -> Vector2:
	return main.get_viewport().get_visible_rect().end - Vector2(5, 5)


func test_a_click_outside_the_panel_closes_the_supply() -> void:
	await with_supply(supply_game(10), func(main: Node, _views: Array[CardView]):
		var closed := [false]
		main.supply.closed.connect(func(): closed[0] = true)
		click_point(main, corner(main))
		check(not main.supply.is_open(), "the screen is closed")
		check(closed[0], "closed is emitted"))


func test_a_click_inside_the_panel_keeps_the_supply_open() -> void:
	await with_supply(supply_game(10), func(main: Node, _views: Array[CardView]):
		click_point(main, main.supply.counter(GameEngine.WEALTH).get_global_rect().get_center())
		check(main.supply.is_open(), "a click on the panel's Wealth counter leaves it open"))


func test_a_click_outside_a_details_modal_closes_only_the_modal() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.details.open(views[0])
		await wait_frames()
		check(not main.details.shown().is_empty(), "the details modal is open")
		click_point(main, corner(main))
		check(main.details.shown().is_empty(), "the details modal closes")
		check(main.supply.is_open(), "the supply stays open"))


# --- 259: a click on a pile opens its details, which offer Buy. Hooks: main.details.buy_button(), buy_reason(),
# pile_tag() and pile_left() (null unless a supply pile's details are on show). ---

## The discard's copies of card id.
func discarded(id: String) -> int:
	return Game.engine.zone("discard").cards.filter(func(c: CardInstance): return c.def.id == id).size()


func test_a_click_on_a_pile_opens_its_details_and_buys_nothing() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		var before := discarded("obelisk")
		click_point(main, views[0].get_global_rect().get_center())
		await wait_frames()
		eq(main.details.shown().get("name", ""), "Obelisk", "the pile's details are on show")
		eq(Game.engine.resources[GameEngine.WEALTH], 10, "no wealth spent")
		eq(Game.engine.supply_left("obelisk"), 6, "no copy taken")
		eq(discarded("obelisk"), before, "nothing in the discard")
		check(main.supply.is_open(), "the supply stays open under the details"))


func test_enter_on_a_focused_pile_opens_its_details() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.focus.set_card(views[0])
		press_key(main, KEY_ENTER)
		await wait_frames()
		eq(main.details.shown().get("name", ""), "Obelisk", "the pile's details are on show")
		eq(Game.engine.supply_left("obelisk"), 6, "no copy taken"))


func test_a_piles_details_show_its_tag_count_and_an_enabled_buy() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.supply.pick(views[0])
		await wait_frames()
		var d = main.details
		var tag: Control = d.pile_tag()
		check(tag != null and tag.is_visible_in_tree(), "a price tag in the aside")
		if tag != null:
			eq(label_texts(tag), ["Buy", "3"], "the pile's price")
			check(d.aside.is_ancestor_of(tag), "the tag is in the aside")
		var left: Label = d.pile_left()
		check(left != null and left.is_visible_in_tree(), "a copies-left line")
		if left != null:
			eq(left.text, "6 left", "copies left")
			if tag != null:
				check(left.get_global_rect().position.y >= tag.get_global_rect().end.y - 1.0, "the count sits under the tag")
		var buy: Button = d.buy_button()
		check(buy.visible and not buy.disabled, "Buy is shown and enabled")
		eq(buy.text, "Buy", "its label")
		var shown: Array = d.footer.get_children().filter(func(c: Control): return c is Button and c.visible)
		eq(shown.back(), buy, "Buy is rightmost")
		check(not d.play_button().visible and not d.research_button().visible, "no Play or Learn")
		check(d.unit_buttons().all(func(b: Button): return not b.visible), "no Move… or Disband")
		check(not d.buy_reason().visible, "no reason while it can be bought"))


func test_buy_in_a_piles_details_buys_a_copy_and_closes_them() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		var before := discarded("obelisk")
		main.supply.pick(views[0])
		await wait_frames()
		main.details.buy_button().pressed.emit()
		await wait_frames()
		check(main.details.shown().is_empty(), "the details close")
		check(main.supply.is_open(), "the supply stays open")
		eq(Game.engine.resources[GameEngine.WEALTH], 7, "3 wealth paid")
		eq(Game.engine.supply_left("obelisk"), 5, "one copy taken")
		eq(discarded("obelisk"), before + 1, "the copy is in the discard")
		eq(main.supply.copies_left(views[0]).text, "5 left", "the screen's count follows"))


func test_buy_flies_a_copy_to_the_discard_counter() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.supply.pick(views[0])
		await wait_frames()
		main.details.buy_button().pressed.emit()
		var flying: Array = main.find_children("*", "CardView", true, false).filter(
			func(v: CardView): return v.uid == -100)
		eq(flying.size(), 1, "one copy in flight to the Discard counter"))


## The copy in flight to the Discard counter after Buy on view's details (361), or null.
func bought_copy(main: Node, view: CardView) -> CardView:
	main.supply.pick(view)
	await wait_frames()
	main.details.buy_button().pressed.emit()
	var flying: Array = main.find_children("*", "CardView", true, false).filter(func(v: CardView): return v.uid == -100)
	check(flying.size() == 1, "one copy in flight")
	return flying[0] if flying.size() == 1 else null


func test_bug_361_the_bought_copy_keeps_the_pile_cards_size_as_it_flies() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		var pile: CardView = views[1]  # Scout
		var copy := await bought_copy(main, pile)
		var tallest := 0.0
		var frames := 0
		while is_instance_valid(copy) and frames < 120:
			tallest = maxf(tallest, copy.size.y)
			check(absf(copy.size.x - pile.size.x) <= 1.0, "frame %d: the copy is the pile card's width" % frames)
			await wait_frames(1)
			frames += 1
		check(tallest <= pile.size.y + 1.0, "the copy is never taller than the pile card (%d): %d" % [pile.size.y, tallest]))


func test_bug_361_the_bought_copy_starts_on_the_pile_card() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		var pile: CardView = views[1]  # Scout
		await wait_screen_transition()  # the pile cards have popped in
		main.supply.pick(pile)
		await wait_frames()
		var centre := pile.get_global_rect().get_center()
		main.details.buy_button().pressed.emit()
		var flying: Array = main.find_children("*", "CardView", true, false).filter(func(v: CardView): return v.uid == -100)
		eq(flying.size(), 1, "one copy in flight")
		if flying.size() != 1:
			return
		var at: Vector2 = (flying[0] as CardView).get_global_rect().get_center()
		check(at.distance_to(centre) <= 1.0, "the copy starts centred on the pile card %s: %s" % [centre, at]))


func test_an_unaffordable_piles_buy_is_disabled_with_the_reason_on_the_footer() -> void:
	await with_supply(supply_game(2), func(main: Node, views: Array[CardView]):
		main.supply.pick(views[0])
		await wait_frames()
		var d = main.details
		check(d.buy_button().visible and d.buy_button().disabled, "Buy is shown, disabled")
		var reason: Label = d.buy_reason()
		check(reason.is_visible_in_tree(), "the reason is shown")
		eq(reason.text, Game.engine.buy_error("obelisk"), "the engine's reason")
		check(d.footer.is_ancestor_of(reason), "on the footer")
		var first: Control = d.footer.get_children().filter(func(c: Control): return c.visible).front()
		eq(first, reason, "at its left")
		check(d.pile_tag() != null and d.pile_tag().modulate.a < 1.0, "the tag is dimmed")
		eq(Game.engine.supply_left("obelisk"), 6, "opening bought nothing"))


func test_a_sold_out_piles_buy_is_disabled_with_the_reason() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.supply.buy(views[1])  # the only Scout
		main.supply.refresh(Game.engine)
		main.supply.pick(views[1])
		await wait_frames()
		var d = main.details
		check(d.buy_button().disabled, "Buy is disabled")
		eq(d.buy_reason().text, Game.engine.buy_error("scout"), "the engine's reason")
		check(d.buy_reason().is_visible_in_tree(), "shown")
		eq(d.pile_left().text, "0 left", "none left")
		check(d.pile_tag().modulate.a < 1.0, "the tag is dimmed"))


func test_esc_or_close_on_a_piles_details_buys_nothing() -> void:
	await with_supply(supply_game(10), func(main: Node, views: Array[CardView]):
		main.supply.pick(views[0])
		await wait_frames()
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check(main.details.shown().is_empty(), "Esc closes the details")
		check(main.supply.is_open(), "the supply stays open after Esc")
		main.supply.pick(views[0])
		await wait_frames()
		main.details.close()
		await wait_frames()
		check(main.details.shown().is_empty(), "Close closes the details")
		check(main.supply.is_open(), "the supply stays open after Close")
		eq(Game.engine.supply_left("obelisk"), 6, "nothing bought")
		eq(Game.engine.resources[GameEngine.WEALTH], 10, "no wealth spent"))
