class_name KnowledgeScreen
extends VBoxContainer
## The Knowledge screen (backlog 208; the tech tree modal of 059 and 140 before it): a navigated screen on the play
## area's navigator (the Realm at its root, 101), its header "Realm › Knowledge" with the turn and era at its right.
## One row per era from GameEngine.tech_eras, top to bottom, headed with its name; an era not reached yet is dimmed and
## shows its unlock thresholds. Each tech is a tile showing its state with a mark and a word (not colour alone), its
## cost now, its eureka (✔ when met, 141), its prerequisite and what it gives; clicking one opens its details. An
## available tech has a Learn button beside it (140), disabled with buy_tech_error as its tooltip when it can't be
## learned. It slides in from the right over the Realm (or a territory view) and back; T, Esc or the header's link go
## back.

static var STATE_LOOK: Dictionary:  # state -> [mark, word, border colour, text alpha], as the palette reads now (183)
	get:
		return {
			GameEngine.TECH_RESEARCHED: ["✔", "Researched", Palette.RESEARCHED, 1.0],
			GameEngine.TECH_AVAILABLE: ["○", "Available", Palette.AVAILABLE, 1.0],
			GameEngine.TECH_LOCKED: ["🔒", "Locked", Palette.LOCKED, 0.8],
			GameEngine.TECH_FUTURE: ["…", "Later era", Palette.FUTURE, 0.6],
		}
const TILE_WIDTH := Tokens.SPACE_9 * 3  # a tech tile in its era's row

var header: ScreenHeader

var _nav: Navigator
var _place: Control  # the Realm section, whose place the screen takes
var _open_def: Callable  # opens a card definition's details over the screen
var _context: Label
var _insight: Label
var _rows: VBoxContainer
var _titles: Array[String] = []  # the era rows on show
var _headings: Array[Label] = []


## Builds the screen beside place (the Realm section) for nav, hidden. Its techs open their details with
## open_def(card_id).
func _init(nav: Navigator, place: Control, open_def: Callable) -> void:
	_nav = nav
	_place = place
	_open_def = open_def
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	var top := HBoxContainer.new()
	add_child(top)
	header = ScreenHeader.new(nav, close)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(header)
	_context = UIKit.heading("")
	_context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_context)
	_insight = UIKit.heading("")
	add_child(_insight)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", Tokens.SPACE_5)
	scroll.add_child(_rows)
	hide()
	place.get_parent().add_child(self)


func is_open() -> bool:
	return Navigator.is_shown(self)


## Test hook: the era rows' names on show, top to bottom; [] while closed.
func shown() -> Array[String]:
	return _titles if is_open() else ([] as Array[String])


## Test hooks (208).
func context_text() -> String:
	return _context.text


func era_heading(i: int) -> Label:
	return _headings[i]


func slide_offset() -> float:
	return Navigator.offset_of(self).x


## How far the screen under it has moved left (the Realm, or a territory view).
func realm_shift() -> float:
	var below := _nav.below(self)
	return Navigator.offset_of(below).x if below != null else 0.0


## Slides the screen in over the top of the play area's stack (the Realm or a territory view).
func open() -> void:
	var e := Game.engine
	if e == null or e.tech_eras().is_empty() or is_open():
		return
	_fill(e)
	var top := _nav.top()
	var at: Control = top if top != null else _place
	get_parent().move_child(self, at.get_index() + 1)
	global_position = at.global_position  # where its container will put it: the place of the screen it covers
	size = at.size
	_nav.push(self, null, "Knowledge", Rect2(), true)


## Back to the screen under it.
func close() -> void:
	if is_open() and _nav.top() == self:
		_nav.back()


## T opens it, or closes it while open.
func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Esc or T closes it. Returns whether the key was used.
func handle_key(event: InputEvent) -> bool:
	if is_open() and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ESCAPE, KEY_T]:
		close()
		return true
	return false


## Shows engine e again while open (a tech learned, insight gained).
func refresh(e: GameEngine) -> void:
	if is_open():
		_fill(e)


func _fill(e: GameEngine) -> void:
	_context.text = "Turn %d · %s" % [e.turn, e.era_name(e.era())]
	_insight.text = "Insight %d" % e.resources.get(GameEngine.INSIGHT, 0)
	if e.research_card_name() != "":
		_insight.text += " · play %s card for more" % UIKit.with_article(e.research_card_name())
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_titles.clear()
	_headings.clear()
	for era in e.tech_eras():
		_titles.append(era.name)
		_rows.add_child(_row(e, era))


## One era's row: its name, its status when not reached, then its techs' tiles. era is a tech_eras() entry.
func _row(e: GameEngine, era: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_2)
	var heading := UIKit.heading(era.name)
	row.add_child(heading)
	_headings.append(heading)
	if not era.reached:
		row.add_child(UIKit.heading(_era_status(era)))
		UIKit.painted(row, func(): row.modulate = Palette.FUTURE)
	var tiles := HFlowContainer.new()
	tiles.add_theme_constant_override("h_separation", Tokens.SPACE_3)
	tiles.add_theme_constant_override("v_separation", Tokens.SPACE_3)
	row.add_child(tiles)
	for tech in era.techs:
		tiles.add_child(_tech_row(e, tech))
	return row


## A tech's tile and, while it is available, its Learn button beside it.
func _tech_row(e: GameEngine, tech: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.x = TILE_WIDTH
	var tile := _tech_button(e, tech)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tile)
	if tech.state == GameEngine.TECH_AVAILABLE:
		var error := e.buy_tech_error(tech.uid)
		var learn := UIKit.button("Learn", func(): Game.engine.buy_tech(tech.uid))
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
	b.size_flags_horizontal = Control.SIZE_FILL  # a tile: fills its row beside its Learn button
	b.tooltip_text = "Click for the full details."
	var state: String = tech.state
	UIKit.painted(b, func(): b.add_theme_stylebox_override("normal", UIKit.panel_style(Palette.TILE, STATE_LOOK[state][2], Tokens.SPACE_2)))
	b.modulate.a = look[3]
	return b
