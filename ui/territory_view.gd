class_name TerritoryView
extends VBoxContainer
## The territory view (backlog 101): one settled territory, under a sage title bar ("◂ Realm", then its name; 104,
## 241), shown in place of the Realm section. The territory is the box (105): a frame in the territory colour titled with
## its name (its city name over its land's, 248) and info, its stats and pop meter, Rename… beside the name (248), a row of its actions (Grow, 227), then its city and buildings and an outline per free slot, then its units (160); its card stays in
## the Realm. It keeps its own animated Navigator with the Realm as the root (a nested stack: the board's nav stays
## empty while a game is on,
## 103), and grows out of the territory's card when it opens (104). A drop anywhere on it targets its territory. The
## board places the view's cards through refresh; navigated asks the board to refresh after it opens or closes.

signal navigated
## Rename… pressed: the board opens the naming modal for territory t (248).
signal rename_requested(t: int)

var uid := -1  # the territory shown, -1 while closed
var header: ScreenHeader
var back_button: Button  # the header's
var actions: HBoxContainer  # the territory's actions, under the stats and meter (227)
var grow_button: Button  # in actions: Grow and its food cost; disabled with the reason as its tooltip (227)
var rename_button: Button  # Rename…, a link beside the name, opening the naming modal (248)
var frame: PanelContainer  # the framed body, bordered in the territory colour: the territory itself
var row: HFlowContainer  # the territory's city and buildings in tableau order, then the free-slot outlines
var units_row: HFlowContainer  # the units stationed here (160), under their caption; hidden when there are none

var _name: Label  # the territory's name: its city name once named (248)
var _land: Label  # its card's name, as a caption under _name (248)
var _info: RichTextLabel  # the territory card's info line (keywords, rolled resources)
var _stats: RichTextLabel  # the live line, drawn with icons (123)
var _outlines: Array[Panel] = []  # one per free slot, after the cards in row
var _units_caption: Label  # over units_row
var _meter: HBoxContainer  # the pop meter (124): a pip per housing
var _pips: Array[TextureRect] = []  # the meter's pips: pop glyphs, the first _filled tinted POP, the rest dimmer (242)
var _filled := 0
var _outside_press := false  # the left button went down on the view outside the box (200)
var _growing := false  # while a grow from Grow runs, so the refresh it causes pops the new pip in
var nav := Navigator.new()  # the play area's: the Realm at its root, this view and Knowledge (208) over it
var _realm: Control
var _board: MainScreen


## Builds the view next to the Realm section realm, hidden.
func _init(board: MainScreen, realm: Control) -> void:
	_board = board
	_realm = realm
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	nav.animated = true
	header = ScreenHeader.new(nav, close, &"TERRITORY")
	add_child(header)
	back_button = header.back_button
	mouse_filter = Control.MOUSE_FILTER_STOP  # a click on the view outside the box closes it (200)
	frame = PanelContainer.new()
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # as tall as its content: the board shows below it (200)
	UIKit.painted(frame, func(): frame.add_theme_stylebox_override("panel", UIKit.panel_style(
		Palette.RAISED.lerp(Palette.TERRITORY, 0.12), Palette.TERRITORY, Tokens.SPACE_4)))
	add_child(frame)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_3)
	frame.add_child(body)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", Tokens.SPACE_4)
	body.add_child(title)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", Tokens.SPACE_0)
	title.add_child(names)
	_name = UIKit.title("")
	names.add_child(_name)
	_land = Label.new()
	_land.theme_type_variation = &"Caption"
	names.add_child(_land)
	rename_button = UIKit.button("Rename…", func(): rename_requested.emit(uid))
	rename_button.theme_type_variation = &"CapsLink"  # a tertiary action beside the name (guide §7.3)
	rename_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title.add_child(rename_button)
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
	_meter.add_theme_constant_override("separation", Tokens.SPACE_1)
	UIKit.painted(_meter, _tint_pips)
	bar.add_child(_meter)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", Tokens.SPACE_3)
	body.add_child(actions)
	grow_button = UIKit.button("", _grow)
	grow_button.theme_type_variation = "IconButton"
	grow_button.icon = Icons.FOOD
	UIKit.painted(grow_button, func():  # food's green, as everywhere else (242)
		for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			grow_button.add_theme_color_override(state, Palette.GAIN))
	grow_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actions.add_child(grow_button)
	row = HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	_units_caption = Label.new()
	_units_caption.theme_type_variation = &"Caption"
	_units_caption.text = "Units"
	body.add_child(_units_caption)
	units_row = HFlowContainer.new()
	units_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	units_row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	units_row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	body.add_child(units_row)
	hide()
	realm.get_parent().add_child(self)
	realm.get_parent().move_child(self, realm.get_index() + 1)
	nav.set_root(realm, null, _realm_title())


func is_open() -> bool:
	return Navigator.is_shown(self)


## Shows territory t in place of the Realm, growing out of its card.
func open(t: int) -> void:
	uid = t
	var card: CardView = _board.views.get(t)
	global_position = _realm.global_position  # where its container will put it: the Realm's place
	size = _realm.size
	var title := Game.engine.territory_name(t)
	nav.push(self, null, title, card.get_global_rect() if card != null else Rect2())
	navigated.emit()


## Back to the Realm. With a card focused (the keyboard), the focus goes to the territory's card there.
func close() -> void:
	var was := uid
	var keyboard := _board.focus.focused != null
	if not nav.back():
		return
	uid = -1
	navigated.emit()
	if keyboard and _board.views.has(was):
		_board.focus.set_card(_board.views[was])


## Closes the view without refreshing the board (a new game, or the territory is gone).
func reset() -> void:
	nav.set_root(_realm, null, _realm_title())
	uid = -1


## The Realm section's heading: the root of the view's navigator, the title its tab back names.
func _realm_title() -> String:
	return (_realm.get_child(0) as Label).text


## A left click on the view outside the box (pressed and released there) goes back to the Realm, as Back does (200).
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not is_open():
		return
	var outside := not frame.get_global_rect().has_point(click.global_position)
	if click.pressed:
		_outside_press = outside
	elif _outside_press and outside:
		_outside_press = false
		accept_event()
		close()


## Esc closes the view. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if is_open() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		return true
	return false


## Whether t is a settled territory (one with a view to open) in engine e.
static func is_territory(e: GameEngine, t: int) -> bool:
	return not e.territory_summary(t).is_empty()


## The uids shown: the territory's city, buildings and units in tableau order ([] while closed). Its own card stays in the
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
	var land := ("  " + _land.text) if _land.visible else ""
	return "%s%s  %s" % [_name.text, land, _info.get_meta("source", "")]


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
	_name.text = e.territory_name(uid)
	_land.text = territory.def.name
	_land.visible = _land.text != _name.text
	nav.retitle(self, _name.text)
	var rename_error := e.rename_territory_error(uid, _name.text)
	rename_button.disabled = rename_error != ""
	rename_button.tooltip_text = rename_error if rename_error != "" else "Give %s a new name." % _name.text
	var info := CardFace.keyword_line(territory)
	_info.set_meta("source", info)
	Icons.fill(_info, info, Tokens.TYPE_BODY, Palette.TEXT_DIM)
	var units := e.units_at(uid)
	var cards := card_uids().filter(func(c): return not units.has(c))
	for i in cards.size():
		place.call(tableau.find(cards[i]), row, i)
	_show_outlines(e.free_slots(uid))
	for i in units.size():  # the units stationed here, in a row of their own (160)
		place.call(tableau.find(units[i]), units_row, i)
	_units_caption.visible = not units.is_empty()
	units_row.visible = not units.is_empty()


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


## The pop meter's pips in order (124); none with population off.
func pips() -> Array[Control]:
	var out: Array[Control] = []
	if _meter.visible:
		for child in _meter.get_children():
			if (child as Control).visible:
				out.append(child)
	return out


## Grows the shown territory from Grow; the refresh that follows animates it (124).
func _grow() -> void:
	_growing = true
	Game.engine.grow(uid)
	_growing = false


## Shows the pop meter and the actions row (with population on): a pip per housing, the first pop filled, and Grow
## with its food cost, disabled with grow_error as its tooltip when it can't be used (227). After a grow from Grow,
## the new pip pops in; the top bar rolls the food and pop (181).
func _show_meter(e: GameEngine) -> void:
	_meter.visible = e.population_on()
	actions.visible = _meter.visible
	if not _meter.visible:
		return
	var error := e.grow_error(uid)
	var cost := e.grow_cost(uid)
	grow_button.text = "Grow %d" % cost
	grow_button.disabled = error != ""
	grow_button.tooltip_text = error if error != "" else "Grow: +1 pop for %d food." % cost
	var pop := e.pop(uid)
	while _pips.size() > e.housing(uid):
		_pips.pop_back().free()
	while _pips.size() < e.housing(uid):
		var pip := Icons.glyph(TopBar.POP, Tokens.TYPE_BODY)  # the stats line's text size (242)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_meter.add_child(pip)
		_pips.append(pip)
	_filled = pop
	_tint_pips()
	if _growing and not UIKit.calm():
		_pop_in(_pips[pop - 1])


## Tints the first _filled pips POP and the rest a faint POP, as the palette reads now (242).
func _tint_pips() -> void:
	var faint := Palette.POP
	faint.a = 0.35
	for i in _pips.size():
		_pips[i].self_modulate = Palette.POP if i < _filled else faint


## pip (the one a grow from Grow just filled) pops in (124).
static func _pop_in(pip: Control) -> void:
	pip.pivot_offset = Vector2.ONE * Tokens.TYPE_BODY / 2
	pip.scale = Vector2.ONE * 0.4
	pip.create_tween().tween_property(pip, "scale", Vector2.ONE, Anim.POP_IN_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
