class_name RenameModal
extends Modal
## The naming modal (backlog 248), opened from the territory view's Rename…: a drafting sheet titled "Rename territory"
## with the land's name as its context, a caption and a field holding the territory's name, and Cancel, then Rename
## (primary) in the footer. Rename is disabled with GameEngine.rename_territory_error as its tooltip while the engine
## would refuse the text; Enter or Rename renames and closes, Cancel, Esc or a click outside closes without a change.

var field: LineEdit
var cancel_button: Button
var rename_button: Button

var _uid := -1  # the territory being named


## Builds the sheet on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Rename territory"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # the field spans the sheet, under the title block
	body.add_child(UIKit.heading("Name"))
	field = LineEdit.new()
	field.custom_minimum_size.x = BODY_MAX_WIDTH * 0.5  # room for a long name; it fills the sheet when wider
	field.select_all_on_focus = true
	field.text_changed.connect(func(_text: String): _check())
	field.text_submitted.connect(func(_text: String): _rename())
	body.add_child(field)
	cancel_button = add_footer_button(UIKit.button("Cancel", close))
	rename_button = add_footer_button(UIKit.button("Rename", _rename), true)


## Opens it for settled territory uid, its name in the field and selected.
func open(uid: int) -> void:
	var e := Game.engine
	_uid = uid
	context = e.zone("tableau").find(uid).def.name
	field.text = e.territory_name(uid)
	_check()
	present()
	FocusRing.focus(field)
	field.select_all()


func closed() -> void:
	_uid = -1


## Enables Rename when the engine would take the field's text; otherwise its tooltip says why not.
func _check() -> void:
	var error := Game.engine.rename_territory_error(_uid, field.text)
	rename_button.disabled = error != ""
	rename_button.tooltip_text = error if error != "" else "Give the territory this name."


func _rename() -> void:
	if Game.engine.rename_territory(_uid, field.text):
		close()
