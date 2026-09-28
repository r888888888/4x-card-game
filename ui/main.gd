extends Control
## Main game screen. The layout is built in code so the prototype is easy to
## change. It holds no game state: it renders Game.engine and forwards player actions.
##
## Card views stay alive between refreshes (_views, keyed by uid), so they can animate from where
## they were to where the engine now says they are. Cards in motion live on _fx, a layer above the
## board; at rest they sit in slot Controls inside the hand, tableau, frontier and choice containers.

const SECTION_GAP := 22  # between the frontier, tableau and hand sections
const HEADING_GAP := 6  # from a heading to its content
const CARD_GAP := 10  # between cards in a row
const GROUP_GAP := 16  # between territory groups in the tableau
const GROUP_PADDING := 11  # inside a territory group's frame
const PANEL_COLOR := Color("171a1e")  # log panel background

var _turn_label: Label
var _food_label: Label
var _score_label: Label
var _pop_label: Label
var _piles_label: Label
var _seed_edit: LineEdit
var _tableau: HFlowContainer  # holds one group per territory, then the ghost
var _groups := {}  # territory uid (-1 for cards with no territory) -> TerritoryGroup
var _tableau_scroll: ScrollContainer
var _hand: HBoxContainer
var _frontier: HBoxContainer  # discovered, unsettled territories
var _frontier_section: Control  # the frontier's heading and row, hidden while it is empty
var _choice_overlay: Control  # dims the board while an explore choice is pending
var _choice_panel: PanelContainer  # the centred panel on _choice_overlay
var _reveal: HBoxContainer  # the revealed territories to choose from, inside _choice_panel
var _log: RichTextLabel
var _end_turn_button: Button
var _game_over_overlay: Control
var _game_over_label: Label

var _fx: Control  # effects layer: flying, dragged and leaving cards, resource tokens, errors
var _views := {}  # uid -> CardView
var _dragging: CardView
var _targeting: CardView  # hand card waiting for a target click (double-click with several targets)
var _lit: Array[int] = []  # uids of the target views lit up for the dragged or targeting card
var _drop_highlight: Panel  # lights up the tableau (the drop zone) during a drag
var _drop_style: StyleBoxFlat
var _drag_hint: PanelContainer  # the engine's reason, under the dragged card while it shows red
var _drag_hint_label: Label
var _ghost: Panel  # outline of the tableau slot a dragged building or city will land in (in its group)
var _show_ghost := false  # the dragged card is a targeted permanent: the ghost follows its target group
var _outcome := {}  # the last card_played outcome, animated by the next _refresh
var _outcome_point := Vector2.ZERO  # where the played card was when it was played


## The framed box for one territory in the tableau: a slot count and Grow button, then a row of card slots.
class TerritoryGroup:
	var uid := -1  # the territory's uid (-1: cards on no territory)
	var frame: PanelContainer
	var style: StyleBoxFlat
	var label: Label
	var grow_button: Button
	var row: HBoxContainer

	func set_lit(on: bool) -> void:
		style.border_color = CardView.HIGHLIGHT_COLOR if on else CardView.TYPE_COLORS.territory
		style.set_border_width_all(3 if on else 1)


func _ready() -> void:
	_build_layout()
	if not Game.load_errors.is_empty():
		_show_load_errors(Game.load_errors)
		return
	Game.engine.changed.connect(_refresh)
	Game.engine.logged.connect(_append_log)
	Game.engine.card_played.connect(_on_card_played)
	_start_game(-1)


func _unhandled_key_input(event: InputEvent) -> void:
	# Enter/Space ends the turn (unless a text field has focus).
	if event.is_action_pressed("ui_accept") and Game.engine != null and not Game.engine.is_over \
			and Game.engine.pending_choice.is_empty():
		Game.engine.end_turn()


func _input(event: InputEvent) -> void:
	if _targeting != null:
		var cancel: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
		cancel = cancel or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
		if cancel:
			get_viewport().set_input_as_handled()
			_end_targeting()
		return
	if _dragging == null:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			get_viewport().set_input_as_handled()
			_drop()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			get_viewport().set_input_as_handled()
			_cancel_drag()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel_drag()
	elif event is InputEventMouseMotion:
		_update_drag_feedback()


# --- Actions ---

func _start_game(seed_value: int) -> void:
	if seed_value < 0:
		seed_value = randi_range(1, 999999)
	_seed_edit.text = str(seed_value)
	_log.clear()
	_reset_views()
	Game.new_game(seed_value)


func _on_restart_pressed() -> void:
	var text := _seed_edit.text.strip_edges()
	_start_game(text.to_int() if text.is_valid_int() else -1)


## Plays the card (on target_uid) if it's legal; otherwise sends it back with a shake and says why.
func _try_play(view: CardView, target_uid := -1) -> void:
	var error := Game.engine.play_error(view.uid, target_uid)
	if error != "":
		_log.append_text("[color=#e88]%s[/color]\n" % error)
		_show_error(view, error)
		view.reject()
		return
	Game.engine.play_card(view.uid, target_uid)


## Why a hand card can't be played at all, or "". A card that needs a target is checked against
## its first valid target, so "choose a target" doesn't grey it out.
func _hand_error(uid: int) -> String:
	var e := Game.engine
	var targets := e.valid_targets(uid)
	return e.play_error(uid, targets[0] if e.needs_target(uid) and not targets.is_empty() else -1)


func _on_double_clicked(view: CardView) -> void:
	if _targeting != null:
		_end_targeting()
	if _dragging != null or not Game.engine.pending_choice.is_empty():
		return
	var e := Game.engine
	if e.needs_target(view.uid) and e.valid_targets(view.uid).size() > 1 and _hand_error(view.uid) == "":
		_begin_targeting(view)
	else:
		_try_play(view)


func _on_picked(view: CardView) -> void:
	if _targeting != null:
		var card := _targeting
		_end_targeting()
		_try_play(card, view.uid)
	else:
		Game.engine.choose(view.uid)


# --- Targeting mode (double-click on a card with several targets) ---

func _begin_targeting(view: CardView) -> void:
	_targeting = view
	view.set_highlight(true)
	_light_targets(view.uid, true)
	_log.append_text("[color=#ffd966]Click a territory to play %s on (Esc cancels).[/color]\n"
		% Game.engine.zone("hand").find(view.uid).def.name)


func _end_targeting() -> void:
	if is_instance_valid(_targeting):
		_targeting.set_highlight(false)
	_targeting = null
	_unlight_targets()


## Lights up the valid targets of hand card uid; clickable makes them pickable (targeting mode).
func _light_targets(uid: int, clickable: bool) -> void:
	_lit = Game.engine.valid_targets(uid)
	for target in _lit:
		if _groups.has(target):
			_groups[target].set_lit(true)
		var view: CardView = _views.get(target)
		if view != null:
			view.set_highlight(true)
			if clickable:
				view.set_pickable(true, "Click to play the card here.")


func _unlight_targets() -> void:
	for target in _lit:
		if _groups.has(target):
			_groups[target].set_lit(false)
		var view: CardView = _views.get(target)
		if view != null:
			view.set_highlight(false)
			var in_reveal := is_instance_valid(view.slot) and view.slot.get_parent() == _reveal
			view.set_pickable(in_reveal, "Click to keep this territory.")
	_lit = []


# --- Dragging ---

func _on_drag_requested(view: CardView, grab_offset: Vector2) -> void:
	if _targeting != null:
		_end_targeting()
	if _dragging != null or Game.engine.is_over or not Game.engine.pending_choice.is_empty():
		return
	_dragging = view
	view.begin_drag(_fx, grab_offset)
	var e := Game.engine
	var card := e.zone("hand").find(view.uid)
	if _hand_error(view.uid) == "":
		if e.needs_target(view.uid):
			_light_targets(view.uid, false)
			_show_ghost = card.def.is_permanent()
		else:
			_drop_highlight.global_position = _tableau_scroll.global_position
			_drop_highlight.size = _tableau_scroll.size
			_drop_highlight.show()
			if card.def.is_permanent():
				_ghost.show()
				_tableau.move_child(_ghost, -1)
	_update_drag_feedback()


## Red when the drop here would fail: over a card it can't target, or in the drop zone when the
## card can't be played (or needs a target to be picked).
func _update_drag_feedback() -> void:
	var e := Game.engine
	var over := _over_drop_zone()
	var target := _target_under_mouse()
	var error := e.play_error(_dragging.uid)
	if e.needs_target(_dragging.uid) and target != -1:
		error = e.play_error(_dragging.uid, target)
	_dragging.set_warning(over and error != "")
	_drop_style.bg_color.a = 0.10 if over else 0.03
	_drag_hint.visible = over and error != ""
	if _drag_hint.visible:
		_drag_hint_label.text = error
		_drag_hint.reset_size()
		var card := _dragging.get_global_rect()
		_drag_hint.global_position = Vector2(
			clampf(card.get_center().x - _drag_hint.size.x / 2, 8.0, size.x - _drag_hint.size.x - 8.0), card.end.y + 8)
	if _show_ghost:
		# In the lit group under the cursor, or in the only lit group.
		var group_key := target if _lit.has(target) else (_lit[0] if _lit.size() == 1 else -1)
		_move_ghost(_groups[group_key].row if _groups.has(group_key) else null)


## Shows the ghost at the end of row, or hides it back in the tableau when row is null.
func _move_ghost(row: HBoxContainer) -> void:
	var parent: Control = row if row != null else _tableau
	if _ghost.get_parent() != parent:
		_ghost.reparent(parent, false)
	parent.move_child(_ghost, -1)
	_ghost.visible = row != null


## The drop zone: the tableau, plus the frontier row when it is showing (settle targets live there).
func _over_drop_zone() -> bool:
	var mouse := get_global_mouse_position()
	return _tableau_scroll.get_global_rect().has_point(mouse) \
		or (_frontier.is_visible_in_tree() and _frontier.get_global_rect().has_point(mouse))


## What the mouse is over as a target: a territory group's territory uid, else the uid of the
## tableau or frontier card under it, else -1.
func _target_under_mouse() -> int:
	var mouse := get_global_mouse_position()
	for key in _groups:
		if key != -1 and _groups[key].frame.get_global_rect().has_point(mouse):
			return key
	for uid in _views:
		var view: CardView = _views[uid]
		if view.in_hand or view == _dragging or view.state != CardView.State.REST:
			continue
		if view.slot.get_parent() != _reveal and view.get_global_rect().has_point(mouse):
			return uid
	return -1


func _drop() -> void:
	var view := _dragging
	var over := _over_drop_zone()
	var target := _target_under_mouse() if Game.engine.needs_target(view.uid) else -1
	_end_drag()
	if over:
		_try_play(view, target)
	else:
		view.return_home()


func _cancel_drag() -> void:
	var view := _dragging
	_end_drag()
	view.return_home()


func _end_drag() -> void:
	_dragging.set_warning(false)
	_dragging = null
	_drop_highlight.hide()
	_drag_hint.hide()
	_move_ghost(null)
	_show_ghost = false
	_unlight_targets()


# --- Rendering ---

func _on_card_played(outcome: Dictionary) -> void:
	_outcome = outcome
	var view: CardView = _views.get(outcome.uid)
	_outcome_point = view.get_global_rect().get_center() if view != null else size / 2


## Brings the views in line with the engine: new cards are dealt in from the deck or pop into place,
## cards that changed zone fly to their new place, and cards that left fly towards where they went.
func _refresh() -> void:
	var e := Game.engine
	_set_stat(_turn_label, "Turn %d / %d" % [e.turn, e.turn_limit()])
	_set_stat(_food_label, "Food: %d" % e.resources.get("food", 0))
	_set_stat(_score_label, "Score: %d" % e.score())
	_pop_label.visible = e.population_on()
	_set_stat(_pop_label, "Pop: %d" % e.total_pop())
	_set_stat(_piles_label, "Deck %d  ·  Discard %d" % [e.zone("deck").size(), e.zone("discard").size()])

	var hand := e.zone("hand").cards
	var tableau := e.zone("tableau").cards
	var frontier := e.zone("frontier").cards
	var reveal := e.zone("reveal").cards
	var shown := {}
	for card in hand + tableau + frontier + reveal:
		shown[card.uid] = true
	for uid in _views.keys():
		if not shown.has(uid):
			_remove_view(uid)
	var dealt := 0
	for i in hand.size():
		if _place(hand[i], true, _hand, i, dealt * Anim.DEAL_STAGGER):
			dealt += 1
	_place_tableau(tableau)
	for i in frontier.size():
		_place(frontier[i], false, _frontier, i, 0.0)
	for i in reveal.size():
		_place(reveal[reveal.size() - 1 - i], false, _reveal, i, 0.0)  # top of the deck first
	_frontier_section.visible = not frontier.is_empty()
	_choice_overlay.visible = not e.pending_choice.is_empty()
	_animate_outcome()

	_end_turn_button.disabled = e.is_over or not e.pending_choice.is_empty()
	_game_over_overlay.visible = e.is_over
	if e.is_over:
		_game_over_label.text = "Game over\n\nFinal score: %d\nSeed: %d" % [e.score(), e.seed_value]


## Places tableau cards in territory groups: each territory card first, then the cards on it.
## Cards with no territory go in a last group. Empty groups are removed.
func _place_tableau(tableau: Array[CardInstance]) -> void:
	var e := Game.engine
	var members := {}  # group key -> Array[CardInstance], in tableau order
	var order: Array[int] = []
	for card in tableau:
		var key := -1
		if card.def.type == "territory":
			key = card.uid
		elif e.territory_of(card) != null:
			key = card.territory_uid
		if not members.has(key):
			members[key] = []
			if key != -1:
				order.append(key)
		if card.def.type == "territory":
			members[key].push_front(card)
		else:
			members[key].append(card)
	if members.has(-1):
		order.append(-1)
	for i in order.size():
		var key := order[i]
		if not _groups.has(key):
			_groups[key] = _new_group()
		var group: TerritoryGroup = _groups[key]
		_tableau.move_child(group.frame, i)
		for j in members[key].size():
			_place(members[key][j], false, group.row, j, 0.0)
		group.uid = key
		group.label.visible = key != -1
		group.grow_button.visible = key != -1 and e.population_on()
		if group.grow_button.visible:
			var error := e.grow_error(key)
			group.grow_button.text = "Grow (%d food)" % e.grow_cost(key)
			group.grow_button.disabled = error != ""
			group.grow_button.tooltip_text = error
		if key != -1:
			var slots: int = e.zone("tableau").find(key).def.slots
			var text := "%d / %d slots used" % [slots - e.free_slots(key), slots]
			if e.population_on():
				text += "  ·  Pop %d / %d" % [e.pop(key), e.housing(key)]
			_set_stat(group.label, text)
	for key in _groups.keys():
		if not members.has(key):
			_groups[key].frame.queue_free()
			_tableau.remove_child(_groups[key].frame)
			_groups.erase(key)
	_tableau.move_child(_ghost, -1)


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
	box.add_theme_constant_override("separation", HEADING_GAP)
	group.frame.add_child(box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	group.label = _heading("")
	header.add_child(group.label)
	group.grow_button = _button("", func(): Game.engine.grow(group.uid))
	group.grow_button.add_theme_font_size_override("font_size", 16)
	header.add_child(group.grow_button)
	group.row = HBoxContainer.new()
	group.row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.row.add_theme_constant_override("separation", CARD_GAP)
	box.add_child(group.row)
	_tableau.add_child(group.frame)
	return group


## Makes sure card has a view resting in (or flying to) a slot at index in container.
## Returns true if the card was newly dealt into the hand.
func _place(card: CardInstance, in_hand: bool, container: Container, index: int, delay: float) -> bool:
	var e := Game.engine
	var error := _hand_error(card.uid) if in_hand else ""
	var view: CardView = _views.get(card.uid)
	if view == null:
		view = CardView.new()
		view.setup(card, e.card_db, in_hand, error)
		view.set_pickable(container == _reveal, "Click to keep this territory.")
		view.drag_requested.connect(_on_drag_requested)
		view.double_clicked.connect(_on_double_clicked)
		view.picked.connect(_on_picked)
		_views[card.uid] = view
		var slot := _new_slot(in_hand, container, index)
		if in_hand:
			view.deal(slot, _fx, _pile_point(0.25), delay)
		else:
			view.pop_in(slot)
		return in_hand
	if view.slot.get_parent() != container:
		if view == _dragging:
			_end_drag()
		var old_slot := view.slot
		view.setup(card, e.card_db, in_hand, error)
		view.set_pickable(container == _reveal, "Click to keep this territory.")
		view.fly_to_slot(_new_slot(in_hand, container, index), _fx)
		_free_slot(old_slot)
		return false
	container.move_child(view.slot, index)
	if in_hand:
		view.set_play_error(error)
	else:
		view.set_idle(e.is_idle(card.uid))
	return false


## The card is no longer shown: it flies towards the zone it went to and fades (popping first if it
## was just played, so the player sees it resolve).
func _remove_view(uid: int) -> void:
	var view: CardView = _views[uid]
	_views.erase(uid)
	if view == _dragging:
		_end_drag()
	if view == _targeting:
		_end_targeting()
	var old_slot := view.slot
	var just_played: bool = not _outcome.is_empty() and _outcome.uid == uid
	var via: Variant = null
	if just_played and _views.has(_outcome.target):  # fly to where it was played, e.g. the settled territory
		via = (_views[_outcome.target] as CardView).get_global_rect().get_center()
	view.leave(_fx, _leave_point(uid), just_played, via)
	_free_slot(old_slot)


## Where a card that left the board flies: the deck or discard counter, or for a territory put back
## in the territory deck, the edge of the choice panel.
func _leave_point(uid: int) -> Vector2:
	var e := Game.engine
	if e.zone("territory_deck").find(uid) != null:
		var r := _choice_panel.get_global_rect()
		return Vector2(r.end.x, r.get_center().y)
	if e.zone("deck").find(uid) != null:
		return _pile_point(0.25)
	return _pile_point(0.75)


## Resource tokens for the last play: costs fly from the counters to the card, gains and VP fly
## from the card to the counters, which pulse when they arrive.
func _animate_outcome() -> void:
	if _outcome.is_empty():
		return
	var o := _outcome
	_outcome = {}
	var n := 0
	for r in o.paid:
		var label := _resource_label(r)
		if label != null:
			var from := label.get_global_rect().get_center() + Vector2(0, label.size.y)  # just below the counter
			_fly_token("−%d %s" % [o.paid[r], r], from, _outcome_point,
				Color("ff8a80"), null, n * Anim.TOKEN_STAGGER)
			n += 1
	for r in o.gained:
		var label := _resource_label(r)
		if label != null and o.gained[r] != 0:
			_fly_token("+%d %s" % [o.gained[r], r], _outcome_point, label.get_global_rect().get_center(),
				Color("ffd966"), label, n * Anim.TOKEN_STAGGER)
			n += 1
	if o.vp != 0:
		_fly_token("+%d VP" % o.vp, _outcome_point, _score_label.get_global_rect().get_center(),
			Color("ffd966"), _score_label, n * Anim.TOKEN_STAGGER)


func _resource_label(resource: String) -> Label:
	return _food_label if resource == "food" else null


func _fly_token(text: String, from: Vector2, to: Vector2, color: Color, pulse_on_arrival: Control, delay: float) -> void:
	var token := _fx_label(text, 26, color)
	token.modulate.a = 0.0
	_fx.add_child(token)
	token.reset_size()
	token.global_position = from - token.size / 2
	var t := token.create_tween()
	t.tween_interval(delay)
	t.tween_property(token, "modulate:a", 1.0, 0.1)
	t.tween_property(token, "global_position", to - token.size / 2, Anim.TOKEN_FLY_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if pulse_on_arrival != null:
		t.tween_callback(_pulse.bind(pulse_on_arrival))
	t.tween_property(token, "modulate:a", 0.0, 0.12)
	t.tween_callback(token.queue_free)


## A short message on a dark backing over the card, drifting up and fading out.
func _show_error(view: CardView, text: String) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	style.border_color = Color("ff8a80")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.z_index = 3  # above flying cards
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(_fx_label(text, 20, Color("ff8a80")))
	_fx.add_child(panel)
	panel.reset_size()
	var home := view.slot.get_global_rect() if is_instance_valid(view.slot) else view.get_global_rect()
	var x := clampf(home.get_center().x - panel.size.x / 2, 8.0, size.x - panel.size.x - 8.0)
	panel.global_position = Vector2(x, home.position.y + home.size.y * 0.35)
	var t := panel.create_tween()
	t.tween_property(panel, "global_position:y", panel.global_position.y - 30, Anim.ERROR_SHOW_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(panel, "modulate:a", 0.0, Anim.ERROR_SHOW_TIME) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(panel.queue_free)


## Sets a stat label, pulsing it when the value changes.
func _set_stat(label: Label, text: String) -> void:
	if label.text != "" and label.text != text:
		_pulse(label)
	label.text = text


func _pulse(node: Control) -> void:
	node.pivot_offset = node.size / 2
	node.scale = Vector2.ONE * Anim.PULSE_SCALE
	node.create_tween().tween_property(node, "scale", Vector2.ONE, Anim.PULSE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A point on the "Deck N · Discard M" label: 0.25 is roughly the deck, 0.75 the discard pile.
func _pile_point(fraction: float) -> Vector2:
	var r := _piles_label.get_global_rect()
	return Vector2(r.position.x + r.size.x * fraction, r.get_center().y)


func _new_slot(in_hand: bool, container: Container, index: int) -> Control:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = CardView.HAND_SIZE + Vector2(0, Anim.LIFT_ROOM) if in_hand else CardView.TABLEAU_SIZE
	container.add_child(slot)
	container.move_child(slot, index)
	return slot


## Removes a slot now (so the container relayouts this frame) and frees it.
func _free_slot(slot: Control) -> void:
	if is_instance_valid(slot):
		slot.get_parent().remove_child(slot)
		slot.queue_free()


## Drops every view without animating (new game or restart).
func _reset_views() -> void:
	if _dragging != null:
		_end_drag()
	_end_targeting()
	for uid in _views:
		var view: CardView = _views[uid]
		_free_slot(view.slot)
		view.queue_free()
	_views.clear()
	_outcome = {}
	for child in _fx.get_children():
		if child != _drop_highlight and child != _drag_hint:
			child.queue_free()


func _append_log(message: String) -> void:
	if message.begins_with("—"):
		_log.append_text("\n[b]%s[/b]\n" % message)
	elif message.begins_with("Game over"):
		_log.append_text("[b][color=#e8c547]%s[/color][/b]\n" % message)
	else:
		_log.append_text(message + "\n")


func _show_load_errors(errors: Array[String]) -> void:
	var overlay := _overlay(CardView.WARN_COLOR)
	var box := overlay.get_meta("box") as VBoxContainer
	box.add_child(_heading("Game data has errors — fix data/*.json and restart"))
	var text := RichTextLabel.new()
	text.custom_minimum_size = Vector2(800, 400)
	text.text = "\n".join(PackedStringArray(errors))
	box.add_child(text)
	overlay.visible = true


# --- Layout ---

func _build_layout() -> void:
	# Default text size for everything without an explicit override (log, buttons, inputs).
	theme = Theme.new()
	theme.default_font_size = 20

	var bg := ColorRect.new()
	bg.color = Color("1d2126")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Top bar: stats + seed controls.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 36)
	root.add_child(bar)
	_turn_label = _stat(bar)
	_food_label = _stat(bar, Color("ffd966"))
	_score_label = _stat(bar, Color("ffd966"))
	_pop_label = _stat(bar, Color("9fd89f"))
	_piles_label = _stat(bar, Color("c3cad3"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	bar.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size.x = 130
	_seed_edit.tooltip_text = "Restart replays this seed (same shuffle)."
	bar.add_child(_seed_edit)
	bar.add_child(_button("Restart", _on_restart_pressed))
	bar.add_child(_button("New game", func(): _start_game(-1)))

	# Body: play area on the left, log + end turn on the right.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var play_area := VBoxContainer.new()
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.add_theme_constant_override("separation", SECTION_GAP)
	body.add_child(play_area)

	_frontier_section = _section(play_area, "Frontier — discovered, not yet settled")
	_frontier_section.hide()
	var frontier_scroll := ScrollContainer.new()
	frontier_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frontier_section.add_child(frontier_scroll)
	_frontier = HBoxContainer.new()
	_frontier.add_theme_constant_override("separation", CARD_GAP)
	frontier_scroll.add_child(_frontier)

	var tableau_section := _section(play_area, "Tableau")
	tableau_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tableau_scroll = ScrollContainer.new()
	_tableau_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tableau_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Room for one territory group (header, a row of tableau cards, padding) before it scrolls.
	_tableau_scroll.custom_minimum_size.y = CardView.TABLEAU_SIZE.y + 100
	tableau_section.add_child(_tableau_scroll)
	_tableau = HFlowContainer.new()
	_tableau.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tableau.add_theme_constant_override("h_separation", GROUP_GAP)
	_tableau.add_theme_constant_override("v_separation", GROUP_GAP)
	_tableau_scroll.add_child(_tableau)

	var hand_section := _section(play_area, "Hand — drag a card into the tableau to play it (or double-click)")
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = CardView.HAND_SIZE.y + Anim.LIFT_ROOM + 20
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_section.add_child(hand_scroll)
	var hand_pad := MarginContainer.new()
	hand_pad.add_theme_constant_override("margin_left", int(Anim.HAND_SIDE_ROOM))
	hand_pad.add_theme_constant_override("margin_right", int(Anim.HAND_SIDE_ROOM))
	hand_scroll.add_child(hand_pad)
	_hand = HBoxContainer.new()
	_hand.add_theme_constant_override("separation", 12)
	hand_pad.add_child(_hand)

	var side_col := _section(body, "Log")
	side_col.custom_minimum_size.x = 400
	side_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var log_panel := PanelContainer.new()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_COLOR, Color(1, 1, 1, 0.08), 12))
	side_col.add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 19)
	_log.add_theme_font_size_override("bold_font_size", 20)
	_log.add_theme_color_override("default_color", Color("dde3ea"))
	log_panel.add_child(_log)
	_end_turn_button = _button("End turn  (Enter)", func(): Game.engine.end_turn())
	_end_turn_button.custom_minimum_size.y = 60
	_end_turn_button.add_theme_font_size_override("font_size", 24)
	side_col.add_child(_end_turn_button)

	# Effects layer, above the board and below the overlays.
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)
	_drop_style = StyleBoxFlat.new()
	_drop_style.bg_color = Color(1, 0.85, 0.4, 0.03)
	_drop_style.border_color = Color("ffd966")
	_drop_style.set_border_width_all(3)
	_drop_style.set_corner_radius_all(10)
	_drop_highlight = Panel.new()
	_drop_highlight.add_theme_stylebox_override("panel", _drop_style)
	_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_highlight.hide()
	_fx.add_child(_drop_highlight)
	_drag_hint = PanelContainer.new()
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	hint_style.border_color = CardView.WARN_COLOR
	hint_style.set_border_width_all(1)
	hint_style.set_corner_radius_all(6)
	hint_style.set_content_margin_all(8)
	_drag_hint.add_theme_stylebox_override("panel", hint_style)
	_drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_hint.z_index = 3  # above the dragged card
	_drag_hint_label = _fx_label("", 19, Color("ff8a80"))
	_drag_hint.add_child(_drag_hint_label)
	_drag_hint.hide()
	_fx.add_child(_drag_hint)
	var pulse := _drop_highlight.create_tween().set_loops()
	pulse.tween_property(_drop_highlight, "modulate:a", 0.45, Anim.HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_drop_highlight, "modulate:a", 1.0, Anim.HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)

	var ghost_style := StyleBoxFlat.new()
	ghost_style.bg_color = Color(1, 1, 1, 0.04)
	ghost_style.border_color = Color(1, 1, 1, 0.35)
	ghost_style.set_border_width_all(2)
	ghost_style.set_corner_radius_all(8)
	_ghost = Panel.new()
	_ghost.add_theme_stylebox_override("panel", ghost_style)
	_ghost.custom_minimum_size = CardView.TABLEAU_SIZE
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.hide()
	_tableau.add_child(_ghost)

	# Explore choice: a centred panel over the dimmed board, so the board keeps its layout.
	_choice_overlay = _overlay(CardView.TYPE_COLORS.territory)
	_choice_overlay.z_index = 5  # above lifted cards, below the game-over overlay
	_choice_panel = _choice_overlay.get_meta("panel")
	var choice_box := _choice_overlay.get_meta("box") as VBoxContainer
	var choice_title := _heading("Explore")
	choice_title.add_theme_font_size_override("font_size", 26)
	choice_title.add_theme_color_override("font_color", Color.WHITE)
	choice_box.add_child(choice_title)
	choice_box.add_child(_heading("Keep one territory in the frontier; the other goes to the bottom of the territory deck."))
	_reveal = HBoxContainer.new()
	_reveal.add_theme_constant_override("separation", CARD_GAP)
	choice_box.add_child(_reveal)

	# Game-over overlay.
	_game_over_overlay = _overlay()
	var box := _game_over_overlay.get_meta("box") as VBoxContainer
	_game_over_label = _heading("")
	_game_over_label.add_theme_font_size_override("font_size", 32)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_game_over_label)
	box.add_child(_button("Replay this seed", _on_restart_pressed))
	box.add_child(_button("New game", func(): _start_game(-1)))


## Full-screen dimmer with a centred, opaque panel. The panel is stored as meta "panel" and its
## VBox as meta "box".
func _overlay(border := Color(1, 1, 1, 0.25)) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 10  # above lifted and flying cards
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color("262b31"), border, 24))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	overlay.set_meta("panel", panel)
	overlay.set_meta("box", box)
	return overlay


## A section of the board: a heading with its content close under it. Returns the VBox to add
## the content to.
func _section(parent: Control, title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADING_GAP)
	section.add_child(_heading(title))
	parent.add_child(section)
	return section


static func _panel_style(bg: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a < 1.0 else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(padding)
	return style


func _stat(parent: Control, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("b4bcc6"))
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # so Enter always means "end turn"
	button.pressed.connect(on_pressed)
	return button


func _fx_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 3  # above flying cards
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	return label
