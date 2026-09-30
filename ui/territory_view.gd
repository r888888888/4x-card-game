class_name TerritoryView
extends VBoxContainer
## The territory view (backlog 101): one settled territory, its stats and Grow, then its card, city and buildings,
## shown in place of the Realm section. It keeps its own Navigator with the Realm as the root (a nested stack: the
## board's nav stays empty while a game is on, 103). A drop anywhere on it targets its territory. The board places
## the view's cards through refresh; navigated asks the board to refresh after it opens or closes.

signal navigated

var uid := -1  # the territory shown, -1 while closed
var back_button: Button
var grow_button: Button
var row: HFlowContainer  # the territory's card, then its city and buildings, in tableau order

var _stats: Label
var _nav := Navigator.new()
var _realm: Control
var _board: MainScreen


## Builds the view next to the Realm section realm, hidden.
func _init(board: MainScreen, realm: Control) -> void:
	_board = board
	_realm = realm
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	back_button = UIKit.button("Back (Esc)", close)
	bar.add_child(back_button)
	_stats = UIKit.heading("")
	bar.add_child(_stats)
	grow_button = UIKit.button("", func(): Game.engine.grow(uid))
	bar.add_child(grow_button)
	row = HFlowContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	add_child(row)
	hide()
	realm.get_parent().add_child(self)
	realm.get_parent().move_child(self, realm.get_index() + 1)
	_nav.set_root(realm)


func is_open() -> bool:
	return visible


## Shows territory t in place of the Realm.
func open(t: int) -> void:
	uid = t
	_nav.push(self)
	navigated.emit()


## Back to the Realm. With a card focused (the keyboard), the focus goes to the territory's card there.
func close() -> void:
	var was := uid
	var keyboard := _board.focus.focused != null
	if not _nav.back():
		return
	uid = -1
	navigated.emit()
	if keyboard and _board.views.has(was):
		_board.focus.set_card(_board.views[was])


## Closes the view without refreshing the board (a new game, or the territory is gone).
func reset() -> void:
	_nav.set_root(_realm)
	uid = -1


## Esc closes the view. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		return true
	return false


## Whether t is a settled territory (one with a view to open) in engine e.
static func is_territory(e: GameEngine, t: int) -> bool:
	return t != -1 and e.territory_groups().any(func(g): return g.territory == t)


## The uids shown: the territory's card, then its city and buildings in tableau order ([] while closed).
func card_uids() -> Array[int]:
	var out: Array[int] = []
	if is_open():
		for group in Game.engine.territory_groups():
			if group.territory == uid:
				out.assign(group.cards)
	return out


func stats_text() -> String:
	return _stats.text


## The territory a drop at global point would target: this one anywhere on the open view, else -1.
func target_at(point: Vector2) -> int:
	return uid if is_open() and get_global_rect().has_point(point) else -1


## Closes the view when the game is over or its territory is gone. Call before laying out the board.
func close_if_stale(e: GameEngine) -> void:
	if is_open() and (e.is_over or not is_territory(e, uid)):
		reset()


## Lays out the open view: stats, Grow, and place(card, row, index) for each card.
func refresh(e: GameEngine, place: Callable) -> void:
	if not is_open():
		return
	UIKit.set_stat(_stats, stats(e, uid))
	show_grow(grow_button, e, uid)
	var cards := card_uids()
	for i in cards.size():
		place.call(e.zone("tableau").find(cards[i]), row, i)


## "U / S slots used", then "  ·  Pop P / H" with population on.
static func stats(e: GameEngine, t: int) -> String:
	var slots := e.total_slots(t)
	var text := "%d / %d slots used" % [slots - e.free_slots(t), slots]
	if e.population_on():
		text += "  ·  Pop %d / %d" % [e.pop(t), e.housing(t)]
	return text


## Shows button as territory t's Grow (with population on): its cost, disabled with the reason when it can't.
static func show_grow(button: Button, e: GameEngine, t: int) -> void:
	button.visible = e.population_on()
	if button.visible:
		var error := e.grow_error(t)
		button.text = "Grow (%d food)" % e.grow_cost(t)
		button.disabled = error != ""
		button.tooltip_text = error
