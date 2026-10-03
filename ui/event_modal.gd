class_name EventModal
extends Modal
## The drawn-event modal (backlog 079): when a turn start draws an event (237), a big card on the left and, on the right,
## how long it lasts and what it just did (GameEngine.outcome_summary). While on top it takes every key and click;
## Esc, Enter, OK or a click outside closes it.

var _flavor: RichTextLabel
var _lasts: Label
var _summary: Label
var ok_button: Button
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
	body.add_child(_lasts)
	ok_button = add_footer_button(UIKit.button("OK (Enter)", close), true)


## Test hook: {uid, id, text, flavor, lasts, summary} on show, {} while hidden.
func shown() -> Dictionary:
	return _shown if is_open() else {}


## Shows the event an event_drawn outcome reports, with what it just did.
func open(outcome: Dictionary) -> void:
	var e := Game.engine
	var def: CardDef = e.card_db[outcome.id]
	var summary := e.outcome_summary(outcome)
	_shown = {"uid": outcome.uid, "id": def.id, "text": def.rules_text(e.card_db), "flavor": def.flavor,
		"lasts": def.lasts_text(),
		"summary": summary if summary != "" else "No immediate effect"}
	title = def.name
	context = "Turn %d" % e.turn
	_flavor.text = CardDetailsModal.body_bbcode({"flavor": def.flavor, "rules": [], "state": [], "terms": []})
	_flavor.visible = def.flavor != ""
	_summary.text = _shown.summary
	_lasts.text = _shown.lasts
	for child in aside.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, def), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.custom_minimum_size = card.slot_size()
	card.attach(aside)
	present()
	FocusRing.focus(ok_button)


func closed() -> void:
	_shown = {}
