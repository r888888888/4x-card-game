extends "res://tests/lib/raid_case.gd"
## The raid modal (backlog 271): a raid that strikes opens a modal in the real main scene with its card and what
## happened, above the turn's event, and plays its sound. Hooks: main.raid_modal() is the open raid modal's {uid, id,
## repelled, result, title, context}, {} while closed; main.raid_modal_ok_button() is its OK.


## Runs body(main) on main showing a raid_engine game (overrides) started again on seed 1 and set up as raid_engine's,
## Raiders then Omens on top of the event deck.
func with_raid_main(body: Callable, overrides := {}) -> void:
	var e := raid_engine(["raiders"], {"raiders": 1, "horde": 1, "omen": 3}, overrides)
	await with_main(e, func(main: Node):
		raid_setup(Game.engine, ["raiders", "omen", "omen", "omen"])
		Game.engine.changed.emit()
		await body.call(main))


## Ends turns until Raiders has 1 turn left (turn 3), closing every modal on the way.
func to_the_eve_of_the_strike(main: Node) -> void:
	Game.engine.end_turn()
	Game.engine.end_turn()
	main.modals.close_all()


# --- AC2: the modal ---

func test_a_pillaging_raid_opens_its_modal() -> void:
	await with_raid_main(func(main: Node):
		to_the_eve_of_the_strike(main)
		var raid := active_uid(Game.engine, "raiders")
		var outcomes := record_raids(Game.engine)
		Game.engine.end_turn()
		var m: Dictionary = main.raid_modal()
		check(not m.is_empty(), "the raid modal is open")
		if m.is_empty() or outcomes.size() != 1:
			return
		eq([m.get("uid"), m.get("id"), m.get("repelled")], [raid, "raiders", false], "uid, id, pillaged")
		eq(m.get("result"), Game.engine.raid_outcome_text(outcomes[0]), "the result line")
		check(String(m.get("result", "")).contains("pillaged"), "says pillaged: %s" % m.get("result"))
		eq([m.get("title"), m.get("context")], ["Raiders", "Turn 4"], "title and context")
		eq(main.get_viewport().gui_get_focus_owner(), main.raid_modal_ok_button(), "OK focused"))


func test_a_repelled_raid_opens_its_modal() -> void:
	await with_raid_main(func(main: Node):
		Game.engine.end_turn()
		build_on(Game.engine, hills_of(Game.engine), ["town"])
		recruit(Game.engine, hills_of(Game.engine))
		Game.engine.end_turn()
		main.modals.close_all()
		Game.engine.end_turn()
		var m: Dictionary = main.raid_modal()
		eq(m.get("repelled"), true, "repelled")
		check(String(m.get("result", "")).contains("repelled"), "says repelled: %s" % m.get("result")))


# --- AC3: above the turn's event ---

func test_the_raid_modal_sits_above_the_turns_event() -> void:
	for way in ["ok", "enter", "esc"]:
		await with_raid_main(func(main: Node):
			to_the_eve_of_the_strike(main)
			Game.engine.end_turn()
			eq(main.raid_modal().get("id", ""), "raiders", "%s: the raid modal" % way)
			eq(main.event_modal().get("id", ""), "omen", "%s: the turn's event under it" % way)
			match way:
				"ok": main.raid_modal_ok_button().pressed.emit()
				"enter": press_key(main, KEY_ENTER)
				"esc": press_key(main, KEY_ESCAPE)
			eq(main.raid_modal(), {}, "%s closes the raid modal" % way)
			eq(main.event_modal().get("id", ""), "omen", "%s: the event is still open" % way))


# --- AC5: the era sheet ---

func test_the_raid_modal_waits_for_the_era_sheet() -> void:
	await with_reduce_motion(true, func():
		await with_raid_main(func(main: Node):
			to_the_eve_of_the_strike(main)
			Game.engine.resources[GameEngine.WEALTH] = 50
			Game.engine.end_turn()
			await wait_frames()
			check(main.era_sheet.is_open(), "the sheet first")
			eq(main.raid_modal(), {}, "the raid waits")
			press_key(main, KEY_ENTER)
			await (Engine.get_main_loop() as SceneTree).create_timer(0.25).timeout
			eq(main.raid_modal().get("id", ""), "raiders", "then the raid opens"),
			{"era_unlocks": {"2": {"wealth": 50}}}))



# --- AC4: its sound ---

const PILLAGED := &"ui.milestone.pillaged"
const REPELLED := &"ui.milestone.repelled"
const EVENT_SOUNDS := [PILLAGED, REPELLED, Sfx.MILESTONE_BREAKTHROUGH, Sfx.MILESTONE_CITY, Sfx.MILESTONE_ERA]


func events_heard(main: Node) -> Array:
	return main.sfx.played().filter(func(r): return EVENT_SOUNDS.has(r.token)).map(func(r): return r.token)


func test_the_raid_sounds_are_level_3_with_their_files() -> void:
	for token in [PILLAGED, REPELLED]:
		eq(Sfx.level(token), 3, "%s is Level 3" % token)
		eq(Sfx.bus(token), Settings.GAME, "%s on the Game bus" % token)
		var path := "res://assets/sounds/events/%s.wav" % String(token).replace(".", "_")
		check(ResourceLoader.exists(path), "%s exists" % path)


func test_a_pillaging_raid_plays_the_pillaged_sound() -> void:
	await with_raid_main(func(main: Node):
		to_the_eve_of_the_strike(main)
		await wait_frames()
		main.sfx.set_clock(0.0)
		Game.engine.end_turn()
		eq(events_heard(main), [PILLAGED], "pillaged"))


func test_a_repelled_raid_plays_the_repelled_sound() -> void:
	await with_raid_main(func(main: Node):
		Game.engine.end_turn()
		build_on(Game.engine, hills_of(Game.engine), ["town"])
		recruit(Game.engine, hills_of(Game.engine))
		Game.engine.end_turn()
		main.modals.close_all()
		await wait_frames()
		main.sfx.set_clock(0.0)
		Game.engine.end_turn()
		eq(events_heard(main), [REPELLED], "repelled"))


func test_a_raid_outranks_a_city_but_not_an_era() -> void:
	var order: Array = EventSounds.SOUNDS.map(func(pair): return pair[1])
	eq(order, [Sfx.MILESTONE_ERA, PILLAGED, REPELLED, Sfx.MILESTONE_CITY, Sfx.MILESTONE_BREAKTHROUGH],
		"era > pillaged > repelled > city > tech")
