class_name EventsSection
extends RefCounted
## The play area's Events section (068, 084, 115): a heading with the event piles' counts, the active events' row,
## and the Relieve button, shown while a Famine can be relieved. Hidden when the config has no event deck.

var box: VBoxContainer  # the section: heading, row, Relieve
var row: HBoxContainer  # the active events, in draw order
var _heading: Label
var _relieve: Button


func _init(parent: Control) -> void:
	box = UIKit.card_row_section(parent, "Events")
	row = box.get_meta("row")
	_heading = box.get_child(0)
	_relieve = UIKit.button("", func(): Game.engine.relieve_famine())
	_relieve.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_relieve)


func refresh(e: GameEngine) -> void:
	box.visible = not e.config.get("event_deck", {}).is_empty()
	_heading.text = "Events · deck %d · discard %d" % [e.zone("event_deck").size(), e.zone("event_discard").size()]
	_heading.tooltip_text = "One event is drawn at the end of each turn. It stays active until its turns run out."
	var waiting := e.zone("future_events").size()
	if waiting > 0:
		_heading.tooltip_text += "\n%d %s for a later era." % [waiting, "event waits" if waiting == 1 else "events wait"]
	# Relieve: shown while a Famine is active and has a relief price, disabled with the reason it can't pay.
	var relief := e.famine_relief()
	_relieve.visible = e.famine_counters() > 0 and not relief.is_empty()
	_relieve.text = "Relieve famine (%s)" % CardFace.cost_text(relief)
	var error := e.relieve_famine_error()
	_relieve.disabled = error != ""
	_relieve.tooltip_text = error if error != "" else "Pay to end the famine now. A later hungry upkeep brings a new one."


## {visible, info, tooltip}: the section and its heading, for main's event_panel test hook.
func info() -> Dictionary:
	return {"visible": box.visible, "info": _heading.text, "tooltip": _heading.tooltip_text}


## Where an event leaving the board flies: its heading's counts.
func heading_point() -> Vector2:
	return _heading.get_global_rect().get_center()
