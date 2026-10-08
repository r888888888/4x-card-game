extends "res://tests/lib/anarchy_case.gd"
## The Renewal modal (backlogs 255, 385): during Anarchy a Renew button beside Relieve famine shows the renewals left and
## opens a sheet listing every renewal option as a row in options order; rows are chosen and put back, renewals_left()
## caps them, and "Trash N cards" trashes 1 to that many in one renew call. Esc or Close shuts it without trashing.
## Sounds: toggle on/off, reject.locked past the count. Fixtures: tests/lib/anarchy_case.gd.


## Runs body(main, modal) on a real main scene whose game fell into Anarchy with block's renewal, the discard holding
## discard_ids, and the Renew button pressed. Use with await.
func with_renewal(block: Dictionary, discard_ids: Array, body: Callable) -> void:
	await with_main(anarchy_engine(block), func(main: Node):
		var e := Game.engine
		for id in discard_ids:
			put_in(e, id, "discard")
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		MainProbe.renew_button(main).pressed.emit()
		await wait_frames()
		await body.call(main, main.renewal_modal))


func tokens(main: Node) -> Array:
	return main.sfx.played().map(func(r): return r.token)


# --- 385: the Renew button ---

func test_the_renew_button_shows_the_renewals_left_during_anarchy() -> void:
	await with_main(anarchy_engine({"renewal": 1}), func(main: Node):
		var e := Game.engine
		var renew := MainProbe.renew_button(main)
		await wait_frames()
		check(not renew.is_visible_in_tree(), "hidden outside Anarchy")
		put_in(e, "scout", "discard")
		e.resources["unrest"] = 5
		e.end_turn()
		await wait_frames()
		check(renew.is_visible_in_tree(), "shown in Anarchy")
		eq(renew.text, "Renew (1 left)", "the count left")
		eq(renew.get_parent(), MainProbe.relieve_button(main).get_parent(), "beside Relieve famine")
		check(not main.renewal_modal.is_open(), "nothing opens by itself")
		check(e.renew([e.renewal_options()[0]]), "renew")
		await wait_frames()
		check(not renew.is_visible_in_tree(), "hidden with none left"))


# --- AC7: the sheet ---

func test_the_renewal_modal_lists_every_option_in_order() -> void:
	await with_renewal({"renewal": 1}, ["scout", "kings"], func(main: Node, modal: RenewalModal):
		var e := Game.engine
		check(modal.is_open(), "the Renew button opens the Renewal modal")
		eq(main.modals.top(), modal, "on the modal stack")
		eq(modal.title, "Renewal", "titled")
		eq(modal.row_uids(), e.renewal_options(), "a row per option, in their order")
		var names: Array = modal.rows().map(func(r): return r.text.strip_edges())
		eq(names, e.renewal_options().map(func(u): return e.card_details(u).name), "each row its card's name")
		check(main.views_in(main.hand).size() == e.zone("hand").size(), "the hand stays in place"))


func test_the_renewal_modal_closes_without_trashing() -> void:
	await with_renewal({"renewal": 1}, ["scout"], func(main: Node, modal: RenewalModal):
		var e := Game.engine
		modal.rows()[0].pressed.emit()
		press_key(main, KEY_ESCAPE)
		await wait_frames()
		check(not modal.is_open(), "Esc closes it")
		eq(e.zone("trashed").size(), 0, "nothing trashed")
		eq(e.renewals_left(), 1, "the renewal is still there"))


func test_rows_are_chosen_and_put_back_up_to_the_renewals_left() -> void:
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


func test_trash_takes_1_to_the_renewals_left_then_closes() -> void:
	await with_renewal({"renewal": 2}, ["scout", "shrine"], func(main: Node, modal: RenewalModal):
		var e := Game.engine
		var ids: Array = modal.row_uids()
		check(modal.trash_button.disabled, "none chosen: locked")
		modal.rows()[0].pressed.emit()
		check(not modal.trash_button.disabled, "1 chosen: unlocked")
		eq(modal.trash_button.text, "Trash 1 card", "the key names the cards chosen")
		modal.trash_button.pressed.emit()
		await wait_frames()
		eq(card_ids(e.zone("trashed")).size(), 1, "one trashed")
		check(e.zone("trashed").find(ids[0]) != null, "the chosen one")
		eq(e.renewals_left(), 1, "1 left")
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


# --- 381: the shown card's art plate ---

func test_the_shown_card_has_its_art_plate() -> void:
	await with_renewal({"renewal": 1}, ["scout", "kings"], func(_main: Node, modal: RenewalModal):
		var card := card_under(modal)
		check(card != null and art_plate(card) != null, "the shown card has a plate"))
