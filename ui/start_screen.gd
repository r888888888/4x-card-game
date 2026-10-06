class_name StartScreen
extends RefCounted
## The title screen (backlog 063, 099; a ledger since 213): two halves. On the left, flush left, a caps kicker, the
## game's title on two lines, a caps subtitle and the three large keys New game, Settings and Exit in one column of one
## width; on the right the Art, a sun over a hill (214), behind a 1 px rule. The art rises when the screen opens, and the
## keys move its sun: New game brings on the day, Exit a sunset. It is the Navigator's root on launch and after leaving
## a game, with the board hidden behind it. The board decides what the keys do through the signals.

signal new_game_requested
signal settings_requested
signal exit_requested

var overlay: Control
var art: Control  # the right half
var sunrise: SunriseArt  # in it (214)
var kicker: Label
var title: Label
var subtitle: Label
var new_game_button: Button
var settings_button: Button
var exit_button: Button

var _hovered: Button  # the key under the pointer, or null
var _focused: Button  # the key with the focus, or null


## Builds the screen on parent, hidden.
func _init(parent: Control) -> void:
	var sheet := ColorRect.new()
	UIKit.painted(sheet, func(): sheet.color = Palette.BACKGROUND)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.z_index = 15  # above the game-over sheet, below the card details (the menu can't be open)
	sheet.visible = false
	parent.add_child(sheet)
	overlay = sheet
	var halves := HBoxContainer.new()
	halves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	halves.add_theme_constant_override("separation", Tokens.SPACE_0)
	sheet.add_child(halves)
	var ledger := MarginContainer.new()
	ledger.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ledger.add_theme_constant_override("margin_left", Tokens.SPACE_9)
	ledger.add_theme_constant_override("margin_right", Tokens.SPACE_7)
	halves.add_child(ledger)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", Tokens.SPACE_3)
	ledger.add_child(column)
	kicker = UIKit.heading("Est. Turn 001")
	column.add_child(kicker)
	var name: String = ProjectSettings.get_setting("application/config/name")
	var cut := name.rfind(" ")
	title = UIKit.title(name if cut < 0 else name.substr(0, cut) + "\n" + name.substr(cut + 1))  # on two lines
	title.theme_type_variation = &"Display"
	column.add_child(title)
	subtitle = UIKit.heading("Civilizations in cards")
	column.add_child(subtitle)
	var gap := Control.new()
	gap.custom_minimum_size.y = Tokens.SPACE_5
	column.add_child(gap)
	new_game_button = _key("New game", "Choose a civilization and a seed", new_game_requested, true)
	new_game_button.tooltip_text = "Choose a civilization and a seed, then start."
	settings_button = _key("Settings", "Motion, day mode, sound", settings_requested)
	exit_button = _key("Exit Game", "Close the game", exit_requested)
	exit_button.tooltip_text = "Quit the game."
	var keys := UIKit.button_column(column, [new_game_button, settings_button, exit_button])
	keys.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # flush left, one width
	UIKit.focus_loop([new_game_button, settings_button, exit_button])
	art = Control.new()
	art.name = "Art"
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	halves.add_child(art)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.anchor_bottom = 1.0
	rule.offset_right = 1
	UIKit.painted(rule, func(): rule.color = Palette.CONTROL_DISABLED_BORDER)
	art.add_child(rule)
	sunrise = SunriseArt.new()
	art.add_child(sunrise)
	art.move_child(sunrise, 0)  # under the rule
	for key: Button in [new_game_button, settings_button, exit_button]:
		key.mouse_entered.connect(func(): _hovered = key; _aim())
		key.mouse_exited.connect(func():
			if _hovered == key:
				_hovered = null
			_aim())
		key.focus_entered.connect(func(): _focused = key; _aim())
		key.focus_exited.connect(func():
			if _focused == key:
				_focused = null
			_aim())


func is_open() -> bool:
	return Navigator.is_shown(overlay)


## The screen opened (launch, or back from a game): the art makes its entrance. The key focused by default doesn't move
## the sun until the player moves the focus.
func opened() -> void:
	_hovered = null
	_focused = null
	sunrise.enter()


## The sun follows the key under the pointer, else the focused one: up for New game, down for Exit, at rest otherwise.
func _aim() -> void:
	var key := _hovered if _hovered != null else _focused
	sunrise.aim(SunriseArt.DAY_UP if key == new_game_button else -SunriseArt.SUNSET if key == exit_button else 0.0)


## A large key labelled text over caption, emitting pressed_signal; the primary one's lamp is lit.
func _key(text: String, caption: String, pressed_signal: Signal, primary := false) -> BigButton:
	var key := BigButton.new(text, caption, primary)
	key.pressed.connect(func(): pressed_signal.emit())
	key.gui_input.connect(func(event: InputEvent):  # as UIKit.button: a click doesn't leave it focused
		if event is InputEventMouseButton and not event.pressed:
			key.release_focus.call_deferred())
	return key
