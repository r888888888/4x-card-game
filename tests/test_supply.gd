extends "res://tests/lib/tech_case.gd"
## The card supply (backlog 032): buying copies of existing cards with wealth (supply, supply_left,
## buy_price, buy_error, buy) and the config `supply` block.


# --- Helpers ---

## A game whose supply sells Scout (price 2, 2 left), with wealth set to the given amount.
## Extends tech_case so a research deck is available for the blocked-state tests.
func supply_engine(wealth: int, deck := {"farm": 10}, overrides := {}) -> Object:
	var config := {"supply": {"scout": {"price": 2, "count": 2}}}
	config.merge(overrides, true)
	var e := tech_engine(["pottery", "writing", "bronze"], deck, config)
	e.resources.wealth = wealth
	return e


## Parses a config with the given supply block; returns the loader errors.
func supply_errors(supply: Variant) -> Array[String]:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	DataLoader.parse_config(raw_config({"farm": 1}, {"supply": supply}), resources(), cards, "config.json", errors, warnings)
	return errors


## Asserts buy("scout") is refused with message and changes nothing.
func assert_buy_refused(e: Object, card_id: String, message: String) -> void:
	var wealth_before: int = e.resources.wealth
	var discard_before := card_ids(e.zone("discard"))
	var left_before: int = e.supply_left(card_id)
	eq(e.buy_error(card_id), message, "buy_error")
	check(not e.buy(card_id), "buy should fail")
	eq(e.resources.wealth, wealth_before, "wealth unchanged")
	eq(card_ids(e.zone("discard")), discard_before, "discard unchanged")
	eq(e.supply_left(card_id), left_before, "supply unchanged")


# --- AC1: buy a card ---

func test_buying_pays_wealth_and_puts_the_card_on_the_discard() -> void:
	var e := supply_engine(3)
	var events: Array[String] = []
	e.changed.connect(func(): events.append("changed"))
	eq(e.buy_price("scout"), 2, "price")
	eq(e.buy_error("scout"), "", "buy_error")
	check(e.buy("scout"), "buy returns true")
	eq(e.resources.wealth, 1, "wealth 3 - price 2")
	eq(e.zone("discard").cards.back().def.id, "scout", "top of discard")
	eq(e.zone("discard").size(), 1, "discard size")
	eq(e.supply_left("scout"), 1, "2 - 1 left")
	check(events.has("changed"), "changed emitted")


func test_supply_lists_card_counts_left() -> void:
	var e := supply_engine(0, {"farm": 10}, {"supply": {
		"scout": {"price": 2, "count": 2}, "temple": {"price": 3, "count": 1}}})
	eq(e.supply(), {"scout": 2, "temple": 1}, "supply")


# --- AC2: no limit per turn ---

func test_buying_twice_in_one_turn_empties_the_pile() -> void:
	var e := supply_engine(4)
	check(e.buy("scout"), "first buy")
	check(e.buy("scout"), "second buy")
	eq(e.resources.wealth, 0, "wealth 4 - 2 - 2")
	eq(card_ids(e.zone("discard")), ["scout", "scout"], "discard")
	eq(e.supply_left("scout"), 0, "pile empty")


# --- AC3: refused buys ---

func test_cannot_buy_without_enough_wealth() -> void:
	assert_buy_refused(supply_engine(1), "scout", "Scout costs 2 wealth (you have 1).")


func test_cannot_buy_from_an_empty_pile() -> void:
	var e := supply_engine(10)
	check(e.buy("scout"), "first buy")
	check(e.buy("scout"), "second buy")
	assert_buy_refused(e, "scout", "No Scouts left in the supply.")


func test_cannot_buy_a_card_not_in_the_supply() -> void:
	assert_buy_refused(supply_engine(10), "farm", "Farm isn't in the supply.")


func test_cannot_buy_without_a_supply() -> void:
	var e := make_engine({"farm": 10})
	e.resources.wealth = 10
	var o: Object = e
	eq(o.supply(), {}, "empty supply")
	eq(o.supply_left("scout"), 0, "nothing left")
	assert_buy_refused(o, "scout", "Scout isn't in the supply.")


# --- AC4: blocked like grow ---

func test_cannot_buy_when_the_game_is_over() -> void:
	var e := supply_engine(10)
	e.is_over = true
	assert_buy_refused(e, "scout", "The game is over.")


func test_cannot_buy_while_an_explore_choice_is_pending() -> void:
	var e := supply_engine(10)
	e.pending_choice = {"options": [1], "source": e.zone("tableau").cards[0]}
	assert_buy_refused(e, "scout", "Choose a territory first.")


func test_cannot_buy_while_research_options_are_open() -> void:
	var e := supply_engine(10)
	check(play_research(e), "research opens")
	assert_buy_refused(e, "scout", "Buy a tech or decline first.")


func test_cannot_buy_while_a_discard_is_pending() -> void:
	var e := supply_engine(10, {"scout": 10})
	for i in 3:
		check(e.play_card(first_in_hand(e)), "play scout %d" % i)
	e.end_turn()
	eq(e.discard_needed(), 1, "a discard is pending")
	e.resources.wealth = 10
	assert_buy_refused(e, "scout", "Discard down to 7 cards first.")


# --- AC5: loader ---

func test_supply_block_is_normalized() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}, {"supply": {"scout": {"price": 2, "count": 3}}}),
		resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(config.supply, {"scout": {"price": 2, "count": 3}}, "supply")


func test_supply_defaults_to_empty() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(config.supply, {}, "supply")


func test_supply_unknown_card_is_error() -> void:
	has_msg(supply_errors({"dragon": {"price": 2, "count": 1}}), "config.json: supply: unknown card 'dragon'")


func test_supply_rejects_cities_territories_and_techs() -> void:
	has_msg(supply_errors({"city": {"price": 2, "count": 1}}), "config.json: supply: 'city' is a city")
	has_msg(supply_errors({"grassland": {"price": 2, "count": 1}}), "config.json: supply: 'grassland' is a territory")
	has_msg(supply_errors({"pottery": {"price": 2, "count": 1}}), "config.json: supply: 'pottery' is a tech")


func test_supply_price_must_be_at_least_1() -> void:
	has_msg(supply_errors({"scout": {"price": 0, "count": 1}}), "config.json: supply: 'scout': 'price' must be an integer >= 1")
	has_msg(supply_errors({"scout": {"count": 1}}), "config.json: supply: 'scout': 'price' must be an integer >= 1")


func test_supply_count_must_be_at_least_1() -> void:
	has_msg(supply_errors({"scout": {"price": 2, "count": 0}}), "config.json: supply: 'scout': 'count' must be an integer >= 1")
	has_msg(supply_errors({"scout": {"price": 2}}), "config.json: supply: 'scout': 'count' must be an integer >= 1")


func test_supply_entry_must_be_an_object() -> void:
	has_msg(supply_errors({"scout": 2}), "config.json: supply: 'scout' must be an object like {\"price\": 2, \"count\": 1}")
