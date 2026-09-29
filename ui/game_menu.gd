class_name GameMenu
extends RefCounted
## The menu modal, above everything else: the seed field, Restart, New game, Reduce motion, Close and Exit.
## Tab and the arrows stay inside it; a click on the dimmed area closes it. The board decides what the buttons
## do through the signals.

## Restart, or Enter in the seed field; seed_text is the field's text.
signal restart_requested(seed_text: String)
signal new_game_requested
## Close, Esc, or a click on the dimmed area.
signal close_requested
signal exit_requested

var overlay: Control
var _seed_edit: LineEdit
var _motion_toggle: Button  # "Reduce motion: on/off"


## Builds the menu on parent, hidden.
func _init(parent: Control) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 20  # above the explore choice and game-over overlays
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			overlay.accept_event()
			close_requested.emit())
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 320
	box.add_child(UIKit.title("Menu"))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	box.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	_seed_edit = LineEdit.new()
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.tooltip_text = "Restart replays this seed (same shuffle)."
	_seed_edit.text_submitted.connect(func(text: String): restart_requested.emit(text))
	seed_row.add_child(_seed_edit)
	var restart := UIKit.button("Restart", func(): restart_requested.emit(_seed_edit.text))
	restart.tooltip_text = "Start again with the seed above."
	box.add_child(restart)
	var new_game := UIKit.button("New game", func(): new_game_requested.emit())
	new_game.tooltip_text = "Start again with a random seed."
	box.add_child(new_game)
	# A toggle that says its state in words (a checkbox's box is hard to read on this background).
	_motion_toggle = UIKit.button("", func(): pass)
	_motion_toggle.toggle_mode = true
	_motion_toggle.tooltip_text = "No bouncing, shaking or tilting; cards jump to their place and fade in. Saved."
	_motion_toggle.toggled.connect(Settings.set_reduce_motion)
	box.add_child(_motion_toggle)
	box.add_child(HSeparator.new())
	var close := UIKit.button("Close (Esc)", func(): close_requested.emit())
	box.add_child(close)
	var exit := UIKit.button("Exit", func(): exit_requested.emit())
	exit.tooltip_text = "Quit the game. It isn't saved."
	box.add_child(exit)
	# Keep keyboard focus inside the menu: Tab/Shift+Tab and Up/Down wrap around its controls.
	var controls: Array[Control] = [_seed_edit, restart, new_game, _motion_toggle, close, exit]
	for i in controls.size():
		var here := controls[i]
		var next := controls[(i + 1) % controls.size()]
		var prev := controls[i - 1]
		here.focus_next = here.get_path_to(next)
		here.focus_previous = here.get_path_to(prev)
		here.focus_neighbor_bottom = here.focus_next
		here.focus_neighbor_top = here.focus_previous
		here.focus_neighbor_left = NodePath(".")
		here.focus_neighbor_right = NodePath(".")


func is_open() -> bool:
	return overlay.visible


## Puts seed_value in the seed field (shown the next time the menu opens).
func set_seed(seed_value: int) -> void:
	_seed_edit.text = str(seed_value)


## Shows the menu with the seed field focused and holding seed_value.
func open(seed_value: int) -> void:
	set_seed(seed_value)
	overlay.show()
	_seed_edit.grab_focus()
	_seed_edit.select_all()


func hide() -> void:
	overlay.hide()


## Matches the Reduce motion toggle to the setting.
func show_motion_setting(calm: bool) -> void:
	_motion_toggle.set_pressed_no_signal(calm)
	_motion_toggle.text = "Reduce motion: %s" % ("on" if calm else "off")
