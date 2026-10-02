class_name ModalStack
extends RefCounted
## The open modals, bottom to top (backlog 153). Opening one puts it on top: the ones below stay shown, dimmed by its
## scrim, and it alone takes the keys and clicks. Esc, its close keys, its Close button or a click outside its panel
## close the top one only; closing a lower one closes everything above it too. Each level's sheet sits Modal.STACK_SHIFT
## from the one below (Modal.cascade); opening lays a sheet down (Modal.enter) and closing lifts it off (Modal.leave),
## several at once together (207). Like Navigator it only orders them: the modals are children of host. A modal is a drafting
## sheet (189): opening lays one down (a stacked one STACKED_DB quieter, one opened with a notice UNDER_BELL_DB quieter so
## the bell leads), and a close lifts the sheets off with one sound however many go.

const STACKED_DB := -1.0
const UNDER_BELL_DB := -3.0

var host: Control  # the modals' parent (the board)

var _open: Array[Modal] = []


func _init(p_host: Control) -> void:
	host = p_host


## Opens modal on top. Already open: it comes back to the top, closing whatever was above it.
func push(modal: Modal) -> void:
	if _open.has(modal):
		if _open.back() != modal:
			_close_above(modal)
			_sound(Sfx.SHEET_CLOSE)
		modal.cascade(_open.size() - 1)
	else:
		_open.append(modal)
		var sfx := Sfx.find(host)
		var gain := (STACKED_DB if _open.size() > 1 else 0.0) + (UNDER_BELL_DB if sfx != null and sfx.notified() else 0.0)
		_sound(Sfx.SHEET_OPEN, gain)
		modal.cascade(_open.size() - 1)
		modal.enter(_open.size() > 1)
	host.move_child(modal, -1)  # input goes by tree order, not z_index: the last child takes keys and clicks first


## Closes modal and every modal above it.
func close(modal: Modal) -> void:
	if not _open.has(modal):
		return
	_close_above(modal)
	_open.pop_back()
	_hide(modal)
	_sound(Sfx.SHEET_CLOSE)


## Closes every open modal, top first.
func close_all() -> void:
	if not _open.is_empty():
		_sound(Sfx.SHEET_CLOSE)
	while not _open.is_empty():
		_hide(_open.pop_back())


## Whether modal is open (a closing one still drawn is not).
func has(modal: Modal) -> bool:
	return _open.has(modal)


## The top modal, or null.
func top() -> Modal:
	return null if _open.is_empty() else _open.back()


func is_open() -> bool:
	return not _open.is_empty()


## How many modals are open.
func depth() -> int:
	return _open.size()


## Plays token as a sheet goes down or comes up: the player's input when their key or click did it.
func _sound(token: StringName, gain := 0.0) -> void:
	var sfx := Sfx.find(host)
	if sfx != null:
		sfx.play(token, 0.0, sfx.player_acted(), gain)


func _close_above(modal: Modal) -> void:
	while _open.back() != modal:
		_hide(_open.pop_back())


func _hide(modal: Modal) -> void:
	modal.leave()
	modal.closed()
