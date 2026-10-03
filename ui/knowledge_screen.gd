class_name KnowledgeScreen
extends VBoxContainer
## The Knowledge screen (backlog 208; the tech tree modal of 059 and 140 before it): a navigated screen on the play
## area's navigator (the Realm at its root, 101), its header "Realm › Knowledge" with the turn and era at its right.
## Drawn as the mock's drafting sheet (222, guide §11.3): one band per era from GameEngine.tech_eras, top to bottom,
## its title block in a left column and its techs as index-card tiles of one size, each showing its name and a marker
## for its state (✓, its cost now, "needs <prerequisite>") and filled by state; an era not reached lies under a vellum
## printed with how it opens. A click, Enter, a right click or I on a tile shows the tech's details, whose Research
## button learns it (229). It slides in from the right over the Realm (or a territory view) and back; T, Esc or the header's link go
## back. It is an opaque sheet (224), so nothing under it shows through as it slides.

const STATE_WORD := {
	GameEngine.TECH_RESEARCHED: "Researched",
	GameEngine.TECH_AVAILABLE: "Available",
	GameEngine.TECH_LOCKED: "Locked",
	GameEngine.TECH_FUTURE: "Later era",
}
const TILE_LOOK := {  # a tile's GameTheme variation by state; a later era's looks available under its vellum
	GameEngine.TECH_RESEARCHED: &"TechTileResearched",
	GameEngine.TECH_LOCKED: &"TechTileLocked",
}
const TILE_SIZE := Vector2(Tokens.SPACE_9 * 2, Tokens.SPACE_9)  # every tech tile, an index card (222)
const TITLE_WIDTH := Tokens.SPACE_9 + Tokens.SPACE_4  # an era's title block, the rows' left column

var header: ScreenHeader

var _nav: Navigator
var _place: Control  # the Realm section, whose place the screen takes
var _open_tech: Callable  # opens a tech's details over the screen
var _context: Label
var _insight: Label
var _rows: VBoxContainer
var _titles: Array[String] = []  # the era rows on show
var _headings: Array[Label] = []
var _era_tiles: Array = []  # per era row, its tiles (Array[Button])
var _vellums: Array = []  # per era row, its vellum, or null once reached
var _tiles := {}  # tech name -> its tile
var _tile_texts := {}  # tech name -> the texts its tile shows


## Builds the screen beside place (the Realm section) for nav, hidden. Its techs open their details with
## open_tech(card_id, uid), uid the tech to learn or -1 for one researched or of a later era.
func _init(nav: Navigator, place: Control, open_tech: Callable) -> void:
	_nav = nav
	_place = place
	_open_tech = open_tech
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UIKit.HEADING_GAP)
	header = ScreenHeader.new(nav, close, &"TECH")
	add_child(header)
	_context = UIKit.heading("")
	header.add_context(_context)
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
	UIKit.painted(self, queue_redraw)
	hide()
	place.get_parent().add_child(self)


## The colour the sheet is filled with: the board's.
func sheet_color() -> Color:
	return Palette.BACKGROUND


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), sheet_color())


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


## Test hooks (222): the tile of the tech called tech_name (null if none), the texts it shows (name, marker,
## "✔ Eureka"), era row i's tiles, and its vellum (null once reached) and the vellum's text.
func tile(tech_name: String) -> Button:
	return _tiles.get(tech_name)


func tile_texts(tech_name: String) -> Array[String]:
	return _tile_texts.get(tech_name, [] as Array[String])


func era_tiles(i: int) -> Array:
	return _era_tiles[i]


func era_vellum(i: int) -> Control:
	return _vellums[i]


func vellum_text(i: int) -> String:
	var label: Label = _vellums[i].get_child(0)
	return label.text.to_upper()


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
	_era_tiles.clear()
	_vellums.clear()
	_tiles.clear()
	_tile_texts.clear()
	for era in e.tech_eras():
		_titles.append(era.name)
		_rows.add_child(_row(e, era))


## One era's row under a hairline rule: its title block at the left, then its techs' tiles; an era not reached is
## covered by its vellum. era is a tech_eras() entry.
func _row(e: GameEngine, era: Dictionary) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_3)
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1  # a hairline (guide border.hair)
	UIKit.painted(rule, func(): rule.color = Palette.HAIRLINE)
	row.add_child(rule)
	var band := MarginContainer.new()  # the era and, over it, its vellum
	row.add_child(band)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", Tokens.SPACE_3)
	band.add_child(line)
	var heading := UIKit.heading(era.name)
	heading.custom_minimum_size.x = TITLE_WIDTH
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(heading)
	_headings.append(heading)
	var tiles := HFlowContainer.new()
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_theme_constant_override("h_separation", Tokens.SPACE_3)
	tiles.add_theme_constant_override("v_separation", Tokens.SPACE_3)
	line.add_child(tiles)
	var era_tiles: Array[Button] = []
	for tech in era.techs:
		var tile := _tile(e, tech)
		tiles.add_child(tile)
		era_tiles.append(tile)
	_era_tiles.append(era_tiles)
	_vellums.append(null if era.reached else _vellum(band, era))
	return row


## The vellum over an era not reached, printed with its name and how it opens; it takes the clicks meant for the
## tiles under it.
func _vellum(band: MarginContainer, era: Dictionary) -> PanelContainer:
	var vellum := PanelContainer.new()
	vellum.theme_type_variation = &"EraVellum"
	vellum.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := UIKit.heading("%s · %s" % [era.name, _opens(era)])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vellum.add_child(label)
	band.add_child(vellum)
	return vellum


## "Opens at 8 pop or 15 wealth" (from its unlocks), or "Opens through a tech". era is a tech_eras() entry.
static func _opens(era: Dictionary) -> String:
	var need: Dictionary = era.unlocks
	var parts: PackedStringArray = []
	if need.has("pop"):
		parts.append("%d pop" % need.pop)
	if need.has(GameEngine.WEALTH):
		parts.append("%d wealth" % need.wealth)
	if parts.is_empty():
		return "Opens through a tech"
	return "Opens at %s" % " or ".join(parts)


## A tech's index-card tile: its name, its marker (✓, its cost now, or "needs <prerequisite>"), and "✔ Eureka" when
## its eureka is met. A click, a right click or I shows its details. Its tooltip says its state in words, why it can't be learned, what it gives and its eureka.
func _tile(e: GameEngine, tech: Dictionary) -> Button:
	var state: String = tech.state
	var b := Button.new()
	b.custom_minimum_size = TILE_SIZE
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.theme_type_variation = TILE_LOOK.get(state, &"TechTile")
	b.tooltip_text = _tooltip(e, tech)
	var text := StringName(String(b.theme_type_variation).replace("TechTile", "TechTileText"))
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, Tokens.SPACE_2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var texts: Array[String] = [e.card_db[tech.id].name]
	top.add_child(_tile_label(texts[0], text, true))
	var marker := ""
	match state:
		GameEngine.TECH_RESEARCHED:
			marker = "✓"
		GameEngine.TECH_AVAILABLE:
			marker = str(tech.cost)
		GameEngine.TECH_LOCKED:
			marker = "needs " + e.card_db[tech.prereq].name
	if marker != "":
		texts.append(marker)
		if state == GameEngine.TECH_LOCKED:  # too long for the corner: its own line
			box.add_child(_tile_label(marker, text, true))
		else:
			top.add_child(_tile_label(marker, text, false))
	if tech.eureka and state != GameEngine.TECH_RESEARCHED:
		texts.append("✔ Eureka")
		box.add_child(_tile_label(texts[-1], text, true))
	_tiles[texts[0]] = b
	_tile_texts[texts[0]] = texts
	var learnable := state == GameEngine.TECH_AVAILABLE or state == GameEngine.TECH_LOCKED
	var details := func(): _open_tech.call(tech.id, tech.uid if learnable else -1)
	b.pressed.connect(details)
	b.gui_input.connect(func(event: InputEvent):
		var right: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed
		var key_i: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I
		if right or key_i:
			b.accept_event()
			details.call())
	return b


func _tile_label(text: String, variation: StringName, fill: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fill:  # a line of its own, cut short with an ellipsis; a corner marker keeps its width
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## "Available · 3 insight", then why it can't be learned, what it gives, its eureka, and how to see the details.
func _tooltip(e: GameEngine, tech: Dictionary) -> String:
	var state: String = tech.state
	var lines: PackedStringArray = [STATE_WORD[state]]
	if state != GameEngine.TECH_RESEARCHED:
		lines[0] += " · %d insight" % tech.cost
	if state == GameEngine.TECH_AVAILABLE:
		var error := e.buy_tech_error(tech.uid)
		if error != "":
			lines.append(error)
	if not tech.gives.is_empty():
		lines.append("gives " + ", ".join(PackedStringArray(tech.gives.map(func(id): return e.card_db[id].name))))
	var eureka: String = e.card_db[tech.id].eureka_text(e.card_db)
	if eureka != "" and state != GameEngine.TECH_RESEARCHED:
		lines.append(eureka)
	if tech.prereq != "" and state != GameEngine.TECH_LOCKED:
		lines.append("after " + e.card_db[tech.prereq].name)
	lines.append("Click, right click or I for the details.")
	return "\n".join(lines)
