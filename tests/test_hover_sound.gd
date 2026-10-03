extends "res://tests/lib/test_case.gd"
## Hover sound (245) in the real main.tscn, its sound clock frozen at 0: an enabled button or an actionable card ticks
## once as the mouse enters it, a disabled key, a display-only card, a held mouse, a repeat inside HOVER_GAP and a
## Level 3 event are silent, and late-added buttons tick too.

const HOVER := Sfx.HOVER
const GAP := Sfx.HOVER_GAP

var _old_window_size := Vector2i.ZERO


func open_game() -> Node:
	var window := (Engine.get_main_loop() as SceneTree).root
	_old_window_size = window.size
	window.size = Vector2i(1920, 1080)
	var main := open_main()
	main.start_game(1)
	await wait_frames()
	main.sfx.set_clock(0.0)
	return main


func close_game(main: Node) -> void:
	close_main(main)
	(Engine.get_main_loop() as SceneTree).root.size = _old_window_size


func shown_button(root: Node, prefix: String) -> Button:
	for b in UIKit.buttons_in(root):
		if b.is_visible_in_tree() and b.text.begins_with(prefix):
			return b
	return null


func move_mouse(main: Node, at: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	main.get_viewport().push_input(event, true)


func centre(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## Moves the mouse well away from everything (and lets Godot notice).
func away(main: Node) -> void:
	move_mouse(main, Vector2(2, 2))


func hovers(main: Node) -> int:
	return main.sfx.played().filter(func(r): return r.token == HOVER).size()


## A button added after main opened, in a layer over the board.
func late_button(main: Node, disabled := false) -> Button:
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var b := Button.new()
	b.text = "Late"
	b.disabled = disabled
	b.position = Vector2(800, 500)
	layer.add_child(b)
	return b


# --- AC1, AC8: a button ticks ---

func test_the_hover_token_is_a_level_1_sound() -> void:
	check(Sfx.TOKENS.has(HOVER), "ui.hover is a token")
	eq(Sfx.level(HOVER), 1, "Level 1")
	eq(Sfx.bus(HOVER), Settings.INTERFACE, "on the Interface bus")


func test_entering_an_enabled_button_ticks_once_and_quietly() -> void:
	var main: Node = await open_game()
	away(main)
	move_mouse(main, centre(shown_button(main, "Log")))
	await wait_frames()
	eq(hovers(main), 1, "one tick")
	var record: Dictionary = main.sfx.played()[0]
	eq(record.token, HOVER, "it is the hover token")
	check(record.db < 0.0, "quieter than a press (0 dB)")
	close_game(main)


# --- AC2: cards ---

func test_entering_a_hand_card_ticks() -> void:
	var main: Node = await open_game()
	away(main)
	await wait_frames(240)  # the deal lands
	var card: CardView = main.views_in(main.hand)[0]
	move_mouse(main, centre(card))
	await wait_frames()
	eq(hovers(main), 1, "one tick")
	close_game(main)


func test_a_display_only_card_is_silent() -> void:
	var main: Node = await open_game()
	away(main)
	var slot := Control.new()
	slot.custom_minimum_size = CardView.HAND_SIZE
	slot.size = CardView.HAND_SIZE
	slot.position = Vector2(700, 300)
	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	layer.add_child(slot)
	var view := CardView.new()
	view.setup(CardInstance.new(9000, Game.engine.zone("hand").cards[0].def), Game.engine.card_db, false)
	view.attach(slot)
	await wait_frames()
	move_mouse(main, centre(view))
	await wait_frames()
	eq(hovers(main), 0, "silent")
	close_game(main)


# --- AC3: disabled ---

func test_a_disabled_button_is_silent_on_hover() -> void:
	var main: Node = await open_game()
	away(main)
	var locked := late_button(main, true)
	await wait_frames()
	move_mouse(main, centre(locked))
	await wait_frames()
	eq(hovers(main), 0, "silent")
	close_game(main)


# --- AC4: once per entry, with a gap ---

func test_moving_within_and_leaving_do_not_tick_again_and_a_fresh_entry_does() -> void:
	var main: Node = await open_game()
	away(main)
	var log_button := shown_button(main, "Log")
	var c := centre(log_button)
	move_mouse(main, c)
	move_mouse(main, c + Vector2(2, 0))
	move_mouse(main, c + Vector2(-2, 0))
	await wait_frames()
	eq(hovers(main), 1, "moving within ticks nothing more")
	away(main)
	await wait_frames()
	eq(hovers(main), 1, "leaving is silent")
	main.sfx.set_clock(1.0)
	move_mouse(main, c)
	await wait_frames()
	eq(hovers(main), 2, "a fresh entry ticks again")
	close_game(main)


func test_a_re_entry_inside_the_gap_is_dropped() -> void:
	var main: Node = await open_game()
	away(main)
	var c := centre(shown_button(main, "Log"))
	move_mouse(main, c)
	away(main)
	main.sfx.set_clock(GAP * 0.5)
	move_mouse(main, c)
	await wait_frames()
	eq(hovers(main), 1, "the second is too soon")
	away(main)
	main.sfx.set_clock(GAP * 3.0)
	move_mouse(main, c)
	await wait_frames()
	eq(hovers(main), 2, "after the gap it ticks")
	close_game(main)


# --- AC5: held mouse ---

func test_entering_a_button_with_the_mouse_held_is_silent() -> void:
	var main: Node = await open_game()
	away(main)
	move_mouse(main, centre(shown_button(main, "Log")), true)
	await wait_frames()
	eq(hovers(main), 0, "silent")
	close_game(main)


# --- AC6: late buttons ---

func test_a_button_added_later_ticks() -> void:
	var main: Node = await open_game()
	away(main)
	var late := late_button(main)
	await wait_frames()
	move_mouse(main, centre(late))
	await wait_frames()
	eq(hovers(main), 1, "it ticks")
	close_game(main)


# --- AC7: gives way ---

func test_hover_gives_way_to_a_level_3_event() -> void:
	var main: Node = await open_game()
	away(main)
	main.sfx.play(Sfx.MILESTONE_ERA)
	move_mouse(main, centre(shown_button(main, "Log")))
	await wait_frames()
	eq(hovers(main), 0, "silent under the event")
	close_game(main)
