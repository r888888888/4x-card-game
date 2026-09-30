class_name CardDetailsModal
extends ColorRect
## The card details modal (backlog 056): a big card on the left and, on the right, the engine's full rules, live
## state and explanation of every mechanic the card uses (GameEngine.card_details / def_details). It sits on top of
## the board and blocks no engine action; while open it takes every key. Esc, I or a click outside closes it.

var _card_slot: Control
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _details := {}  # what is shown; {} while hidden


## Builds the modal on parent, hidden.
func _init(parent: Control) -> void:
	color = Palette.SCRIM
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20  # above the menu, the supply screen and flying cards
	visible = false
	gui_input.connect(_on_dimmer_input)
	parent.add_child(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a click beside the panel reaches the dimmer and closes
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	panel.add_child(row)
	_card_slot = Control.new()
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_card_slot)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 10)
	row.add_child(text)
	_title = UIKit.title("")
	text.add_child(_title)
	_subtitle = UIKit.heading("")
	text.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(620, 0)
	_body.add_theme_font_size_override("normal_font_size", 19)
	_body.add_theme_font_size_override("bold_font_size", 19)
	_body.add_theme_font_size_override("italics_font_size", 19)
	text.add_child(_body)
	text.add_child(UIKit.button("Close (Esc)", close))


## Test hook: the details on show, {} while hidden.
func shown() -> Dictionary:
	return _details if visible else {}


## Test hook: the body text on show, without markup.
func body_text() -> String:
	return _body.get_parsed_text()


## Opens the details of the card view shows: its live copy, or its definition for a supply pile.
func open(view: CardView) -> void:
	var details := Game.engine.card_details(view.uid)
	_show(details if not details.is_empty() else Game.engine.def_details(view.card_id), view.card_id)


## Opens the details of card definition card_id (a tech in the tree).
func open_def(card_id: String) -> void:
	_show(Game.engine.def_details(card_id), card_id)


func _show(details: Dictionary, card_id: String) -> void:
	if details.is_empty():
		return
	var e := Game.engine
	_details = details
	_title.text = details.name
	var facts: PackedStringArray = [details.type]
	if details.cost != "":
		facts.append(details.cost)
	if details.vp > 0:
		facts.append("%d VP" % details.vp)
	_subtitle.text = " · ".join(facts)
	_body.text = _body_text(details)
	for child in _card_slot.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, e.card_db[card_id]), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_slot.custom_minimum_size = card.slot_size()
	card.attach(_card_slot)
	show()


func close() -> void:
	hide()
	_details = {}


static func _body_text(details: Dictionary) -> String:
	var parts: PackedStringArray = []
	if details.get("flavor", "") != "":
		parts.append("[i]%s[/i]" % details.flavor)
	var quote: Dictionary = details.get("quote", {})
	if not quote.is_empty():
		parts.append("“%s”\n— %s" % [quote.text, quote.by])
	if not details.rules.is_empty():
		parts.append("[b]Rules[/b]\n" + "\n".join(PackedStringArray(details.rules)))
	if not details["state"].is_empty():
		parts.append("[b]Now[/b]\n" + "\n".join(PackedStringArray(details["state"])))
	var terms: PackedStringArray = []
	for t in details.terms:
		terms.append("[color=#ffd966]%s[/color]: %s" % [t.term, t.text])
	if not terms.is_empty():
		parts.append("[b]How it works[/b]\n" + "\n".join(terms))
	return "\n\n".join(parts)


## While open, every key stops here: Esc and I close, the rest do nothing.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_I]:
		close()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()
