class_name UpgradeList
extends VBoxContainer
## A building's Upgrades section in its details (387, design Y of building-upgrade-options.html): a row per upgrade its
## chain could take (GameEngine.upgrade_rows), built or not, each its name over its rules, then its status: "Built", why
## it has fallen back, why it can't be built, or an Upgrade button with its cost. A built row also offers Abandon… (412). While the game is blocked (a decision
## owed, or over) each row not built keeps its button, disabled with why. Hidden when the card has no rows.

## A row's Upgrade was pressed: build card_id on base.
signal upgrade_pressed(card_id: String, base: int)
## A built row's Abandon… was pressed (412): abandon upgrade uid.
signal abandon_pressed(uid: int)

var _list: VBoxContainer
var _rows: Array[Dictionary] = []  # what each row shows: {name, rules, status, button}


func _init() -> void:
	add_theme_constant_override("separation", Tokens.SPACE_2)
	visible = false
	add_child(UIKit.heading("Upgrades"))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", Tokens.SPACE_3)
	add_child(_list)


## Shows card uid's upgrade rows; hidden when it has none (anything but a building in the realm).
func show_for(uid: int) -> void:
	for row in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	var e := Game.engine
	var rows := e.upgrade_rows(uid)
	visible = not rows.is_empty()
	var blocked := e.build_menu_error()
	for row in rows:
		_add_row(e, row, blocked)


## Test hook: each row as {name, rules, status, button, status_label, abandon}, button null for a row without one,
## status_label null for one with, and abandon (the Abandon… button) null for a row not built.
func rows() -> Array[Dictionary]:
	return _rows


func _add_row(e: GameEngine, row: Dictionary, blocked: String) -> void:
	var def: CardDef = e.card_db[row.card_id]
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Tokens.SPACE_4)
	_list.add_child(line)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", Tokens.SPACE_0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	text.add_child(_label(def.name, &"CardTitle"))
	var rules := e.upgrade_rules_text(row.card_id)
	text.add_child(_label(rules, &"BodySmall"))
	var shown := {"name": def.name, "rules": rules, "status": "", "button": null, "status_label": null, "abandon": null}
	if row.built != -1:
		var why := e.fallen_back_reason(row.built)
		shown.status = why if why != "" else "Built"
		shown.status_label = _status(shown.status, &"Refusal" if why != "" else &"Caption")
		line.add_child(shown.status_label)
		var stop := e.abandon_error(row.built)
		var abandon := UIKit.button("Abandon…", func(): abandon_pressed.emit(row.built))
		abandon.disabled = stop != ""
		abandon.tooltip_text = stop if stop != "" else e.abandon_line(row.built)
		abandon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(abandon)
		shown.abandon = abandon
	elif blocked != "" or row.error == "":
		var cost := e.build_cost(row.card_id)
		var button := UIKit.button("Upgrade for %s" % Fields.amounts_text(cost) if not cost.is_empty() else "Upgrade",
			func(): upgrade_pressed.emit(row.card_id, row.base))
		button.disabled = blocked != ""
		button.tooltip_text = blocked
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(button)
		shown.button = button
	else:
		shown.status = row.error
		shown.status_label = _status(row.error, &"Refusal")
		line.add_child(shown.status_label)
	_rows.append(shown)


## A row's status: it shares the row with the name and rules (a third of it), so it wraps at words, not letters (411).
func _status(text: String, variation: StringName) -> Label:
	var label := _label(text, variation)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
