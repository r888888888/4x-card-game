class_name TechTreeModal
extends ColorRect
## The Knowledge modal (backlog 059): the tech tree from GameEngine.tech_tree, one column per era named with era_name.
## An era not reached yet shows its unlock thresholds. Each tech shows its state with a mark and a word (not colour
## alone), its cost now, its prerequisite and what it gives; clicking one opens its details. A view only: research
## stays reveal-2. While open it takes every key; T, Esc or a click outside closes it.

const STATE_LOOK := {  # state -> [mark, word, border colour, text alpha]
	GameEngine.TECH_RESEARCHED: ["✔", "Researched", Color("7fd48a"), 1.0],
	GameEngine.TECH_AVAILABLE: ["○", "Available", Color("5ec8ff"), 1.0],
	GameEngine.TECH_FUTURE: ["…", "Later era", Color("6b7280"), 0.6],
	GameEngine.TECH_LOST: ["✕", "Lost", Color("b5566f"), 0.5],
}

var _header: Label
var _columns: HBoxContainer
var _titles: Array[String] = []  # the column titles on show


## Builds the modal on parent (the board), hidden. Its techs open parent's details modal.
func _init(parent: Control) -> void:
	color = Color(0, 0, 0, 0.7)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 15  # above the supply screen; the details modal (20) opens over it
	visible = false
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			accept_event()
			close())
	parent.add_child(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_style(Color("262b31"), Color(1, 1, 1, 0.25), 24))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIKit.title("Knowledge"))
	_header = UIKit.heading("")
	box.add_child(_header)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", 24)
	box.add_child(_columns)
	box.add_child(UIKit.button("Close (T / Esc)", close))


## Test hook: the era column titles on show, [] while hidden.
func shown() -> Array[String]:
	return _titles if visible else ([] as Array[String])


func open() -> void:
	var e := Game.engine
	if e == null or e.tech_eras().is_empty():
		return
	_header.text = "Research deck %d · lost %d" % [e.zone("research_deck").size(), e.zone("lost_techs").size()]
	if e.research_card_name() != "":
		_header.text += " · play %s card to reveal 2 techs" % UIKit.with_article(e.research_card_name())
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_titles.clear()
	for era in e.tech_eras():
		_titles.append(era.name)
		_columns.add_child(_column(e, era))
	show()


func close() -> void:
	hide()


## One era's column: its name, status and techs. era is a tech_eras() entry.
func _column(e: GameEngine, era: Dictionary) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.custom_minimum_size.x = 320
	column.add_child(UIKit.title(era.name))
	var status := UIKit.heading(_era_status(era))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 320
	column.add_child(status)
	for tech in era.techs:
		column.add_child(_tech_button(e, tech))
	return column


## "Reached", or "Unlocks at 8 pop or 15 wealth" (from its unlocks), or "Unlocks through a tech". era is a
## tech_eras() entry.
static func _era_status(era: Dictionary) -> String:
	if era.reached:
		return "Reached"
	var need: Dictionary = era.unlocks
	var parts: PackedStringArray = []
	if need.has("pop"):
		parts.append("%d pop" % need.pop)
	if need.has(GameEngine.WEALTH):
		parts.append("%d wealth" % need.wealth)
	if parts.is_empty():
		return "Unlocks through a tech"
	return "Unlocks at %s, or through a tech" % " or ".join(parts)


func _tech_button(e: GameEngine, tech: Dictionary) -> Button:
	var look: Array = STATE_LOOK[tech.state]
	var title := "%s %s" % [look[0], e.card_db[tech.id].name]
	if tech.state in [GameEngine.TECH_AVAILABLE, GameEngine.TECH_FUTURE]:
		title += " · %d wealth" % tech.cost
		if tech.passes > 0:
			title += " (%d pass%s)" % [tech.passes, "" if tech.passes == 1 else "es"]
	var status: String = look[1]
	if not tech.gives.is_empty():
		status += " · gives " + ", ".join(PackedStringArray(tech.gives.map(func(id): return e.card_db[id].name)))
	var lines: PackedStringArray = [title, status]
	if tech.prereq != "":
		lines.append("after " + e.card_db[tech.prereq].name)
	var b := UIKit.button("\n".join(lines), func(): get_parent().details.open_def(tech.id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_FILL  # a tile: fills its era column (100)
	b.tooltip_text = "Click for the full details."
	var style := UIKit.panel_style(Color("1f2328"), look[2], 6)
	b.add_theme_stylebox_override("normal", style)
	b.modulate.a = look[3]
	return b


## While open, every key stops here: T and Esc close, the rest do nothing.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_T]:
		close()
