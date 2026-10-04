extends "res://tests/lib/anarchy_case.gd"
## The government choice's default (backlog 254): the config's starting government when it's in the government deck,
## else the deck's first card; pending() lists the default first and the overlay focuses it. Fixtures:
## tests/lib/anarchy_case.gd (Chiefs, the starting government; Kings, limit 7).


## A game whose Anarchy has just burnt out, with Kings created into the government deck before Chiefs fell after it
## (the deck: Kings, Chiefs); the government choice is owed.
func kings_first_engine(overrides := {}) -> GameEngine:
	var e := anarchy_engine({}, overrides)
	e.create_card("kings", "discard", null)
	e.resources["unrest"] = 5
	e.end_turn()  # falls into Anarchy at turn 2's start: Chiefs goes in after Kings
	for i in 4:
		e.end_turn()  # 4 counters: burns out
	return e


# --- AC1: the starting government is the default, listed first ---

func test_the_default_government_is_the_starting_one_listed_first() -> void:
	var e := kings_first_engine()
	eq(card_ids(e.zone("governments")), ["kings", "chiefs"] as Array[String], "precondition: deck order Kings, Chiefs")
	var chiefs := uid_of(e.zone("governments"), "chiefs")
	var kings := uid_of(e.zone("governments"), "kings")
	eq(e.default_government(), chiefs, "Chiefs, the starting government")
	eq(e.pending().get("options"), [chiefs, kings], "the default first, the rest in deck order")


# --- AC2: without the starting government, the deck's first ---

func test_without_a_starting_government_the_default_is_the_decks_first() -> void:
	var e := anarchy_engine({}, {"starting": {"resources": {"food": 10, "wealth": 10, "insight": 10},
		"tableau": ["capital"], "territory": "homeland"}})
	put_in(e, "chiefs", "government")
	e.create_card("kings", "discard", null)
	e.resources["unrest"] = 5
	e.end_turn()
	for i in 4:
		e.end_turn()
	var kings := uid_of(e.zone("governments"), "kings")
	eq(e.pending().get("kind"), GameEngine.PENDING_GOVERNMENT, "precondition: the choice is owed")
	eq(e.default_government(), kings, "Kings, first in the deck")
	eq(e.pending().get("options")[0], kings, "listed first")


# --- AC3: no choice owed ---

func test_with_no_choice_owed_there_is_no_default_government() -> void:
	var e := anarchy_engine()
	eq(e.default_government(), -1, "no choice owed")
	e.resources["unrest"] = 5
	e.end_turn()
	eq(e.default_government(), -1, "nor under Anarchy")


# --- the overlay ---

func test_the_government_overlay_lists_and_focuses_the_default_first() -> void:
	await with_main(anarchy_engine(), func(main: Node):
		var e := Game.engine
		e.create_card("kings", "discard", null)
		e.resources["unrest"] = 5
		e.end_turn()
		for i in 4:
			e.end_turn()
		await (Engine.get_main_loop() as SceneTree).create_timer(0.6).timeout  # behind the cabinet doors (209)
		var row: Node = main.choices.get("government_row")
		var in_row: Array = main.views_in(row).map(func(v): return v.uid)
		var chiefs := uid_of(e.zone("governments"), "chiefs")
		eq(in_row.front() if not in_row.is_empty() else -1, chiefs, "Chiefs first in the row")
		check(main.focus.focused != null and main.focus.focused.uid == chiefs, "Chiefs has the card focus"))
