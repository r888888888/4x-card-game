class_name SettingsModal
extends Modal
## The Settings modal (backlog 206; the settings screen of 099 before it): Reduce motion, Day mode, Interface sounds
## and a volume slider per bus (182, 183, 185), each saved and applied at once, and, in a game, a Game section with the
## seed field and Restart with seed. It opens from the menu's Settings (over the menu) and the title screen's Settings
## (without the Game section). The board decides what a restart does through restart_requested.

## Restart with seed, or Enter in the seed field holding a whole number.
signal restart_requested(seed_value: int)

var motion_toggle: LegendKey
var day_toggle: LegendKey  # under Reduce motion (183)
var sound_toggle: LegendKey  # under Day mode (185)
var sliders := {}  # bus -> its volume HSlider (185)
var figures := {}  # bus -> its volume figure Label
var game_section: VBoxContainer  # the seed field and Restart with seed; hidden on the title screen
var seed_edit: LineEdit
var restart_button: Button
var close_button: Button

var _volume_rows := {}  # bus -> its row
var _loop: Array[Control] = []  # the keys and sliders, in reading order


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Settings"
	motion_toggle = UIKit.motion_toggle()
	day_toggle = UIKit.day_toggle()
	sound_toggle = UIKit.sound_toggle()
	var rows: Array[Control] = [UIKit.setting_row("Reduce motion", motion_toggle), UIKit.setting_row("Day mode", day_toggle),
		UIKit.setting_row("Interface sounds", sound_toggle)]
	_loop.assign([motion_toggle, day_toggle, sound_toggle])
	for spec in [["Master", Settings.MASTER, "Everything."], ["Game", Settings.GAME, "Events: techs, cities, eras."],
			["Interface", Settings.INTERFACE, "Clicks, panels and confirmations."]]:
		var row := UIKit.volume_row(spec[0], spec[1], spec[2])
		rows.append(row)
		_loop.append(row.get_meta("slider"))
		_volume_rows[spec[1]] = row
		sliders[spec[1]] = row.get_meta("slider")
		figures[spec[1]] = row.get_meta("figure")
	UIKit.button_column(body, rows)
	game_section = VBoxContainer.new()
	game_section.add_theme_constant_override("separation", Tokens.SPACE_2)
	body.add_child(game_section)
	game_section.add_child(UIKit.heading("Game"))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", Tokens.SPACE_3)
	game_section.add_child(seed_row)
	var seed_label := Label.new()
	seed_label.text = "Seed"
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.tooltip_text = "Restart with seed replays this seed (same shuffle)."
	seed_edit.text_changed.connect(func(_text: String): _check_seed())
	seed_edit.text_submitted.connect(func(_text: String): _restart())
	seed_row.add_child(seed_edit)
	restart_button = UIKit.button("Restart with seed", _restart)
	restart_button.tooltip_text = "Start this game again as this civilization, with the seed above."
	game_section.add_child(restart_button)
	close_button = add_footer_button(UIKit.button("Close", close))


## Opens it with Reduce motion focused; with seed_value (a game's, 0 or more) the Game section shows it, without
## (negative: the title screen) the section is hidden.
func open(seed_value := -1) -> void:
	game_section.visible = seed_value >= 0
	seed_edit.text = str(seed_value) if seed_value >= 0 else ""
	_check_seed()
	var loop := _loop.duplicate()
	if game_section.visible:
		loop.append_array([seed_edit, restart_button])
	loop.append(close_button)
	UIKit.focus_loop(loop)
	show_settings()
	present()
	FocusRing.focus(motion_toggle)


## Matches the keys and the volume rows to the settings.
func show_settings() -> void:
	UIKit.show_setting(motion_toggle, UIKit.calm())
	UIKit.show_setting(day_toggle, Palette.day)
	UIKit.show_setting(sound_toggle, Settings.interface_sounds)
	for bus: StringName in _volume_rows:
		UIKit.show_volume(_volume_rows[bus], Settings.volume(bus))


## Restart with seed works only on a whole number.
func _check_seed() -> void:
	restart_button.disabled = not seed_edit.text.strip_edges().is_valid_int()


func _restart() -> void:
	var text := seed_edit.text.strip_edges()
	if game_section.visible and text.is_valid_int():
		restart_requested.emit(text.to_int())
