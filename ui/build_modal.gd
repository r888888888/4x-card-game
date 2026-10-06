class_name BuildModal
extends Modal
## The Build modal (backlog 297; the build-menu canvas's "Ledger"): opened on a territory from its view's Build… (B) or a
## "+ Build" free slot, titled "Build on <territory>". On the left a selectable list (217) of the build menu's entries,
## under Buildings and Units headings, each row its name and cost after discounts, a row the engine refuses dimmed with
## the reason under its name. Under Upgrades (302) a row per upgrade entry and building here it builds on ("Plough", "on
## Farm"). On the right the selected entry's card and either "If built on <territory or building>" with build_preview's
## lines and the cost, or the refusal. One key builds it (Build X; Recruit X for a unit); Enter too, and Up and Down
## move the selection. Everything shown comes from the engine. Laid out as the guide's ledger sheet (343, 344): the list
## Modal.LEDGER_LIST_WIDTH × LEDGER_LIST_HEIGHT with its rows wrapping, the card at hand size, lines wrapping at its width.

const DIMMED := 0.5  # a refused row's opacity
## build_preview's line keys beside the resources, as the sheet labels them.
const LINE_LABELS := {"free_slots": "Free slots", "free_workers": "Free workers", "defense": "Defence",
	"housing": "Housing", "actions_left": "Actions left"}

var list: SelectList
var build_button: Button
var cancel_button: Button

var _territory := -1  # the territory building goes on; -1 while closed
var _headings: Array[String] = []
var _reasons := {}  # row id -> build_error's refusal ("" when allowed)
var _targets := {}  # row id -> [card_id, the target it builds on: the territory, or an upgrade's base (302)]
var _card_slot: Control  # the selected entry's card
var _card: CardView  # on _card_slot, or null
var _row := ""  # the row id on the sheet
var _shown := ""  # the card id on the sheet
var _lines: VBoxContainer  # the preview's heading and lines, or the refusal


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", LEDGER_GAP)  # a ledger sheet (343, 344)
	body.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(LEDGER_LIST_WIDTH, LEDGER_LIST_HEIGHT)
	row.add_child(scroll)
	list = UIKit.select_list()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.chosen.connect(_show_entry)
	scroll.add_child(list)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", Tokens.SPACE_3)
	row.add_child(sheet)
	_card_slot = Control.new()
	_card_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_slot.custom_minimum_size = CardView.HAND_SIZE
	sheet.add_child(_card_slot)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", Tokens.SPACE_1)
	sheet.add_child(_lines)
	cancel_button = add_footer_button(UIKit.button("Cancel", close))
	build_button = add_footer_button(UIKit.button("Build", _build), true)


## The list id of upgrade card_id's row on building base (302).
static func upgrade_row_id(card_id: String, base: int) -> String:
	return "%s@%d" % [card_id, base]


## Opens it on settled territory t: the build menu listed, row select selected if given, else the first row the engine
## allows (else the first).
func open(t: int, select := "") -> void:
	var e := Game.engine
	_territory = t
	title = "Build on %s" % e.territory_name(t)
	list.clear()  # the rows and the headings
	_headings.clear()
	_reasons.clear()
	_targets.clear()
	var upgrades := e.build_menu().filter(func(id): return e.upgrade_base_name(id) != "")
	for kind in [CardDef.BUILDING, CardDef.UNIT]:
		var ids := e.build_menu().filter(func(id): return e.card_db[id].type == kind and not upgrades.has(id))
		if kind == CardDef.UNIT:
			_add_upgrades(e, t)
		if ids.is_empty():
			continue
		_add_heading("Buildings" if kind == CardDef.BUILDING else "Units")
		for id: String in ids:
			_add_row(id, id, t, "%s   %s" % [e.card_db[id].name, CardFace.cost_text(e.build_cost(id))])
	var first := select if list.row(select) != null else ""
	for id in list.ids():
		if first == "" and _reasons[id] == "":
			first = id
	if first == "" and not list.ids().is_empty():
		first = list.ids()[0]
	list.select(first)
	_show_entry(first)
	present()
	get_viewport().gui_release_focus()  # Up, Down and Enter reach key_pressed


## The Upgrades heading and a row per upgrade entry and building on territory t it builds on (302); none with no rows.
func _add_upgrades(e: GameEngine, t: int) -> void:
	var options := e.upgrade_options(t)
	if options.is_empty():
		return
	_add_heading("Upgrades")
	for option in options:
		var id: String = option.card_id
		var base_name := e.zone("tableau").find(option.base).def.name
		_add_row(upgrade_row_id(id, option.base), id, option.base, "%s   %s\non %s" % [e.card_db[id].name,
			CardFace.cost_text(e.build_cost(id)), base_name])


func _add_heading(heading: String) -> void:
	_headings.append(heading)
	list.add_heading(heading)


## Row row_id building card_id on target, reading text, dimmed with build_error's reason when it refuses.
func _add_row(row_id: String, card_id: String, target: int, text: String) -> void:
	var reason := Game.engine.build_error(card_id, target)
	_reasons[row_id] = reason
	_targets[row_id] = [card_id, target]
	var entry := list.add_row(row_id, text + ("\n" + reason if reason != "" else ""))
	entry.modulate.a = DIMMED if reason != "" else 1.0
	entry.tooltip_text = Game.engine.build_error_detail(card_id, target) if reason != "" else ""  # 347
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long name or reason wraps inside the column (343)


func closed() -> void:
	_territory = -1


## Test hooks (297).
func headings() -> Array[String]:
	return _headings.duplicate()


func row_text(id: String) -> String:
	return list.row(id).text if list.row(id) != null else ""


func row_reason(id: String) -> String:
	return _reasons.get(id, "")


func row_dimmed(id: String) -> bool:
	return list.row(id) != null and list.row(id).modulate.a < 1.0


## Test hook (343): the card on the sheet, or null.
func card_view() -> CardView:
	return _card if is_instance_valid(_card) else null


func shown_card() -> String:
	return _shown


## The face text of the card on the sheet (302), or "".
func face_text() -> String:
	return _card.face_text() if is_instance_valid(_card) else ""


## The sheet's lines: the preview's heading, its lines and the cost; [] while a refusal shows.
func preview_lines() -> Array[String]:
	var out: Array[String] = []
	if row_reason(_row) == "":
		for label in _lines.get_children():
			out.append((label as Label).text)
	return out


func refusal_text() -> String:
	return row_reason(_row)


## Up and Down move the selection, Enter builds; the close keys close (Modal).
func key_pressed(keycode: Key) -> void:
	var ids := list.ids()
	var at := ids.find(list.selected)
	match keycode:
		KEY_UP, KEY_DOWN:
			var to := at + (1 if keycode == KEY_DOWN else -1)
			if to >= 0 and to < ids.size():
				list.select(ids[to])
				_show_entry(ids[to])
		KEY_ENTER, KEY_KP_ENTER:
			_build()
		_:
			super(keycode)


## Shows row id on the sheet: its card, then the preview and its cost, or the refusal; the key names it.
func _show_entry(id: String) -> void:
	var e := Game.engine
	_row = id
	_shown = _targets[id][0] if _targets.has(id) else ""
	for child in _card_slot.get_children():
		child.queue_free()
	_card = null
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	if _shown == "":
		build_button.disabled = true
		return
	var def: CardDef = e.card_db[_shown]
	var target: int = _targets[id][1]
	_card = CardView.new()
	_card.setup(CardInstance.new(-1, def), e.card_db, true)  # a hand-size face
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.still = true
	_card.attach(_card_slot)
	var reason: String = _reasons.get(id, "")
	build_button.text = "%s %s" % ["Recruit" if def.type == CardDef.UNIT else "Build", def.name]
	build_button.disabled = reason != ""
	build_button.tooltip_text = reason
	if reason != "":
		_add_line(reason, &"Refusal")
		return
	var preview := e.build_preview(_shown, target)
	var where := e.territory_name(target) if target == _territory else e.zone("tableau").find(target).def.name
	_add_line("If built on %s" % where, &"Heading")
	for line in preview.get("lines", []):
		_add_line(line_text(line), &"Body")
	_add_line("Costs %s" % CardFace.cost_text(preview.get("cost", {})), &"Body")


## A build_preview line as the sheet reads it: "Food at next upkeep +1 → +3", "Free slots 2 → 1".
static func line_text(line: Array) -> String:
	if LINE_LABELS.has(line[0]):
		return "%s %d → %d" % [LINE_LABELS[line[0]], line[1], line[2]]
	return "%s at next upkeep %+d → %+d" % [String(line[0]).capitalize(), line[1], line[2]]


func _add_line(text: String, look: StringName) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = look
	if look == &"Refusal":  # a reason may be long; the preview's lines stay whole
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = LEDGER_DETAIL_WIDTH
	_lines.add_child(label)


func _build() -> void:
	var e := Game.engine
	if _shown == "" or _territory == -1 or e.build_error(_shown, _targets[_row][1]) != "":
		return
	var id := _shown
	var target: int = _targets[_row][1]
	close()
	e.build(id, target)
