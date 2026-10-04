class_name MoveModal
extends Modal
## Moving a unit (backlog 163), opened from its details' Move…: titled "Move <unit>" with where it stands now, a button
## per territory it can march to (GameEngine.move_targets, each with that territory's defence), and Cancel. A pick
## moves the unit (one action) and closes the sheet.

var cancel_button: Button

var _note: Label
var _column: VBoxContainer
var _uid := -1  # the unit being moved, -1 while closed


## Builds the sheet on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	_note = Label.new()
	_note.theme_type_variation = &"Body"
	body.add_child(_note)
	cancel_button = add_footer_button(UIKit.button("Cancel", close))


## Opens it for unit uid in engine e, if it can move somewhere now.
func open(e: GameEngine, uid: int) -> void:
	if e.unit_move_block(uid) != "":
		return
	_uid = uid
	var unit := e.zone("tableau").find(uid)
	title = "Move %s" % unit.def.name
	context = "Turn %d" % e.turn
	_note.text = "Now on %s. Moving uses an action." % e.territory_name(e.unit_station(uid))
	if _column != null:
		_column.queue_free()
	var buttons: Array[Control] = []
	for t in e.move_targets(uid):
		var target: int = t
		var button := UIKit.button("%s  ⛨ %d" % [e.territory_name(target), e.defense(target)], func(): _move(target))
		button.tooltip_text = "March to %s." % e.territory_name(target)
		buttons.append(button)
	_column = UIKit.button_column(body, buttons)
	present()
	FocusRing.focus(buttons[0])


## Test hook: the target buttons, in order.
func target_buttons() -> Array[Button]:
	var out: Array[Button] = []
	if _column != null:
		for child in _column.get_children():
			if child is Button:
				out.append(child)
	return out


func closed() -> void:
	_uid = -1


func _move(target: int) -> void:
	var uid := _uid
	close()
	Game.engine.move_unit(uid, target)
