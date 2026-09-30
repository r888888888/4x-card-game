class_name SupplyScreen
extends RefCounted
## The supply screen: dims the board and shows one card per supply pile to click and buy; stays open for several
## buys. Also owns the "Buy Cards (S)" button that opens it.

## A buy was refused; message is the engine's reason, for the log.
signal refused(message: String)
## The screen closed (Close, S or Esc, or a new game).
signal closed

var button: Button  # "Buy Cards (S)", hidden when the config has no supply
var _overlay: Control
var _row: HBoxContainer  # slots for the pile cards, in config order
var _views := {}  # card_id -> CardView (display-only; not the board's card views)
var _wealth: Label  # the screen's own counters: the top bar's sit under the dimmer
var _discard: Label
var _fx: Control  # tokens, flying copies and errors above the panel
var _board: MainScreen


## Builds the screen on parent, hidden. on_open is the Supply button's action.
func _init(parent: MainScreen, on_open: Callable) -> void:
	_board = parent
	button = UIKit.button("Buy Cards (S)", on_open)
	button.custom_minimum_size.y = 44
	button.hide()
	_overlay = UIKit.overlay(parent, CardView.HIGHLIGHT_COLOR)
	_overlay.z_index = 5
	var box := _overlay.get_meta("box") as VBoxContainer
	box.add_child(UIKit.title("Supply"))
	box.add_child(UIKit.heading("Click a card to buy a copy into your discard. Buy as many as you can pay for."))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 36)
	box.add_child(stats)
	_wealth = UIKit.stat(stats, Palette.WEALTH)
	_discard = UIKit.stat(stats, Palette.PILES)
	var pad := MarginContainer.new()  # room above the cards for their hover lift
	pad.add_theme_constant_override("margin_top", int(Anim.HOVER_LIFT) + 8)
	box.add_child(pad)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", UIKit.CARD_GAP)
	pad.add_child(_row)
	box.add_child(UIKit.button("Close (S / Esc)", close))
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_fx)


func is_open() -> bool:
	return _overlay.visible


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
		var slot := Control.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = CardView.TABLEAU_SIZE
		_row.add_child(slot)
		var view := CardView.new()
		view.setup(CardInstance.new(-1 - i, e.card_db[id]), e.card_db, false)
		view.lift_on_hover = true
		view.set_pickable(true)
		view.picked.connect(pick)
		view.details_requested.connect(func(v: CardView): _board.details.open(v))
		view.pop_in(slot, i * Anim.DEAL_STAGGER)
		_views[id] = view
		i += 1
	_overlay.show()
	refresh(e)  # after show: it only fills in the cards while the screen is open
	_overlay.modulate.a = 0.0
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, Anim.CALM_FADE_TIME)


func close() -> void:
	if not is_open():
		return
	_overlay.hide()
	_wealth.text = ""  # so the next open doesn't pulse it
	_views.clear()
	for slot in _row.get_children():
		_row.remove_child(slot)
		slot.queue_free()
	for child in _fx.get_children():
		child.queue_free()
	closed.emit()


## A click (or Enter) on a pile card: buy a copy, or shake and say why not.
func pick(view: CardView) -> void:
	var e := Game.engine
	var id: String = _views.find_key(view)
	var error := e.buy_error(id)
	if error != "":
		refused.emit(error)
		UIKit.show_error(_fx, view, error, _overlay.size.x)
		view.reject()
		return
	var price := e.buy_price(id)
	e.buy(id)
	view.squash()
	var wealth_from := _wealth.get_global_rect().get_center() + Vector2(0, _wealth.size.y)
	UIKit.float_token(_fx, "−%d wealth" % price, wealth_from, UIKit.COST_COLOR, 0.0)
	# A copy flies to the screen's Discard counter, which pulses as it lands.
	var copy := CardView.new()
	copy.setup(CardInstance.new(-100, e.card_db[id]), e.card_db, false)
	_fx.add_child(copy)
	copy.size = view.size
	copy.global_position = view.global_position
	copy.leave(_fx, _discard.get_global_rect().get_center(), true)
	if not UIKit.calm():
		var t := _fx.create_tween()
		t.tween_interval(Anim.DISCARD_POP_TIME + Anim.DISCARD_FLY_TIME)
		t.tween_callback(UIKit.pulse.bind(_discard))


## The Supply button, and while the screen is open its counters and each pile's price, count and state.
func refresh(e: GameEngine) -> void:
	var reason := e.supply_error()
	button.visible = not e.supply().is_empty()
	button.disabled = reason != ""
	button.tooltip_text = reason if reason != "" else "Buy copies of cards into your discard."
	if not is_open():
		return
	UIKit.set_stat(_wealth, "Wealth: %d" % e.resources.get(GameEngine.WEALTH, 0))
	_discard.text = "Discard: %d" % e.zone("discard").size()
	for id in _views:
		_views[id].set_buy_info(e.buy_price(id), e.supply_left(id), e.buy_error(id))
