class_name ModalStack
extends RefCounted
## The open modals, bottom to top (backlog 153). Opening one puts it on top: the ones below stay shown, dimmed by its
## scrim, and it alone takes the keys and clicks. Esc, its close keys, its Close button or a click outside its panel
## close the top one only; closing a lower one closes everything above it too. Each level's panel is cascaded from the
## one below (Modal.cascade). Like Navigator it only orders them: the modals are children of host.

var host: Control  # the modals' parent (the board)

var _open: Array[Modal] = []


func _init(p_host: Control) -> void:
	host = p_host


## Opens modal on top. Already open: it comes back to the top, closing whatever was above it.
func push(modal: Modal) -> void:
	if _open.has(modal):
		_close_above(modal)
	else:
		_open.append(modal)
	modal.cascade(_open.size() - 1)
	host.move_child(modal, -1)  # input goes by tree order, not z_index: the last child takes keys and clicks first
	modal.show()


## Closes modal and every modal above it.
func close(modal: Modal) -> void:
	if not _open.has(modal):
		return
	_close_above(modal)
	_open.pop_back()
	_hide(modal)


## Closes every open modal, top first.
func close_all() -> void:
	while not _open.is_empty():
		_hide(_open.pop_back())


## The top modal, or null.
func top() -> Modal:
	return null if _open.is_empty() else _open.back()


func is_open() -> bool:
	return not _open.is_empty()


## How many modals are open.
func depth() -> int:
	return _open.size()


func _close_above(modal: Modal) -> void:
	while _open.back() != modal:
		_hide(_open.pop_back())


func _hide(modal: Modal) -> void:
	modal.hide()
	modal.closed()
