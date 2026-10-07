class_name CardActions
extends RefCounted
## What the player does with a card view (backlog 316, out of main.gd): play it (on a target), a single click (a Realm
## territory opens its view, anything else its details), a double-click, discard it, pick it as a target or a choice,
## and start dragging it. Each goes through the engine's error query, and a refusal is logged and shown over the card.
## The card views, the drag controller and the card focus call it; it reaches the board through main.

var _board: MainScreen


func _init(board: MainScreen) -> void:
	_board = board


## Plays the card (on target_uid) if it's legal; otherwise sends it back with a shake and says why.
func try_play(view: CardView, target_uid := -1) -> void:
	var error := Game.engine.play_error(view.uid, target_uid)
	if error != "":
		_refuse(view, error)
		view.reject()
		return
	Game.engine.play_card(view.uid, target_uid)


## A single click on a board card: a Realm territory opens its view (101), anything else shows its details.
func on_clicked(view: CardView) -> void:
	if not _board.territory_view.is_open() and TerritoryView.is_territory(Game.engine, view.uid):
		_board.territory_view.open(view.uid)
	else:
		_board.details.open(view)


## Logs the engine's refusal and shows it over view.
func _refuse(view: CardView, error: String) -> void:
	_board.log_note("[color=#e88]%s[/color]" % error)
	UIKit.show_error(_board.fx, view, error, _board.size.x)


func on_double_clicked(view: CardView) -> void:
	if _board.drag.targeting != null:
		_board.drag.end_targeting()
	var e := Game.engine
	if _board.drag.dragging != null or e.hand_input_error() != "":
		return
	if _board.pending_kind() == GameEngine.PENDING_DISCARD:
		discard(view)
		return
	if _board.territory_view.is_open() and e.needs_target(view.uid):
		try_play(view, _board.territory_view.uid)  # onto the territory on view (101)
	elif e.needs_target_choice(view.uid):
		_board.drag.begin_targeting(view)
	else:
		try_play(view)


## Discards a hand card (right-click, D, or double-click while over the hand limit).
func discard(view: CardView) -> void:
	if _board.drag.dragging != null or _board.drag.targeting != null:
		return
	var error := Game.engine.discard_error(view.uid)
	if error != "":
		_refuse(view, error)
		view.reject()
		return
	Game.engine.discard_card(view.uid)


## A click on a lit target, or on a card in a choice row: a revealed territory, a government (154) or an offered
## card (370). A choice goes through its error query, so a pick on a view left over from an earlier choice is refused.
func on_picked(view: CardView) -> void:
	if _board.drag.targeting != null:
		var card := _board.drag.targeting
		_board.drag.end_targeting()
		try_play(card, view.uid)
		return
	var e := Game.engine
	var error: Callable = e.choose_error
	var action: Callable = e.choose
	match e.zone_of(view.uid):
		"governments":
			error = e.choose_government_error
			action = e.choose_government
		"offered":
			error = e.take_error
			action = e.take
	var refused: String = error.call(view.uid)
	if refused != "":
		_refuse(view, refused)
	else:
		action.call(view.uid)


## A hand card asks to be dragged: it is, unless a drag is on or hand cards can't be picked up now (175).
func on_drag_requested(view: CardView, grab_offset: Vector2) -> void:
	if _board.drag.targeting != null:
		_board.drag.end_targeting()
	if _board.drag.dragging == null and Game.engine.hand_input_error() == "":
		_board.drag.begin_drag(view, grab_offset)
