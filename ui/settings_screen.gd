class_name SettingsScreen
extends RefCounted
## The settings screen (backlog 099): its header with Back to the title screen (104), the Reduce motion and Day mode
## keys, and the sound rows (185): the Interface sounds key and a volume slider per bus. It opens from the title
## screen's Settings, with the board hidden behind it. The keys are the same settings as the menu's.

var overlay: Control
var header: ScreenHeader
var motion_toggle: LegendKey
var day_toggle: LegendKey  # Day mode, under Reduce motion (183)
var back_button: Button  # the header's
var sound_toggle: LegendKey  # Interface sounds, under Day mode (185)
var sliders := {}  # bus -> its volume HSlider (185)
var figures := {}  # bus -> its volume figure Label
var _volume_rows := {}  # bus -> its row


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
	sound_toggle = UIKit.sound_toggle()
	var rows: Array[Control] = [UIKit.setting_row("Reduce motion", motion_toggle), UIKit.setting_row("Day mode", day_toggle),
		UIKit.setting_row("Interface sounds", sound_toggle)]
	var loop: Array[Control] = [back_button, motion_toggle, day_toggle, sound_toggle]
	for spec in [["Master", Settings.MASTER, "Everything."], ["Game", Settings.GAME, "Events: techs, cities, eras."],
			["Interface", Settings.INTERFACE, "Clicks, panels and confirmations."]]:
		var row := UIKit.volume_row(spec[0], spec[1], spec[2])
		rows.append(row)
		loop.append(row.get_meta("slider"))
		_volume_rows[spec[1]] = row
		sliders[spec[1]] = row.get_meta("slider")
		figures[spec[1]] = row.get_meta("figure")
	UIKit.button_column(box, rows)
	UIKit.focus_loop(loop)


## Matches the sound key and the volume rows to the settings.
func show_sound() -> void:
	UIKit.show_setting(sound_toggle, Settings.interface_sounds)
	for bus: StringName in _volume_rows:
		UIKit.show_volume(_volume_rows[bus], Settings.volume(bus))


func is_open() -> bool:
	return Navigator.is_shown(overlay)

