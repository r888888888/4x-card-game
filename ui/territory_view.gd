class_name TerritoryView
extends VBoxContainer
## The territory view (backlog 101): one settled territory, under a header ("← Realm", "Realm › River Meadow", 104),
## shown in place of the Realm section. The territory is the box (105): a frame in the territory colour titled with
## its name and info, its stats and Grow, then its city and buildings and an outline per free slot; its card stays in
## the Realm. It keeps its own animated Navigator with the Realm as the root (a nested stack: the board's nav stays
## empty while a game is on,
## 103), and grows out of the territory's card when it opens (104). A drop anywhere on it targets its territory. The
## board places the view's cards through refresh; navigated asks the board to refresh after it opens or closes.

signal navigated

var uid := -1  # the territory shown, -1 while closed
var header: ScreenHeader
var back_button: Button  # the header's
var grow_button: Button
var frame: PanelContainer  # the framed body, bordered in the territory colour: the territory itself
var row: HFlowContainer  # the territory's city and buildings in tableau order, then the free-slot outlines

var _name: Label
var _info: RichTextLabel  # the territory card's info line (slots, housing, keywords, rolled resources)
var _stats: RichTextLabel  # the live line, drawn with icons (123)
var _outlines: Array[Panel] = []  # one per free slot, after the cards in row
var _nav := Navigator.new()
var _realm: Control
var _board: MainScreen


## Builds the view next to the Realm section realm, hidden.
func _init(board: MainScreen, realm: Control) -> void:
	_board = board
	_realm = realm
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	_nav.animated = true
	header = ScreenHeader.new(_nav, close)
	add_child(header)
	back_button = header.back_button
	frame = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UIKit.panel_style(Palette.RAISED.lerp(Palette.TERRITORY, 0.12),
		Palette.TERRITORY, 18))
	add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	frame.add_child(body)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 16)
	body.add_child(title)
	_name = UIKit.title("")
	title.add_child(_name)
	_info = CardFace.rich_label("", 19, Palette.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_info)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	body.add_child(bar)
	_stats = CardFace.rich_label("", 19, Palette.TEXT_DIM)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_stats)
	grow_button = UIKit.button("", func(): Game.engine.grow(uid))
	bar.add_child(grow_button)
	row = HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	hide()
	realm.get_parent().add_child(self)
	realm.get_parent().move_child(self, realm.get_index() + 1)
	_nav.set_root(realm, null, _realm_title())


func is_open() -> bool:
	return Navigator.is_shown(self)


## Shows territory t in place of the Realm, growing out of its card.
func open(t: int) -> void:
	uid = t
	var card: CardView = _board.views.get(t)
	global_position = _realm.global_position  # where its container will put it: the Realm's place
	size = _realm.size
	var title := Game.engine.zone("tableau").find(t).def.name
	_nav.push(self, null, title, card.get_global_rect() if card != null else Rect2())
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
	_nav.set_root(_realm, null, _realm_title())
	uid = -1


## The Realm section's heading: the root of the view's breadcrumb.
func _realm_title() -> String:
	return (_realm.get_child(0) as Label).text


## Esc closes the view. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		return true
	return false


## Whether t is a settled territory (one with a view to open) in engine e.
static func is_territory(e: GameEngine, t: int) -> bool:
	return not e.territory_summary(t).is_empty()


## The uids shown: the territory's city and buildings in tableau order ([] while closed). Its own card stays in the
## Realm: the view is the territory (105).
func card_uids() -> Array[int]:
	var out: Array[int] = []
	if is_open():
		for group in Game.engine.territory_groups():
			if group.territory == uid:
				out.assign(group.cards.slice(1))
	return out


## The title line: the territory's name, then its info.
func title_text() -> String:
	return "%s  %s" % [_name.text, _info.get_meta("source", "")]


func stats_text() -> String:
	return _stats.get_meta("source", "")


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
	var line := stats(e, uid)
	if line != stats_text():
		if stats_text() != "":
			UIKit.pulse(_stats)
		_stats.set_meta("source", line)
		Icons.fill(_stats, line, 19, Palette.TEXT_DIM)
	show_grow(grow_button, e, uid)
	var tableau := e.zone("tableau")
	var territory := tableau.find(uid)
	_name.text = territory.def.name
	var info := CardFace.territory_info(territory)
	_info.set_meta("source", info)
	Icons.fill(_info, info, 19, Palette.TEXT_DIM)
	var cards := card_uids()
	for i in cards.size():
		place.call(tableau.find(cards[i]), row, i)
	_show_outlines(e.free_slots(uid))


## The free-slot outlines, in order.
func outlines() -> Array[Panel]:
	return _outlines.duplicate()


func free_slot_count() -> int:
	return _outlines.size()


## Keeps n outlines at the end of the row, like the Realm's ghost slot.
func _show_outlines(n: int) -> void:
	while _outlines.size() > n:
		var gone: Panel = _outlines.pop_back()
		row.remove_child(gone)
		gone.queue_free()
	while _outlines.size() < n:
		var outline := UIKit.slot_outline()
		row.add_child(outline)
		_outlines.append(outline)
	for outline in _outlines:
		row.move_child(outline, -1)


## Territory t's live line (123): "▢ F   ⌂ P/H   ⚒ W" (free slots, pop / housing, free workers), or "▢ F" with
## population off. The card in the Realm and the view's header both show it.
static func stats(e: GameEngine, t: int) -> String:
	var s := e.territory_status(t)
	if not e.population_on():
		return "▢ %d" % s.free_slots
	return "▢ %d   ⌂ %d/%d   ⚒ %d" % [s.free_slots, s.pop, s.housing, s.free_workers]


## Shows button as territory t's Grow (with population on): its cost, disabled with the reason when it can't.
static func show_grow(button: Button, e: GameEngine, t: int) -> void:
	button.visible = e.population_on()
	if button.visible:
		var error := e.grow_error(t)
		button.text = "Grow (%d food)" % e.grow_cost(t)
		button.disabled = error != ""
		button.tooltip_text = error
