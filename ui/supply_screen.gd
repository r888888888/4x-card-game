class_name SupplyScreen
extends RefCounted
## The supply screen: dims the board and shows one card per supply pile; a click (or Enter) on one opens its details,
## whose Buy buys a copy (259); stays open for several buys. Each card shows its play cost like a hand card, with its
## price on a tag hanging below it and the copies left under that (232). A click outside its panel closes it (258).
## Also owns the "Buy Cards" button that opens it (S).

## The screen closed (Close, S or Esc, a click outside its panel, or a new game).
signal closed
## The screen opened or closed (288): what is buyable then counts as seen.
signal looked

var close_button: Button
var button: Button  # "Buy Cards" (S, in its tooltip: 120), hidden when the config has no supply
var _overlay: Control
var _row: HFlowContainer  # slots for the pile cards, in config order; wraps (see _fit_row)
var _views := {}  # card_id -> CardView (display-only; not the board's card views)
var _columns := {}  # card_id -> its pile_column: the card's slot, its price tag and the copies left under that
var _wealth: Counter  # the screen's own counters: the top bar's sit under the dimmer (181: an odometer)
var _discard: Label
var _fresh := true  # the next refresh shows the wealth at once: the screen just opened
var _fx: Control  # flying copies above the panel
var _board: MainScreen


const DISCARD := "discard"  # counter()'s key for the discard count, beside GameEngine.WEALTH (177)
const TAG_DIMMED := 0.4  # a price tag's opacity while its pile can't be bought


## Builds the screen on parent, hidden. on_open is the Supply button's action.
func _init(parent: MainScreen, on_open: Callable) -> void:
	_board = parent
	button = UIKit.button("Buy Cards", on_open)
	button.custom_minimum_size.y = 44
	button.hide()
	_overlay = UIKit.overlay(parent, &"GAIN")
	_overlay.z_index = 5
	_overlay.gui_input.connect(_on_dimmer_input)
	var box := _overlay.get_meta("box") as VBoxContainer
	box.add_child(UIKit.title("Supply"))
	box.add_child(UIKit.heading("Click a card to see it and buy a copy into your discard. Buy as many as you can pay for."))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", Tokens.SPACE_6)
	box.add_child(stats)
	_wealth = Counter.new("", "Wealth: ", &"Stat")
	UIKit.painted(_wealth, func(): _wealth.set_color(Palette.WEALTH))
	stats.add_child(_wealth)
	_discard = UIKit.stat(stats, &"PILES")
	var pad := MarginContainer.new()  # room above the cards for their hover lift
	pad.add_theme_constant_override("margin_top", int(Anim.HOVER_LIFT) + Tokens.SPACE_2)
	box.add_child(pad)
	_row = HFlowContainer.new()
	_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	_row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	pad.add_child(_row)
	close_button = UIKit.button("Close", close)
	box.add_child(close_button)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fx)


## The screen's own counter for key (GameEngine.WEALTH or DISCARD), or null (177).
func counter(key: String) -> Control:
	return {GameEngine.WEALTH: _wealth, DISCARD: _discard}.get(key)


## counter(key)'s text ("Wealth: 10"), or "" for an unknown key (177).
func counter_text(key: String) -> String:
	var c := counter(key)
	if c is Counter:
		return (c as Counter).text()
	return (c as Label).text if c is Label else ""


func is_open() -> bool:
	return _overlay.visible


## view's price tag (232): "Buy", the wealth glyph and the price, hanging below the card.
func price_tag(view: CardView) -> Control:
	return _columns[_views.find_key(view)].get_meta("tag")


## The Label under view's price tag saying how many copies are left ("6 left").
func copies_left(view: CardView) -> Label:
	return _columns[_views.find_key(view)].get_meta("left")


## The pile cards, in config order.
func views() -> Array[CardView]:
	var out: Array[CardView] = []
	out.assign(_views.values())
	return out


## Whether the screen can open now: engine e has an open supply pile and nothing blocks buying.
func can_open(e: GameEngine) -> bool:
	return not is_open() and not e.open_supply_piles().is_empty() and e.supply_error() == ""


## Opens the screen: the panel fades in and one card per pile pops in, one after another.
func open(e: GameEngine) -> void:
	var i := 0
	for id in e.open_supply_piles():  # a locked pile stays hidden until a tech unlocks it
		_columns[id] = pile_column(CardView.TABLEAU_SIZE)
		_row.add_child(_columns[id])
		var view := CardView.new()
		view.setup(CardInstance.new(-1 - i, e.card_db[id]), e.card_db, false)
		view.lift_on_hover = true
		view.set_pickable(true)
		view.picked.connect(pick)
		view.details_requested.connect(pick)
		view.pop_in(_columns[id].get_meta("slot"), i * Anim.DEAL_STAGGER)
		view.minimum_size_changed.connect(_equalize_heights)
		_views[id] = view
		i += 1
	_fit_row(i)
	_overlay.show()
	refresh(e)  # after show: it only fills in the cards while the screen is open
	_overlay.modulate.a = 0.0
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, Anim.CALM_FADE_TIME)
	looked.emit()


## A pile's column (232): a slot of slot_size for its card, the price tag hanging from the card's edge and the copies
## left under it. Its metas "slot", "tag" and "left" are the three; the tag's figure is its child named "Price".
## The supply screen's piles and a pile's details (259) both use it.
static func pile_column(slot_size: Vector2) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.SPACE_0)  # the tag hangs from the card's edge
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = slot_size
	column.add_child(slot)
	var tag := _price_tag()
	column.add_child(tag)
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_top", Tokens.SPACE_1)
	column.add_child(pad)
	var left := Label.new()
	left.theme_type_variation = &"Caption"
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pad.add_child(left)
	column.set_meta("slot", slot)
	column.set_meta("tag", tag)
	column.set_meta("left", left)
	return column


## Fills a pile_column's tag and count for pile id of e: its price, the copies left, and the tag dimmed while the pile
## can't be bought.
static func show_pile(column: VBoxContainer, e: GameEngine, id: String) -> void:
	var tag: Control = column.get_meta("tag")
	(tag.find_child("Price", true, false) as Label).text = str(e.buy_price(id))
	tag.modulate.a = 1.0 if e.buy_error(id) == "" else TAG_DIMMED
	(column.get_meta("left") as Label).text = "%d left" % e.supply_left(id)


## A new price tag: "Buy", the wealth glyph and a figure refresh() fills in, centred under its card.
static func _price_tag() -> PanelContainer:
	var tag := PanelContainer.new()
	tag.theme_type_variation = &"PriceTag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", Tokens.SPACE_2)
	tag.add_child(line)
	var buy := Label.new()
	buy.theme_type_variation = &"PriceTagText"
	buy.text = "Buy"
	line.add_child(buy)
	var price := HBoxContainer.new()
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_constant_override("separation", Tokens.GLYPH_GAP)
	line.add_child(price)
	var glyph := Icons.glyph(GameEngine.WEALTH, 20)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.painted(glyph, func(): glyph.self_modulate = Palette.TEXT_ON_ACCENT)  # ink on the gold, not gold on gold
	price.add_child(glyph)
	var figure := Label.new()
	figure.name = "Price"
	figure.theme_type_variation = &"PriceTagText"
	price.add_child(figure)
	return tag


## Gives every pile card the height of the tallest, so a card whose text wraps doesn't make the row uneven.
func _equalize_heights() -> void:
	var tallest := 0.0
	for view: CardView in _views.values():
		tallest = maxf(tallest, view.get_combined_minimum_size().y)
	for view: CardView in _views.values():
		view.min_height = tallest


## Fixes the row's width to as many whole cards as fit the window (at most count), so the piles wrap onto
## further lines instead of running off the screen. The panel sits in a CenterContainer, which would
## otherwise shrink the flow to a single column.
func _fit_row(count: int) -> void:
	var slot := CardView.TABLEAU_SIZE.x + UIKit.CARD_GAP
	var room := _overlay.size.x - 120.0  # the panel's padding and a margin to the window edge
	var per_line := clampi(int((room + UIKit.CARD_GAP) / slot), 1, maxi(count, 1))
	_row.custom_minimum_size.x = per_line * slot - UIKit.CARD_GAP


func close() -> void:
	if not is_open():
		return
	_overlay.hide()
	_fresh = true  # so the next open shows the wealth at once, without rolling
	_views.clear()
	_columns.clear()
	for column in _row.get_children():
		_row.remove_child(column)
		column.queue_free()
	for child in _fx.get_children():
		child.queue_free()
	closed.emit()
	looked.emit()


## A click on the dimmer, outside the panel, closes the screen, as a click beside a modal's sheet does (258).
func _on_dimmer_input(event: InputEvent) -> void:
	var panel := _overlay.get_meta("panel") as Control
	if event is InputEventMouseButton and event.pressed and not panel.get_global_rect().has_point(event.global_position):
		_overlay.accept_event()
		close()


## A click, right-click or Enter on a pile card: its details, which offer Buy (259).
func pick(view: CardView) -> void:
	_board.details.open_pile(view, _views.find_key(view))


## Buys a copy of view's pile (its details' Buy), flying it to the screen's Discard counter; nothing if the engine
## refuses.
func buy(view: CardView) -> void:
	var e := Game.engine
	var id: Variant = _views.find_key(view)
	if not is_open() or id == null or e.buy_error(id) != "":
		return
	e.buy(id)  # the refresh that follows rolls the wealth down (181)
	# A copy flies to the screen's Discard counter, which pulses as it lands.
	var copy := CardView.new()
	copy.setup(CardInstance.new(-100, e.card_db[id]), e.card_db, false)
	_fx.add_child(copy)
	copy.size = view.size
	copy.global_position = view.global_position
	copy.leave(_fx, _discard.get_global_rect().get_center(), true, null, UIKit.pulse.bind(_discard))


## The Supply button, and while the screen is open its counters and each pile's play cost, price, count and state.
func refresh(e: GameEngine) -> void:
	var reason := e.supply_error()
	button.visible = not e.supply().is_empty()
	button.disabled = reason != ""
	button.tooltip_text = reason if reason != "" else "Shortcut: S. Buy copies of cards into your discard."
	if e.supply_lamp():
		button.tooltip_text += "\nNew: a card you can buy."  # its lamp is lit (288)
	if not is_open():
		return
	_wealth.show_value(e.resources.get(GameEngine.WEALTH, 0), _fresh)
	_fresh = false
	_discard.text = "Discard: %d" % e.zone("discard").size()
	for id in _views:
		_views[id].set_play_cost(e.supply_play_cost(id))
		_views[id].set_buy_error(e.buy_error(id))
		show_pile(_columns[id], e, id)
