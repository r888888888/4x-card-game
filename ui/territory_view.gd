class_name TerritoryView
extends VBoxContainer
## The territory view (backlog 101): one settled territory, under a header ("← Realm", "Realm › River Meadow", 104),
## shown in place of the Realm section. The territory is the box (105): a frame in the territory colour titled with
## its name and info, its stats and pop meter, then its city and buildings and an outline per free slot; its card stays in
## the Realm. It keeps its own animated Navigator with the Realm as the root (a nested stack: the board's nav stays
## empty while a game is on,
## 103), and grows out of the territory's card when it opens (104). A drop anywhere on it targets its territory. The
## board places the view's cards through refresh; navigated asks the board to refresh after it opens or closes.

signal navigated

var uid := -1  # the territory shown, -1 while closed
var header: ScreenHeader
var back_button: Button  # the header's
var grow_button: Button  # the pop meter's first empty pip: Grow, showing its food cost (124)
var grow_reason: Label  # why Grow can't be used, dim, beside the meter; hidden when it can (124)
var frame: PanelContainer  # the framed body, bordered in the territory colour: the territory itself
var row: HFlowContainer  # the territory's city and buildings in tableau order, then the free-slot outlines

var _name: Label
var _info: RichTextLabel  # the territory card's info line (slots, housing, keywords, rolled resources)
var _stats: RichTextLabel  # the live line, drawn with icons (123)
var _outlines: Array[Panel] = []  # one per free slot, after the cards in row
var _meter: HBoxContainer  # the pop meter (124): a pip per housing, Grow on the first empty one
var _pips: Array[Panel] = []  # the meter's filled and empty pips, Grow not among them
var _growing := false  # while a grow from the meter runs, so the refresh it causes pops the new pip in
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
	UIKit.painted(frame, func(): frame.add_theme_stylebox_override("panel", UIKit.panel_style(
		Palette.RAISED.lerp(Palette.TERRITORY, 0.12), Palette.TERRITORY, Tokens.SPACE_4)))
	add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_3)
	frame.add_child(body)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", Tokens.SPACE_4)
	body.add_child(title)
	_name = UIKit.title("")
	title.add_child(_name)
	_info = CardFace.rich_label("", Tokens.TYPE_BODY, Palette.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(_info)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", Tokens.SPACE_4)
	body.add_child(bar)
	_stats = CardFace.rich_label("", Tokens.TYPE_BODY, Palette.TEXT_DIM)
	_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.painted(_stats, func():
		for line: RichTextLabel in [_info, _stats]:
			line.add_theme_color_override("default_color", Palette.TEXT_DIM))
	bar.add_child(_stats)
	_meter = HBoxContainer.new()
	_meter.add_theme_constant_override("separation", Tokens.SPACE_2)
	bar.add_child(_meter)
	grow_button = UIKit.button("", _grow)
	grow_button.theme_type_variation = "GrowPip"
	grow_button.icon = Icons.FOOD
	grow_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter.add_child(grow_button)
	grow_reason = UIKit.heading("")
	grow_reason.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(grow_reason)
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


## Lays out the open view: stats, the pop meter, and place(card, row, index) for each card.
func refresh(e: GameEngine, place: Callable) -> void:
	if not is_open():
		return
	var line := stats(e, uid)
	if line != stats_text():
		if stats_text() != "":
			UIKit.pulse(_stats)
		_stats.set_meta("source", line)
		Icons.fill(_stats, line, Tokens.TYPE_BODY, Palette.TEXT_DIM)
	_show_meter(e)
	var tableau := e.zone("tableau")
	var territory := tableau.find(uid)
	_name.text = territory.def.name
	var info := CardFace.territory_info(territory)
	_info.set_meta("source", info)
	Icons.fill(_info, info, Tokens.TYPE_BODY, Palette.TEXT_DIM)
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


## The pop meter's pips in order, Grow among them (124); none with population off.
func pips() -> Array[Control]:
	var out: Array[Control] = []
	if _meter.visible:
		for child in _meter.get_children():
			if (child as Control).visible:
				out.append(child)
	return out


## Grows the shown territory from the meter; the refresh that follows animates it (124).
func _grow() -> void:
	_growing = true
	Game.engine.grow(uid)
	_growing = false


## Shows the pop meter (with population on): a pip per housing, the first pop filled, Grow on the first empty one
## (hidden at housing), and grow_error as a dim line when Grow can't be used. After a grow from the meter, the new
## pip pops in; the top bar tags the food and pop (126, 181).
func _show_meter(e: GameEngine) -> void:
	_meter.visible = e.population_on()
	var error := e.grow_error(uid) if _meter.visible else ""
	grow_reason.visible = error != ""
	grow_reason.text = error
	if not _meter.visible:
		return
	var pop := e.pop(uid)
	var room := pop < e.housing(uid)
	grow_button.visible = room
	grow_button.text = str(e.grow_cost(uid))
	grow_button.disabled = error != ""
	grow_button.tooltip_text = "Grow: +1 pop for %d food." % e.grow_cost(uid)
	var plain := e.housing(uid) - (1 if room else 0)
	while _pips.size() > plain:
		_pips.pop_back().free()
	while _pips.size() < plain:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2.ONE * GameTheme.PIP_SIZE
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meter.add_child(pip)
		_pips.append(pip)
	for i in _pips.size():
		_pips[i].theme_type_variation = "PipFilled" if i < pop else "PipEmpty"
		_meter.move_child(_pips[i], i if i < pop else i + 1)
	_meter.move_child(grow_button, pop)
	if _growing and not UIKit.calm():
		_pop_in(_pips[pop - 1])


## pip (the one a grow from the meter just filled) pops in (124).
static func _pop_in(pip: Panel) -> void:
	pip.pivot_offset = Vector2.ONE * GameTheme.PIP_SIZE / 2
	pip.scale = Vector2.ONE * 0.4
	pip.create_tween().tween_property(pip, "scale", Vector2.ONE, Anim.POP_IN_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
