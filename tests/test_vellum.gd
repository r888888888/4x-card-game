extends "res://tests/lib/test_case.gd"
## Targeting under vellum (backlog 210) in the real main scene on a TEST_CARDS game with two territories (Homeland and
## Grassland) and a Temple in hand that can go on either. Hooks: main.vellum (a Control: covered_rect(), the part of
## the window it covers now; lifted(), the card views drawn above it).

const Looks := preload("res://tests/lib/surface_looks.gd")
const WIPE_IN := 0.26
const WIPE_OUT := 0.20
const SLACK := 0.06


## Runs body(main, temple, targets) on that game, Reduce motion calm or not.
func with_two_targets(calm: bool, body: Callable) -> void:
	await with_reduce_motion(calm, func():
		await with_territories_main(func(main: Node):
			var e := Game.engine
			settle(e, ["grassland"])
			var temple := put_in_hand(e, "temple")
			e.changed.emit()
			await wait_frames()
			var targets: Array[int] = []
			targets.assign(e.valid_targets(temple))
			eq(targets.size(), 2, "precondition: two targets")
			await body.call(main, temple, targets)))


func vellum_shown(main: Node) -> bool:
	return (main.vellum as Control).is_visible_in_tree()


# --- AC1: the vellum wipes in, the targets above it ---

func test_targeting_wipes_vellum_in_from_the_left_with_the_targets_above_it() -> void:
	await with_two_targets(false, func(main: Node, temple: int, targets: Array[int]):
		main.card_actions.on_double_clicked(main.views[temple])
		check(main.drag.targeting != null, "targeting")
		check(vellum_shown(main), "the vellum is down")
		var start: Rect2 = main.vellum.covered_rect()
		check(start.size.x <= 2.0, "it starts as a sliver: %s" % start)
		check(start.position.x <= 1.0, "at the left edge: %s" % start)
		eq(Color(main.vellum.color, 1.0), Palette.RAISED, "paper-coloured")
		check(main.vellum.color.a > 0.0 and main.vellum.color.a < 1.0, "see-through: %.2f" % main.vellum.color.a)
		await wait_seconds(WIPE_IN / 2)
		var mid: Rect2 = main.vellum.covered_rect()
		check(mid.position.x <= 1.0 and mid.size.x > 0.0 and mid.end.x < main.get_viewport_rect().size.x, "part way across: %s" % mid)
		await wait_seconds(WIPE_IN / 2 + SLACK)
		var full: Rect2 = main.vellum.covered_rect()
		check(full.encloses(main.tableau.row.get_global_rect()), "over the Realm: %s" % full)
		check(full.encloses(main.hand_scroll.get_global_rect()), "over the hand: %s" % full)
		var lifted: Array = main.vellum.lifted()
		for uid in targets + [temple]:
			check(lifted.has(main.views[uid]), "card %d is above the vellum" % uid)
		for uid in targets:
			var box := Looks.frame_of((main.views[uid] as CardView).get_theme_stylebox("panel"))  # its rule (341)
			eq(box.border_color, Palette.FOCUS, "target %d outlined in FOCUS" % uid)
			eq(box.border_width_left, 2, "a 2 px outline on %d" % uid)
		eq(lifted.size(), targets.size() + 1, "nothing else above it")
		main.drag.end_targeting())


# --- AC2: a target plays; the rest is under the vellum ---

func test_a_click_on_a_target_plays_there_and_the_vellum_wipes_off_right() -> void:
	await with_two_targets(false, func(main: Node, temple: int, targets: Array[int]):
		main.card_actions.on_double_clicked(main.views[temple])
		await wait_seconds(WIPE_IN + SLACK)
		main.card_actions.on_picked(main.views[targets[1]])
		var e := Game.engine
		var played := e.zone("tableau").find(temple)
		check(played != null and played.territory_uid == targets[1], "played on the clicked target")
		check(vellum_shown(main), "the vellum is still lifting")
		await wait_seconds(WIPE_OUT / 2)
		var mid: Rect2 = main.vellum.covered_rect()
		check(mid.position.x > 1.0, "it leaves to the right: %s" % mid)
		await wait_seconds(WIPE_OUT / 2 + SLACK)
		check(not vellum_shown(main), "gone by 0.20 s"))


func test_a_click_on_a_non_target_card_reaches_only_the_vellum() -> void:
	await with_two_targets(false, func(main: Node, temple: int, targets: Array[int]):
		var e := Game.engine
		var other := -1
		for c in e.zone("hand").cards:
			if c.uid != temple:
				other = c.uid
		check(other != -1, "precondition: another hand card")
		main.card_actions.on_double_clicked(main.views[temple])
		await wait_seconds(WIPE_IN + SLACK)
		var before := e.zone("hand").cards.size()
		click_point(main, (main.views[other] as CardView).get_global_rect().get_center())
		await wait_seconds(Anim.DETAILS_CLICK_DELAY + 0.1)
		eq(e.zone("hand").cards.size(), before, "nothing played")
		check(main.drag.targeting == null, "the click on the vellum cancelled targeting")
		check(main.details.shown().is_empty(), "no details for the card under it"))


# --- AC3: cancelling ---

func test_esc_right_click_or_a_click_on_the_vellum_cancel_and_wipe_it_off() -> void:
	for way in ["esc", "right", "vellum"]:
		await with_two_targets(false, func(main: Node, temple: int, _targets: Array[int]):
			var e := Game.engine
			main.card_actions.on_double_clicked(main.views[temple])
			await wait_seconds(WIPE_IN + SLACK)
			var empty: Vector2 = main.tableau.row.get_global_rect().end - Vector2(4, 4)
			match way:
				"esc":
					press_key(main, KEY_ESCAPE)
				"right":
					click_point(main, empty, MOUSE_BUTTON_RIGHT)
				"vellum":
					click_point(main, empty)
			await wait_frames()
			check(main.drag.targeting == null, "%s: targeting ended" % way)
			check(e.zone("hand").find(temple) != null, "%s: the Temple is back in the hand" % way)
			await wait_seconds(WIPE_OUT / 2)
			check(vellum_shown(main) and main.vellum.covered_rect().position.x > 1.0, "%s: wiping off right" % way)
			await wait_seconds(WIPE_OUT / 2 + SLACK)
			check(not vellum_shown(main), "%s: gone" % way))


# --- AC4: Reduce motion ---

func test_with_reduce_motion_the_vellum_fades_in_and_out() -> void:
	await with_two_targets(true, func(main: Node, temple: int, _targets: Array[int]):
		main.card_actions.on_double_clicked(main.views[temple])
		var full: Rect2 = main.vellum.covered_rect()
		check(full.encloses(main.tableau.row.get_global_rect()), "whole at once, no wipe: %s" % full)
		check((main.vellum as Control).modulate.a < 1.0, "fading in")
		await wait_seconds(0.12 + SLACK)
		eq((main.vellum as Control).modulate.a, 1.0, "in by 0.12 s")
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check((main.vellum as Control).modulate.a < 1.0, "fading out")
		check(main.vellum.covered_rect().encloses(main.tableau.row.get_global_rect()), "still whole")
		await wait_seconds(0.12 + SLACK)
		check(not vellum_shown(main), "gone"))


# --- AC5: a drag has no vellum ---

func test_a_drag_lights_targets_without_vellum() -> void:
	await with_two_targets(false, func(main: Node, temple: int, targets: Array[int]):
		main.drag.begin_drag(main.views[temple], Vector2.ZERO)
		await wait_frames()
		check(not vellum_shown(main), "no vellum while dragging")
		eq(sorted(main.drag.lit), sorted(targets), "the targets lit as today")
		main.drag.end_drag())
