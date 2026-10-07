class_name EventModal
extends Modal
## The drawn-event modal (backlog 079): when a turn start draws an event (237), a big card on the left and, on the right,
## how long it lasts and what it just did (GameEngine.outcome_summary). While on top it takes every key and click;
## Esc, Enter, OK or a click outside closes it. A choice event (269) shows its options as buttons in place of OK and
## can't be dismissed: a refused option is disabled with the engine's reason as its tooltip, and choosing closes it.

var _flavor: RichTextLabel
var _lasts: Label
var _summary: Label
var ok_button: Button
var option_buttons: Array[Button] = []  # a choice event's options, in order; [] for any other event
var _shown := {}  # what is shown; {} while hidden


## Builds the modal on stack's host, hidden: the event's card in the aside, what it did and how long it lasts in the
## body, OK in the footer; titled with the event, the turn as its context (207).
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]
	aside.visible = true
	body.custom_minimum_size.x = 420
	body.add_child(UIKit.heading("A new event"))
	_flavor = RichTextLabel.new()
	_flavor.bbcode_enabled = true
	_flavor.fit_content = true
	_flavor.theme_type_variation = &"RichBody"
	body.add_child(_flavor)
	_summary = UIKit.heading("")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_summary)
	_lasts = UIKit.heading("")
	_lasts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a raid's line names its target (162)
	body.add_child(_lasts)
	ok_button = add_footer_button(UIKit.button("OK (Enter)", close), true)


## Test hook: {uid, id, text, flavor, lasts, summary, options: the option buttons' texts} on show, {} while hidden.
func shown() -> Dictionary:
	return _shown if is_open() else {}


## Shows the event an event_drawn outcome reports, with what it just did.
func open(outcome: Dictionary) -> void:
	var e := Game.engine
	var def: CardDef = e.card_db[outcome.id]
	var summary := e.outcome_summary(outcome)
	var raid := e.military.raid_line(outcome.uid)  # a raid lasts until it strikes; it says where and against what (162)
	_shown = {"uid": outcome.uid, "id": def.id, "text": def.rules_text(e.card_db), "flavor": def.flavor,
		"lasts": raid if raid != "" else def.lasts_text(),
		"summary": summary if summary != "" else "No immediate effect"}
	_set_options(e, def, outcome.uid)
	_shown.options = option_buttons.map(func(b: Button): return b.text)
	title = def.name
	context = "Turn %d" % e.turn
	_flavor.text = CardDetailsModal.body_bbcode({"flavor": def.flavor, "rules": [], "state": [], "terms": []})
	_flavor.visible = def.flavor != ""
	_summary.text = _shown.summary
	_lasts.text = _shown.lasts
	show_card(def, e.card_db)
	present()
	if option_buttons.is_empty():  # a choice isn't made by Enter on whatever has focus
		FocusRing.focus(ok_button)


## A button per option of def (a choice event, uid) in the footer in place of OK, each disabled with its reason while
## refused; none, and OK, for any other event.
func _set_options(e: GameEngine, def: CardDef, uid: int) -> void:
	for b in option_buttons:
		b.queue_free()
	option_buttons.clear()
	for i in def.choices.size():
		var b := add_footer_button(UIKit.button(e.option_text(uid, i), func(): _choose(i)))
		b.tooltip_text = e.choose_option_error(i)
		b.disabled = b.tooltip_text != ""
		option_buttons.append(b)
	ok_button.visible = option_buttons.is_empty()
	dismissable = option_buttons.is_empty()


func _choose(index: int) -> void:
	if Game.engine.choose_option(index):
		close()


func closed() -> void:
	_shown = {}
