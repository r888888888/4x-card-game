class_name RenewalModal
extends Modal
## The Renewal sheet (backlog 255; design: docs/design/mocks/renewal-options.html, the ledger): while Anarchy's renewal is
## owed, every option (the engine's pending() options, hand, deck and discard by name) is a row in a ledger, and the
## pulled-out row (hover or Up/Down) shows its card plainly beside it. A click or Enter on a row chooses it, lighting
## its lamp (ui.toggle.on), and again puts it back (ui.toggle.off); a choice past the count is a dead tap
## (ui.reject.locked). "Trash N cards" stays locked, with renew_error as its reason, until the count is chosen, then
## pays the renewal in one renew call. It can't be dismissed: the renewal is owed. Main opens and closes it (refresh).

var trash_button: Button

var _lede: Label
var _ledger: VBoxContainer
var _face: Control  # the pulled-out row's card
var _tally: Label  # "Chosen n / N"
var _rows := {}  # uid -> its row, in options order
var _lamps := {}  # uid -> its row's lamp
var _chosen: Array = []  # the chosen uids, in the order chosen
var _shown := -1  # the pulled-out row's uid
var _options: Array = []  # the options the rows were built for
var _count := 0


## Builds the sheet on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	dismissable = false
	title = "Renewal"
	_lede = Label.new()
	_lede.theme_type_variation = &"Body"
	_lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_lede)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", Tokens.SPACE_5)
	body.add_child(columns)
	var well := PanelContainer.new()
	well.theme_type_variation = &"ListWell"
	var scroll := SmoothScroll.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(Tokens.SPACE_9 * 3, Tokens.SPACE_9 * 4)
	well.add_child(scroll)
	_ledger = VBoxContainer.new()
	_ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger.add_theme_constant_override("separation", Tokens.SPACE_1)
	scroll.add_child(_ledger)
	columns.add_child(well)
	_face = Control.new()
	columns.add_child(_face)
	_tally = Label.new()
	_tally.theme_type_variation = &"Body"
	footer.add_child(_tally)
	trash_button = add_footer_button(UIKit.button("", _trash), true)


## Opens it while engine e owes a renewal (rebuilding the rows when the options change) and closes it when not.
func refresh(e: GameEngine) -> void:
	var pending: Dictionary = e.pending() if e != null else {}
	if pending.get("kind", "") != GameEngine.PENDING_RENEWAL:
		if is_open():
			close()
		return
	context = "Turn %d" % e.turn
	if pending.options != _options or pending.count != _count:
		_build(e, pending.options, pending.count)
	_sync()
	if not is_open():
		present()
		if not _options.is_empty():
			FocusRing.focus(_rows[_options[0]])


## Test hooks: the rows in order, their uids, and the chosen uids in the order chosen.
func rows() -> Array[Button]:
	var out: Array[Button] = []
	for uid in _options:
		out.append(_rows[uid])
	return out


func row_uids() -> Array:
	return _options.duplicate()


func chosen() -> Array:
	return _chosen.duplicate()


func closed() -> void:
	_options = []
	_chosen = []
	_shown = -1


func _build(e: GameEngine, options: Array, count: int) -> void:
	_options = options.duplicate()
	_count = count
	_chosen = []
	_shown = -1
	for child in _ledger.get_children():
		_ledger.remove_child(child)
		child.queue_free()
	_rows.clear()
	_lamps.clear()
	_lede.text = "The old ways are torn down. Choose %d card%s from your hand, deck or discard to trash for good; each calms 1 %s." % [
		count, "" if count == 1 else "s", GameEngine.UNREST]
	trash_button.text = "Trash %d card%s" % [count, "" if count == 1 else "s"]
	for uid in _options:
		_ledger.add_child(_row(e, uid))
	if not _options.is_empty():
		_show(_options[0])


func _row(e: GameEngine, uid: int) -> Button:
	var row := UIKit.button(e.card_details(uid).name, func(): _toggle(uid))
	row.theme_type_variation = &"ListRowQuiet"
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_FILL
	row.add_to_group(KeySounds.OWN_SOUNDS)  # its lamp latches instead of a key's click (255)
	var lamp := Panel.new()
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lamp.anchor_left = 1.0
	lamp.anchor_right = 1.0
	lamp.anchor_top = 0.5
	lamp.anchor_bottom = 0.5
	lamp.offset_left = -Tokens.SPACE_4 - Tokens.SPACE_4
	lamp.offset_right = -Tokens.SPACE_4
	lamp.offset_top = -Tokens.SPACE_2
	lamp.offset_bottom = Tokens.SPACE_2
	row.add_child(lamp)
	_rows[uid] = row
	_lamps[uid] = lamp
	row.mouse_entered.connect(func(): _show(uid))
	row.focus_entered.connect(func(): _show(uid))
	_paint_lamp(uid)
	return row


## The pulled-out row: its card shows, plainly, beside the ledger.
func _show(uid: int) -> void:
	if uid == _shown or not _rows.has(uid):
		return
	_shown = uid
	for child in _face.get_children():
		child.queue_free()
	var e := Game.engine
	var card := CardView.new()
	card.setup(e.zone(e.zone_of(uid)).find(uid), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.custom_minimum_size = card.slot_size()
	card.attach(_face)
	_sync()


func _toggle(uid: int) -> void:
	var sfx := Sfx.find(self)
	if _chosen.has(uid):
		_chosen.erase(uid)
		if sfx != null:
			sfx.at_contact(Sfx.TOGGLE_OFF, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true)
	elif _chosen.size() < _count:
		_chosen.append(uid)
		if sfx != null:
			sfx.at_contact(Sfx.TOGGLE_ON, Anim.KEY_PRESS_TIME, Anim.SNAP, true)
	elif sfx != null:
		sfx.play(Sfx.REJECT_LOCKED, 0.0, true)
	_show(uid)
	_sync()


func _sync() -> void:
	for uid in _rows:
		(_rows[uid] as Button).set_pressed_no_signal(uid == _shown)
		_paint_lamp(uid)
	_tally.text = "Chosen %d / %d" % [_chosen.size(), _count]
	var reason := Game.engine.renew_error(_chosen) if Game.engine != null else ""
	trash_button.disabled = reason != ""
	trash_button.tooltip_text = reason


func _paint_lamp(uid: int) -> void:
	var on := _chosen.has(uid)
	var style := UIKit.panel_style(Palette.COST if on else Palette.FIELD, Palette.COST if on else Palette.CONTROL_BORDER, 0)
	style.set_corner_radius_all(Tokens.RADIUS_FULL)
	(_lamps[uid] as Panel).add_theme_stylebox_override("panel", style)


func _trash() -> void:
	Game.engine.renew(_chosen.duplicate())
