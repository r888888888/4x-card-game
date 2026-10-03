extends "res://tests/lib/tech_case.gd"
## The supply screen's pile cards (232): each shows its play cost after discounts in its title row, like a hand card,
## and its buy price on a tag below the card ("Buy", the wealth glyph, the price) with the copies left under it.
## Local fixtures: civilization Builders (wonders −3 wealth) and building Obelisk (12 wealth, wonder).

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
		main.supply.pick(views[0])
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
		main.supply.pick(scout)
		main.supply.refresh(Game.engine)
		check(main.supply.price_tag(scout).modulate.a < 1.0, "sold out: the tag dims"))
