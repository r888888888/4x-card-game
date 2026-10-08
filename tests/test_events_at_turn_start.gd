extends "res://tests/lib/anarchy_case.gd"
## The turn's event is drawn at the start of the turn, from turn 2 (backlog 237): last in the turn start, after upkeep,
## feeding, the Anarchy checks and the hand draw; never in end_turn. Fixtures: TEST_EVENTS, the
## Anarchy fixtures (tests/lib/anarchy_case.gd) and the events below.

## A one-turn event with an upkeep effect: ⟳ +1 wealth.
const FAIR := {"id": "fair", "name": "Fair", "type": "event",
	"effects": [{"op": "gain", "resource": "wealth", "amount": 1, "trigger": "upkeep"}]}
## A two-turn event with a modifier: +1 action.
const ZEAL := {"id": "zeal", "name": "Zeal", "type": "event", "discard": {"turns": 2}, "modifiers": {"actions": 1}}
## A one-turn event that gains 1 unrest when drawn.
const STIR := {"id": "stir", "name": "Stir", "type": "event",
	"effects": [{"op": "gain", "resource": "unrest", "amount": 1}]}
## A two-turn event with a renewal modifier: +1 card.
const REFORM := {"id": "reform", "name": "Reform", "type": "event", "discard": {"turns": 2}, "modifiers": {"renewal": 1}}
const EVENTS := [FAIR, ZEAL, STIR, REFORM]


## A game on TEST_CARDS, TEST_EVENTS, Fair and Zeal with the main deck {scout: 10} and event_deck, its event deck arranged
## order_top_first, 0 wealth; not started when start is false. overrides replace config keys.
func turn_start_engine(event_deck: Dictionary, order_top_first: Array = [], overrides := {}, start := true) -> GameEngine:
	var cards := fixture_db([FAIR, ZEAL], [TEST_EVENTS])
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var config := DataLoader.parse_config(raw_config({"scout": 10}, {"event_deck": event_deck}.merged(overrides, true)),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, config)
	if start:
		e.new_game(1)
		if not order_top_first.is_empty():
			arrange(e.zone("event_deck"), order_top_first)
		e.resources.wealth = 0
	return e


## An Anarchy game (anarchy_engine, block merged into the unrest block) with EVENTS and TEST_EVENTS loaded and
## event_deck arranged order_top_first.
func anarchy_events_engine(block: Dictionary, event_deck: Dictionary, order_top_first: Array) -> GameEngine:
	var e := anarchy_engine(block, {"event_deck": event_deck}, EVENTS + TEST_EVENTS)
	arrange(e.zone("event_deck"), order_top_first)
	return e


## Records each event_drawn as {turn, outcome}.
func record_draws(e: GameEngine) -> Array:
	var draws := []
	e.event_drawn.connect(func(outcome: Dictionary): draws.append({"turn": e.turn, "outcome": outcome}))
	return draws


# --- AC1: no event on turn 1 ---

func test_no_event_is_drawn_on_turn_1() -> void:
	var e := turn_start_engine({"windfall": 1, "trade_winds": 1, "omen": 1}, [], {}, false)
	var draws := record_draws(e)
	e.new_game(1)
	eq(e.turn, 1, "turn 1")
	eq(e.zone("active_events").size(), 0, "no active event")
	eq(e.zone("event_deck").size(), 3, "event deck untouched")
	eq(draws.size(), 0, "event_drawn not emitted")


# --- AC2: drawn as turn 2 starts, not in end_turn ---

func test_the_event_is_drawn_as_turn_2_starts() -> void:
	var e := turn_start_engine({"windfall": 1, "trade_winds": 1, "omen": 1}, ["windfall", "trade_winds", "omen"])
	var draws := record_draws(e)
	e.end_turn()
	eq(e.turn, 2, "turn 2")
	eq(card_ids(e.zone("active_events")), ["windfall"], "the former top event is active")
	eq(e.zone("event_deck").size(), 2, "one drawn")
	eq(draws.size(), 1, "event_drawn emitted once")
	if draws.size() == 1:
		eq(draws[0].turn, 2, "drawn once turn 2 started, not during turn 1's end")
		eq(draws[0].outcome.get("gained", {}), {"food": 2}, "Windfall's play resolved")


func test_end_turn_draws_nothing_before_the_hand_limit_discard() -> void:
	var e := turn_start_engine({"windfall": 1, "trade_winds": 1, "omen": 1}, ["windfall", "trade_winds", "omen"],
		{"hand_limit": 5})
	while e.zone("hand").size() <= e.config.hand_limit:
		put_in_hand(e, "scout")
	e.end_turn()
	eq(e.pending().get("kind", ""), GameEngine.PENDING_DISCARD, "stopped for the hand-limit discard")
	eq(e.zone("active_events").size(), 0, "nothing drawn yet")
	eq(e.zone("event_deck").size(), 3, "event deck untouched")
	check(e.discard_card(first_in_hand(e)), "discard should finish the turn")
	eq(card_ids(e.zone("active_events")), ["windfall"], "drawn as turn 2 starts")


# --- AC3: a one-turn event lasts through the turn it is drawn ---

func test_a_one_turn_event_is_active_through_its_turn_then_ends_at_the_next_upkeep() -> void:
	var e := turn_start_engine({"fair": 1, "omen": 1}, ["fair", "omen"])
	e.end_turn()
	var uid := uid_of(e.zone("active_events"), "fair")
	check(uid != -1, "Fair active during turn 2")
	eq(e.event_turns_left(uid), 1, "1 turn left during turn 2")
	eq(e.resources.wealth, 0, "its upkeep hasn't run yet")
	e.end_turn()
	eq(e.resources.wealth, 1, "turn 3's upkeep: Fair +1 wealth")
	eq(card_ids(e.zone("event_discard")), ["fair"], "Fair discarded at turn 3's upkeep")
	eq(card_ids(e.zone("active_events")), ["omen"], "turn 3's event drawn after Fair ended")


# --- AC4: modifiers apply for every turn the event lasts ---

func test_an_events_modifier_applies_every_turn_it_lasts() -> void:
	var e := turn_start_engine({"zeal": 1, "omen": 2}, ["zeal", "omen", "omen"])
	var seen := []
	for turn in 3:
		e.end_turn()
		seen.append(e.modifier(Modifiers.ACTIONS))
	eq(seen, [1, 1, 0], "Zeal's +1 action during turns 2 and 3, not 4")


# --- AC5: an unrest event warns a turn before Anarchy ---

func test_an_unrest_event_reaching_the_limit_lets_the_turn_play_before_anarchy() -> void:
	var e := anarchy_events_engine({}, {"stir": 1, "omen": 2}, ["stir", "omen", "omen"])
	e.resources["unrest"] = 4
	e.end_turn()
	eq(e.resources.get("unrest"), 5, "Stir brought unrest to Chiefs' limit 5")
	eq(ruling(e), "chiefs", "no Anarchy on the turn Stir is drawn")
	e.end_turn()
	check(e.anarchy() != -1, "still at the limit as turn 3 starts: Anarchy falls")


# --- AC6: under Anarchy the event is drawn too (the drain went in 384, renewal's wait in 385) ---

func test_an_event_drawn_under_anarchy_joins_it() -> void:
	for top in ["windfall", "omen"]:
		var e := anarchy_events_engine({"renewal": 1}, {"windfall": 1, "omen": 1},
			[top, "windfall" if top == "omen" else "omen"])
		for id in ["farm", "scout", "farm"]:
			put_in(e, id, "discard")
		e.resources["unrest"] = 5
		e.end_turn()
		check(e.anarchy() != -1, "%s game: Anarchy fell at turn 2's start" % top)
		eq(card_ids(e.zone("active_events")), ["anarchy", top], "%s game: the event is active beside Anarchy (253)" % top)


## 385 AC3: an event drawn this turn with a renewal modifier raises this turn's renewals.
func test_an_event_drawn_this_turn_raises_this_turns_renewals() -> void:
	var e := anarchy_events_engine({"renewal": 1}, {"reform": 1, "omen": 1}, ["reform", "omen"])
	for id in ["farm", "scout", "farm"]:
		put_in(e, id, "discard")
	e.resources["unrest"] = 5
	e.end_turn()
	eq(card_ids(e.zone("active_events")), ["anarchy", "reform"], "Reform active beside Anarchy (253)")
	eq(e.pending(), {}, "nothing owed")
	eq(e.renewals_left(), 2, "1 + Reform's 1")


# --- AC7: the final turn draws nothing ---

func test_the_final_turn_draws_no_event() -> void:
	var e := turn_start_engine({"windfall": 1, "trade_winds": 1, "omen": 1}, ["trade_winds", "windfall", "omen"],
		{"turn_limit": 1})
	e.end_turn()
	check(e.is_over, "game over")
	eq(e.zone("active_events").size(), 0, "no event drawn")
	eq(e.zone("event_deck").size(), 3, "event deck untouched")


# --- AC8: Anarchy burning out ---

func test_anarchy_burning_out_draws_the_next_event_once_the_government_is_chosen() -> void:
	var e := anarchy_events_engine({"anarchy_turns": 1}, {"omen": 3}, [])
	e.resources["unrest"] = 5
	e.end_turn()
	check(e.anarchy() != -1, "Anarchy fell at turn 2's start")
	var deck_size: int = e.zone("event_deck").size()
	e.end_turn()  # its 1 turn ends
	eq(e.pending().get("kind", ""), GameEngine.PENDING_GOVERNMENT, "the government choice is owed")
	eq(e.zone("event_deck").size(), deck_size, "no event drawn while the choice is owed")
	check(e.choose_government(uid_of(e.zone("governments"), "chiefs")), "choose Chiefs")
	eq(e.turn, 3, "turn 3 started")
	eq(e.zone("event_deck").size(), deck_size - 1, "exactly one event drawn")
