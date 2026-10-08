extends "res://tests/lib/tech_case.gd"
## Event sounds (191) in the real main.tscn, its sound clock frozen: the engine's milestones play their Level 3 sound
## (only the highest of one action), the game-over sheet plays the closing ceremony once, routine system sounds of the
## same action stay silent while it plays, and the Game bus ignores the Interface sounds key.

const ERA_CARDS := [
	{"id": "philosophy", "name": "Philosophy", "type": "tech", "cost": {"insight": 3},
	 "effects": [{"op": "add_era", "era": 2}]},
	{"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2},
	{"id": "astronomy", "name": "Astronomy", "type": "tech", "cost": {"insight": 5}, "era": 2},
]
const EVENTS := [Sfx.MILESTONE_BREAKTHROUGH, Sfx.MILESTONE_CITY, Sfx.MILESTONE_ERA, Sfx.MILESTONE_VICTORY]


## A game whose research deck holds the era-1 techs ids, era 2 waiting.
func era_engine(ids: Array) -> GameEngine:
	var counts := {"optics": 1, "astronomy": 1}
	for id in ids:
		counts[id] = counts.get(id, 0) + 1
	return tech_engine(ids, {"farm": 10}, {"research_deck": counts}, ERA_CARDS)


## Runs body(main) on main showing engine's game (started on seed 1), insight 20, its sound clock at 0.
func with_game_of(engine: GameEngine, body: Callable) -> void:
	await with_main(engine, func(main: Node):
		Game.engine.resources[GameEngine.INSIGHT] = 20
		Game.engine.changed.emit()
		await wait_frames()
		main.sfx.set_clock(0.0)
		await body.call(main))


func events_heard(main: Node, from := 0) -> Array:
	return main.sfx.played().slice(from).filter(func(r): return EVENTS.has(r.token)).map(func(r): return r.token)


# --- AC3: the board plays them, the highest only ---

func test_learning_a_tech_plays_the_breakthrough() -> void:
	await with_game_of(era_engine(["pottery", "writing"]), func(main: Node):
		check(Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery")), "learn Pottery")
		eq(events_heard(main), [Sfx.MILESTONE_BREAKTHROUGH], "the breakthrough")
		eq(main.sfx.played().filter(func(r): return r.token == Sfx.MILESTONE_BREAKTHROUGH).map(func(r): return r.bus),
			[Settings.GAME], "on the Game bus"))


func test_settling_plays_the_city() -> void:
	var e := make_engine({"pioneer": 10}, {"territory_deck": {"hills": 1}})
	await with_game_of(e, func(main: Node):
		to_frontier(Game.engine, ["hills"])
		Game.engine.resources.food = 3
		Game.engine.changed.emit()
		await wait_frames()
		check(Game.engine.play_card(first_in_hand(Game.engine)), "settle the Hills")
		eq(events_heard(main), [Sfx.MILESTONE_CITY], "the city"))


func test_a_tech_that_adds_an_era_plays_only_the_era() -> void:
	await with_game_of(era_engine(["philosophy", "pottery"]), func(main: Node):
		check(Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "philosophy")), "learn Philosophy")
		eq(events_heard(main), [Sfx.MILESTONE_ERA], "era over tech"))


# --- AC4: the game-over sheet ---

func test_the_game_over_sheet_plays_the_victory_once() -> void:
	var e := make_engine({"farm": 10}, {"turn_limit": 2})
	await with_game_of(e, func(main: Node):
		Game.engine.end_turn()
		Game.engine.end_turn()
		check(Game.engine.is_over, "the game is over")
		await wait_frames()
		eq(events_heard(main), [Sfx.MILESTONE_VICTORY], "the closing ceremony")
		Game.engine.changed.emit()
		await wait_frames()
		eq(events_heard(main), [Sfx.MILESTONE_VICTORY], "a refresh while shown: nothing more")
		MainProbe.game_over_buttons(main)[0].pressed.emit()  # Replay
		await wait_frames()
		eq(events_heard(main), [Sfx.MILESTONE_VICTORY], "restarting: nothing more"))


# --- AC5: the event isn't talked over ---

func test_while_an_event_plays_its_actions_routine_sounds_stay_silent() -> void:
	await with_reduce_motion(false, func():
		await with_game_of(era_engine(["philosophy", "pottery"]), func(main: Node):
			var notices := [0]
			Game.engine.noticed.connect(func(_m, _p): notices[0] += 1)
			check(Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "philosophy")), "learn Philosophy")
			check(notices[0] >= 1, "the era's notices: %d" % notices[0])
			var heard: Array = main.sfx.played().map(func(r): return r.token)
			check(heard.has(Sfx.MILESTONE_ERA), "the era: %s" % [heard])
			check(not heard.any(func(t): return Sfx.NOTIFICATIONS.has(t)), "no notification: %s" % [heard])
			check(not heard.any(func(t): return [Sfx.COUNTER_TICK, Sfx.RESOURCE_GAIN, Sfx.RESOURCE_LOSS].has(t)),
				"no counter: %s" % [heard])
			eq(main.sfx.play(Sfx.BUTTON_PRESS, 0.1, true), true, "a press during it still clicks")))


# --- AC6: the Game bus ---

func test_event_sounds_ignore_the_interface_key_but_not_the_game_volume() -> void:
	await with_temp_settings(func():
		Settings.set_interface_sounds(false)
		var game_bus := AudioServer.get_bus_index(Settings.GAME)
		await with_game_of(era_engine(["pottery", "writing"]), func(main: Node):
			check(Game.engine.buy_tech(uid_of(Game.engine.zone("research_deck"), "pottery")), "learn Pottery")
			eq(events_heard(main), [Sfx.MILESTONE_BREAKTHROUGH], "it plays")
			eq(AudioServer.is_bus_mute(game_bus), false, "on a Game bus that is still on")
			Settings.set_volume(Settings.GAME, 0)
			eq(AudioServer.is_bus_mute(game_bus), true, "the Game volume at 0 silences it")))
