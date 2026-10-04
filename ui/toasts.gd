class_name Toasts
extends Control
## The notification flags (250, guide §10.7, §15.9; toasts under the top bar since 116): the engine's notices and the
## targeting hint, each a sheet strip that slides out of the rail (clipped at its edge, so it comes from behind it)
## and rests against it, stacked downward, newest at the bottom; at most MAX show. A notice's flag shows its priority
## (190): a glyph and a hue bar against the rail in the priority's hue, and the bell's pattern for it as it arrives.
## Info and caution flags go after Anim.TOAST_TIME; urgent ones stay until their × is pressed. The hint's flag is text
## only and stays until targeting ends. Only a × takes the mouse and nothing takes the focus; flags hide while covered
## (a modal, the menu or a screen is open) and keep ageing meanwhile.

const MAX := 3
const WIDTH := 360  # a flag's least width (§15.9); a longer line widens it
const MIN_HEIGHT := Tokens.SPACE_7
const BAR_WIDTH := Tokens.SPACE_1  # the priority's hue bar on a notice's rail side
const GLYPH_SIZE := Tokens.SPACE_6  # the guide's icon.l
const IN_TIME := 0.2  # sliding out of the rail, machined
const OUT_TIME := 0.16  # sliding back in, release
const CLOSE_UP_TIME := 0.12  # the flags below a leaving one moving up into its place
const CALM_TIME := 0.12  # with Reduce motion a flag fades in and out instead
## Each priority's bell, its bar's and glyph's Palette role, and its glyph.
const PRIORITY_LOOKS := {
	GameEngine.NOTICE_INFO: [Sfx.NOTIFICATION_INFO, &"INSIGHT", preload("res://assets/icons/insight.svg")],
	GameEngine.NOTICE_CAUTION: [Sfx.NOTIFICATION_CAUTION, &"WEALTH", preload("res://assets/icons/shield.svg")],
	GameEngine.NOTICE_URGENT: [Sfx.NOTIFICATION_URGENT, &"WARN", preload("res://assets/icons/blocked.svg")],
}

var _rail: Control
var _covered: Callable  # -> bool: whether something covers the board
var _clip: Control  # ends at the rail's left edge, so a flag behind the rail is out of view
var _column: VBoxContainer
var _hint: Control  # the targeting hint's flag, or null


## rail: the flags come out of its left edge. covered() -> bool says when to hide them.
func _init(rail: Control, covered: Callable) -> void:
	_rail = rail
	_covered = covered
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 5  # above the board and flying cards, below the log drawer
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", Tokens.SPACE_2)
	_clip.add_child(_column)


func _process(_delta: float) -> void:
	visible = not _covered.call()
	var rail := _rail.get_global_rect()
	_clip.position = Vector2(0, rail.position.y - global_position.y)
	_clip.size = Vector2(rail.position.x - global_position.x, rail.size.y)
	_column.reset_size()
	_column.position = Vector2(_clip.size.x - _column.size.x, Tokens.SPACE_4)


## Shows message's flag, ringing the bell for its priority (189, 190); an urgent one stays until its × is pressed,
## any other goes after Anim.TOAST_TIME.
func notice(message: String, priority := GameEngine.NOTICE_INFO) -> void:
	var look: Array = PRIORITY_LOOKS.get(priority, PRIORITY_LOOKS[GameEngine.NOTICE_INFO])
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.play(look[0])
	var flag := _add(message, look)
	flag.set_meta("priority", priority)
	flag.set_meta("bar_role", look[1])
	if priority != GameEngine.NOTICE_URGENT:
		var t := flag.create_tween()
		t.tween_interval(Anim.TOAST_TIME)
		t.tween_callback(_leave.bind(flag))


## Shows text until clear_hint (the targeting hint), replacing any hint already shown.
func hint(text: String) -> void:
	clear_hint()
	_hint = _add(text, [])


func clear_hint() -> void:
	if _hint != null:
		_leave(_hint)
		_hint = null


## Takes every flag away at once (a new game).
func clear() -> void:
	for slot in _column.get_children():
		slot.set_meta("leaving", true)
		slot.queue_free()
	_hint = null


## The flags showing (not leaving), top to bottom: each is the flag's panel.
func shown() -> Array[Control]:
	var out: Array[Control] = []
	for slot in _column.get_children():
		if not slot.is_queued_for_deletion() and not slot.has_meta("leaving"):
			out.append(slot.get_child(0))
	return out


## The priority of each notice showing, top to bottom (the hint has none).
func priorities() -> Array[StringName]:
	var out: Array[StringName] = []
	for panel in shown():
		if panel.has_meta("priority"):
			out.append(panel.get_meta("priority"))
	return out


## The Palette role of flag's priority bar (&"" for the hint, which has none).
func bar_role(flag: Control) -> StringName:
	return flag.get_meta("bar_role", &"")


## flag's glyph, × and hue bar (each null for the hint, which has text only).
func glyph(flag: Control) -> TextureRect:
	return flag.get_meta("glyph") if flag.has_meta("glyph") else null


func close_button(flag: Control) -> Button:
	return flag.get_meta("close") if flag.has_meta("close") else null


func bar(flag: Control) -> Control:
	return flag.get_meta("bar") if flag.has_meta("bar") else null


## The text of each flag showing, top to bottom.
func texts() -> Array[String]:
	var out: Array[String] = []
	for panel in shown():
		out.append((panel.get_meta("label") as Label).text)
	return out


## A new flag at the bottom with text and, for a notice, look (PRIORITY_LOOKS): its glyph, a × and its bar. It slides
## out of the rail (fades in with Reduce motion); the oldest leaves past MAX.
func _add(text: String, look: Array) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"Flag"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(WIDTH, MIN_HEIGHT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.SPACE_3)
	panel.add_child(row)
	var label := Label.new()
	label.theme_type_variation = &"FlagText"
	label.text = text.strip_edges()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_meta("label", label)
	if look.is_empty():
		row.add_child(label)
		var room := Control.new()  # the hint has no bar: room on its right instead
		room.custom_minimum_size.x = Tokens.SPACE_3
		room.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(room)
	else:
		row.add_child(_glyph(look))
		row.add_child(label)
		var close := Button.new()
		close.text = "×"
		close.theme_type_variation = &"FlagClose"
		close.focus_mode = Control.FOCUS_NONE
		close.tooltip_text = "Dismiss."
		close.pressed.connect(_leave.bind(panel))
		row.add_child(close)
		var hue_bar := ColorRect.new()
		hue_bar.custom_minimum_size.x = BAR_WIDTH
		hue_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIKit.painted(hue_bar, func(): hue_bar.color = Palette.color(look[1]))
		row.add_child(hue_bar)
		panel.set_meta("glyph", row.get_child(0))
		panel.set_meta("close", close)
		panel.set_meta("bar", hue_bar)
	var slot := Control.new()  # holds the flag's place in the column while the flag slides inside it
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_END  # each flag against the rail, however wide
	slot.add_child(panel)
	_column.add_child(slot)
	panel.reset_size()
	slot.custom_minimum_size = panel.size
	var t := panel.create_tween()
	if UIKit.calm():
		panel.modulate.a = 0.0
		t.tween_property(panel, "modulate:a", 1.0, CALM_TIME)
	else:
		panel.position.x = panel.size.x
		t.tween_property(panel, "position:x", 0.0, IN_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var showing := shown()
	if showing.size() > MAX:
		_leave(showing[0])
	return panel


## A notice's glyph for look, at icon.l, tinted its priority's hue.
func _glyph(look: Array) -> TextureRect:
	var g := TextureRect.new()
	g.texture = look[2]
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.custom_minimum_size = Vector2(GLYPH_SIZE, GLYPH_SIZE)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.painted(g, func(): g.self_modulate = Palette.color(look[1]))
	return g


## Slides panel's flag back into the rail (fades it with Reduce motion), closes the stack up and frees it; it stops
## counting as shown at once.
func _leave(panel: Control) -> void:
	var slot := panel.get_parent() as Control
	if slot == null or slot.has_meta("leaving"):
		return
	slot.set_meta("leaving", true)
	var t := panel.create_tween()
	if UIKit.calm():
		t.tween_property(panel, "modulate:a", 0.0, CALM_TIME)
	else:
		t.tween_property(panel, "position:x", panel.size.x, OUT_TIME).set_trans(Tween.TRANS_QUART) \
			.set_ease(Tween.EASE_IN)
	t.tween_property(slot, "custom_minimum_size:y", 0.0, CLOSE_UP_TIME)
	t.tween_callback(slot.queue_free)
