extends "res://tests/lib/anarchy_case.gd"
## The Renewal modal (backlog 255): while renewal is owed a sheet lists every option as a row in options order; rows
## are chosen and put back, the count caps them, and "Trash N cards" pays the renewal in one renew call. It can't be
## dismissed. Sounds: toggle on/off, reject.locked past the count. Fixtures: tests/lib/anarchy_case.gd.


## Runs body(main, modal) on a real main scene whose game fell into Anarchy owing renewal block's count, the discard
## holding discard_ids. Use with await.
func with_renewal(block: Dictionary, discard_ids: Array, body: Callable) -> void:
	await with_main(anarchy_engine(block), func(main: Node):
		var e := Game.engine
		for id in discard_ids:
			put_in(e, id, "discard")
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		await body.call(main, main.renewal_modal))


func tokens(main: Node) -> Array:
	return main.sfx.played().map(func(r): return r.token)


# --- AC7: the sheet ---

func test_the_renewal_modal_lists_every_option_in_order() -> void:
	await with_renewal({"renewal": 1}, ["scout", "kings"], func(main: Node, modal: RenewalModal):
		var e := Game.engine
		check(modal != null and modal.is_open(), "the Renewal modal is open")
		if modal == null:
			return
		eq(main.modals.top(), modal, "on the modal stack")
		eq(modal.title, "Renewal", "titled")
		eq(modal.row_uids(), e.pending().get("options"), "a row per option, in their order")
		var names: Array = modal.rows().map(func(r): return r.text.strip_edges())
		eq(names, e.pending().get("options").map(func(u): return e.card_details(u).name), "each row its card's name")
		check(main.views_in(main.hand).size() == e.zone("hand").size(), "the hand stays in place")
		check(main.choices.get("renewal_row") == null, "the old overlay is gone"))


func test_the_renewal_modal_cant_be_dismissed() -> void:
	await with_renewal({"renewal": 1}, ["scout"], func(main: Node, modal: RenewalModal):
		press_key(main, KEY_ESCAPE)
		for pressed in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = Vector2(4, 4)
			event.global_position = Vector2(4, 4)
			main.get_viewport().push_input(event, true)
		await wait_frames()
		check(modal.is_open(), "Esc and a click outside leave it open"))


func test_rows_are_chosen_and_put_back_up_to_the_count() -> void:
	await with_renewal({"renewal": 2}, ["scout", "shrine", "farm"], func(main: Node, modal: RenewalModal):
		var rows: Array = modal.rows()
		var ids: Array = modal.row_uids()
		rows[0].pressed.emit()
		rows[1].pressed.emit()
		eq(modal.chosen(), [ids[0], ids[1]], "two chosen")
		rows[2].pressed.emit()
		eq(modal.chosen(), [ids[0], ids[1]], "a third is refused at the count")
		rows[0].pressed.emit()
		eq(modal.chosen(), [ids[1]], "a second click puts it back"))


func test_trash_is_refused_until_the_count_then_pays_and_closes() -> void:
	await with_renewal({"renewal": 2}, ["scout", "shrine"], func(main: Node, modal: RenewalModal):
		var e := Game.engine
		var rows: Array = modal.rows()
		var ids: Array = modal.row_uids()
		eq(modal.trash_button.text, "Trash 2 cards", "the key names the count")
		rows[0].pressed.emit()
		modal.trash_button.pressed.emit()
		eq(e.pending().get("kind"), GameEngine.PENDING_RENEWAL, "1 of 2: refused, still owed")
		check(modal.is_open(), "still open")
		rows[1].pressed.emit()
		modal.trash_button.pressed.emit()
		await wait_frames()
		eq(e.pending(), {}, "paid")
		eq(sorted(e.zone("trashed").cards.map(func(c): return c.uid)), sorted([ids[0], ids[1]]), "the chosen two trashed")
		check(not modal.is_open(), "the sheet closes"))


# --- AC8: sounds ---

func test_choosing_sounds_like_a_lamp_key_and_past_the_count_is_locked() -> void:
	await with_renewal({"renewal": 1}, ["scout", "shrine"], func(main: Node, modal: RenewalModal):
		var rows: Array = modal.rows()
		var before: int = main.sfx.played().size()
		rows[0].pressed.emit()
		rows[1].pressed.emit()
		rows[0].pressed.emit()
		await wait_frames()
		var heard: Array = tokens(main).slice(before).filter(func(t): return t in [Sfx.TOGGLE_ON, Sfx.TOGGLE_OFF,
			Sfx.REJECT_LOCKED])
		eq(heard, [Sfx.TOGGLE_ON, Sfx.REJECT_LOCKED, Sfx.TOGGLE_OFF], "on, locked past the count, off"))


func test_the_renewal_sheet_opens_and_closes_with_the_sheet_sounds() -> void:
	await with_renewal({"renewal": 1}, ["scout"], func(main: Node, modal: RenewalModal):
		check(tokens(main).has(Sfx.SHEET_OPEN), "ui.sheet.open as it opens")
		modal.rows()[0].pressed.emit()
		modal.trash_button.pressed.emit()
		await wait_frames()
		check(tokens(main).has(Sfx.SHEET_CLOSE), "ui.sheet.close as it closes"))


# --- Backlog 362: the ledger glides ---

## Opens the renewal modal with more ledger rows than its column shows and checks a wheel notch over the ledger moves
## it a step, gliding unless calm (check_wheel_step).
func check_ledger_wheel_step(calm: bool) -> void:
	var discard := []
	discard.resize(24)
	discard.fill("scout")
	await with_reduce_motion(calm, func():
		await with_renewal({"renewal": 1}, discard, func(main: Node, modal: RenewalModal):
			await wait_frames()
			await check_wheel_step(main, scroll_around(modal.rows()[0]), "the ledger")))


func test_a_wheel_notch_glides_the_ledger_a_step() -> void:
	await check_ledger_wheel_step(false)


func test_with_reduce_motion_a_wheel_notch_jumps_the_ledger_a_step() -> void:
	await check_ledger_wheel_step(true)
