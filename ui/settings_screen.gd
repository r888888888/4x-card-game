class_name SettingsScreen
extends RefCounted
## The settings screen (backlog 099): its header with Back to the title screen (104) and the Reduce motion toggle. It
## opens from the title screen's Settings, with the board hidden behind it. The toggle is the same setting as the
## menu's.

var overlay: Control
var header: ScreenHeader
var motion_toggle: LegendKey
var day_toggle: LegendKey  # Day mode, under Reduce motion (183)
var back_button: Button  # the header's


## Builds the screen on parent, hidden, for the board's navigator nav.
func _init(parent: Control, nav: Navigator) -> void:
	overlay = UIKit.overlay(parent)
	overlay.z_index = 15  # above the game-over overlay, below the card details (the menu can't be open)
	var box := overlay.get_meta("box") as VBoxContainer
	box.custom_minimum_size.x = 320
	header = ScreenHeader.new(nav)
	box.add_child(header)
	back_button = header.back_button
	motion_toggle = UIKit.motion_toggle()
	day_toggle = UIKit.day_toggle()
	UIKit.button_column(box, [UIKit.setting_row("Reduce motion", motion_toggle), UIKit.setting_row("Day mode", day_toggle)])
	UIKit.focus_loop([back_button, motion_toggle, day_toggle])


func is_open() -> bool:
	return Navigator.is_shown(overlay)

