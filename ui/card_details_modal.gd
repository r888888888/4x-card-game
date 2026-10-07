class_name CardDetailsModal
extends Modal
## The card details modal (backlog 056): a big card on the left and, on the right, the engine's full rules, live
## state and explanation of every mechanic the card uses (GameEngine.card_details / def_details). It sits on top of
## the board and blocks no engine action; while on top it takes every key. Esc, I or a click outside closes it.
## A hand card's details also offer Play (225), and a tech's from the Knowledge screen Research (229), each disabled
## with the engine's reason when it can't be done. A unit's in the realm offer Move… and Disband (163), likewise.
## A supply pile's, opened from the supply screen, show the pile's price tag and copies left under the card and offer
## Buy, disabled with the engine's reason on the footer's left when the pile can't be bought (259). A wonder site's
## offer Contribute, which puts in GameEngine.contribute_limit, and Abandon…, which asks first (286).
## A tech's show the cards it gives in a Gives row across the sheet, each captioned with how you get it; a click, or
## Enter or I on a focused one, opens that card's details on given_details, over this one (289).

## Play was pressed on a hand card's details: the modal has closed, and view is the card to play.
signal play_requested(view: CardView)
## Buy was pressed on a supply pile's details: the modal has closed, and view is the pile card to buy from (259).
signal buy_requested(view: CardView)
## Move… was pressed on a unit's details: the modal has closed, and uid is the unit to move (163).
signal move_requested(uid: int)

var _subtitle: Label
var _body: RichTextLabel
var _details := {}  # what is shown; {} while hidden
var _play: Button
var _view: CardView  # the hand card Play plays; null when Play is hidden
var _research: Button
var _tech := -1  # the uid of the tech Research learns; -1 when Research is hidden
var _move: Button
var _disband: Button
var _upgrade: Button  # re-equips the unit as its upgrade (166); hidden unless it has one
var _unit := -1  # the unit in the realm Move…, Disband and Upgrade act on (163, 166); -1 when they are hidden
var _contribute: Button
var _abandon: Button
var _site := -1  # the wonder site Contribute and Abandon… act on (286); -1 when they are hidden
var abandon_modal: AbandonModal  # Abandon…'s confirmation, on this modal's stack (286)
var _buy: Button
var _reason: Label  # why Buy is disabled, on the footer's left (259)
var _pile: CardView  # the supply pile card Buy buys from; null when Buy is hidden
var _column: VBoxContainer  # the pile's card, price tag and copies left in the aside; null unless a pile is on show
var _gives: VBoxContainer  # the Gives row (289): its heading and the cards; hidden when the card gives nothing
var _gives_row: HBoxContainer  # per given card, a column: its card as a button, its caption under it
var given_details: CardDetailsModal  # where a Gives card's details open, over this one; built on first use


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
	_reason = Label.new()
	_reason.theme_type_variation = &"Refusal"
	_reason.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.visible = false
	footer.add_child(_reason)
	add_footer_button(UIKit.button("Close", close))
	_buy = add_footer_button(UIKit.button("Buy", _on_buy), true)
	_play = add_footer_button(UIKit.button("Play", _on_play), true)
	_research = add_footer_button(UIKit.button("Learn", _on_research), true)  # the card called Research has that word
	_disband = add_footer_button(UIKit.button("Disband", _on_disband))
	_upgrade = add_footer_button(UIKit.button("Upgrade", _on_upgrade))
	_move = add_footer_button(UIKit.button("Move…", _on_move), true)
	_abandon = add_footer_button(UIKit.button("Abandon…", _on_abandon))
	_contribute = add_footer_button(UIKit.button("Contribute", _on_contribute), true)
	abandon_modal = AbandonModal.new(p_stack)
	_gives = VBoxContainer.new()
	_gives.add_theme_constant_override("separation", Tokens.SPACE_2)
	_gives.visible = false
	footer_rule.get_parent().add_child(_gives)
	footer_rule.get_parent().move_child(_gives, footer_rule.get_index())  # under the card and body, over the footer
	_gives.add_child(UIKit.heading("Gives"))
	_gives_row = HBoxContainer.new()
	_gives_row.add_theme_constant_override("separation", UIKit.CARD_GAP)
	_gives.add_child(_gives_row)


## Test hook: the details on show, {} while hidden.
func shown() -> Dictionary:
	return _details if is_open() else {}


## Test hook (225): the Play button, hidden unless a hand card's details are on show.
func play_button() -> Button:
	return _play


## Test hook (229): the Research button, hidden unless a tech to learn is on show.
func research_button() -> Button:
	return _research


## Test hook (163): the Move… and Disband buttons, hidden unless a unit in the realm is on show.
func unit_buttons() -> Array[Button]:
	return [_move, _disband]


## Test hook (166): the Upgrade button, hidden unless a unit in the realm with an upgrade is on show.
func upgrade_button() -> Button:
	return _upgrade


## Test hook (286): the Contribute and Abandon… buttons, hidden unless a wonder site is on show.
func site_buttons() -> Array[Button]:
	return [_contribute, _abandon]


## Test hook (259): the Buy button, hidden unless a supply pile's details are on show.
func buy_button() -> Button:
	return _buy


## Test hook (259): the footer's reason Buy is disabled, hidden unless it is.
func buy_reason() -> Label:
	return _reason


## Test hook (259): the pile's price tag in the aside, or null unless a supply pile's details are on show.
func pile_tag() -> Control:
	return _column.get_meta("tag") if _column != null else null


## Test hook (259): the Label under the aside's price tag ("6 left"), or null unless a supply pile is on show.
func pile_left() -> Label:
	return _column.get_meta("left") if _column != null else null


## Test hooks (289): the Gives row's card ids and captions, in order; its card button i, or null.
func gives_ids() -> Array[String]:
	var out: Array[String] = []
	for column in _gives_columns():
		out.append(column.get_meta("card_id"))
	return out


func gives_captions() -> Array[String]:
	var out: Array[String] = []
	for column in _gives_columns():
		out.append((column.get_meta("caption") as Label).text)
	return out


func gives_card(i: int) -> Button:
	var columns := _gives_columns()
	return columns[i].get_meta("button") if i < columns.size() else null


## Test hook: the body text on show, without markup.
func body_text() -> String:
	return _body.get_parsed_text()


## Opens the details of the card view shows: its live copy, or its definition for a supply pile. A hand card's
## details offer Play.
func open(view: CardView) -> void:
	var details := Game.engine.card_details(view.uid)
	_show(details if not details.is_empty() else Game.engine.def_details(view.card_id), view.card_id,
		view if view.in_hand else null, -1, view.uid)


## Opens the details of supply pile card_id from the supply screen, whose card is view: the pile's price tag and copies
## left under the card, and Buy (259).
func open_pile(view: CardView, card_id: String) -> void:
	_show(Game.engine.def_details(card_id), card_id, null, -1, -1, view)


## Opens the live details of card, in whatever zone it is (the civilization modal's cards and deck tabs, 231).
func open_card(card: CardInstance) -> void:
	var details := Game.engine.card_details(card.uid)
	_show(details if not details.is_empty() else Game.engine.def_details(card.def.id), card.def.id, null, -1, card.uid)


## Opens the details of card definition card_id (a tech in the tree).
func open_def(card_id: String) -> void:
	_show(Game.engine.def_details(card_id), card_id)


## Opens the details of tech card_id from the Knowledge screen; uid is the tech to learn, whose details offer Research,
## or -1 (researched, or a later era's).
func open_tech(card_id: String, uid: int) -> void:
	_show(Game.engine.def_details(card_id), card_id, null, uid)


## uid is the live card shown (-1 for a definition): a unit in the realm gets Move… and Disband.
## pile is the supply pile card (259): Buy and the pile's tag and count.
func _show(details: Dictionary, card_id: String, hand_view: CardView = null, tech := -1, uid := -1,
		pile: CardView = null) -> void:
	if details.is_empty():
		return
	var e := Game.engine
	_details = details
	_pile = pile
	_buy.visible = pile != null
	var cant := e.buy_error(card_id) if pile != null else ""
	_buy.disabled = cant != ""
	_reason.text = cant
	_reason.visible = cant != ""
	_view = hand_view
	_tech = tech
	_research.visible = tech >= 0
	if tech >= 0:
		var reason := e.buy_tech_error(tech)
		_research.disabled = reason != ""
		_research.tooltip_text = reason
	_unit = uid if e.unit_station(uid) != -1 else -1
	_move.visible = _unit != -1
	_disband.visible = _unit != -1
	var upgrade := e.upgrade_line(_unit) if _unit != -1 else ""
	_upgrade.visible = upgrade != ""
	if upgrade != "":
		var refused := e.upgrade_unit_error(_unit)
		_upgrade.disabled = refused != ""
		_upgrade.tooltip_text = refused if refused != "" else upgrade
	if _unit != -1:
		var block := e.unit_move_block(_unit)
		_move.disabled = block != ""
		_move.tooltip_text = block if block != "" else "March to another territory (an action)."
		var no := e.disband_error(_unit)
		_disband.disabled = no != ""
		var gone := "Send it to your discard" if e.disbands_to_discard(_unit) else "Dismiss it"  # 296, 297
		_disband.tooltip_text = no if no != "" else "%s; its worker is freed." % gone
	_site = uid if uid != -1 and e.is_site(uid) else -1
	_contribute.visible = _site != -1
	_abandon.visible = _site != -1
	if _site != -1:
		var most := e.contribute_limit(_site)
		var no := e.contribute_error(_site, maxi(1, most))
		_contribute.text = "Contribute %d wealth" % most if no == "" else "Contribute"
		_contribute.disabled = no != ""
		_contribute.tooltip_text = no if no != "" else "Pay wealth into it now (no action)."
		var stop := e.abandon_error(_site)
		_abandon.disabled = stop != ""
		_abandon.tooltip_text = stop if stop != "" else "Stop building: it goes to your discard and what went in is lost."
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
	_column = null
	if pile == null:
		aside.custom_minimum_size = card.slot_size()
		card.attach(aside)
	else:
		_column = SupplyScreen.pile_column(card.slot_size())
		aside.add_child(_column)
		SupplyScreen.show_pile(_column, e, card_id)
		aside.custom_minimum_size = _column.get_combined_minimum_size()
		card.attach(_column.get_meta("slot"))
	_show_gives(details.get("gives", []))
	present()  # last among its siblings, so a screen added later (the new game screen) can't take its input (107)


## Fills the Gives row with a column per given card (289): its card, at TABLEAU_SIZE, as a button, and how you get it
## under it. Hidden when gives is empty.
func _show_gives(gives: Array) -> void:
	for column in _gives_row.get_children():
		_gives_row.remove_child(column)
		column.queue_free()
	_gives.visible = not gives.is_empty()
	var e := Game.engine
	for given in gives:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", Tokens.SPACE_1)
		_gives_row.add_child(column)
		var button := Button.new()
		button.theme_type_variation = &"GivesCard"
		button.custom_minimum_size = CardView.TABLEAU_SIZE
		button.tooltip_text = "See its details."
		button.pressed.connect(_open_given.bind(given.card_id))
		column.add_child(button)
		var card := CardView.new()
		card.setup(CardInstance.new(-1, e.card_db[given.card_id]), e.card_db, false)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.attach(button)
		var caption := Label.new()
		caption.theme_type_variation = &"Caption"
		caption.text = given.how
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.x = CardView.TABLEAU_SIZE.x
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(caption)
		column.set_meta("card_id", given.card_id)
		column.set_meta("button", button)
		column.set_meta("caption", caption)


func _gives_columns() -> Array[Node]:
	return _gives_row.get_children().filter(func(c): return not c.is_queued_for_deletion()) if is_open() else []


## Opens given card card_id's details over this modal, with no footer action (289).
func _open_given(card_id: String) -> void:
	if given_details == null:
		given_details = CardDetailsModal.new(stack)
	given_details.open_def(card_id)


## I on a focused Gives card opens it, as Enter does (289); otherwise the close keys close.
func key_pressed(keycode: Key) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if keycode == KEY_I and focused != null and _gives_row.is_ancestor_of(focused):
		(focused as Button).pressed.emit()
		return
	super(keycode)


func closed() -> void:
	_details = {}
	_view = null
	_tech = -1
	_unit = -1
	_site = -1
	_pile = null


func _on_buy() -> void:
	var view := _pile
	close()
	if view != null and is_instance_valid(view):
		buy_requested.emit(view)


func _on_move() -> void:
	var uid := _unit
	close()
	move_requested.emit(uid)


func _on_disband() -> void:
	var uid := _unit
	close()
	if Game.engine.disband_error(uid) == "":
		Game.engine.disband(uid)


func _on_upgrade() -> void:
	var uid := _unit
	close()
	if Game.engine.upgrade_unit_error(uid) == "":
		Game.engine.upgrade_unit(uid)


func _on_contribute() -> void:
	var uid := _site
	close()
	var e := Game.engine
	var most := e.contribute_limit(uid)
	if e.contribute_error(uid, most) == "":
		e.contribute(uid, most)


func _on_abandon() -> void:
	var uid := _site
	close()
	abandon_modal.open(Game.engine, uid)


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
		terms.append("%s: %s" % [Palette.bbcode(t.term, Palette.EMPHASIS), t.text])
	if not terms.is_empty():
		parts.append("[b]How it works[/b]\n" + "\n".join(terms))
	return "\n\n".join(parts)
