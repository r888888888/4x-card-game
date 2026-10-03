class_name FocusRing
extends Node
## Whether the keyboard focus ring shows (230), like a browser's :focus-visible. The game starts in pointer mode,
## where a control the code focuses (a modal's action button, a screen's first control) has the focus but draws no
## ring; Tab or Shift+Tab switches to keyboard mode, where it draws; a mouse click switches back. Main holds one as its
## last child, so it sees each event before the modals do; every code focus in ui/ goes through focus().

static var keyboard := false  # keyboard mode: a code focus draws the ring


## Gives control the focus, drawing its ring when shown (by default: in keyboard mode).
static func focus(control: Control, shown := keyboard) -> void:
	control.grab_focus(not shown)


func _ready() -> void:
	keyboard = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		keyboard = false
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		keyboard = true
