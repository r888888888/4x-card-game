class_name EndTurnKey
extends Button
## End turn as the desk's biggest key (backlog 203, guide §15.12), at the foot of the sidebar: an ACCENT key on a
## plinth with a lamp at its left that says whether you're ready (sage: ready; ochre: actions left, counted in the
## caption under it; brick: the turn can't end, the reason in the caption), "END TURN", and the turn on a plate at its
## right. Pressed, it ends the turn and is busy ("UPKEEP…", the lamp off, presses ignored) while the plate flaps to the
## new turn, then shows the new turn's state. Its sounds (187): the big key going down; coming up, a relay and the
## turn drum when the press ended the turn, else the plain key's release.

const SIZE := Vector2(220, 64)
const LAMP := 12  # px across
const FLAP_TIME := 0.08  # each digit of the plate turning over
const BUSY_MIN := 0.12  # the shortest busy spell, so UPKEEP… reads

var caption: Label  # under the key: actions left, or why the turn can't end; hidden when there's nothing to say

var _lamp: Panel
var _lamp_style: StyleBoxFlat
var _label: Label
var _plate: Label
var _busy := false
var _lamp_role := &"GAIN"
var _lit := true
var _tween: Tween
# The press's sounds: its release sounds wait for both the key coming up and its action (a mouse release sends
# button_up before pressed, a key sends them the other way round).
var _key_up := false
var _acted := false
var _turn_ended := false


func _init() -> void:
	text = "End turn"
	theme_type_variation = &"EndTurnKey"
	custom_minimum_size = SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_END
	tooltip_text = "Shortcut: E. Upkeep, then draw up to your hand size."
	add_to_group(KeySounds.OWN_SOUNDS)
	var face := MarginContainer.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		face.add_theme_constant_override("margin_" + side, Tokens.SPACE_4)
	add_child(face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Tokens.SPACE_3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(row)
	_lamp = Panel.new()
	_lamp.custom_minimum_size = Vector2(LAMP, LAMP)
	_lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lamp_style = StyleBoxFlat.new()
	_lamp_style.set_corner_radius_all(Tokens.RADIUS_FULL)
	_lamp_style.set_border_width_all(1)
	_lamp.add_theme_stylebox_override("panel", _lamp_style)
	row.add_child(_lamp)
	_label = Label.new()
	_label.text = "End turn"
	_label.uppercase = true
	_label.theme_type_variation = &"KeyLabel"
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	_plate = Label.new()
	_plate.theme_type_variation = &"Plate"
	_plate.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_plate)
	caption = Label.new()
	caption.theme_type_variation = &"Caption"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = SIZE.x
	caption.size_flags_horizontal = Control.SIZE_SHRINK_END
	pressed.connect(_end_turn)
	button_down.connect(_down)
	button_up.connect(_up)
	UIKit.painted(self, _paint_lamp)


## Shows engine e's state: the lamp, the caption, whether the turn can end; the plate's turn unless it is flapping.
func refresh(e: GameEngine) -> void:
	if _busy:
		return
	_plate.text = plate_for(e.turn)
	var error := e.end_turn_error()
	disabled = error != ""
	tooltip_text = error if error != "" else "Shortcut: E. Upkeep, then draw up to your hand size."
	var left := e.actions_left() if e.actions_per_turn() >= 0 else 0
	if error != "":
		_set_lamp(&"UNREST", true)
		_set_caption(error)
	elif left > 0:
		_set_lamp(&"WEALTH", true)
		_set_caption("%d action%s left" % [left, "" if left == 1 else "s"])
	else:
		_set_lamp(&"GAIN", true)
		_set_caption("")


## The plate's text for turn: three digits ("012").
static func plate_for(turn: int) -> String:
	return "%03d" % turn


## Test hooks (203).
func lamp_lit() -> bool:
	return _lit


func lamp_color() -> Color:
	return Palette.color(_lamp_role)


func label_text() -> String:
	return _label.text.to_upper()


func plate_text() -> String:
	return _plate.text


func caption_text() -> String:
	return caption.text if caption.visible else ""


func busy() -> bool:
	return _busy


func _end_turn() -> void:
	if _busy:
		return
	var e := Game.engine
	var turn := e.turn
	_set_busy(true)
	e.end_turn()
	_turn_ended = e.turn != turn
	_acted = true
	if _key_up:
		_released()
	if not _turn_ended:
		_set_busy(false)
		refresh(e)
		return
	_flap(plate_for(turn), plate_for(e.turn))


## The plate turns over a digit at a time to the new turn, then the key shows the new turn's state.
func _flap(from: String, to: String) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if UIKit.calm():
		_plate.text = to
		_set_busy(false)
		refresh(Game.engine)
		return
	_plate.text = from
	_tween = create_tween()
	_tween.tween_interval(BUSY_MIN)
	for i in to.length():
		var shown := to.substr(0, i + 1) + from.substr(i + 1)
		_tween.tween_property(_plate, "scale:y", 0.0, FLAP_TIME / 2)
		_tween.tween_callback(func(): _plate.text = shown)
		_tween.tween_property(_plate, "scale:y", 1.0, FLAP_TIME / 2)
	_tween.tween_callback(func():
		_set_busy(false)
		refresh(Game.engine))


func _set_busy(on: bool) -> void:
	_busy = on
	theme_type_variation = &"EndTurnKeyBusy" if on else &"EndTurnKey"
	_label.text = "Upkeep…" if on else "End turn"
	_lit = not on
	_paint_lamp()


func _set_lamp(role: StringName, lit: bool) -> void:
	_lamp_role = role
	_lit = lit
	_paint_lamp()


func _paint_lamp() -> void:
	_lamp_style.bg_color = Palette.color(_lamp_role) if _lit else Palette.FIELD
	_lamp_style.border_color = Palette.TEXT


func _set_caption(text_: String) -> void:
	caption.text = text_
	caption.visible = text_ != ""


func _down() -> void:
	_key_up = false
	_acted = false
	_turn_ended = false
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.at_contact(Sfx.ENDTURN_PRESS, Anim.KEY_PRESS_TIME, Anim.SNAP, true)


func _up() -> void:
	_key_up = true
	if _acted:
		_released()
	else:
		_released_without_action.call_deferred()


## A release that ran no action by the end of the frame (dragged off the key) only comes back up.
func _released_without_action() -> void:
	if not _acted:
		_released()


func _released() -> void:
	_acted = true  # sound once
	_key_up = false
	var sfx := Sfx.find(self)
	if sfx == null:
		return
	if not _turn_ended:
		sfx.at_contact(Sfx.BUTTON_RELEASE, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true)
		return
	var commit := 0.0 if UIKit.calm() else Anim.contact(Anim.KEY_RELEASE_TIME, Anim.MACHINED)
	sfx.play(Sfx.ENDTURN_COMMIT, commit, true)
	sfx.play(Sfx.ENDTURN_TURN, commit + Anim.ENDTURN_TURN_DELAY, true)
