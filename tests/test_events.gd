extends "res://tests/lib/test_case.gd"
## The event deck (backlog 039): the event card type and its discard condition, the event_deck config, drawing
## one event per end_turn, active events' upkeep, discarding them, and reshuffling the event discard.
## Fixture events: TEST_EVENTS in tests/lib/test_case.gd. Engine helpers return Object, not GameEngine, so calls
## to new engine methods fail at run time, not parse time.

const ALL_EVENTS := {"windfall": 1, "trade_winds": 1, "omen": 1}


## A game with the main deck {scout: 10}, the event deck order_top_first on top (the rest of event_deck below),
## 2 food and 0 wealth. overrides replace config keys.
func event_engine(order_top_first: Array = [], overrides := {}, seed_value := 1) -> GameEngine:
	var config := {"event_deck": ALL_EVENTS}
	config.merge(overrides, true)
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := event_db(errors, warnings)
	var parsed := DataLoader.parse_config(raw_config({"scout": 10}, config), resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, parsed)
	e.new_game(seed_value)
	if not order_top_first.is_empty():
		arrange(e.zone("event_deck"), order_top_first)
	e.resources.food = 2
	e.resources.wealth = 0
	return e


## Ends the turn with one card over the hand limit, so it stops after the event phase and before cleanup.
## The game needs hand_limit 5 (see event_engine overrides).
func end_turn_before_cleanup(e: GameEngine) -> void:
	while e.zone("hand").size() <= e.config.hand_limit:
		put_in_hand(e, "scout")
	e.end_turn()
	eq(e.pending().get("kind", ""), GameEngine.PENDING_DISCARD, "stopped for the hand-limit discard")


## Loads a card 'x' of type with extra fields; returns {cards, errors, warnings}.
func load_x(type: String, fields := {}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var x := {"id": "x", "name": "X", "type": type}
	x.merge(fields, true)
	var raw := {"cards": [{"id": "city", "name": "City", "type": "city"}, x]}
	var cards := DataLoader.parse_cards(raw, resources(), "cards.json", errors, warnings, keywords())
	return {"cards": cards, "errors": errors, "warnings": warnings}


func load_config(overrides: Dictionary, deck := {"farm": 1}) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := event_db(errors)
	check(errors.is_empty(), "fixture cards should load: %s" % [errors])
	var config := DataLoader.parse_config(raw_config(deck, overrides), resources(), cards, "config.json", errors, warnings)
	return {"config": config, "errors": errors, "warnings": warnings}


# --- AC1: event cards load ---

func test_event_loads_with_discard_turns() -> void:
	var r := load_x("event", {"discard": {"turns": 2}})
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.type, "event", "type")
		eq(r.cards.x.discard_turns, 2, "discard_turns")


func test_event_discard_defaults_to_one_turn() -> void:
	var r := load_x("event")
	eq(r.errors, [] as Array[String], "loader errors")
	if r.cards.has("x"):
		eq(r.cards.x.discard_turns, 1, "discard_turns default")


func test_event_card_validation() -> void:
	check_cases([
		["zero turns", {"discard": {"turns": 0}}, "cards.json: card 'x': discard"],
		["turns not a number", {"discard": {"turns": "x"}}, "cards.json: card 'x': discard"],
		["unknown condition", {"discard": {"until": 3}}, "cards.json: card 'x': discard"],
		["discard not an object", {"discard": 2}, "cards.json: card 'x': discard"],
		["cost", {"cost": {"food": 1}}, "cards.json: card 'x': cost"],
		["vp", {"vp": 1}, "cards.json: card 'x': vp"],
		["keyword effect", {"effects": [{"op": "gain", "resource": "food", "amount": 1, "keyword": "mountain"}]},
			"cards.json: card 'x': effects[0]"],
		["targeting effect", {"effects": [{"op": "settle", "card": "city"}]}, "cards.json: card 'x': effects[0]"],
		["upkeep effect not upkeep_ok", {"effects": [{"op": "draw", "amount": 1, "trigger": "upkeep"}]},
			"cards.json: card 'x': effects[0]"],
	], func(fields): return load_x("event", fields).errors)


# --- 069 AC7: grow "here" needs a territory ---

func test_grow_here_on_a_card_with_no_territory_is_a_load_error() -> void:
	check_cases([
		["event, where here", ["event", {"effects": [{"op": "grow", "amount": 1, "where": "here"}]}],
			"cards.json: card 'x': effects[0]"],
		["event, where defaults to here", ["event", {"effects": [{"op": "grow", "amount": 1}]}],
			"cards.json: card 'x': effects[0]"],
		["tech, where here", ["tech", {"cost": {"wealth": 2}, "effects": [{"op": "grow", "amount": 1, "where": "here"}]}],
			"cards.json: card 'x': effects[0]"],
	], func(args): return load_x(args[0], args[1]).errors)


func test_grow_each_on_an_event_loads() -> void:
	var r := load_x("event", {"effects": [{"op": "grow", "amount": 1, "where": "each"}]})
	eq(r.errors, [] as Array[String], "loader errors")


func test_discard_on_a_non_event_is_a_warning() -> void:
	check_cases([
		["discard on a building", {"discard": {"turns": 1}}, ["cards.json: card 'x'", "'discard'"], "warning_only"],
	], func(fields): return load_x("building", fields))


func test_event_text_says_how_long_it_lasts() -> void:
	var cards := event_db()
	eq(cards.trade_winds.rules_text(cards), "⟳ +1 wealth\nLasts 2 turns", "Trade Winds text")
	eq(cards.omen.rules_text(cards), "Lasts 1 turn", "Omen text")


## Backlog 070: the tooltip (the full text) says how long the event lasts too.
func test_event_tooltip_says_how_long_it_lasts() -> void:
	var cards := event_db()
	eq(cards.trade_winds.rules_tooltip(cards), "Each upkeep: +1 wealth\nLasts 2 turns", "Trade Winds tooltip")
	eq(cards.omen.rules_tooltip(cards), "Lasts 1 turn", "Omen tooltip")


## Backlog 070: a card's own text replaces the generated text in both forms, the duration included.
func test_card_text_replaces_the_duration_on_an_event() -> void:
	var r := load_x("event", {"text": "Something odd", "discard": {"turns": 2}})
	eq(r.errors, [] as Array[String], "loads")
	if r.cards.has("x"):
		eq(r.cards.x.rules_text(r.cards), "Something odd", "rules_text")
		eq(r.cards.x.rules_tooltip(r.cards), "Something odd", "rules_tooltip")


# --- AC2: event_deck config ---

func test_event_deck_is_normalized() -> void:
	var r := load_config({"event_deck": {"windfall": 2.0, "omen": 1}})
	eq(r.errors, [] as Array[String], "errors")
	eq(r.config.get("event_deck"), {"windfall": 2, "omen": 1}, "event_deck")


func test_event_deck_defaults_to_empty() -> void:
	var r := load_config({})
	eq(r.config.get("event_deck"), {}, "event_deck default")
	eq(r.warnings, [] as Array[String], "no warnings")


func test_event_deck_validation() -> void:
	check_cases([
		["unknown card", [{"event_deck": {"dragon": 1}}, {"farm": 1}], "config.json: event_deck: unknown card 'dragon'"],
		["not an event", [{"event_deck": {"farm": 1}}, {"farm": 1}], "config.json: event_deck: 'farm'"],
		["count 0", [{"event_deck": {"omen": 0}}, {"farm": 1}], "config.json: event_deck: count for 'omen'"],
		["event in the main deck", [{}, {"farm": 1, "omen": 1}], "config.json: deck: 'omen'"],
		["event in the supply", [{"supply": {"omen": {"price": 1, "count": 1}}}, {"farm": 1}], "config.json: supply: 'omen'"],
	], func(args): return load_config(args[0], args[1]).errors)


# --- AC3: setup ---

func test_new_game_shuffles_the_event_deck_by_seed() -> void:
	var a := event_engine([], {}, 7)
	var b := event_engine([], {}, 7)
	eq(sorted(card_ids(a.zone("event_deck"))), ["omen", "trade_winds", "windfall"], "event deck holds the 3 events")
	eq(card_ids(a.zone("event_deck")), card_ids(b.zone("event_deck")), "same seed, same order")
	eq(a.zone("active_events").size(), 0, "no active events")
	eq(a.zone("event_discard").size(), 0, "event discard empty")


func test_no_event_deck_leaves_the_event_zones_empty() -> void:
	var e := event_engine([], {"event_deck": {}})
	for z in ["event_deck", "active_events", "event_discard"]:
		eq(e.zone(z).size(), 0, z)
	e.end_turn()
	eq(e.turn, 2, "end turn works as before")
	eq(e.zone("active_events").size(), 0, "nothing drawn")


# --- AC4: drawing in the event phase ---

func test_end_turn_draws_the_top_event_and_resolves_it_before_cleanup() -> void:
	var e := event_engine(["windfall", "trade_winds", "omen"], {"hand_limit": 5})
	end_turn_before_cleanup(e)
	eq(e.resources.food, 4, "2 food + Windfall 2, before turn 2's upkeep")
	eq(card_ids(e.zone("active_events")), ["windfall"], "active events")
	var uid := uid_of(e.zone("active_events"), "windfall")
	eq(e.event_turns_left(uid), 1, "turns left")
	eq(e.zone("event_deck").size(), 2, "event deck after one draw")


func test_finishing_the_discard_does_not_draw_another_event() -> void:
	var e := event_engine(["windfall", "trade_winds", "omen"], {"hand_limit": 5})
	end_turn_before_cleanup(e)
	check(e.discard_card(first_in_hand(e)), "discard should finish the turn")
	eq(e.turn, 2, "turn 2 started")
	eq(e.zone("event_deck").size(), 2, "still one event drawn")


func test_each_end_turn_draws_exactly_one_event() -> void:
	var e := event_engine(["omen", "windfall", "trade_winds"])
	e.end_turn()
	eq(e.zone("event_deck").size(), 2, "one drawn after turn 1")
	e.end_turn()
	eq(e.zone("event_deck").size(), 1, "one more after turn 2")


func test_the_final_turn_draws_an_event() -> void:
	var e := event_engine(["trade_winds", "windfall", "omen"], {"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	eq(card_ids(e.zone("active_events")), ["trade_winds"], "event drawn on the final turn")


func test_event_turns_left_is_zero_for_a_card_that_is_not_active() -> void:
	var e := event_engine(["omen", "windfall", "trade_winds"])
	eq(e.event_turns_left(uid_of(e.zone("event_deck"), "omen")), 0, "event still in the deck")
	eq(e.event_turns_left(-1), 0, "no such card")


# --- AC5: upkeep and discard ---

func test_an_active_event_gives_its_upkeep_every_turn_it_lasts() -> void:
	var e := event_engine(["trade_winds", "windfall", "omen"])
	e.end_turn()
	var uid := uid_of(e.zone("active_events"), "trade_winds")
	eq(e.resources.wealth, 1, "turn 2 upkeep: Trade Winds +1")
	eq(e.event_turns_left(uid), 1, "turns left after turn 2's upkeep")
	e.end_turn()
	eq(e.resources.wealth, 2, "turn 3 upkeep: Trade Winds +1 again")
	eq(uid_of(e.zone("active_events"), "trade_winds"), -1, "no longer active")
	check(uid_of(e.zone("event_discard"), "trade_winds") != -1, "Trade Winds in the event discard")
	e.end_turn()
	eq(e.resources.wealth, 2, "turn 4 upkeep: nothing from Trade Winds")


func test_event_upkeep_resolves_before_pop_eats() -> void:
	# Capital makes 2 food and Harvest 1; 3 pop eat 3. Without Harvest's food first, 1 pop would starve.
	var e := event_engine(["harvest"], {"event_deck": {"harvest": 1},
		"population": {"start": 2, "food_upkeep": 1, "vp_per_pop": 0}})
	e.zone("tableau").find(home_uid(e)).pop = 3
	e.end_turn()
	e.resources.food = 0
	e.end_turn()
	eq(e.pop(home_uid(e)), 3, "no pop starved at turn 3's upkeep")
	eq(e.resources.food, 0, "2 + 1 made, 3 eaten")


func test_forecast_includes_active_event_upkeep() -> void:
	var e := event_engine(["trade_winds", "windfall", "omen"])
	e.end_turn()
	eq(e.upkeep_forecast().get("wealth"), 1, "Trade Winds +1 wealth in the forecast")


func test_forecast_leaves_the_event_zones_alone() -> void:
	var e := event_engine(["trade_winds", "windfall", "omen"])
	e.end_turn()
	var uid := uid_of(e.zone("active_events"), "trade_winds")
	e.upkeep_forecast()  # on the fork, Trade Winds would end
	eq(card_ids(e.zone("active_events")), ["trade_winds"], "still active")
	eq(e.zone("event_discard").size(), 0, "event discard untouched")
	eq(e.event_turns_left(uid), 1, "turns left unchanged")


# --- AC6: single-turn events and several active ---

func test_a_single_turn_event_ends_at_the_next_upkeep() -> void:
	var e := event_engine(["windfall", "trade_winds", "omen"])
	e.end_turn()
	eq(card_ids(e.zone("event_discard")), ["windfall"], "Windfall discarded at turn 2's upkeep")
	eq(uid_of(e.zone("active_events"), "windfall"), -1, "no longer active")


## Backlog 116: an active event ending is a notice; drawing one is not (its modal shows it).
func test_an_event_ending_is_a_notice_and_drawing_one_is_not() -> void:
	var e := event_engine(["windfall", "trade_winds", "omen"])
	var recorded := record_messages(e)
	e.end_turn()
	check_noticed(recorded, "Windfall ends.")
	check(recorded.has("log: Event: Windfall."), "Windfall drawn: %s" % [recorded])
	check(not notices_in(recorded).has("Event: Windfall."), "drawing isn't a notice")


func test_several_events_can_be_active_in_draw_order() -> void:
	var e := event_engine(["trade_winds", "omen", "windfall"], {"hand_limit": 5})
	e.end_turn()
	end_turn_before_cleanup(e)
	eq(card_ids(e.zone("active_events")), ["trade_winds", "omen"], "both active, in draw order")
	for z in ["hand", "tableau", "discard"]:
		for id in ["trade_winds", "omen"]:
			eq(uid_of(e.zone(z), id), -1, "%s not in %s" % [id, z])


func test_active_events_score_no_vp() -> void:
	var e := event_engine(["trade_winds", "omen", "windfall"], {"hand_limit": 5})
	var before: int = e.score()
	e.end_turn()
	end_turn_before_cleanup(e)
	eq(e.score(), before, "score with two active events")


# --- AC7: empty event deck ---

func test_empty_event_deck_reshuffles_the_event_discard_by_seed() -> void:
	var drawn := []
	for i in 2:
		var e := event_engine([], {"hand_limit": 5}, 3)
		for card in e.zone("event_deck").take_all():
			e.zone("event_discard").add(card)
		end_turn_before_cleanup(e)
		eq(e.zone("event_deck").size(), 2, "3 reshuffled, 1 drawn")
		eq(e.zone("event_discard").size(), 0, "event discard emptied")
		drawn.append(card_ids(e.zone("active_events")) + card_ids(e.zone("event_deck")))
	eq(drawn[0], drawn[1], "same seed, same reshuffle")


func test_nothing_is_drawn_when_both_event_piles_are_empty() -> void:
	var e := event_engine(["trade_winds"], {"event_deck": {"trade_winds": 1}, "hand_limit": 5})
	e.end_turn()
	end_turn_before_cleanup(e)  # the event phase found both piles empty
	eq(card_ids(e.zone("active_events")), ["trade_winds"], "only Trade Winds, still active")
	eq(e.zone("event_deck").size() + e.zone("event_discard").size(), 0, "nothing else to draw")
	check(e.discard_card(first_in_hand(e)), "discard should finish the turn")
	eq(e.turn, 3, "turn ended normally")
