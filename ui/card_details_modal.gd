class_name CardDetailsModal
extends Modal
## The card details modal (backlog 056): a big card on the left and, on the right, the engine's full rules, live
## state and explanation of every mechanic the card uses (GameEngine.card_details / def_details). It sits on top of
## the board and blocks no engine action; while on top it takes every key. Esc, I or a click outside closes it.

var _card_slot: Control
var _title: Label
var _subtitle: Label
var _body: RichTextLabel
var _details := {}  # what is shown; {} while hidden
var _action_button: Button  # an optional action beside Close, e.g. "Play as …" on the new game screen (107)
var _action := Callable()


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_I]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_6)
	panel.add_child(row)
	_card_slot = Control.new()
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_card_slot)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", Tokens.SPACE_3)
	row.add_child(text)
	_title = UIKit.title("")
	text.add_child(_title)
	_subtitle = UIKit.heading("")
	text.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(620, 0)
	_body.theme_type_variation = &"RichBody"
	text.add_child(_body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", Tokens.SPACE_3)
	text.add_child(buttons)
	_action_button = UIKit.button("", _on_action)
	buttons.add_child(_action_button)
	buttons.add_child(UIKit.button("Close (Esc)", close))


## Test hook: the details on show, {} while hidden.
func shown() -> Dictionary:
	return _details if visible else {}


## Test hook: the body text on show, without markup.
func body_text() -> String:
	return _body.get_parsed_text()


## Test hook: the optional action button (hidden when the details were opened without an action).
func action_button() -> Button:
	return _action_button


## Opens the details of the card view shows: its live copy, or its definition for a supply pile. With an action,
## a button labelled action_text closes the details and calls it.
func open(view: CardView, action_text := "", action := Callable()) -> void:
	var details := Game.engine.card_details(view.uid)
	_show(details if not details.is_empty() else Game.engine.def_details(view.card_id), view.card_id)
	_action = action
	_action_button.text = action_text
	_action_button.visible = action.is_valid()


## Opens the details of card definition card_id (a tech in the tree).
func open_def(card_id: String) -> void:
	_show(Game.engine.def_details(card_id), card_id)
	_action = Callable()
	_action_button.visible = false


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
	_body.text = body_bbcode(details)
	for child in _card_slot.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, e.card_db[card_id]), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_slot.custom_minimum_size = card.slot_size()
	card.attach(_card_slot)
	present()  # last among its siblings, so a screen added later (the new game screen) can't take its input (107)


func closed() -> void:
	_details = {}


func _on_action() -> void:
	var action := _action
	close()
	action.call()


## The body for details (from GameEngine.card_details / def_details) as BBCode: flavor, quote, rules, state and terms,
## each only when it has something (also the identity modal's sections, 119).
static func body_bbcode(details: Dictionary) -> String:
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
