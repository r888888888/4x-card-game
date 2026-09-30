class_name TableauView
extends ScrollContainer
## The tableau: one framed group per territory (slot count, pop and a Grow button over a row of card slots), then
## the ghost, the outline of the slot a dragged building or city will land in. The scroll box is the drop zone.
## A group's territory is its title bar, and a group can be collapsed to that and a one-line summary of what's built
## on it (087).

## A group was collapsed or expanded: the board refreshes (the Collapse all button's text).
signal collapse_changed

const GROUP_GAP := 16  # between territory groups
const GROUP_PADDING := 11  # inside a territory group's frame

var ghost: Panel
var _flow: HFlowContainer  # holds one group per territory, then the ghost
var _groups := {}  # territory uid (-1 for cards with no territory) -> TerritoryGroup
var _collapsed := {}  # territory uid -> true while its group is collapsed; cleared by reset (a new game)


## The framed box for one territory: a slot count and Grow button, then a row of card slots.
class TerritoryGroup:
	var uid := -1  # the territory's uid (-1: cards on no territory)
	var frame: PanelContainer
	var style: StyleBoxFlat
	var label: Label
	var grow_button: Button
	var toggle: Button  # ▾ / ▸: collapse or expand the group (none for the no-territory group)
	var header: VBoxContainer  # the title line (toggle, the territory's title bar) over the stats line
	var banner: HBoxContainer  # holds the territory's view, drawn as the group's title bar (087)
	var summary: Label  # "1 city · 3 buildings (1 idle)", shown while collapsed
	var row: HFlowContainer  # wraps; _fit_rows keeps it no wider than the tableau (078)

	func set_lit(on: bool) -> void:
		style.border_color = CardView.HIGHLIGHT_COLOR if on else CardView.TYPE_COLORS.territory
		style.set_border_width_all(3 if on else 1)


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Room for one territory group (header, a row of tableau cards, padding) before it scrolls.
	custom_minimum_size.y = CardView.TABLEAU_SIZE.y + 115
	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", GROUP_GAP)
	_flow.add_theme_constant_override("v_separation", GROUP_GAP)
	add_child(_flow)
	resized.connect(_fit_rows)
	var ghost_style := StyleBoxFlat.new()
	ghost_style.bg_color = Color(1, 1, 1, 0.04)
	ghost_style.border_color = Color(1, 1, 1, 0.35)
	ghost_style.set_border_width_all(2)
	ghost_style.set_corner_radius_all(8)
	ghost = Panel.new()
	ghost.add_theme_stylebox_override("panel", ghost_style)
	ghost.custom_minimum_size = CardView.TABLEAU_SIZE
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.hide()
	_flow.add_child(ghost)


## Lays out engine e's territory groups, calling place(card, row, index) for each tableau card. Empty groups
## are removed.
func refresh(e: GameEngine, place: Callable) -> void:
	var tableau := e.zone("tableau")
	var groups := e.territory_groups()
	var shown := {}  # group keys in use
	for i in groups.size():
		var key: int = groups[i].territory
		shown[key] = true
		if not _groups.has(key):
			_groups[key] = _new_group()
		var group: TerritoryGroup = _groups[key]
		_flow.move_child(group.frame, i)
		var cards: Array = groups[i].cards
		if key != -1:  # the territory (always first) is the title bar; the rest go in the row
			place.call(tableau.find(cards[0]), group.banner, 0)
			cards = cards.slice(1)
		for j in cards.size():
			place.call(tableau.find(cards[j]), group.row, j)
		group.uid = key
		group.toggle.visible = key != -1
		group.label.visible = key != -1
		group.grow_button.visible = false
		if key != -1:
			TerritoryView.show_grow(group.grow_button, e, key)
			UIKit.set_stat(group.label, TerritoryView.stats(e, key))
	for key in _groups.keys():
		if not shown.has(key):
			_groups[key].frame.queue_free()
			_flow.remove_child(_groups[key].frame)
			_groups.erase(key)
			_collapsed.erase(key)
	_flow.move_child(ghost, -1)
	for key in _groups:
		_apply_collapse(_groups[key])
	_fit_rows()


## Forgets which groups were collapsed (a new game starts with every group expanded). Emits nothing: the new
## game's refresh lays the groups out.
func reset() -> void:
	_collapsed.clear()
	for key in _groups:
		_apply_collapse(_groups[key])


## Collapses (on) or expands territory uid's group.
func set_collapsed(uid: int, on: bool) -> void:
	on = on and has_toggle(uid)
	if on == is_collapsed(uid):
		return
	if on:
		_collapsed[uid] = true
	else:
		_collapsed.erase(uid)
	_apply_collapse(_groups[uid])
	_fit_rows()
	collapse_changed.emit()


func is_collapsed(uid: int) -> bool:
	return _collapsed.has(uid)


## Collapses (on) or expands every territory group.
func set_all_collapsed(on: bool) -> void:
	for key in _groups:
		set_collapsed(key, on)


## Whether every territory group is collapsed (false with none).
func all_collapsed() -> bool:
	var territories := _groups.keys().filter(func(k): return k != -1)
	return not territories.is_empty() and territories.all(func(k): return _collapsed.has(k))


## Whether territory uid's group has a collapse toggle (every group but the no-territory one).
func has_toggle(uid: int) -> bool:
	return uid != -1 and _groups.has(uid)


## The collapsed summary of territory uid's group, or "" while it is expanded.
func group_summary(uid: int) -> String:
	return _groups[uid].summary.text if _groups.has(uid) and _groups[uid].summary.visible else ""


## The framed box of territory uid's group, or null.
func group_frame(uid: int) -> Control:
	return _groups[uid].frame if _groups.has(uid) else null


## Expands the group holding tableau card uid, so a lit target inside it can be seen and reached. A territory is
## its group's title bar, shown even when collapsed, so lighting one (a building's target) leaves the group as it is.
func reveal(uid: int) -> void:
	for group in Game.engine.territory_groups():
		if group.cards.has(uid) and group.territory != uid:
			set_collapsed(group.territory, false)


## Whether container is a group's title-bar slot (the board draws the territory there as a banner).
func is_banner(container: Node) -> bool:
	return _groups.values().any(func(g): return g.banner == container)


## The header of territory uid's group (its title bar and stats line), or null.
func group_header(uid: int) -> Control:
	return _groups[uid].header if _groups.has(uid) else null


## Shows or hides a group's cards (the row; the territory stays as the title bar), its summary and its toggle arrow.
func _apply_collapse(group: TerritoryGroup) -> void:
	var on := _collapsed.has(group.uid)
	for slot in group.row.get_children():
		if slot != ghost:
			slot.visible = not on
	group.toggle.text = "▸" if on else "▾"
	group.toggle.tooltip_text = "Show the cards on this territory." if on else "Hide the cards on this territory."
	group.summary.visible = on
	if on:
		group.summary.text = _summary_text(Game.engine.territory_summary(group.uid))


static func _summary_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return ""
	var cities: int = summary.cities
	var buildings: int = summary.buildings
	var text := "%d %s · %d building%s" % [cities, "city" if cities == 1 else "cities", buildings, "" if buildings == 1 else "s"]
	if summary.idle > 0:
		text += " (%d idle)" % summary.idle
	return text


## Lights up (or dims) the group of territory uid, if it has one.
func set_lit(uid: int, on: bool) -> void:
	if _groups.has(uid):
		_groups[uid].set_lit(on)


## The territory uid of the group at point, or -1.
func group_at(point: Vector2) -> int:
	for key in _groups:
		if key != -1 and _groups[key].frame.get_global_rect().has_point(point):
			return key
	return -1


## Shows the ghost at the end of the tableau (a permanent with no target).
func show_ghost_at_end() -> void:
	ghost.show()
	_flow.move_child(ghost, -1)


## Shows the ghost at the end of territory uid's group, or hides it back in the tableau when there is no
## such group.
func move_ghost(uid: int) -> void:
	var parent: Control = _groups[uid].row if _groups.has(uid) else _flow
	if ghost.get_parent() != parent:
		ghost.reparent(parent, false)
	parent.move_child(ghost, -1)
	ghost.visible = parent != _flow
	_fit_rows()


## Gives each group's row the width of its cards in one line, capped at the tableau's width, so a full territory
## wraps its cards onto more lines instead of widening the tableau (and pushing the side panel off screen, 078).
func _fit_rows() -> void:
	var cap := maxf(size.x - 2 * GROUP_PADDING - get_v_scroll_bar().size.x, 0.0)
	for key in _groups:
		var row: HFlowContainer = _groups[key].row
		var width := 0.0
		for child in row.get_children():
			if child is Control and child.visible:
				width += child.get_combined_minimum_size().x + (UIKit.CARD_GAP if width > 0 else 0)
		row.custom_minimum_size.x = minf(width, cap)


## A framed group for one territory's cards, added to the tableau.
func _new_group() -> TerritoryGroup:
	var group := TerritoryGroup.new()
	group.frame = PanelContainer.new()
	group.frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN  # a collapsed group keeps its height beside a tall one
	group.style = StyleBoxFlat.new()
	group.style.bg_color = Color(1, 1, 1, 0.03)
	group.style.set_corner_radius_all(10)
	group.style.set_content_margin_all(GROUP_PADDING)
	group.set_lit(false)
	group.frame.add_theme_stylebox_override("panel", group.style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UIKit.HEADING_GAP)
	group.frame.add_child(box)
	group.header = VBoxContainer.new()
	group.header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.header.add_theme_constant_override("separation", 4)
	box.add_child(group.header)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	group.header.add_child(title)
	group.toggle = UIKit.button("▾", func(): set_collapsed(group.uid, not is_collapsed(group.uid)))
	title.add_child(group.toggle)
	group.banner = HBoxContainer.new()
	group.banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(group.banner)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	group.header.add_child(header)
	group.label = UIKit.heading("")
	header.add_child(group.label)
	group.grow_button = UIKit.button("", func(): Game.engine.grow(group.uid))
	header.add_child(group.grow_button)
	group.row = HFlowContainer.new()
	group.row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	group.row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	box.add_child(group.row)
	group.summary = UIKit.heading("")
	group.summary.hide()
	box.add_child(group.summary)
	_flow.add_child(group.frame)
	return group
