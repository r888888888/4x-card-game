extends "res://tests/lib/test_case.gd"
## How a card lands in its slot (backlog 117): a dealt card flies in, fades in and settles without the landing
## squash-and-bounce; since 179 no card squashes (it lands with a firm stop), and a rejected card still shakes. CardViews run in a plain Control
## tree (a slot and an effects layer) and are stepped frame by frame.

const MAX_FRAMES := 900
const AFTER_LANDING := 0.32  # s to watch a landed card's scale (the old squash took 0.22)


## A root holding a slot and an effects layer, and a CardView for the first hand card, not yet placed. Returns
## {root, slot, layer, view}; free root when done.
func fixture() -> Dictionary:
	var e := make_engine({"farm": 10})
	var root := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.size = Vector2(1200, 800)
	var slot := Control.new()
	slot.custom_minimum_size = CardView.HAND_SIZE
	slot.size = CardView.HAND_SIZE
	slot.position = Vector2(900, 500)
	root.add_child(slot)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)
	var view := CardView.new()
	view.setup(e.zone("hand").cards[0], e.card_db, true)
	return {"root": root, "slot": slot, "layer": layer, "view": view}


## Waits frames until view is at rest, up to MAX_FRAMES. Returns whether it got there.
func wait_until_landed(view: CardView) -> bool:
	for i in MAX_FRAMES:
		await wait_frames(1)
		if view.state == CardView.State.REST:
			return true
	return false


## The largest distance of view.fx_scale from 1 over the next AFTER_LANDING seconds (by waiting real time).
func largest_squash_after_landing(view: CardView) -> float:
	var largest := view.fx_scale.distance_to(Vector2.ONE)
	var timer := (Engine.get_main_loop() as SceneTree).create_timer(AFTER_LANDING)
	while timer.time_left > 0.0:
		await wait_frames(1)
		largest = maxf(largest, view.fx_scale.distance_to(Vector2.ONE))
	return largest


func test_a_dealt_card_lands_without_a_squash() -> void:
	await with_reduce_motion(false, func():
		var f := fixture()
		var view: CardView = f.view
		view.deal(f.slot, f.layer, Vector2(100, 100), 0.0)
		check(await wait_until_landed(view), "the card lands")
		check(view.slot == f.slot and view.get_parent() == f.slot, "it rests in its slot")
		check(await largest_squash_after_landing(view) < 0.001, "no squash after landing: scale stays 1")
		eq(view.scale, Vector2.ONE, "scale 1")
		(f.root as Node).free())


func test_a_dealt_card_still_flies_and_fades_in() -> void:
	await with_reduce_motion(false, func():
		var f := fixture()
		var view: CardView = f.view
		view.deal(f.slot, f.layer, Vector2(100, 100), 0.0)
		await wait_frames(1)
		check(view.get_parent() == f.layer, "flying on the effects layer")
		check(view.state == CardView.State.FLYING, "flying")
		check(await wait_until_landed(view), "the card lands")
		await wait_frames(30)
		check(view.modulate.a > 0.99, "faded in: %s" % view.modulate.a)
		(f.root as Node).free())


func test_a_card_sent_to_another_slot_doesnt_squash_when_it_lands() -> void:
	await with_reduce_motion(false, func():
		var f := fixture()
		var view: CardView = f.view
		view.attach(f.slot)
		var other := Control.new()
		other.custom_minimum_size = CardView.HAND_SIZE
		other.size = CardView.HAND_SIZE
		other.position = Vector2(100, 100)
		f.root.add_child(other)
		view.fly_to_slot(other, f.layer)
		var largest := 0.0
		for i in MAX_FRAMES:
			await wait_frames(1)
			largest = maxf(largest, view.fx_scale.distance_to(Vector2.ONE))
			if view.state == CardView.State.REST:
				break
		check(view.state == CardView.State.REST, "the card lands")
		largest = maxf(largest, await largest_squash_after_landing(view))
		check(largest < 0.001, "no squash in flight or on landing: scale strays %s" % largest)
		(f.root as Node).free())


func test_a_rejected_card_returning_to_its_slot_still_shakes_on_landing() -> void:
	await with_reduce_motion(false, func():
		var f := fixture()
		var view: CardView = f.view
		view.attach(f.slot)
		var start := view.position
		view.begin_drag(f.layer, Vector2.ZERO)
		view.global_position = Vector2(300, 300)
		view.reject()
		check(await wait_until_landed(view), "the card lands")
		var moved := false
		var timer := (Engine.get_main_loop() as SceneTree).create_timer(Anim.SHAKE_TIME)
		while timer.time_left > 0.0:
			await wait_frames(1)
			moved = moved or absf(view.position.x - start.x) > 0.5
		check(moved, "it shakes sideways after landing")
		(f.root as Node).free())
