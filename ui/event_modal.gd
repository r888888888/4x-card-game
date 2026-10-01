class_name EventModal
extends Modal
## The drawn-event modal (backlog 079): when the event phase draws an event, a big card on the left and, on the right,
## how long it lasts and what it just did (GameEngine.outcome_summary). While on top it takes every key and click;
## Esc, Enter, OK or a click outside closes it.

var _card_slot: Control
var _title: Label
var _lasts: Label
var _summary: Label
var ok_button: Button
var _shown := {}  # what is shown; {} while hidden


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]
	panel.add_theme_stylebox_override("panel", GameTheme.dark_panel(Palette.EVENT))  # bordered in the event colour
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	_card_slot = Control.new()
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_card_slot)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 10)
	text.custom_minimum_size.x = 420
	row.add_child(text)
	text.add_child(UIKit.heading("A new event"))
	_title = UIKit.title("")
	text.add_child(_title)
	_summary = UIKit.heading("")
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_summary)
	_lasts = UIKit.heading("")
	text.add_child(_lasts)
	ok_button = UIKit.button("OK (Enter)", close)
	text.add_child(ok_button)


## Test hook: {uid, id, text, lasts, summary} on show, {} while hidden.
func shown() -> Dictionary:
	return _shown if visible else {}


## Shows the event an event_drawn outcome reports, with what it just did.
func open(outcome: Dictionary) -> void:
	var e := Game.engine
	var def: CardDef = e.card_db[outcome.id]
	var summary := e.outcome_summary(outcome)
	_shown = {"uid": outcome.uid, "id": def.id, "text": def.rules_text(e.card_db), "lasts": def.lasts_text(),
		"summary": summary if summary != "" else "No immediate effect"}
	_title.text = def.name
	_summary.text = _shown.summary
	_lasts.text = _shown.lasts
	for child in _card_slot.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, def), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_slot.custom_minimum_size = card.slot_size()
	card.attach(_card_slot)
	present()
	ok_button.grab_focus()


func closed() -> void:
	_shown = {}
