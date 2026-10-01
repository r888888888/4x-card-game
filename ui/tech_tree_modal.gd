class_name TechTreeModal
extends Modal
## The Knowledge modal (backlog 059): the tech tree from GameEngine.tech_tree, one column per era named with era_name.
## An era not reached yet shows its unlock thresholds. Each tech shows its state with a mark and a word (not colour
## alone), its cost now, its eureka (✔ when met, 141), its prerequisite and what it gives; clicking one opens its details. An available tech has a
## Learn button beside it (140), disabled with buy_tech_error as its tooltip when it can't be learned. While on top it
## takes every key; T, Esc or a click outside closes it. A tech's details open over it.

const STATE_LOOK := {  # state -> [mark, word, border colour, text alpha]
	GameEngine.TECH_RESEARCHED: ["✔", "Researched", Palette.RESEARCHED, 1.0],
	GameEngine.TECH_AVAILABLE: ["○", "Available", Palette.AVAILABLE, 1.0],
	GameEngine.TECH_LOCKED: ["🔒", "Locked", Palette.LOCKED, 0.8],
	GameEngine.TECH_FUTURE: ["…", "Later era", Palette.FUTURE, 0.6],
}

var _header: Label
var _columns: HBoxContainer
var _titles: Array[String] = []  # the column titles on show


var _open_def: Callable  # opens a card definition's details over the tree


## Builds the modal on stack's host, hidden. Its techs open their details with open_def(card_id).
func _init(p_stack: ModalStack, open_def: Callable) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_T]
	_open_def = open_def
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
	_header.text = "Insight %d" % e.resources.get(GameEngine.INSIGHT, 0)
	if e.research_card_name() != "":
		_header.text += " · play %s card for more" % UIKit.with_article(e.research_card_name())
	for child in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	_titles.clear()
	for era in e.tech_eras():
		_titles.append(era.name)
		_columns.add_child(_column(e, era))
	present()


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
		column.add_child(_tech_row(e, tech))
	return column


## A tech's tile and, while it is available, its Learn button beside it.
func _tech_row(e: GameEngine, tech: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	var tile := _tech_button(e, tech)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tile)
	if tech.state == GameEngine.TECH_AVAILABLE:
		var error := e.buy_tech_error(tech.uid)
		var learn := UIKit.button("Learn", func():
			Game.engine.buy_tech(tech.uid)
			open())
		learn.disabled = error != ""
		learn.tooltip_text = error
		row.add_child(learn)
	return row


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
	if tech.state != GameEngine.TECH_RESEARCHED:
		title += " · %d insight" % tech.cost
	var status: String = look[1]
	if not tech.gives.is_empty():
		status += " · gives " + ", ".join(PackedStringArray(tech.gives.map(func(id): return e.card_db[id].name)))
	var lines: PackedStringArray = [title, status]
	var eureka: String = e.card_db[tech.id].eureka_text(e.card_db)
	if eureka != "" and tech.state != GameEngine.TECH_RESEARCHED:
		lines.append(("✔ " if tech.eureka else "") + eureka)
	if tech.prereq != "":
		lines.append(("needs " if tech.state == GameEngine.TECH_LOCKED else "after ") + e.card_db[tech.prereq].name)
	var b := UIKit.button("\n".join(lines), func(): _open_def.call(tech.id))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_FILL  # a tile: fills its era column (100) beside its Learn button
	b.tooltip_text = "Click for the full details."
	var style := UIKit.panel_style(Palette.TILE, look[2], 6)
	b.add_theme_stylebox_override("normal", style)
	b.modulate.a = look[3]
	return b
