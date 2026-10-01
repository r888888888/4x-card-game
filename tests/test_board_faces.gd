extends "res://tests/lib/test_case.gd"
## Board card faces (backlog 138): every card in the Realm's row rests at board_size() with one line per field
## (the rest is in its details); frontier territories and events carry a badge naming what they are. Runs the real
## main scene on a board_engine game through with_main. Faces are read with CardView.face_text() (one line per label).


## The face text of uid's card view, one line per label.
func face(main: Node, uid: int) -> String:
	return (main.views[uid] as CardView).face_text()


## The face lines of uid's card view.
func face_lines(main: Node, uid: int) -> PackedStringArray:
	return face(main, uid).split("\n")


# --- AC1: one fixed height ---

func test_every_card_in_the_row_rests_at_board_size() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "grassland"))
		grass.keywords.assign(["fresh_water", "flood_plain", "mountain"])  # rolled: a long keyword line
		to_frontier(e, ["hills"])
		var paddy: CardInstance = e.create_card("paddy", "tableau", null)  # on no territory; two lines of rules
		var winds: CardInstance = e.create_card("trade_winds", "active_events", null)
		e.changed.emit()
		await wait_frames()
		var uids: Array[int] = [winds.uid, uid_of(e.zone("frontier"), "hills"), home_uid(e), grass.uid, paddy.uid]
		for uid in uids:
			var view: CardView = main.views[uid]
			eq(view.slot_size(), board_size(), "%s at board size" % view.card_id)
			eq(view.slot.custom_minimum_size, board_size(), "%s's slot" % view.card_id))


# --- AC2: the frontier face ---

func test_a_frontier_card_has_a_badge_its_keywords_and_printed_slots_and_housing() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		to_frontier(e, ["hills"])
		var hills := uid_of(e.zone("frontier"), "hills")
		e.changed.emit()
		await wait_frames()
		var def := e.card_db["hills"] as CardDef
		eq(face_lines(main, hills), PackedStringArray(["▲ Frontier · unsettled", "Hills", "Mountain",
			"▢%d ⌂%d" % [def.slots, def.housing]]), "badge, name, keywords, printed slots and housing")
		var home_face := face(main, home_uid(e))
		check(not home_face.contains("Frontier"), "a settled territory has no badge: %s" % home_face))


# --- AC3: the event face ---

func test_an_event_card_has_a_badge_with_its_turns_left_then_its_first_rules_line() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		var winds: CardInstance = e.create_card("trade_winds", "active_events", null)
		winds.turns_left = 1
		var omen: CardInstance = e.create_card("omen", "active_events", null)
		omen.turns_left = 1
		e.changed.emit()
		await wait_frames()
		var first_rule: String = (e.card_db["trade_winds"] as CardDef).rules_text(e.card_db).split("\n")[0]
		check(not first_rule.begins_with("Lasts"), "Trade Winds' first rules line is its effect: %s" % first_rule)
		eq(face_lines(main, winds.uid), PackedStringArray(["❖ Event", "1 turn left", "Trade Winds", first_rule]),
			"Trade Winds: badge, turns left, name, effect")
		eq(face_lines(main, omen.uid), PackedStringArray(["❖ Event", "1 turn left", "Omen"]),
			"Omen: no rules line, no 'Lasts' line"))


func test_a_famine_card_shows_its_counters_beside_its_badge() -> void:
	await with_main(board_engine({"population": HUNGRY_POP}), func(main: Node):
		var e := Game.engine
		e.zone("tableau").find(home_uid(e)).pop = 4
		e.resources.food = 0
		e.end_turn()  # hungry upkeep: a Famine arrives
		check(e.famine_counters() > 0, "a Famine is active")
		await wait_frames()
		var famine: int = e.zone("active_events").cards[0].uid
		var lines := face_lines(main, famine)
		eq(lines.slice(0, 2), PackedStringArray(["❖ Event", "%d counter" % e.famine_counters()]),
			"badge, then counters: %s" % [lines]))


# --- AC4: settling switches the face ---

func test_a_settled_frontier_card_switches_to_the_settled_face_at_board_size() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		to_frontier(e, ["hills"])
		var hills := uid_of(e.zone("frontier"), "hills")
		var pioneer := put_in_hand(e, "pioneer")
		e.resources.food = 5
		e.changed.emit()
		await wait_frames()
		check(e.play_card(pioneer, hills), "settle: %s" % e.play_error(pioneer, hills))
		await wait_frames()
		var text := face(main, hills)
		check(not text.contains("Frontier"), "badge gone: %s" % text)
		check(text.begins_with("Hills\nMountain\n▢ "), "name, keywords, then the live line: %s" % text)
		eq((main.views[hills] as CardView).slot_size(), board_size(), "still at board size"))


# --- AC5: nothing clipped is lost ---

func test_the_details_of_a_board_card_name_every_keyword() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		settle(e, ["grassland"])
		var grass: CardInstance = e.zone("tableau").find(uid_of(e.zone("tableau"), "grassland"))
		grass.keywords.assign(["fresh_water", "flood_plain", "mountain"])
		e.changed.emit()
		await wait_frames()
		main.details.open(main.views[grass.uid])
		var body: String = main.details.body_text()
		for name in ["Fresh Water", "Flood Plain", "Mountain"]:
			check(body.contains(name), "details name %s: %s" % [name, body]))


# --- AC6: the hand is unchanged ---

func test_a_hand_card_keeps_its_size_type_line_and_rules() -> void:
	await with_main(board_engine(), func(main: Node):
		var e := Game.engine
		var paddy := put_in_hand(e, "paddy")
		e.changed.emit()
		await wait_frames()
		var view: CardView = main.views[paddy]
		eq(view.slot_size().x, CardView.HAND_SIZE.x, "hand width")
		var text := view.face_text()
		var rules: String = (e.card_db["paddy"] as CardDef).rules_text(e.card_db)
		check(text.contains("Building") and text.contains(rules), "type line and full rules: %s" % text))
