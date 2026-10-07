extends "res://tests/lib/tech_case.gd"
## The build ceremony (357) in the real main.tscn, its sound clock frozen: a card built, recruited or upgraded from the
## Build modal rests in its slot at once and gets a ceremony on the fx layer (a lamp ring, 12 rays and a BUILT or
## RECRUITED tag; an upgrade's ring and rays on its base, no tag) in its plane colour, with ui.milestone.build (or
## .recruit) a beat after the press; no ceremony for any other arrival; Reduce motion shows it whole and holds it 1.5 s.
## Hooks: MainProbe.build_ceremonies(main); on a ceremony: view, parts(), tag_text(), colour(), ring_out(), ray_length(),
## tag_drop(), opacity().

const BUILD := Sfx.MILESTONE_BUILD
const RECRUIT := Sfx.MILESTONE_RECRUIT
const WARRIORS := {"id": "warriors", "name": "Warriors", "type": "unit", "cost": {"food": 2}, "strength": 2,
	"tags": ["military"]}
const PLOUGH := {"id": "plough", "name": "Plough", "type": "building", "cost": {"food": 1}, "upgrade_of": "farm"}
## Built, it adds era 2: an era milestone in the same action as the build.
const ACADEMY := {"id": "academy", "name": "Academy", "type": "building", "cost": {"food": 1},
	"effects": [{"op": "add_era", "era": 2}]}
const OPTICS := {"id": "optics", "name": "Optics", "type": "tech", "cost": {"insight": 4}, "era": 2}
const MENU := {"farm": {}, "warriors": {}, "plough": {}, "academy": {}}


## A game with build_menu MENU, no government (unlimited actions), Homeland at 3 pop, plenty of food, Farms in the deck
## and Optics waiting in era 2.
func ceremony_engine() -> GameEngine:
	var o := {"build_menu": MENU, "population": {"start": 3, "food_upkeep": 0, "vp_per_pop": 0},
		"starting": {"resources": {"food": 50, "wealth": 10, "insight": 0}, "tableau": ["capital"],
			"territory": "homeland"},
		"research_deck": {"pottery": 1, "optics": 1}}
	return tech_engine(["pottery"], {"farm": 10}, o, [WARRIORS, PLOUGH, ACADEMY, OPTICS])


## Runs body(main) on main showing ceremony_engine's game with Homeland's view open.
func with_home(body: Callable) -> void:
	await with_main(ceremony_engine(), func(main: Node):
		main.territory_view.open(home_uid(Game.engine))
		await wait_frames()
		await body.call(main))


## Opens the Build modal on Homeland with row selected, freezes the sound clock at 0, presses its key and lets a
## couple of frames run. Returns how many sounds had played before the press.
func build_from_modal(main: Node, row: String) -> int:
	main.build_modal.open(home_uid(Game.engine), row)
	await wait_frames()
	main.sfx.set_clock(0.0)
	var before: int = main.sfx.played().size()
	(main.build_modal.build_button as Button).pressed.emit()
	await wait_frames()
	return before


## The sounds played since index from: [token, at] pairs.
func heard(main: Node, from: int) -> Array:
	return main.sfx.played().slice(from).map(func(r): return [r.token, r.at])


func tokens_heard(main: Node, from: int) -> Array:
	return heard(main, from).map(func(p): return p[0])


## The uid of the one card id on the tableau, or -1.
func the(id: String) -> int:
	var cards := Game.engine.zone("tableau").cards.filter(func(c): return c.def.id == id)
	return cards[0].uid if cards.size() == 1 else -1


# --- AC3: a building ---

func test_a_building_built_rests_in_its_slot_under_a_ceremony() -> void:
	await with_home(func(main: Node):
		var from := await build_from_modal(main, "farm")
		var farm := the("farm")
		check(farm != -1 and main.views.has(farm), "the Farm has a view")
		var view: CardView = main.views.get(farm)
		eq(view.fx_scale if view != null else Vector2.ZERO, Vector2.ONE, "no pop-in: full scale at once")
		var all: Array[BuildCeremony] = MainProbe.build_ceremonies(main)
		eq(all.size(), 1, "one ceremony")
		if all.size() == 1:
			var c := all[0]
			check(c.view == view, "on the Farm")
			check(c.get_parent() == main.fx, "on the fx layer")
			eq(c.parts(), ["ring", "rays", "tag"], "ring, rays and tag")
			eq(c.tag_text(), "BUILT", "the tag")
			eq(c.colour(), Palette.BUILDING, "the building plane's colour")
		eq(heard(main, from).filter(func(p): return p[0] == BUILD), [[BUILD, Anim.BUILD_DELAY]],
			"the build sound once, a beat after the press")
		check(not tokens_heard(main, from).has(Sfx.CONFIRM), "no confirm tone"))


func test_the_ceremony_goes_once_it_has_run() -> void:
	await with_home(func(main: Node):
		await build_from_modal(main, "farm")
		eq(MainProbe.build_ceremonies(main).size(), 1, "playing")
		await wait_seconds(Anim.BUILD_CEREMONY_TIME + 0.05)
		eq(MainProbe.build_ceremonies(main).size(), 0, "gone after its run")
		check(main.views.has(the("farm")), "the Farm stays"))


# --- AC4: a unit ---

func test_a_unit_recruited_gets_the_ceremony_and_the_drum() -> void:
	await with_home(func(main: Node):
		var from := await build_from_modal(main, "warriors")
		var unit := the("warriors")
		var all: Array[BuildCeremony] = MainProbe.build_ceremonies(main)
		eq(all.size(), 1, "one ceremony")
		if all.size() == 1:
			var c := all[0]
			check(c.view == main.views.get(unit), "on the Warriors")
			eq(c.parts(), ["ring", "rays", "tag"], "ring, rays and tag")
			eq(c.tag_text(), "RECRUITED", "the tag")
			eq(c.colour(), Palette.UNIT, "the unit plane's colour")
		var events := tokens_heard(main, from).filter(func(t): return t in [BUILD, RECRUIT])
		eq(events, [RECRUIT], "the recruit sound once, not the build sound"))


# --- AC5: an upgrade ---

func test_an_upgrade_plays_ring_and_rays_on_its_base() -> void:
	await with_home(func(main: Node):
		await build_from_modal(main, "farm")
		await wait_seconds(Anim.BUILD_CEREMONY_TIME + 0.05)
		var farm := the("farm")
		var from := await build_from_modal(main, BuildModal.upgrade_row_id("plough", farm))
		check(the("plough") != -1, "a Plough on the Farm")
		var all: Array[BuildCeremony] = MainProbe.build_ceremonies(main)
		eq(all.size(), 1, "one ceremony")
		if all.size() == 1:
			var c := all[0]
			check(c.view == main.views.get(farm), "on the Farm it upgrades")
			eq(c.parts(), ["ring", "rays"], "ring and rays, no tag")
			eq(c.tag_text(), "", "no tag")
		eq(tokens_heard(main, from).filter(func(t): return t == BUILD), [BUILD], "the build sound once"))


# --- AC6: other arrivals ---

func test_a_card_played_from_the_hand_arrives_without_a_ceremony() -> void:
	await with_home(func(main: Node):
		main.sfx.set_clock(0.0)
		var from: int = main.sfx.played().size()
		check(Game.engine.play_card(uid_of(Game.engine.zone("hand"), "farm")), "play a Farm from the hand")
		await wait_frames()
		check(main.views.has(the("farm")), "the Farm is in the view")
		eq(MainProbe.build_ceremonies(main).size(), 0, "no ceremony")
		check(not tokens_heard(main, from).has(BUILD), "no build sound"))


# --- AC7: Reduce motion ---

func test_reduce_motion_shows_the_ceremony_whole_and_holds_it() -> void:
	await with_reduce_motion(true, func():
		await with_home(func(main: Node):
			var from := await build_from_modal(main, "farm")
			var all: Array[BuildCeremony] = MainProbe.build_ceremonies(main)
			eq(all.size(), 1, "one ceremony")
			if all.size() == 1:
				var c := all[0]
				eq([c.ring_out(), c.ray_length(), c.tag_drop(), c.opacity()],
					[float(Tokens.SPACE_3), float(Tokens.SPACE_5), 0.0, 1.0], "ring out, rays drawn, tag down, opaque")
			await wait_seconds(Anim.BUILD_CALM_HOLD - 0.1)
			eq(MainProbe.build_ceremonies(main).size(), 1, "still held just before 1.5 s")
			await wait_seconds(0.2)
			eq(MainProbe.build_ceremonies(main).size(), 0, "gone after 1.5 s")
			eq(tokens_heard(main, from).filter(func(t): return t == BUILD), [BUILD], "the sound still plays")))


# --- AC8: the sounds ---

func test_a_build_that_adds_an_era_plays_only_the_era() -> void:
	await with_home(func(main: Node):
		var from := await build_from_modal(main, "academy")
		var events := tokens_heard(main, from).filter(func(t): return Sfx.level(t) == 3)
		eq(events, [Sfx.MILESTONE_ERA], "the era wins over the build")
		eq(MainProbe.build_ceremonies(main).size(), 1, "the ceremony still plays"))
