class_name DragController
extends RefCounted
## Dragging a hand card onto the board, and targeting mode (a double-click on a card with several targets, then
## a click on the target). While either is on, the card's valid targets are lit; a drag also lights the drop zone
## (the tableau), shows the engine's reason when the drop would fail, and the ghost slot a permanent will land in.

var dragging: CardView
var targeting: CardView  # hand card waiting for a target click
var lit: Array[int] = []  # uids of the target views lit up for the dragged or targeting card
var _board: MainScreen
var _drop_highlight: Panel  # lights up the tableau (the drop zone) during a drag
var _drop_style: StyleBoxFlat
var _drop_pulse: Tween  # the drop highlight's looping pulse; paused with reduce motion
var _hint: PanelContainer  # the engine's reason, under the dragged card while it shows red
var _hint_label: Label
var _show_ghost := false  # the dragged card is a targeted permanent: the ghost follows its target group


## Builds the drop highlight and the hint on board's effects layer.
func _init(board: MainScreen) -> void:
	_board = board
	_drop_style = StyleBoxFlat.new()
	_drop_style.bg_color = Color(1, 0.85, 0.4, 0.03)
	_drop_style.border_color = Color("ffd966")
	_drop_style.set_border_width_all(3)
	_drop_style.set_corner_radius_all(10)
	_drop_highlight = Panel.new()
	_drop_highlight.add_theme_stylebox_override("panel", _drop_style)
	_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_highlight.hide()
	board.fx.add_child(_drop_highlight)
	_hint = PanelContainer.new()
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color(0.08, 0.09, 0.11, 0.92)
	hint_style.border_color = CardView.WARN_COLOR
	hint_style.set_border_width_all(1)
	hint_style.set_corner_radius_all(6)
	hint_style.set_content_margin_all(8)
	_hint.add_theme_stylebox_override("panel", hint_style)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.z_index = 3  # above the dragged card
	_hint_label = UIKit.fx_label("", 19, UIKit.COST_COLOR)
	_hint.add_child(_hint_label)
	_hint.hide()
	board.fx.add_child(_hint)
	_drop_pulse = _drop_highlight.create_tween().set_loops()
	_drop_pulse.tween_property(_drop_highlight, "modulate:a", 0.45, Anim.HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)
	_drop_pulse.tween_property(_drop_highlight, "modulate:a", 1.0, Anim.HIGHLIGHT_PULSE_TIME).set_trans(Tween.TRANS_SINE)


## Whether node is one of the controller's own nodes on the effects layer (kept across new games).
func owns(node: Node) -> bool:
	return node == _drop_highlight or node == _hint


## Pauses the drop zone's pulse with reduce motion.
func apply_motion(calm: bool) -> void:
	if calm:
		_drop_pulse.pause()
		_drop_highlight.modulate.a = 1.0
	else:
		_drop_pulse.play()


## Mouse and Esc while targeting or dragging. Returns whether the event was used.
func handle_input(event: InputEvent) -> bool:
	if targeting != null:
		var cancel: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
		cancel = cancel or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
		if cancel:
			var card := targeting
			end_targeting()
			if _board.focus.focused != null and not _board.focus.focused.in_hand:  # keyboard targeting: back to the card
				_board.focus.set_card(card)
		return cancel
	if dragging == null:
		return false
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drop()
			return true
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_drag()
			return true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		return true
	elif event is InputEventMouseMotion:
		_update_feedback()
	return false


# --- Targeting mode ---

func begin_targeting(view: CardView) -> void:
	targeting = view
	view.set_highlight(true)
	_light_targets(view.uid, true)
	# The engine's reason the card can't be played yet, e.g. "Choose a territory to settle." or "Choose a card to trash."
	_board.log_note("[color=#ffd966]%s Click one (or ←/→ then Enter); Esc cancels.[/color]" % Game.engine.play_error(view.uid))


func end_targeting() -> void:
	if is_instance_valid(targeting):
		targeting.set_highlight(false)
	targeting = null
	_unlight_targets()


## Lights up the valid targets of hand card uid; clickable makes them pickable (targeting mode).
func _light_targets(uid: int, clickable: bool) -> void:
	lit = Game.engine.valid_targets(uid)
	for target in lit:
		_board.tableau.set_lit(target, true)
		var view: CardView = _board.views.get(target)
		if view != null:
			view.set_highlight(true)
			if clickable:
				view.set_pickable(true, "Click to play the card here.")


func _unlight_targets() -> void:
	for target in lit:
		_board.tableau.set_lit(target, false)
		var view: CardView = _board.views.get(target)
		if view != null:
			view.set_highlight(false)
			var row: Node = view.slot.get_parent() if is_instance_valid(view.slot) else null
			var in_choice := _board.choices.is_choice_row(row)
			view.set_pickable(in_choice, _board.choices.pick_hint(row) if in_choice else "")
	lit = []


# --- Dragging ---

func begin_drag(view: CardView, grab_offset: Vector2) -> void:
	dragging = view
	view.begin_drag(_board.fx, grab_offset)
	var e := Game.engine
	var card := e.zone("hand").find(view.uid)
	if e.playable_error(view.uid) == "":
		if e.needs_target(view.uid):
			_light_targets(view.uid, false)
			_show_ghost = card.def.is_permanent()
		else:
			_drop_highlight.global_position = _board.tableau.global_position
			_drop_highlight.size = _board.tableau.size
			_drop_highlight.show()
			if card.def.is_permanent():
				_board.tableau.show_ghost_at_end()
	_update_feedback()


func end_drag() -> void:
	dragging.set_warning(false)
	dragging = null
	_drop_highlight.hide()
	_hint.hide()
	_board.tableau.move_ghost(-1)
	_show_ghost = false
	_unlight_targets()


## Red when the drop here would fail: over a card it can't target, or in the drop zone when the
## card can't be played (or needs a target to be picked).
func _update_feedback() -> void:
	var e := Game.engine
	var over := _over_drop_zone()
	var target := _target_under_mouse()
	var error := e.play_error(dragging.uid)
	if e.needs_target(dragging.uid) and target != -1:
		error = e.play_error(dragging.uid, target)
	dragging.set_warning(over and error != "")
	_drop_style.bg_color.a = 0.10 if over else 0.03
	_hint.visible = over and error != ""
	if _hint.visible:
		_hint_label.text = error
		_hint.reset_size()
		var card := dragging.get_global_rect()
		_hint.global_position = Vector2(
			clampf(card.get_center().x - _hint.size.x / 2, 8.0, _board.size.x - _hint.size.x - 8.0), card.end.y + 8)
	if _show_ghost:
		# In the lit group under the cursor, or in the only lit group.
		_board.tableau.move_ghost(target if lit.has(target) else (lit[0] if lit.size() == 1 else -1))


## The drop zone: the tableau, plus the frontier row when it is showing (settle targets live there), plus any lit
## hand card (a trash target).
func _over_drop_zone() -> bool:
	var mouse := _board.get_global_mouse_position()
	var target: CardView = _board.views.get(_target_under_mouse())
	return _board.tableau.get_global_rect().has_point(mouse) \
		or (_board.frontier.is_visible_in_tree() and _board.frontier.get_global_rect().has_point(mouse)) \
		or (target != null and target.in_hand)


## What the mouse is over as a target: a territory group's territory uid, else the uid of the
## tableau or frontier card under it, or of a lit hand card, else -1.
func _target_under_mouse() -> int:
	var mouse := _board.get_global_mouse_position()
	var group := _board.tableau.group_at(mouse)
	if group != -1:
		return group
	for uid in _board.views:
		var view: CardView = _board.views[uid]
		if (view.in_hand and not lit.has(uid)) or view == dragging or view.state != CardView.State.REST:
			continue
		if view.slot.get_parent() != _board.choices.reveal and view.get_global_rect().has_point(mouse):
			return uid
	return -1


func _drop() -> void:
	var view := dragging
	var over := _over_drop_zone()
	var target := _target_under_mouse() if Game.engine.needs_target(view.uid) else -1
	end_drag()
	if over:
		_board.try_play(view, target)
	else:
		view.return_home()


func _cancel_drag() -> void:
	var view := dragging
	end_drag()
	view.return_home()
