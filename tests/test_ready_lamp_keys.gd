extends "res://tests/lib/tech_case.gd"
## The ready lamps on the Knowledge and Buy Cards keys (288) in the real main scene: lit exactly when the engine's
## tech_lamp() / supply_lamp() is, and opening or closing the Knowledge screen or the Supply sees what is on offer.
## TopBar's hooks: knowledge_lamp_lit(), supply_lamp_lit().


## A tech game for with_main: Pottery (2) and Bronze Working (5) in the research deck, Scout (2) and Temple (3) in the
## supply, starting with the given insight and wealth.
func keys_engine(insight: int, wealth: int) -> GameEngine:
	return tech_engine(["pottery", "bronze"], {"farm": 10}, {
		"supply": {"scout": {"price": 2, "count": 2}, "temple": {"price": 3, "count": 2}},
		"starting": {"resources": {"food": 2, "wealth": wealth, "insight": insight}, "tableau": ["capital"],
			"territory": "homeland"}})


## main's top bar.
func top_bar(main: Node) -> Object:
	return main.find_children("*", "HBoxContainer", true, false).filter(func(n): return n is TopBar)[0]


## Game.engine, typed Object for the red phase.
func engine() -> Object:
	return Game.engine


## Sets resource to amount and has main show it.
func give(main: Node, resource: String, amount: int) -> void:
	Game.engine.resources[resource] = amount
	Game.engine.changed.emit()
	await wait_frames()


# --- AC7: the keys show the engine's lamps ---

func test_the_keys_lamps_follow_the_engine() -> void:
	await with_main(keys_engine(2, 0), func(main: Node):
		var bar := top_bar(main)
		check(engine().tech_lamp(), "precondition: a tech is learnable")
		check(bar.knowledge_lamp_lit(), "Knowledge lit with the engine")
		check(not bar.supply_lamp_lit(), "Buy Cards dark: nothing buyable")
		await give(main, GameEngine.WEALTH, 2)
		check(bar.supply_lamp_lit(), "Buy Cards lit once Scout is buyable"))


func test_opening_knowledge_sees_the_techs_and_puts_its_lamp_out() -> void:
	await with_main(keys_engine(2, 0), func(main: Node):
		main.knowledge.open()
		await wait_frames()
		check(not engine().tech_lamp(), "opening Knowledge saw the techs")
		check(not top_bar(main).knowledge_lamp_lit(), "Knowledge dark"))


func test_closing_knowledge_sees_what_became_learnable_while_it_was_open() -> void:
	await with_main(keys_engine(2, 0), func(main: Node):
		main.knowledge.open()
		await wait_screen_transition()
		await give(main, GameEngine.INSIGHT, 5)
		check(engine().tech_lamp(), "precondition: Bronze Working became learnable while open")
		main.knowledge.close()
		await wait_screen_transition()
		check(not engine().tech_lamp(), "closing Knowledge saw it")
		check(not top_bar(main).knowledge_lamp_lit(), "Knowledge dark"))


func test_opening_the_supply_sees_the_piles_and_puts_its_lamp_out() -> void:
	await with_main(keys_engine(0, 2), func(main: Node):
		check(top_bar(main).supply_lamp_lit(), "precondition: Buy Cards lit")
		main.open_supply()
		await wait_frames()
		check(not engine().supply_lamp(), "opening the Supply saw the piles")
		check(not top_bar(main).supply_lamp_lit(), "Buy Cards dark"))


func test_closing_the_supply_sees_what_became_buyable_while_it_was_open() -> void:
	await with_main(keys_engine(0, 2), func(main: Node):
		main.open_supply()
		await wait_frames()
		await give(main, GameEngine.WEALTH, 3)
		check(engine().supply_lamp(), "precondition: Temple became buyable while open")
		main.supply.close()
		await wait_frames()
		check(not engine().supply_lamp(), "closing the Supply saw it")
		check(not top_bar(main).supply_lamp_lit(), "Buy Cards dark"))
