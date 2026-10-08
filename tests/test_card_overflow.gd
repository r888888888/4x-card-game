extends "res://tests/lib/test_case.gd"
## Overflowing card text (383): a hand-size face keeps its 264 × 360 size and shows whole rules only, with a foot
## (`Over`) counting the rest ("+N more"; on a card in the hand row also "details I"). On a hand-row card, resting the
## pointer raises the text sheet over the art plate as far as the hidden rules need (capped at the plate and its gap);
## if rules are still hidden the foot's meter fills, then a rules popover opens beside the card. Keyboard focus raises
## the sheet at once. Hand cards set no tooltip. CardViews run in a plain Control tree (a slot and a layer for the
## popover), their peek clock driven by the test (`advance`), never by waiting.

const INTENT := 0.12  # Anim.OVERFLOW_INTENT
const SLIDE := 0.12  # Anim.OVERFLOW_SLIDE
const WAIT := 1.1  # Anim.OVERFLOW_WAIT
const CAP := 104.0  # the art plate (96) and its gap (8)
const POPOVER_WIDTH := 320.0

## Fixture cards, all with hand-written text (one rule a line): Long (16 one-line rules), Short (2), Medium (8: cut at
## rest, whole once risen), Essay (one paragraph of 14 sentences), Giant (one paragraph whose first sentence alone is
## taller than the rules area, then a short one), Tail (4 one-line rules, then a long paragraph).
const LONG := {"id": "long", "name": "Long", "type": "action", "text": "Rule 1: +1 food.\nRule 2: +1 food.\n" +
	"Rule 3: +1 food.\nRule 4: +1 food.\nRule 5: +1 food.\nRule 6: +1 food.\nRule 7: +1 food.\nRule 8: +1 food.\n" +
	"Rule 9: +1 food.\nRule 10: +1 food.\nRule 11: +1 food.\nRule 12: +1 food.\nRule 13: +1 food.\n" +
	"Rule 14: +1 food.\nRule 15: +1 food.\nRule 16: +1 food."}
const SHORT := {"id": "short", "name": "Short", "type": "action", "text": "Rule 1: +1 food.\nRule 2: +1 food."}
const MEDIUM := {"id": "medium", "name": "Medium", "type": "action", "text": "Rule 1: +1 food.\nRule 2: +1 food.\n" +
	"Rule 3: +1 food.\nRule 4: +1 food.\nRule 5: +1 food.\nRule 6: +1 food.\nRule 7: +1 food.\nRule 8: +1 food."}
const ESSAY := {"id": "essay", "name": "Essay", "type": "action", "text": "One is here. Two is here. Three is here. " +
	"Four is here. Five is here. Six is here. Seven is here. Eight is here. Nine is here. Ten is here. " +
	"Eleven is here. Twelve is here. Thirteen is here. Fourteen is here."}
const GIANT := {"id": "giant", "name": "Giant", "type": "action", "text": "This first sentence goes on and on " +
	"with word after word after word after word after word after word after word after word after word after word " +
	"after word after word after word after word after word after word after word after word after word after word " +
	"after word after word after word after word after word after word after word after word after word after word " +
	"until it ends. Two."}
const TAIL := {"id": "tail", "name": "Tail", "type": "action", "text": "Rule 1: +1 food.\nRule 2: +1 food.\n" +
	"Rule 3: +1 food.\nRule 4: +1 food.\nThen a long paragraph that wraps over many lines of the card, one more " +
	"clause after another. It has a second sentence that also runs on for a while. And a third one, to be sure " +
	"it is far taller than the room that is left under the four short rules above it."}
const FIXTURES := [LONG, SHORT, MEDIUM, ESSAY, GIANT, TAIL]

var _engine: GameEngine


func overflow_engine() -> GameEngine:
	if _engine == null:
		_engine = make_engine({"farm": 10}, {}, 1, FIXTURES)
	return _engine


## A root with a slot at at and a layer, and a hand-size CardView of card id resting in the slot, its peek clock
## driven by the test; in_row: a hand-row card (peek_on the layer). Returns {root, slot, layer, view}; free root when
## done. Use with await (it lays out).
func fixture(id: String, in_row := true, at := Vector2(100, 200), in_hand := true) -> Dictionary:
	var e := overflow_engine()
	var root := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(root)
	root.size = Vector2((Engine.get_main_loop() as SceneTree).root.get_visible_rect().size)
	var slot := Control.new()
	slot.custom_minimum_size = CardView.HAND_SIZE
	slot.size = CardView.HAND_SIZE
	slot.position = at
	root.add_child(slot)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layer)
	var view: Variant = CardView.new()
	view.setup(CardInstance.new(900, e.card_db[id]), e.card_db, in_hand)
	view.attach(slot)
	if "peek" in view:  # red phase: peek doesn't exist yet
		view.peek.manual_clock = true
		if in_row:
			view.peek_on(layer)
	await wait_frames()
	return {"root": root, "slot": slot, "layer": layer, "view": view}


## The face's rules box (one label per rule), or null.
func rules_box(view: Variant) -> Control:
	return view.find_child("Rules", true, false) as Control


## The rule labels shown, in order.
func shown_rules(view: Variant) -> Array:
	var box := rules_box(view)
	return [] if box == null else box.get_children().filter(func(c): return c is Control and c.visible)


## A rule label's text, glyphs as written.
func rule_text(label: Control) -> String:
	return label.get_meta("source", label.get_parsed_text()) if label is RichTextLabel else (label as Label).text


## The texts of the foot's visible labels in order ([] with no foot shown).
func over_texts(view: Variant) -> Array:
	var foot := view.find_child("Over", true, false) as Control
	if foot == null or not foot.is_visible_in_tree():
		return []
	var out := []
	for c in foot.find_children("*", "", true, false):
		if c is Control and c.is_visible_in_tree() and (c is Label or c is RichTextLabel):
			out.append(rule_text(c))
	return out


## N in the foot's "+N more", or 0 with no foot.
func hidden_count(view: Variant) -> int:
	var texts := over_texts(view)
	if texts.is_empty():
		return 0
	var m := RegEx.create_from_string("^\\+(\\d+) more$").search(texts[0])
	return int(m.get_string(1)) if m != null else -1


## Checks every rule shown lies wholly inside the rules box, and the box inside the card.
func check_whole_rules(view: Variant, what: String) -> void:
	var box := rules_box(view)
	check(box != null, "%s: a Rules box" % what)
	if box == null:
		return
	var area := box.get_global_rect().grow(0.5)
	check((view.get_global_rect() as Rect2).grow(0.5).encloses(box.get_global_rect()), "%s: the rules box is inside the card" % what)
	for label: Control in shown_rules(view):
		check(area.encloses(label.get_global_rect()), "%s: '%s' is wholly inside the rules area (%s in %s)" % [what,
			rule_text(label), label.get_global_rect(), box.get_global_rect()])


## The open popover's text (heading and lines), or "" when none is open.
func popover_text(view: Variant) -> String:
	var pop: Variant = view.peek.popover
	return pop.text() if pop != null and is_instance_valid(pop) else ""


func push(view: Variant, event: InputEvent) -> void:
	(view as Control).get_viewport().push_input(event, true)


func motion(view: Variant, at: Vector2, held := false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	push(view, event)


func press(view: Variant, at: Vector2, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	push(view, event)


## Rests the pointer on view and runs its clock through the intent and the slide: the sheet is up.
func raise(view: Variant) -> void:
	view.mouse_entered.emit()
	view.peek.advance(INTENT)
	view.peek.advance(SLIDE)


## raise, then the meter's whole wait: the popover is open.
func open_popover(view: Variant) -> void:
	raise(view)
	view.peek.advance(WAIT + 0.01)


func test_the_overflow_timings_are_anim_constants() -> void:
	var consts: Dictionary = (Anim as Script).get_script_constant_map()
	eq([consts.get("OVERFLOW_INTENT"), consts.get("OVERFLOW_SLIDE"), consts.get("OVERFLOW_WAIT")], [INTENT, SLIDE, WAIT],
		"Anim.OVERFLOW_INTENT, _SLIDE and _WAIT")


# --- AC1: whole rules at rest, a foot counting the rest ---

func test_a_long_card_keeps_its_size_and_shows_only_whole_rules() -> void:
	var f := await fixture("long")
	eq(f.view.size, CardView.HAND_SIZE, "the card stays 264 × 360")
	var shown := shown_rules(f.view)
	check(shown.size() >= 1 and shown.size() < 16, "some rules shown, some hidden: %d" % shown.size())
	check_whole_rules(f.view, "long at rest")
	eq(shown.map(rule_text), Array(LONG.text.split("\n")).slice(0, shown.size()), "the first rules, in order")
	eq(hidden_count(f.view), 16 - shown.size(), "the foot counts the hidden rules")
	(f.root as Node).free()


func test_a_short_card_has_no_foot() -> void:
	var f := await fixture("short")
	eq(shown_rules(f.view).map(rule_text), Array(SHORT.text.split("\n")), "both rules shown")
	eq(over_texts(f.view), [], "no foot")
	(f.root as Node).free()


func test_a_one_paragraph_rule_is_cut_after_its_last_whole_sentence() -> void:
	var f := await fixture("essay")
	var shown := shown_rules(f.view)
	eq(shown.size(), 1, "the paragraph shows")
	if shown.size() == 1:
		var text := rule_text(shown[0]).strip_edges()
		check(text != ESSAY.text and ESSAY.text.begins_with(text) and text.ends_with("."),
			"cut after a whole sentence: '%s'" % text)
		var kept := text.count(".")
		check(kept >= 1, "at least its first sentence")
		eq(hidden_count(f.view), 14 - kept, "the foot counts the hidden sentences")
	check_whole_rules(f.view, "essay")
	(f.root as Node).free()


func test_a_paragraph_whose_first_sentence_cannot_fit_is_hidden_whole() -> void:
	var f := await fixture("giant")
	eq(shown_rules(f.view).size(), 0, "no part of it shows")
	eq(hidden_count(f.view), 2, "both sentences counted hidden")
	(f.root as Node).free()


func test_a_rule_that_does_not_fit_after_others_is_hidden_whole() -> void:
	var f := await fixture("tail")
	eq(shown_rules(f.view).map(rule_text), Array(TAIL.text.split("\n")).slice(0, 4), "the four short rules, not a part of the paragraph")
	eq(hidden_count(f.view), 1, "+1 more")
	check_whole_rules(f.view, "tail")
	(f.root as Node).free()


# --- AC2: the foot on the hand row and in modals ---

func test_a_hand_row_card_foot_adds_details_i() -> void:
	var f := await fixture("long")
	var texts := over_texts(f.view)
	eq(texts.slice(1), ["details", "I"], "the foot's right side")
	check(texts.size() > 0 and texts[0].ends_with(" more"), "led by +N more: %s" % [texts])
	(f.root as Node).free()


func test_a_hand_size_face_off_the_hand_row_reads_only_more_and_never_peeks() -> void:
	var f := await fixture("long", false)
	eq(over_texts(f.view).size(), 1, "only +N more: %s" % [over_texts(f.view)])
	f.view.mouse_entered.emit()
	f.view.peek.advance(INTENT + SLIDE + WAIT + 0.5)
	eq([f.view.peek.rise(), f.view.peek.meter(), f.view.peek.popover], [0.0, 0.0, null], "it never reacts to hover")
	(f.root as Node).free()


func test_in_the_real_hand_the_foot_says_details_and_the_details_card_does_not() -> void:
	var e := make_engine({"farm": 10}, {}, 1, FIXTURES)
	await with_main(e, func(main: Node):
		var uid := put_in_hand(e, "long")
		e.changed.emit()
		await settle_motion()
		var view: Variant = main.views[uid]
		eq(over_texts(view).slice(1), ["details", "I"], "the hand card's foot")
		open_details(main, uid)
		await wait_frames()
		var shown: Variant = card_under(main.details.aside)
		check(shown != null, "the details show the card")
		if shown != null:
			eq(over_texts(shown).size(), 1, "the details card: only +N more: %s" % [over_texts(shown)])
			shown.peek.manual_clock = true
			shown.mouse_entered.emit()
			shown.peek.advance(INTENT + SLIDE + WAIT + 0.5)
			eq([shown.peek.rise(), shown.peek.popover], [0.0, null], "the details card never reacts to hover"))


# --- AC3: the sheet rises over the art ---

func test_resting_on_a_long_card_raises_its_sheet_to_the_cap() -> void:
	var f := await fixture("long")
	var at_rest := shown_rules(f.view).size()
	f.view.mouse_entered.emit()
	f.view.peek.advance(INTENT - 0.01)
	eq(f.view.peek.rise(), 0.0, "not before the intent")
	f.view.peek.advance(0.01 + SLIDE / 2)
	var mid: float = f.view.peek.rise()
	check(mid > 0.0 and mid < CAP, "easing up mid-slide: %s" % mid)
	f.view.peek.advance(SLIDE / 2)
	check(absf(f.view.peek.rise() - CAP) < 0.5, "up by the plate and its gap: %s" % f.view.peek.rise())
	eq(f.view.size, CardView.HAND_SIZE, "the card keeps its size")
	check(shown_rules(f.view).size() > at_rest, "more rules shown: %d > %d" % [shown_rules(f.view).size(), at_rest])
	eq(hidden_count(f.view), 16 - shown_rules(f.view).size(), "the foot recounts")
	check_whole_rules(f.view, "long, risen")
	(f.root as Node).free()


func test_a_medium_card_rises_only_as_far_as_its_hidden_rules_need() -> void:
	var f := await fixture("medium")
	check(hidden_count(f.view) > 0, "precondition: medium is cut at rest")
	raise(f.view)
	var up: float = f.view.peek.rise()
	check(up > 0.0 and up < CAP, "risen less than the cap: %s" % up)
	eq(shown_rules(f.view).size(), 8, "every rule shown")
	eq(over_texts(f.view), [], "no foot")
	check_whole_rules(f.view, "medium, risen")
	var last: Control = shown_rules(f.view)[-1]
	var gap := rules_box(f.view).get_global_rect().end.y - last.get_global_rect().end.y
	check(gap >= 0.0 and gap < 4.0, "no further than needed: %s px under the last rule" % gap)
	(f.root as Node).free()


func test_leaving_or_moving_before_the_intent_changes_nothing() -> void:
	var f := await fixture("long")
	f.view.mouse_entered.emit()
	f.view.peek.advance(INTENT - 0.02)
	f.view.mouse_exited.emit()
	f.view.peek.advance(1.0)
	eq(f.view.peek.rise(), 0.0, "left before the intent: nothing")
	motion(f.view, Vector2(5, 5))
	await wait_frames()
	motion(f.view, centre(f.view))
	await wait_frames()
	f.view.peek.advance(INTENT - 0.02)
	motion(f.view, centre(f.view) + Vector2(4, 0))
	await wait_frames()
	f.view.peek.advance(0.04)
	eq(f.view.peek.rise(), 0.0, "a move restarts the wait")
	f.view.peek.advance(INTENT + SLIDE)
	check(f.view.peek.rise() > 0.0, "resting again raises it")
	motion(f.view, Vector2(5, 5))
	await wait_frames()
	(f.root as Node).free()


func test_leaving_after_the_rise_restores_the_rest_layout() -> void:
	var f := await fixture("long")
	var at_rest := hidden_count(f.view)
	raise(f.view)
	f.view.mouse_exited.emit()
	f.view.peek.advance(SLIDE)
	eq([f.view.peek.rise(), hidden_count(f.view)], [0.0, at_rest], "back at rest, cut as before")
	check_whole_rules(f.view, "long, back at rest")
	(f.root as Node).free()


func test_a_short_card_never_rises() -> void:
	var f := await fixture("short")
	raise(f.view)
	f.view.peek.advance(WAIT + 0.5)
	eq([f.view.peek.rise(), f.view.peek.meter(), f.view.peek.popover], [0.0, 0.0, null], "nothing moves")
	(f.root as Node).free()


# --- AC4: the meter, then the popover ---

func test_still_hidden_rules_fill_the_meter_then_open_the_popover() -> void:
	var f := await fixture("long")
	raise(f.view)
	check(hidden_count(f.view) > 0, "precondition: rules still hidden once risen")
	eq(f.view.peek.meter(), 0.0, "the meter starts empty")
	f.view.peek.advance(WAIT / 2)
	check(absf(f.view.peek.meter() - 0.5) < 0.02, "half full halfway (linear): %s" % f.view.peek.meter())
	eq(f.view.peek.popover, null, "no popover yet")
	f.view.peek.advance(WAIT / 2 + 0.01)
	eq(f.view.peek.meter(), 1.0, "full")
	var text := popover_text(f.view)
	check(text.contains("Long"), "the popover names the card: %s" % text)
	for line in overflow_engine().card_db["long"].rules_tooltip(overflow_engine().card_db).split("\n"):
		check(text.contains(line), "and holds '%s'" % line)
	(f.root as Node).free()


func test_the_popover_adds_the_play_error_and_its_detail() -> void:
	var f := await fixture("long")
	f.view.set_play_error("Not enough food.", "Needs 2 more food.")
	open_popover(f.view)
	var text := popover_text(f.view)
	check(text.contains("Not enough food.") and text.contains("Needs 2 more food."), "error and detail: %s" % text)
	(f.root as Node).free()


func test_the_popover_opens_right_of_the_card_or_left_without_room() -> void:
	var f := await fixture("long", true, Vector2(100, 200))
	open_popover(f.view)
	var pop: Control = f.view.peek.popover
	check(pop != null, "open")
	if pop != null:
		eq(pop.size.x, POPOVER_WIDTH, "320 px wide")
		check(pop.get_global_rect().position.x >= f.view.get_global_rect().end.x, "right of the card")
	(f.root as Node).free()
	var width: float = (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size.x
	var g := await fixture("long", true, Vector2(width - CardView.HAND_SIZE.x - 20, 200))
	open_popover(g.view)
	pop = g.view.peek.popover
	check(pop != null and pop.get_global_rect().end.x <= g.view.get_global_rect().position.x, "left of it at the edge")
	(g.root as Node).free()


func test_no_meter_or_popover_when_everything_fits_once_risen() -> void:
	var f := await fixture("medium")
	raise(f.view)
	f.view.peek.advance(WAIT + 0.5)
	eq([f.view.peek.meter(), f.view.peek.popover], [0.0, null], "no meter, no popover")
	(f.root as Node).free()


# --- AC5: the popover is not a modal; a press goes through ---

func test_the_pointer_may_cross_onto_the_popover_and_leaving_both_closes_it() -> void:
	var f := await fixture("long")
	motion(f.view, Vector2(5, 5))
	await wait_frames()
	motion(f.view, centre(f.view))
	await wait_frames()
	f.view.peek.advance(INTENT)
	f.view.peek.advance(SLIDE)
	f.view.peek.advance(WAIT + 0.01)
	var pop: Control = f.view.peek.popover
	check(pop != null, "precondition: open")
	if pop != null:
		motion(f.view, centre(pop))
		await wait_frames()
		f.view.peek.advance(INTENT + SLIDE)
		check(f.view.peek.popover != null, "still open on the popover")
		motion(f.view, Vector2(5, 5))
		await wait_frames()
		f.view.peek.advance(INTENT + SLIDE)
		eq([f.view.peek.popover, f.view.peek.rise()], [null, 0.0], "leaving both closes it and lowers the sheet")
	(f.root as Node).free()


func test_esc_or_a_press_anywhere_closes_the_popover() -> void:
	var f := await fixture("long")
	open_popover(f.view)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	push(f.view, esc)
	await wait_frames()
	eq(f.view.peek.popover, null, "Esc closes it")
	f.view.mouse_exited.emit()
	f.view.peek.advance(SLIDE)
	open_popover(f.view)
	press(f.view, Vector2(5, 5))
	press(f.view, Vector2(5, 5), false)
	await wait_frames()
	eq(f.view.peek.popover, null, "a press elsewhere closes it")
	(f.root as Node).free()


func test_a_press_on_the_card_cancels_any_step_and_still_drags() -> void:
	for step in ["waiting", "rising", "filling", "open"]:
		var f := await fixture("long")
		var drags := []
		f.view.drag_requested.connect(func(_v, _o): drags.append(1))
		motion(f.view, Vector2(5, 5))
		await wait_frames()
		motion(f.view, centre(f.view))
		await wait_frames()
		f.view.peek.advance({"waiting": INTENT / 2, "rising": INTENT + SLIDE / 2, "filling": INTENT + SLIDE + WAIT / 2,
			"open": INTENT + SLIDE + WAIT + 0.01}[step])
		var at := centre(f.view)
		press(f.view, at)
		await wait_frames()
		eq(f.view.peek.popover, null, "%s: no popover after the press" % step)
		f.view.peek.advance(WAIT + 1.0)
		eq([f.view.peek.meter(), f.view.peek.popover], [0.0, null], "%s: the step is cancelled" % step)
		motion(f.view, at + Vector2(20, 0), true)
		await wait_frames()
		eq(drags.size(), 1, "%s: the press goes on to drag" % step)
		press(f.view, at + Vector2(20, 0), false)
		motion(f.view, Vector2(5, 5))
		await wait_frames()
		(f.root as Node).free()


func test_hand_cards_set_no_tooltip_and_other_cards_keep_theirs() -> void:
	var f := await fixture("long")
	eq(f.view.tooltip_text, "", "a hand card: none")
	f.view.set_play_error("Not enough food.", "Needs 2 more food.")
	eq(f.view.tooltip_text, "", "none while unplayable either")
	(f.root as Node).free()
	var g := await fixture("long", false, Vector2(100, 200), false)
	check(g.view.tooltip_text != "", "a tableau card keeps its tooltip")
	(g.root as Node).free()


# --- AC6: keyboard focus and Reduce motion ---

func test_keyboard_focus_raises_the_sheet_at_once_with_no_meter() -> void:
	var f := await fixture("long")
	f.view.set_focused(true)
	f.view.peek.advance(SLIDE)
	check(absf(f.view.peek.rise() - CAP) < 0.5, "risen with no wait: %s" % f.view.peek.rise())
	f.view.peek.advance(WAIT + 0.5)
	eq([f.view.peek.meter(), f.view.peek.popover], [0.0, null], "no meter, no popover")
	f.view.set_focused(false)
	f.view.peek.advance(SLIDE)
	eq(f.view.peek.rise(), 0.0, "focus leaving lowers it")
	(f.root as Node).free()


func test_reduce_motion_jumps_the_sheet_steps_the_meter_and_places_the_popover() -> void:
	await with_reduce_motion(true, func():
		var f := await fixture("long")
		f.view.mouse_entered.emit()
		f.view.peek.advance(INTENT + 0.001)
		check(absf(f.view.peek.rise() - CAP) < 0.5, "the sheet jumps up: %s" % f.view.peek.rise())
		var fills := []
		for t in [0.3, 0.1, 0.3, 0.41]:  # at 0.3, 0.4, 0.7 and 1.11 of WAIT's 1.1 s
			f.view.peek.advance(t)
			fills.append(snappedf(f.view.peek.meter(), 0.01))
		eq(fills, [0.0, 0.33, 0.67, 1.0], "the meter fills in three equal steps")
		var pop: Control = f.view.peek.popover
		check(pop != null, "open")
		if pop != null:
			var where := pop.position
			f.view.peek.advance(0.3)
			eq(pop.position, where, "it appears in place, with no slide")
		(f.root as Node).free())
