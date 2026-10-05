extends "res://tests/lib/tech_case.gd"
## Ending the turn returns to the Realm (290) in the real main scene: the Knowledge screen and a territory view close
## when the turn moves on, whether by the End turn key or E, and stay open otherwise. Hooks: main.territory_view.nav
## (the play area's navigator: the Realm at its root), main.knowledge, main.territory_view, main.sidebar.end_turn.


## Runs body(main) via with_main on a game with Pottery and Writing to learn (so Knowledge opens), Grassland and Hills
## to explore, deck and overrides. Use with await.
func with_board(body: Callable, deck := {"farm": 10}, overrides := {}) -> void:
	await with_main(tech_engine(["pottery", "writing"], deck,
		{"territory_deck": {"grassland": 1, "hills": 1}}.merged(overrides)), body)


## Ends the turn the way named: "key" presses the End turn key, "e" presses E.
func end_turn_by(main: Node, way: String) -> void:
	if way == "key":
		(main.sidebar.end_turn as Button).pressed.emit()
	else:
		main.get_viewport().gui_release_focus()
		press_key(main, KEY_E)
	await wait_frames()


## Checks that only the Realm is on the play area's navigator.
func check_realm_only(main: Node, what: String) -> void:
	eq(main.territory_view.nav.depth(), 1, "%s: the Realm is the only screen" % what)
	check(not main.knowledge.is_open(), "%s: Knowledge closed" % what)
	check(not main.territory_view.is_open(), "%s: territory view closed" % what)
	eq(main.territory_view.uid, -1, "%s: no territory shown" % what)
	check(main.tableau.is_visible_in_tree(), "%s: the Realm shows" % what)


func open_territory(main: Node) -> void:
	var view: CardView = main.views[home_uid(Game.engine)]
	view.details_requested.emit(view)
	await wait_frames()
	check(main.territory_view.is_open(), "precondition: the territory view is open")


func open_knowledge(main: Node) -> void:
	main.knowledge.open()
	await wait_frames()
	check(main.knowledge.is_open(), "precondition: Knowledge is open")


# --- AC1: from the Knowledge screen ---

func test_ending_the_turn_from_knowledge_returns_to_the_realm() -> void:
	for way in ["key", "e"]:
		await with_board(func(main: Node):
			await open_knowledge(main)
			var turn := Game.engine.turn
			await end_turn_by(main, way)
			eq(Game.engine.turn, turn + 1, "%s: the turn ended" % way)
			check_realm_only(main, way))


# --- AC2: from a territory view ---

func test_ending_the_turn_from_a_territory_view_returns_to_the_realm() -> void:
	for way in ["key", "e"]:
		await with_board(func(main: Node):
			await open_territory(main)
			var turn := Game.engine.turn
			await end_turn_by(main, way)
			eq(Game.engine.turn, turn + 1, "%s: the turn ended" % way)
			check_realm_only(main, way))


# --- AC3: Knowledge over a territory view ---

func test_ending_the_turn_from_knowledge_over_a_territory_view_closes_both() -> void:
	await with_board(func(main: Node):
		await open_territory(main)
		await open_knowledge(main)
		eq(main.territory_view.nav.depth(), 3, "precondition: Realm, territory, Knowledge")
		await end_turn_by(main, "key")
		check_realm_only(main, "both"))


# --- AC4: a refused end turn leaves the screen open ---

func test_a_refused_end_turn_leaves_the_open_screen() -> void:
	await with_board(func(main: Node):
		var e := Game.engine
		await open_territory(main)
		check(e.play_card(first_in_hand(e)), "play Explorer: a territory choice is owed")
		await wait_frames()
		check(e.end_turn_error() != "", "precondition: the turn can't end")
		var depth: int = main.territory_view.nav.depth()
		var turn := e.turn
		await end_turn_by(main, "key")
		eq(e.turn, turn, "the turn didn't end")
		eq(main.territory_view.nav.depth(), depth, "the screens stay")
		check(main.territory_view.is_open(), "the territory view stays open"), {"explorer": 10})


# --- AC5: on the Realm already ---

func test_ending_the_turn_on_the_realm_stays_on_the_realm() -> void:
	await with_board(func(main: Node):
		var turn := Game.engine.turn
		await end_turn_by(main, "key")
		eq(Game.engine.turn, turn + 1, "the turn ended")
		check_realm_only(main, "realm"))


# --- AC6: within the turn the view stays ---

func test_a_refresh_within_the_turn_leaves_the_territory_view_open() -> void:
	await with_board(func(main: Node):
		var e := Game.engine
		await open_territory(main)
		e.resources.wealth = 10
		check(e.buy("scout"), "buy a Scout")
		await wait_frames()
		check(main.territory_view.is_open(), "still open after a buy")
		eq(main.territory_view.nav.depth(), 2, "Realm and the territory"), {"farm": 10},
		{"supply": {"scout": {"price": 2, "count": 2}}})
