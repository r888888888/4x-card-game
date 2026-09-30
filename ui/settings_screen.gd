class_name SettingsScreen
extends RefCounted
## The settings screen (backlog 099): the Reduce motion toggle and Back to the title screen. It opens from the title
## screen's Settings, with the board hidden behind it. The toggle is the same setting as the menu's.

## Back or Esc: to the title screen.
signal back_requested

var overlay: Control
var motion_toggle: Button
var back_button: Button


## Builds the screen on parent, hidden.
func _init(parent: Control) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 15  # above the game-over overlay, below the card details (the menu can't be open)
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 320
	var title := UIKit.title("Settings")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	motion_toggle = UIKit.motion_toggle()
	box.add_child(motion_toggle)
	back_button = UIKit.button("Back", func(): back_requested.emit())
	box.add_child(back_button)
	UIKit.focus_loop([back_button, motion_toggle])


func is_open() -> bool:
	return overlay.visible


## Shows the screen with Back focused.
func open() -> void:
	overlay.show()
	back_button.grab_focus()


func hide() -> void:
	overlay.hide()
