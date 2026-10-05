class_name IdentityModal
extends Modal
## The civilization and government modal (backlog 119, opened from the sidebar), as two cards on the desk (231): the
## civilization's card and the government's side by side and level, each its name, a band of its type's colour, its
## type, its rules, its live state (the government's unrest against its limit) and its flavor at the foot. A click on
## a card opens its details over this modal (the quote is there); the government's card ends with Revolt… (205).
## Under them, the government deck: a caption, then a tab per card that opens its details, or "empty". It follows the
## engine while open (a new government shows at once). While on top it takes every key: Esc closes it, and so do
## Close and a click outside.

const ZONES: Array[String] = ["civilization", "government"]
const CARD_WIDTH := (BODY_MAX_WIDTH - Tokens.SPACE_3) / 2  # two cards and the gap between them fill the body

var close_button: Button
var revolt_button: Button  # "Revolt…", at the foot of the government card (205); disabled with revolt_error

## Revolt… pressed: the board opens the revolution's confirmation.
signal revolt_requested
## A card (or a deck tab) pressed: the board opens card's details over this modal.
signal details_requested(card: CardInstance)

var _cards: HBoxContainer  # the card buttons, civilization first
var _deck: HBoxContainer  # the deck's caption, then a tab per card or "empty"
var _names: Array[String] = []  # the names shown, left to right


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Civilization"
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", Tokens.SPACE_3)
	body.add_child(_cards)
	_deck = HBoxContainer.new()
	_deck.add_theme_constant_override("separation", Tokens.SPACE_2)
	body.add_child(_deck)
	close_button = add_footer_button(UIKit.button("Close", close))
	revolt_button = UIKit.button("Revolt…", func(): revolt_requested.emit())


## Test hook: the names shown, left to right; [] while closed.
func shown() -> Array[String]:
	return _names if is_open() else ([] as Array[String])


## Test hook: the card buttons, civilization first.
func cards() -> Array[Button]:
	var out: Array[Button] = []
	for c in _cards.get_children():
		out.append(c as Button)
	return out


## Test hook: card i's text, top to bottom (name, type, rules, state, flavor).
func card_lines(i: int) -> Array[String]:
	var lines: Array[String] = []
	for c in _column(cards()[i]).get_children():
		if c is Label:
			lines.append((c as Label).text)
	return lines


## Test hook: the colour of card i's type band.
func band_color(i: int) -> Color:
	return (_column(cards()[i]).get_node("Band") as ColorRect).color


## Test hook: the deck row's caption, then "empty" when the deck has no cards.
func deck_text() -> String:
	var parts: PackedStringArray = []
	for c in _deck.get_children():
		if c is Label:
			parts.append((c as Label).text)
	return " ".join(parts)


## Test hook: one tab per card in the government deck, in deck order.
func deck_tabs() -> Array[Button]:
	var out: Array[Button] = []
	for c in _deck.get_children():
		if c is Button:
			out.append(c as Button)
	return out


## Test hook: the cards' text, a blank line between the two.
func body_text() -> String:
	var parts: PackedStringArray = []
	for i in cards().size():
		parts.append("\n".join(card_lines(i)))
	return "\n\n".join(parts)


func open() -> void:
	_fill(Game.engine)
	present()


## Shows engine e's civilization and government again, if open.
func refresh(e: GameEngine) -> void:
	if is_open():
		_fill(e)


func _fill(e: GameEngine) -> void:
	_names = []
	if revolt_button.get_parent() != null:  # kept: it moves to the new government card
		revolt_button.get_parent().remove_child(revolt_button)
	for c in _cards.get_children() + _deck.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	for zone_name in ZONES:
		var z := e.zone(zone_name)
		if z.is_empty():
			continue
		var card := z.cards[0]
		_names.append(card.def.name)
		var column := _add_card(card, e.card_details(card.uid))
		if zone_name == "government":  # the government's card ends with Revolt… (205)
			column.add_child(revolt_button)
			var error := e.revolt_error()
			revolt_button.disabled = error != ""
			revolt_button.tooltip_text = error if error != "" else "Overthrow %s: see what follows first." % card.def.name
	_fill_deck(e)


## The government deck's row (154): its caption, then a tab per card, or "empty". None with no government and no deck.
func _fill_deck(e: GameEngine) -> void:
	var deck := e.zone("governments").cards
	_deck.visible = not deck.is_empty() or not e.zone("government").is_empty()
	var caption := UIKit.heading("Government deck")
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck.add_child(caption)
	if deck.is_empty():
		var empty := Label.new()
		empty.text = "empty"
		empty.theme_type_variation = &"Caption"
		empty.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_deck.add_child(empty)
	for card in deck:
		var tab := UIKit.button(card.def.name, func(): details_requested.emit(card))
		tab.theme_type_variation = &"DeckTab"
		tab.tooltip_text = "See %s's details." % card.def.name
		_deck.add_child(tab)


## Adds card's face to the row, from its details: a button (a click opens its details) holding a column of its name,
## band, type, rules, state and flavor at the foot. Returns the column.
func _add_card(card: CardInstance, details: Dictionary) -> VBoxContainer:
	var button := Button.new()
	button.theme_type_variation = &"IdentityCard"
	button.tooltip_text = "See %s's details." % card.def.name
	button.pressed.connect(func(): details_requested.emit(card))
	_cards.add_child(button)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Tokens.SPACE_3)
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.SPACE_1)
	column.custom_minimum_size.x = CARD_WIDTH - 2 * Tokens.SPACE_3
	margin.add_child(column)
	column.add_child(_line(details.name, &"CardTitle"))
	var band := ColorRect.new()
	band.name = "Band"
	band.custom_minimum_size.y = CardFace.BAND
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type := card.def.type
	UIKit.painted(band, func(): band.color = CardView.type_color(type))
	column.add_child(band)
	column.add_child(_line(details.type, &"Caption"))
	for line in details.rules + details["state"]:
		column.add_child(_line(line, &"BodySmall"))
	if details.rules.is_empty() and details["state"].is_empty():
		column.add_child(_line("No bonus.", &"BodySmall"))
	var foot := Control.new()  # pushes the flavor (and Revolt…) to the card's foot
	foot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	foot.custom_minimum_size.y = Tokens.SPACE_2  # at least a step between the rules and the flavor
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(foot)
	if details.flavor != "":
		column.add_child(_line(details.flavor, &"Flavor"))
	margin.minimum_size_changed.connect(func(): button.custom_minimum_size = margin.get_combined_minimum_size())
	button.custom_minimum_size = margin.get_combined_minimum_size()
	return column


## A wrapping label of text in look, which lets clicks through to its card.
func _line(text: String, look: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = look
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The column of text inside card.
func _column(card: Button) -> VBoxContainer:
	return card.get_child(0).get_node("Column") as VBoxContainer
