extends "res://tests/lib/tech_case.gd"
## The card supply (backlog 032): buying copies of existing cards with wealth (supply, supply_left,
## buy_price, buy_error, buy) and the config `supply` block.


# --- Helpers ---

## A game whose supply sells Scout (price 2, 2 left), with wealth set to the given amount.
## Extends tech_case so a research deck is available for the blocked-state tests.
func supply_engine(wealth: int, deck := {"farm": 10}, overrides := {}) -> GameEngine:
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
func assert_buy_refused(e: GameEngine, card_id: String, message: String) -> void:
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
	var o: GameEngine = e
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
	e.state.pending = {"kind": GameEngine.PENDING_EXPLORE, "options": [1], "source": e.zone("tableau").cards[0].uid}
	assert_buy_refused(e, "scout", "Choose a territory first.")


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
	eq(config.supply, {"scout": {"price": 2, "count": 3, "locked": false}}, "supply")


func test_supply_defaults_to_empty() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([], errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}), resources(), cards, "config.json", errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(config.supply, {}, "supply")


func test_supply_validation() -> void:
	check_cases([
		["unknown card", {"dragon": {"price": 2, "count": 1}}, "config.json: supply: unknown card 'dragon'"],
		["city", {"city": {"price": 2, "count": 1}}, "config.json: supply: 'city' is a city"],
		["territory", {"grassland": {"price": 2, "count": 1}}, "config.json: supply: 'grassland' is a territory"],
		["tech", {"pottery": {"price": 2, "count": 1}}, "config.json: supply: 'pottery' is a tech"],
		["price 0", {"scout": {"price": 0, "count": 1}}, "config.json: supply: 'scout': 'price' must be an integer >= 1"],
		["no price", {"scout": {"count": 1}}, "config.json: supply: 'scout': 'price' must be an integer >= 1"],
		["count 0", {"scout": {"price": 2, "count": 0}}, "config.json: supply: 'scout': 'count' must be an integer >= 1"],
		["no count", {"scout": {"price": 2}}, "config.json: supply: 'scout': 'count' must be an integer >= 1"],
		["not an object", {"scout": 2}, "config.json: supply: 'scout' must be an object like {\"price\": 2, \"count\": 1}"],
	], supply_errors)


# --- Backlog 057: locked piles and the unlock op ---

## Guilds (tech, 2 wealth): a free Guildhall in the discard, and the Guildhall pile unlocked.
const GUILDS := {"id": "guilds", "name": "Guilds", "type": "tech", "cost": {"insight": 2}, "effects": [
	{"op": "create", "card": "guildhall", "zone": "discard"}, {"op": "unlock", "card": "guildhall"}]}
## Actions that unlock a pile: the locked Guildhall, or Scout, which was never locked.
const CHARTER := {"id": "charter", "name": "Charter", "type": "action", "effects": [{"op": "unlock", "card": "guildhall"}]}
const SCOUT_CHARTER := {"id": "scout_charter", "name": "Scout Charter", "type": "action",
	"effects": [{"op": "unlock", "card": "scout"}]}
const LOCKED_SUPPLY := {"scout": {"price": 2, "count": 2}, "guildhall": {"price": 2, "count": 2, "locked": true}}


## A game with LOCKED_SUPPLY, Guilds on top of the research deck and the given wealth.
func locked_engine(wealth: int, deck := {"farm": 10}) -> GameEngine:
	var e := tech_engine(["guilds", "pottery", "writing"], deck, {"supply": LOCKED_SUPPLY}, [GUILDS, CHARTER, SCOUT_CHARTER])
	e.resources.wealth = wealth
	return e


## Loads fixtures plus extra and a config with overrides; returns {cards, config, errors, warnings}.
func load_locked(extra: Array, overrides: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := tech_db([GUILDS] + extra, errors, warnings)
	var config := DataLoader.parse_config(raw_config({"farm": 1}, overrides), resources(), cards, "config.json", errors, warnings)
	return {"cards": cards, "config": config, "errors": errors, "warnings": warnings}


## Loads one action card x with effect; returns {cards, errors, warnings}.
func unlock_card(effect: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := DataLoader.parse_cards({"cards": TEST_CARDS.cards + [
		{"id": "x", "name": "X", "type": "action", "effects": [effect]}]}, resources(), "cards.json", errors, warnings,
		keywords())
	return {"cards": cards, "errors": errors, "warnings": warnings}


# AC1: config

func test_supply_pile_may_be_locked() -> void:
	var r := load_locked([], {"supply": LOCKED_SUPPLY, "research_deck": {"guilds": 1}})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.config.supply.guildhall.get("locked"), true, "guildhall locked")
	eq(r.config.supply.scout.get("locked"), false, "scout defaults to unlocked")


func test_supply_locked_must_be_a_bool() -> void:
	check_cases([
		["locked not a bool", {"scout": {"price": 2, "count": 1, "locked": "yes"}},
			"config.json: supply: 'scout': 'locked' must be true or false"],
		["locked a number", {"scout": {"price": 2, "count": 1, "locked": 1}},
			"config.json: supply: 'scout': 'locked' must be true or false"],
	], supply_errors)


# AC2: the unlock op

func test_unlock_op_loads() -> void:
	var r := unlock_card({"op": "unlock", "card": "guildhall"})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.warnings, [] as Array[String], "warnings")


func test_unlock_validation() -> void:
	check_cases([
		["missing card", {"op": "unlock"}, "cards.json: card 'x': effects[0]: missing 'card'"],
		["unknown card", {"op": "unlock", "card": "dragon"}, "cards.json: card 'x': 'unlock' effect refers to unknown card 'dragon'"],
		["on upkeep", {"op": "unlock", "card": "guildhall", "trigger": "upkeep"},
			"cards.json: card 'x': effects[0]: 'unlock' only works on play (got trigger 'upkeep')"],
	], unlock_card)


func test_unlock_of_a_card_with_no_supply_pile_is_a_config_error() -> void:
	var r := load_locked([], {"supply": {"scout": {"price": 2, "count": 2}}, "research_deck": {"guilds": 1}})
	check(has_message(r.errors, "config.json: 'guilds' unlocks 'guildhall', which has no supply pile"), str(r.errors))


# AC3: a locked pile

func test_a_locked_pile_is_listed_but_cannot_be_bought() -> void:
	var e := locked_engine(5)
	eq(e.supply(), {"scout": 2, "guildhall": 2}, "supply lists the locked pile")
	check(e.supply_locked("guildhall"), "guildhall locked")
	check(not e.supply_locked("scout"), "scout not locked")
	assert_buy_refused(e, "guildhall", "Guildhall isn't unlocked yet.")


# AC4: a tech unlocks it

func test_researching_guilds_adds_a_guildhall_and_unlocks_the_pile() -> void:
	var e := locked_engine(0)
	e.resources.wealth = 2
	check(e.buy_tech(uid_of(e.zone("research_deck"), "guilds")), "learn Guilds")
	eq(card_ids(e.zone("discard")).count("guildhall"), 1, "a free Guildhall in the discard")
	check(not e.supply_locked("guildhall"), "the pile is unlocked")
	e.resources.wealth = 2
	check(e.buy("guildhall"), "buy a Guildhall")
	eq(e.supply_left("guildhall"), 1, "2 - 1 left")


## Backlog 116: a pile that can now be bought is a notice; learning the tech and buying are not.
func test_an_unlocked_pile_is_a_notice_but_learning_and_buying_are_not() -> void:
	var e := locked_engine(0)
	e.resources.wealth = 4
	var recorded := record_messages(e)
	check(e.buy_tech(uid_of(e.zone("research_deck"), "guilds")), "learn Guilds")
	check(e.buy("guildhall"), "buy a Guildhall")
	eq(notices_in(recorded).size(), 1, "one notice: %s" % [recorded])
	check_noticed(recorded, "can now be bought", GameEngine.NOTICE_INFO)


# AC5: idempotent

func test_unlocking_twice_or_an_unlocked_pile_changes_nothing() -> void:
	var e := locked_engine(0, {"charter": 2, "scout_charter": 3})
	for id in ["charter", "charter", "scout_charter"]:
		check(e.play_card(uid_of(e.zone("hand"), id)), "play %s" % id)
	check(not e.supply_locked("guildhall"), "guildhall unlocked")
	check(not e.supply_locked("scout"), "scout still unlocked")
	eq(e.supply(), {"scout": 2, "guildhall": 2}, "counts unchanged")


# AC6: fork

func test_a_fork_copies_the_locks_and_unlocks_on_its_own() -> void:
	var e := locked_engine(0, {"charter": 5})
	var f: GameEngine = e.fork()
	check(f.supply_locked("guildhall"), "the fork starts locked")
	check(f.play_card(uid_of(f.zone("hand"), "charter")), "play Charter on the fork")
	check(not f.supply_locked("guildhall"), "the fork's pile is unlocked")
	check(e.supply_locked("guildhall"), "the game's pile stays locked")


# Text

func test_unlock_text() -> void:
	var r := unlock_card({"op": "unlock", "card": "guildhall"})
	eq(r.cards.x.rules_text(r.cards), "Unlock Guildhall", "short text")
	eq(r.cards.x.rules_tooltip(r.cards), "Guildhall can now be built.", "tooltip: a building is built (295)")
