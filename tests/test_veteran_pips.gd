extends "res://tests/lib/raid_case.gd"
## Veteran pips (388): a unit's card in the territory view shows a row of config veteran_max pips, the first
## e.military.veteran_pips().filled tinted Palette.UNIT and the rest a dim UNIT (alpha CardView.PIP_DIM); none when
## veteran_max is 0 or the card isn't a unit. A counter a raid gives lights as a tally once the raid modal closes: one
## pip per promoted unit, 60 ms apart in tableau order, each with a ui.counter.tick (lit at once with Reduce motion,
## still one tick each). Hook: CardView.veteran_pips(), each pip's tint ([] with no row).

const VETERANS := {"veteran_max": 2}
const LIT := "lit"
const DIM := "dim"


## Runs body(main) on raid_engine's game (Raiders on top, aimed at Hills) with overrides, started in a real main scene.
func with_garrison_main(body: Callable, overrides := VETERANS) -> void:
	var e := raid_engine(["raiders", "omen", "omen", "omen"], {"raiders": 1, "omen": 3}, overrides)
	await with_main(e, func(main: Node):
		raid_setup(Game.engine, ["raiders", "omen", "omen", "omen"])
		await body.call(main))


## Turn 2: Raiders announced at Hills (at 4 pop, workers for all), a Town there and count Levies recruited on it
## (enough to repel). Their uids.
func garrison(count := 1) -> Array[int]:
	var e := Game.engine
	e.end_turn()
	e.zone("tableau").find(hills_of(e)).pop = 4
	build_on(e, hills_of(e), ["town"])
	var out: Array[int] = []
	for i in count:
		var levy := put_in_hand(e, "levy")
		check(e.play_card(levy, hills_of(e)), "Levy recruited: %s" % e.play_error(levy, hills_of(e)))
		out.append(levy)
	return out


## Opens Hills' territory view, the board caught up.
func open_hills(main: Node) -> void:
	Game.engine.changed.emit()
	await wait_frames()
	main.territory_view.open(hills_of(Game.engine))
	await wait_frames()


## Each pip on card uid's view as LIT or DIM ([] with no row). Red phase: the hook is new in 388.
func pips(main: Node, uid: int) -> Array:
	var view: CardView = main.views.get(uid)
	check(view != null, "card %d has a view" % uid)
	if view == null:
		return []
	var tints: Array = (view as Object).call("veteran_pips")  # scaffolding: veteran_pips is new in 388
	var dim := Palette.UNIT
	dim.a = 0.35
	return tints.map(func(c: Color): return LIT if c.is_equal_approx(Palette.UNIT) else DIM if c.is_equal_approx(dim) else c)


func test_a_units_card_shows_its_counters_filled_out_of_the_cap() -> void:
	await with_garrison_main(func(main: Node):
		var levies := garrison(2)
		Game.engine.zone("tableau").find(levies[0]).counters = 1
		await open_hills(main)
		eq(pips(main, levies[0]), [LIT, DIM], "1 counter: one lit, one dim")
		eq(pips(main, levies[1]), [DIM, DIM], "a fresh Levy: two dim"))


func test_no_pips_without_veterans_or_on_a_card_that_isnt_a_unit() -> void:
	await with_garrison_main(func(main: Node):
		var levy: int = garrison()[0]
		await open_hills(main)
		eq(pips(main, levy), [], "veteran_max 0: no row"), {"veteran_max": 0})
	await with_garrison_main(func(main: Node):
		garrison()
		await open_hills(main)
		eq(pips(main, uid_of(Game.engine.zone("tableau"), "town")), [], "a Town: no row"))


## Ends turns until the Raiders strikes, then opens Hills' view under the raid modal (a turn's end closes the view).
func strike(main: Node) -> void:
	var e := Game.engine
	var raid := active_uid(e, "raiders")
	for i in e.military.raid_turns_left(raid) - 1:
		e.end_turn()
		main.modals.close_all()
	e.end_turn()
	await wait_frames()
	await open_hills(main)


## Presses the raid modal's OK with the sound clock frozen at 0; returns how many sounds had played before.
func close_raid(main: Node) -> int:
	main.sfx.set_clock(0.0)
	var before: int = main.sfx.played().size()
	MainProbe.raid_modal_ok_button(main).pressed.emit()
	return before


## The counter ticks played since index from, at their times.
func ticks(main: Node, from: int) -> Array:
	return main.sfx.played().slice(from).filter(func(r): return r.token == Sfx.COUNTER_TICK) \
		.map(func(r): return snappedf(r.at, 0.001))


func test_a_repelled_raids_counter_lights_once_the_modal_closes_as_a_tally() -> void:
	await with_reduce_motion(false, func():
		await with_garrison_main(func(main: Node):
			var levies := garrison(2)
			await strike(main)
			check(not MainProbe.raid_modal(main).is_empty() and MainProbe.raid_modal(main).repelled, "repelled, its modal open")
			eq([pips(main, levies[0]), pips(main, levies[1])], [[DIM, DIM], [DIM, DIM]], "not lit while the modal is open")
			var from := close_raid(main)
			await wait_seconds(0.2)
			eq([pips(main, levies[0]), pips(main, levies[1])], [[LIT, DIM], [LIT, DIM]], "each Levy's first pip lit")
			eq(ticks(main, from), [0.0, 0.06], "a tick per pip, 60 ms apart in tableau order")))


func test_with_reduce_motion_the_pips_light_at_once_with_a_tick_each() -> void:
	await with_reduce_motion(true, func():
		await with_garrison_main(func(main: Node):
			var levies := garrison(2)
			await strike(main)
			var from := close_raid(main)
			await wait_frames()
			eq([pips(main, levies[0]), pips(main, levies[1])], [[LIT, DIM], [LIT, DIM]], "lit at once")
			eq(ticks(main, from).size(), 2, "still a tick each")))


func test_a_unit_played_again_starts_dim() -> void:
	await with_garrison_main(func(main: Node):
		var e := Game.engine
		var levy: int = garrison()[0]
		await strike(main)
		close_raid(main)
		await wait_seconds(0.2)
		eq(pips(main, levy), [LIT, DIM], "a veteran")
		check(e.military.disband(levy), "disbanded: %s" % e.military.disband_error(levy))
		var card := e.zone("discard").find(levy)
		check(card != null, "the Levy is in the discard")
		if card == null:
			return
		e.zone("discard").remove(card)
		e.zone("hand").add(card)
		check(e.play_card(levy, hills_of(e)), "played again: %s" % e.play_error(levy, hills_of(e)))
		await wait_frames()
		eq(pips(main, levy), [DIM, DIM], "it starts dim"))
