extends "res://tests/lib/test_case.gd"
## Event decks that escalate by era (backlog 074): an event may have an era; later-era events wait in future_events
## and are shuffled into the event deck when their era is added. Fixture: TEST_EVENTS (era 1) plus two local era-2
## events, Raid and Blight.

const ERA_2_EVENTS := [
	{"id": "raid", "name": "Raid", "type": "event", "era": 2},
	{"id": "blight", "name": "Blight", "type": "event", "era": 2},
]
const DECK := {"windfall": 1, "trade_winds": 1, "omen": 1, "raid": 1, "blight": 1}


## TEST_CARDS + TEST_EVENTS + ERA_2_EVENTS, parsed.
func era_db(errors: Array[String] = [], warnings: Array[String] = []) -> Dictionary:
	return DataLoader.parse_cards({"cards": TEST_CARDS.cards + TEST_EVENTS + ERA_2_EVENTS}, resources(), "cards.json",
		errors, warnings, keywords())


## A game with event_deck DECK (or event_deck), main deck {scout: 10}; overrides replace config keys.
func event_era_engine(overrides := {}, event_deck := DECK, seed_value := 1) -> GameEngine:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := era_db(errors, warnings)
	var parsed := DataLoader.parse_config(raw_config({"scout": 10}, {"event_deck": event_deck}.merged(overrides, true)),
		resources(), cards, "test", errors, warnings)
	check(errors.is_empty(), "test data should load: %s" % [errors])
	var e := GameEngine.new(cards, parsed)
	e.new_game(seed_value)
	return e


# --- AC1: loader ---

func test_an_event_may_have_an_era() -> void:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var cards := era_db(errors, warnings)
	eq(errors, [] as Array[String], "errors")
	eq(warnings, [] as Array[String], "no 'only applies to techs' warning for an event's era")
	eq(cards.raid.era, 2, "Raid's era")
	eq(cards.windfall.era, 1, "era defaults to 1")


func test_event_era_validation() -> void:
	var load_event := func(fields: Dictionary) -> Dictionary:
		var errors: Array[String] = []
		var warnings: Array[String] = []
		var x := {"id": "x", "name": "X", "type": "event"}
		x.merge(fields, true)
		DataLoader.parse_cards({"cards": [x]}, resources(), "cards.json", errors, warnings, keywords())
		return {"errors": errors, "warnings": warnings}
	check_cases([
		["era 0", {"era": 0}, "cards.json: card 'x': era: must be an integer >= 1"],
		["era not an integer", {"era": "two"}, "cards.json: card 'x': era: must be an integer >= 1"],
	], load_event)


# --- AC2: setup ---

func test_later_era_events_wait_in_future_events() -> void:
	var e := event_era_engine()
	eq(sorted(card_ids(e.zone("event_deck"))), ["omen", "trade_winds", "windfall"], "era-1 events in the deck")
	eq(sorted(card_ids(e.zone("future_events"))), ["blight", "raid"], "era-2 events wait")


# --- AC3: era added ---

func test_adding_era_2_shuffles_its_events_into_the_event_deck_once() -> void:
	var e := event_era_engine()
	e.end_turn()  # draws one era-1 event
	var active := card_ids(e.zone("active_events"))
	var discard := card_ids(e.zone("event_discard"))
	var era_1_left := sorted(card_ids(e.zone("event_deck")))
	e.add_era(2)
	eq(card_ids(e.zone("future_events")), [] as Array[String], "none wait any more")
	var deck := card_ids(e.zone("event_deck"))
	eq(sorted(deck), sorted(era_1_left + ["raid", "blight"]), "era-1 events stay; era-2 events join them")
	eq(card_ids(e.zone("active_events")), active, "active events stay")
	eq(card_ids(e.zone("event_discard")), discard, "the event discard stays")
	e.add_era(2)
	eq(card_ids(e.zone("event_deck")), deck, "adding era 2 again changes nothing")


## Backlog 116: an era's events added is a notice.
func test_an_eras_events_added_is_a_notice() -> void:
	var e := event_era_engine()
	var recorded := record_messages(e)
	e.add_era(2)
	check_noticed(recorded, "events added to the event deck", GameEngine.NOTICE_INFO)


func test_era_2_events_are_shuffled_in_by_seed() -> void:
	var orders := []
	for i in 2:
		var e := event_era_engine()
		check(not card_ids(e.zone("event_deck")).has("raid"), "Raid isn't in the deck before era 2")
		e.add_era(2)
		orders.append(card_ids(e.zone("event_deck")))
	check(orders[0].has("raid") and orders[0].has("blight"), "the era-2 events joined the deck: %s" % [orders[0]])
	eq(orders[0], orders[1], "same seed, same order")


func test_an_era_unlocks_threshold_adds_the_era_2_events() -> void:
	var e := event_era_engine({"era_unlocks": {"2": {"wealth": 5}}})
	e.resources.wealth = 5
	e.end_turn()  # the next turn's start checks the thresholds
	eq(e.era(), 2, "era 2 reached")
	eq(card_ids(e.zone("future_events")), [] as Array[String], "the era-2 events left future_events")
	var everywhere: Array[String] = []
	for z in ["event_deck", "active_events", "event_discard"]:
		everywhere.append_array(card_ids(e.zone(z)))
	check(everywhere.has("raid") and everywhere.has("blight"), "Raid and Blight are in play: %s" % [everywhere])


# --- AC4: panel ---

## The event info label's tooltip in the real main scene, on event_era_engine's game with event_deck.
func event_tooltip(event_deck: Dictionary) -> String:
	var real := Game.engine
	Game.engine = event_era_engine({}, event_deck)
	var main := open_main()
	main.start_game(1)
	var tooltip: String = main.event_panel().tooltip
	close_main(main)
	Game.engine = real
	return tooltip


## Backlog 122: the tooltip no longer says how many events wait for a later era (was 039 AC4).
func test_event_tooltip_names_no_events_waiting_for_a_later_era() -> void:
	var base := "One event is drawn at the start of each turn from turn 2. It stays active until its turns run out."
	eq(event_tooltip(DECK), base, "two waiting: not said")
	eq(event_tooltip({"windfall": 1, "raid": 1}), base, "one waiting: not said")
	eq(event_tooltip({"windfall": 1, "omen": 1}), base, "none waiting")