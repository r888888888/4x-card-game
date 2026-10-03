class_name CardFocus
extends RefCounted
## The keyboard focus ring on the cards: which row Left/Right move through (the supply piles, an open choice,
## the lit targets while targeting, the board row or the hand), what Enter does to the focused card, and keeping the
## focus somewhere sensible after the board changes. Up from the hand goes to the board row: the Realm's territories,
## or the open territory view's cards (101); Down goes back.

var focused: CardView  # the card with the focus ring, or null
var hand_index := -1  # keyboard position in the hand; -1 until the keyboard is used
var on_board := false  # the focus is in the board row rather than the hand
var _board: MainScreen


func _init(board: MainScreen) -> void:
	_board = board


## The cards Left/Right move through now.
func row() -> Array[CardView]:
	if _board.supply.is_open():
		return _board.supply.views()
	var kind := _board.pending_kind()
	if kind == GameEngine.PENDING_EXPLORE:
		return _board.views_in(_board.choices.reveal)
	if _board.drag.targeting != null:
		var targets: Array[CardView] = []
		for uid in _board.drag.lit:
			if _board.views.has(uid):
				targets.append(_board.views[uid])
		return targets
	if Game.engine.is_over:
		return [] as Array[CardView]
	return board_row() if on_board else _board.views_in(_board.hand)


## The open territory view's cards, else the Realm's territory cards in tableau order.
func board_row() -> Array[CardView]:
	if _board.territory_view.is_open():
		return _board.views_in(_board.territory_view.row) + _board.views_in(_board.territory_view.units_row)
	var out: Array[CardView] = []
	for group in Game.engine.territory_groups():
		if group.territory != -1 and _board.views.has(group.territory):
			out.append(_board.views[group.territory])
	return out


## A key press the focused controls didn't use. Left/Right move the card focus, Enter/Space acts on the focused
## card, D discards it, I shows its details, Esc drops the focus (or opens the menu when nothing is focused), E ends
## the turn, S opens the supply screen, T the tech tree, L the log (115). While that screen is open it owns the keys: S or Esc closes it, the arrows
## and Enter pick cards, I shows details, the rest do nothing. Returns whether the key was used.
func handle_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_I and not event.echo:
		if focused != null and is_instance_valid(focused):
			_board.details.open(focused)
		return true
	if _board.supply.is_open():
		if (event.keycode == KEY_S or event.keycode == KEY_ESCAPE) and not event.echo:
			_board.supply.close()
		else:
			_move_or_activate(event)
		return true
	if event.keycode == KEY_S and not event.echo:
		_board.open_supply()
	elif event.keycode == KEY_T and not event.echo:
		_board.knowledge.toggle()
	elif event.keycode == KEY_L and not event.echo:
		_board.log_drawer.open()  # while open, the drawer takes L and closes itself
	elif event.keycode == KEY_E and not event.echo:
		Game.engine.end_turn()  # refused while end_turn_error() says so
	elif event.keycode == KEY_D and not event.echo:
		if focused != null and is_instance_valid(focused) and focused.in_hand:
			_board.discard(focused)
	elif event.keycode == KEY_ESCAPE and not event.echo and _board.drag.targeting == null:
		if focused != null:
			clear()
		else:
			_board.open_menu()
	else:
		return _move_or_activate(event)
	return true


## Left/Right move the focus and Enter acts on the focused card. Returns whether the key was one of them.
func _move_or_activate(event: InputEventKey) -> bool:
	if event.is_action_pressed("ui_right", true):
		move(1)
	elif event.is_action_pressed("ui_left", true):
		move(-1)
	elif event.is_action_pressed("ui_accept"):
		activate()
	elif event.is_action_pressed("ui_up") and not on_board and row() == _board.views_in(_board.hand):
		on_board = true
		set_card(_first(board_row()))
	elif event.is_action_pressed("ui_down") and on_board:
		on_board = false
		var hand := _board.views_in(_board.hand)
		set_card(hand[clampi(hand_index, 0, hand.size() - 1)] if not hand.is_empty() else null)
	else:
		return false
	return true


func _first(cards: Array[CardView]) -> CardView:
	return null if cards.is_empty() else cards[0]


## Drops the focus and forgets the hand position.
func clear() -> void:
	set_card(null)
	hand_index = -1
	on_board = false


## Moves the card focus step cards along the row. With nothing focused, Right starts at the first
## card and Left at the last. The hand and choice stop at the ends; targets cycle.
func move(step: int) -> void:
	var cards := row()
	if cards.is_empty():
		return
	var i := cards.find(focused)
	if i == -1:
		i = 0 if step > 0 else cards.size() - 1
	elif _board.drag.targeting != null:
		i = posmod(i + step, cards.size())
	else:
		i = clampi(i + step, 0, cards.size() - 1)
	set_card(cards[i])
	if cards[i].in_hand:
		hand_index = i


## Enter on the focused card: buy it (supply), keep it (explore choice), buy it (research), play onto it
## (targeting), or play it, which starts targeting when it has several targets (same as a double-click).
func activate() -> void:
	var view := focused
	if view == null or not is_instance_valid(view):
		return
	var drag := _board.drag
	if _board.supply.is_open():
		_board.supply.pick(view)
	elif _board.pending_kind() == GameEngine.PENDING_EXPLORE or (drag.targeting != null and drag.lit.has(view.uid)):
		_board.on_picked(view)
	elif on_board and not _board.territory_view.is_open():
		_board.territory_view.open(view.uid)  # Enter on a Realm territory: its view, focus on its first card
		on_board = true  # the refresh dropped it: the territory's own card isn't in the view's row
		set_card(_first(board_row()))
	elif view.in_hand:
		_board.on_double_clicked(view)
		if drag.targeting != null:
			var targets := row()
			if not targets.is_empty():
				set_card(targets[0])


## Gives view the card focus (null: no card), taking focus away from any button. shown: it draws the ring (a key
## placed it); the code's own placing draws it only in keyboard mode (234).
func set_card(view: CardView, shown := true) -> void:
	if is_instance_valid(focused):
		focused.set_focused(false)
	focused = view
	if view == null:
		return
	view.set_focused(shown)
	_board.get_viewport().gui_release_focus()
	if view.in_hand and is_instance_valid(view.slot):
		_board.hand_scroll.ensure_control_visible(view.slot)


## After the board changes, keeps the focus somewhere sensible: on the first choice card while
## choosing, else on the same hand card, or the one now in its place (or the new last card).
func sync() -> void:
	if _board.supply.is_open():  # the focus stays on the pile card (or nothing) while buying
		return
	var kind := _board.pending_kind()
	if kind == GameEngine.PENDING_EXPLORE:
		var choice := row()
		if not choice.has(focused) and not choice.is_empty():
			set_card(choice[0], FocusRing.keyboard)
		return
	if _board.drag.targeting != null:
		return
	if on_board:
		if board_row().has(focused):
			return
		on_board = false
	var hand := _board.views_in(_board.hand)
	if hand.has(focused):
		hand_index = hand.find(focused)
	elif hand_index != -1 and not hand.is_empty() and not Game.engine.is_over:
		set_card(hand[mini(hand_index, hand.size() - 1)])
	else:
		set_card(null)
