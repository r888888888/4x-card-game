class_name Modal
extends ColorRect
## The base of every modal (backlog 153): a scrim over the whole board with a dark panel centred on it, which
## subclasses fill. It opens on a ModalStack (present), over any modal already open; while it is the top modal it takes
## every key: its close_keys close it, the rest do nothing. A click on its scrim, outside its panel, closes it.

const CASCADE := Vector2(36, 28)  # each level opens this far right and down of the one below, so the trail shows

var stack: ModalStack
var panel: PanelContainer
var close_keys: Array[Key] = [KEY_ESCAPE]

var _center: CenterContainer


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	stack = p_stack
	UIKit.painted(self, func(): color = Palette.SCRIM)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20  # above the board, the drawer, the menu and flying cards; tree order stacks modals among themselves
	visible = false
	gui_input.connect(_on_scrim_input)
	stack.host.add_child(self)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a click beside the panel reaches the scrim and closes
	add_child(_center)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	_center.add_child(panel)


## Shows it on top of the open modals.
func present() -> void:
	stack.push(self)


## Moves its panel level steps along the cascade (0: centred), as the stack opens it at that depth.
func cascade(level: int) -> void:
	var shift := CASCADE * level
	_center.offset_left = shift.x
	_center.offset_top = shift.y
	_center.offset_right = shift.x
	_center.offset_bottom = shift.y


## Closes it, and any modal opened over it.
func close() -> void:
	if visible:
		stack.close(self)


## Called by the stack once it is hidden: subclasses forget what they showed.
func closed() -> void:
	pass


## A key pressed while it is the top modal.
func key_pressed(keycode: Key) -> void:
	if keycode in close_keys:
		close()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or stack.top() != self:
		return
	get_viewport().set_input_as_handled()
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.note_input()  # the top modal takes its keys before the player could hear them (189)
	if event.pressed and not event.echo:
		key_pressed(event.keycode)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()
