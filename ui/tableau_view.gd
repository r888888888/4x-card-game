class_name TableauView
extends ScrollContainer
## The tableau: one framed group per territory (slot count, pop and a Grow button over a row of card slots), then
## the ghost, the outline of the slot a dragged building or city will land in. The scroll box is the drop zone.

const GROUP_GAP := 16  # between territory groups
const GROUP_PADDING := 11  # inside a territory group's frame

var ghost: Panel
var _flow: HFlowContainer  # holds one group per territory, then the ghost
var _groups := {}  # territory uid (-1 for cards with no territory) -> TerritoryGroup


## The framed box for one territory: a slot count and Grow button, then a row of card slots.
class TerritoryGroup:
	var uid := -1  # the territory's uid (-1: cards on no territory)
	var frame: PanelContainer
	var style: StyleBoxFlat
	var label: Label
	var grow_button: Button
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
		for j in groups[i].cards.size():
			place.call(tableau.find(groups[i].cards[j]), group.row, j)
		group.uid = key
		group.label.visible = key != -1
		group.grow_button.visible = key != -1 and e.population_on()
		if group.grow_button.visible:
			var error := e.grow_error(key)
			group.grow_button.text = "Grow (%d food)" % e.grow_cost(key)
			group.grow_button.disabled = error != ""
			group.grow_button.tooltip_text = error
		if key != -1:
			var slots := e.total_slots(key)
			var text := "%d / %d slots used" % [slots - e.free_slots(key), slots]
			if e.population_on():
				text += "  ·  Pop %d / %d" % [e.pop(key), e.housing(key)]
			UIKit.set_stat(group.label, text)
	for key in _groups.keys():
		if not shown.has(key):
			_groups[key].frame.queue_free()
			_flow.remove_child(_groups[key].frame)
			_groups.erase(key)
	_flow.move_child(ghost, -1)
	_fit_rows()


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
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	group.label = UIKit.heading("")
	header.add_child(group.label)
	group.grow_button = UIKit.button("", func(): Game.engine.grow(group.uid))
	header.add_child(group.grow_button)
	group.row = HFlowContainer.new()
	group.row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.row.add_theme_constant_override("h_separation", UIKit.CARD_GAP)
	group.row.add_theme_constant_override("v_separation", UIKit.CARD_GAP)
	box.add_child(group.row)
	_flow.add_child(group.frame)
	return group
