class_name TerritoryView
extends VBoxContainer
## The territory view (backlog 101): one settled territory, under a sage title bar ("◂ Realm", then its name; 104,
## 241), shown in place of the Realm section. The territory is the box (105): a frame in the territory colour titled with
## its name (its city name over its land's, 248) and info, its stats and pop meter, a row of its actions (Grow, 227;
## then Rename…, 248, 252), then its city and buildings and an outline per free slot, then its units (160); its card
## stays in the Realm. It keeps its own animated Navigator with the Realm as the root (a nested stack: the board's nav
## stays empty while a game is on, 103), and grows out of the territory's card when it opens (104). A drop anywhere on
## it targets its territory. The board places the view's cards through refresh; navigated asks the board to refresh
## after it opens or closes.

signal navigated
## Rename… pressed: the board opens the naming modal for territory t (248).
signal rename_requested(t: int)
## Build… (B) or a free slot's "+ Build" pressed: the board opens the Build modal on territory t (297).
signal build_requested(t: int)
## A building's "+ Upgrade" pressed: the board opens the Build modal on territory t with upgrade card_id on building
## base selected (302).
signal upgrade_requested(t: int, card_id: String, base: int)

var uid := -1  # the territory shown, -1 while closed
var header: ScreenHeader
var back_button: Button  # the header's
var actions: HBoxContainer  # the territory's actions, under the stats and meter (227)
var rename_button: Button  # in actions after Grow: Rename…, opening the naming modal (248, 252)
var build_button: Button  # in actions before Rename…: Build…, opening the Build modal (297); hidden with no build menu
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
var _outside_press := false  # the left button went down outside the box (200, 327)
var _hand_press: CardView  # the hand card that press landed on, let through so a drag can start (327)
var _turn := -1  # the turn close_if_stale last saw; -1 before a game's first refresh (290)
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
	mouse_filter = Control.MOUSE_FILTER_STOP  # clicks on the view stop here; handle_click closes it (200, 327)
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
	build_button = UIKit.button("Build…", func(): build_requested.emit(uid))
	build_button.theme_type_variation = "IconButton"
	actions.add_child(build_button)
	rename_button = UIKit.button("Rename…", func(): rename_requested.emit(uid))
	rename_button.theme_type_variation = "IconButton"  # the actions row's keys (252)
	actions.add_child(rename_button)
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
	_turn = -1


## The Realm section's heading: the root of the view's navigator, the title its tab back names.
func _realm_title() -> String:
	return (_realm.get_child(0) as Label).text


## A left click anywhere outside the box (pressed and released there) goes back to the Realm, as Back does, and does
## nothing else (200, 327). The press is held back from the board except on a hand card, so a drag from the hand still
## reaches the territory; the release is held back, and the card forgets the press. Main calls this after the drag
## controller and only with no modal or targeting over the board. Returns whether the event was used.
func handle_click(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not is_open():
		return false
	var outside := not frame.get_global_rect().has_point(click.global_position)
	if click.pressed:
		_outside_press = outside
		_hand_press = _hand_card_at(click.global_position) if outside else null
		return outside and _hand_press == null
	if not (_outside_press and outside):
		return false
	_outside_press = false
	if is_instance_valid(_hand_press):
		_hand_press.forget_press()
	_hand_press = null
	close()
	return true


## The hand card at global point, or null.
func _hand_card_at(point: Vector2) -> CardView:
	for view: CardView in _board.views.values():
		if view.in_hand and view.is_visible_in_tree() and view.get_global_rect().has_point(point):
			return view
	return null


## Esc closes the view, B opens the Build modal (297). Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if not (is_open() and event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.keycode == KEY_ESCAPE:
		close()
		return true
	if event.keycode == KEY_B and build_button.visible and not build_button.disabled:
		build_requested.emit(uid)
		return true
	return false


## Whether t is a settled territory (one with a view to open) in engine e.
static func is_territory(e: GameEngine, t: int) -> bool:
	return not e.territory_summary(t).is_empty()


## The uids shown: the territory's city, buildings and units in tableau order ([] while closed). Its own card stays in the
## Realm: the view is the territory (105). An upgrade has no card: it is a ribbon on its base's (302).
func card_uids() -> Array[int]:
	var out: Array[int] = []
	if is_open():
		var e := Game.engine
		for group in e.territory_groups():
			if group.territory == uid:
				out.assign(group.cards.slice(1).filter(func(c): return e.upgrade_base(c) == -1))
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


## Closes the view when the game is over or its territory is gone, and once the turn has moved on goes back to the
## Realm, closing the view and the Knowledge screen with their transitions (290). Call before laying out the board.
func close_if_stale(e: GameEngine) -> void:
	if is_open() and (e.is_over or not is_territory(e, uid)):
		reset()
	var turn_ended := _turn != -1 and e.turn != _turn
	_turn = e.turn
	if turn_ended:
		while nav.depth() > 1:
			if nav.top() == self:
				close()
			else:
				nav.back()


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
		(_board.views[cards[i]] as CardView).hoverable = true  # 342
		_show_upgrades(e, cards[i])
	_show_outlines(e.free_slots(uid))
	_show_build(e)
	for i in units.size():  # the units stationed here, in a row of their own (160)
		place.call(tableau.find(units[i]), units_row, i)
	_units_caption.visible = not units.is_empty()
	units_row.visible = not units.is_empty()
	_equalize_heights()


## Gives the view's cards and free-slot outlines the height of the tallest card, so a building's ribbons or a long
## text don't make the rows ragged (345), like the supply row.
func _equalize_heights() -> void:
	var cards := _board.views_in(row) + _board.views_in(units_row)
	var tallest := CardView.TABLEAU_SIZE.y
	for view in cards:
		tallest = maxf(tallest, view.get_combined_minimum_size().y)
	for view in cards:
		view.min_height = tallest
	for outline in _outlines:
		outline.custom_minimum_size.y = tallest


## Building b's upgrades as ribbons on its card, depth first, and its "+ Upgrade" chip while it or an upgrade on it
## could take another (302): the chip opens the Build modal on the first such upgrade.
func _show_upgrades(e: GameEngine, b: int) -> void:
	var view: CardView = _board.views.get(b)
	if view == null:
		return
	var ribbons: Array[Dictionary] = []
	for u in e.upgrade_tree(b):
		var def := e.zone("tableau").find(u).def
		ribbons.append({"uid": u, "name": def.name, "rules": e.upgrade_rules_text(def.id), "reason": e.fallen_back_reason(u)})
	var on_chip := Callable()
	for base in [b] + e.upgrade_tree(b):
		var options := e.upgrades_for(base)
		if not options.is_empty():
			on_chip = func(): upgrade_requested.emit(uid, options[0], base)
			break
	view.set_upgrades(ribbons, on_chip, e.build_menu_error())


## Build… and the free slots' "+ Build" (297): shown while the build menu has entries, disabled with the reason while
## nothing can be built.
func _show_build(e: GameEngine) -> void:
	var reason := e.build_menu_error()
	var keys: Array[Button] = [build_button]
	for outline in _outlines:
		keys.append(outline.get_child(0))
	for key in keys:
		key.visible = not e.build_menu().is_empty()
		key.disabled = reason != ""
	build_button.tooltip_text = reason if reason != "" else "Shortcut: B. Build or recruit on this territory."
	for key in keys.slice(1):
		key.tooltip_text = reason if reason != "" else "Build or recruit on this territory."


## Test hook (297): free slot i's "+ Build" key, or null.
func slot_button(i: int) -> Button:
	return _outlines[i].get_child(0) if i < _outlines.size() else null


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
		var key := UIKit.button("+ Build", func(): build_requested.emit(uid))  # 297
		key.theme_type_variation = &"SlotButton"
		key.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		key.mouse_entered.connect(_ink_outline.bind(outline, key, true))  # 342; the key ticks (KeySounds)
		key.mouse_exited.connect(_ink_outline.bind(outline, key, false))
		outline.add_child(key)
		row.add_child(outline)
		_outlines.append(outline)
	for outline in _outlines:
		row.move_child(outline, -1)


## Inks a free slot's outline while the mouse is over its enabled "+ Build" key (342), like a hovered card's border.
func _ink_outline(outline: Panel, key: Button, on: bool) -> void:
	var style := outline.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Palette.TEXT if on and not key.disabled else Palette.GHOST_EDGE


## Territory t's live line (123): "▢ F   ⌂ P/H   ⚒ W   ⛨ D" (free slots, pop / housing, free workers, defence 161), or
## "▢ F   ⛨ D" with population off. The card in the Realm and the view's header both show it.
static func stats(e: GameEngine, t: int) -> String:
	var s := e.territory_status(t)
	if not e.population_on():
		return "▢ %d   ⛨ %d" % [s.free_slots, e.defense(t)]
	return "▢ %d   ⌂ %d/%d   ⚒ %d   ⛨ %d" % [s.free_slots, s.pop, s.housing, s.free_workers, e.defense(t)]


## The pop meter's pips in order (124); none with population off.
func pips() -> Array[Control]:
	var out: Array[Control] = []
	if _meter.visible:
		for child in _meter.get_children():
			if (child as Control).visible:
				out.append(child)
	return out


## Shows the pop meter and the actions row (with population on): a pip per housing, the first pop filled (pop grows
## by itself at upkeep, 260).
func _show_meter(e: GameEngine) -> void:
	_meter.visible = e.population_on()
	actions.visible = _meter.visible
	if not _meter.visible:
		return
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


## Tints the first _filled pips POP and the rest a faint POP, as the palette reads now (242).
func _tint_pips() -> void:
	var faint := Palette.POP
	faint.a = 0.35
	for i in _pips.size():
		_pips[i].self_modulate = Palette.POP if i < _filled else faint
