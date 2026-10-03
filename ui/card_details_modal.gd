class_name CardDetailsModal
extends Modal
## The card details modal (backlog 056): a big card on the left and, on the right, the engine's full rules, live
## state and explanation of every mechanic the card uses (GameEngine.card_details / def_details). It sits on top of
## the board and blocks no engine action; while on top it takes every key. Esc, I or a click outside closes it.
## A hand card's details also offer Play (225), and a tech's from the Knowledge screen Research (229), each disabled
## with the engine's reason when it can't be done.

## Play was pressed on a hand card's details: the modal has closed, and view is the card to play.
signal play_requested(view: CardView)

var _subtitle: Label
var _body: RichTextLabel
var _details := {}  # what is shown; {} while hidden
var _play: Button
var _view: CardView  # the hand card Play plays; null when Play is hidden
var _research: Button
var _tech := -1  # the uid of the tech Research learns; -1 when Research is hidden


## Builds the modal on stack's host, hidden: the card in the aside, its facts and text in the body, Close and (for a
## hand card) Play or (for a tech to learn) Research in the footer (207, 225, 229).
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_I]
	aside.visible = true
	_subtitle = UIKit.heading("")
	body.add_child(_subtitle)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(BODY_MAX_WIDTH - Tokens.SPACE_6, 0)
	_body.theme_type_variation = &"RichBody"
	body.add_child(_body)
	add_footer_button(UIKit.button("Close (Esc)", close))
	_play = add_footer_button(UIKit.button("Play", _on_play), true)
	_research = add_footer_button(UIKit.button("Learn", _on_research), true)  # the card called Research has that word


## Test hook: the details on show, {} while hidden.
func shown() -> Dictionary:
	return _details if is_open() else {}


## Test hook (225): the Play button, hidden unless a hand card's details are on show.
func play_button() -> Button:
	return _play


## Test hook (229): the Research button, hidden unless a tech to learn is on show.
func research_button() -> Button:
	return _research


## Test hook: the body text on show, without markup.
func body_text() -> String:
	return _body.get_parsed_text()


## Opens the details of the card view shows: its live copy, or its definition for a supply pile. A hand card's
## details offer Play.
func open(view: CardView) -> void:
	var details := Game.engine.card_details(view.uid)
	_show(details if not details.is_empty() else Game.engine.def_details(view.card_id), view.card_id,
		view if view.in_hand else null)


## Opens the details of card definition card_id (a tech in the tree).
func open_def(card_id: String) -> void:
	_show(Game.engine.def_details(card_id), card_id)


## Opens the details of tech card_id from the Knowledge screen; uid is the tech to learn, whose details offer Research,
## or -1 (researched, or a later era's).
func open_tech(card_id: String, uid: int) -> void:
	_show(Game.engine.def_details(card_id), card_id, null, uid)


func _show(details: Dictionary, card_id: String, hand_view: CardView = null, tech := -1) -> void:
	if details.is_empty():
		return
	var e := Game.engine
	_details = details
	_view = hand_view
	_tech = tech
	_research.visible = tech >= 0
	if tech >= 0:
		var reason := e.buy_tech_error(tech)
		_research.disabled = reason != ""
		_research.tooltip_text = reason
	_play.visible = hand_view != null
	if hand_view != null:
		var error := e.playable_error(hand_view.uid)
		_play.disabled = error != ""
		_play.tooltip_text = error
	title = details.name
	context = details.type.capitalize()
	var facts: PackedStringArray = []
	if details.cost != "":
		facts.append(details.cost)
	if details.vp > 0:
		facts.append("%d VP" % details.vp)
	_subtitle.text = " · ".join(facts)
	_subtitle.visible = not facts.is_empty()
	_body.text = body_bbcode(details)
	for child in aside.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, e.card_db[card_id]), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.custom_minimum_size = card.slot_size()
	card.attach(aside)
	present()  # last among its siblings, so a screen added later (the new game screen) can't take its input (107)


func closed() -> void:
	_details = {}
	_view = null
	_tech = -1


func _on_play() -> void:
	var view := _view
	close()
	if view != null and is_instance_valid(view):
		play_requested.emit(view)


func _on_research() -> void:
	var tech := _tech
	close()
	if Game.engine.buy_tech_error(tech) == "":
		Game.engine.buy_tech(tech)


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
