class_name LogDrawer
extends PanelContainer
## The game log in a drawer (backlog 115): closed at the start, it slides in from the right edge over the board
## (fades with Reduce motion). L, Esc, the top bar's Log button or a click outside close it. Lines append whether
## it is open or not.

const WIDTH := 480.0

var _log: RichTextLabel
var _tween: Tween


func _init() -> void:
	z_index = 10  # above the board and flying cards, below the modals (20)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIKit.panel_style(Palette.PANEL, Palette.FAINT_EDGE, 12))
	set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH
	offset_right = 0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.HEADING_GAP)
	add_child(box)
	box.add_child(UIKit.heading("Log"))
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 19)
	_log.add_theme_font_size_override("bold_font_size", 20)
	_log.add_theme_color_override("default_color", Palette.LOG_TEXT)
	box.add_child(_log)
	hide()


func is_open() -> bool:
	return visible


## The log as plain text.
func text() -> String:
	return _log.get_parsed_text()


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


## Shows the drawer: it slides in from the right edge, or fades in with Reduce motion.
func open() -> void:
	if is_open():
		return
	show()
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if UIKit.calm():
		position.x = get_parent_area_size().x - WIDTH
		modulate.a = 0.0
		_tween.tween_property(self, "modulate:a", 1.0, Anim.SCREEN_TIME)
	else:
		modulate.a = 1.0
		position.x = get_parent_area_size().x
		_tween.tween_property(self, "position:x", get_parent_area_size().x - WIDTH, Anim.SCREEN_TIME)


func close() -> void:
	if _tween != null:
		_tween.kill()
	hide()


func clear() -> void:
	_log.clear()


## Adds a line of BBCode to the log.
func note(bbcode: String) -> void:
	_log.append_text(bbcode + "\n")


## Adds an engine log message: turn headers bold, game over gold.
func append_log(message: String) -> void:
	message = Icons.bbcode(message, 19)  # the log's font size
	if message.begins_with("—"):
		_log.append_text("\n[b]%s[/b]\n" % message)
	elif message.begins_with("Game over"):
		_log.append_text("[b][color=#e8c547]%s[/color][/b]\n" % message)
	else:
		_log.append_text(message + "\n")


## While open, L and Esc close it, and so does a click outside it (the click does nothing else).
func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo and key.keycode in [KEY_L, KEY_ESCAPE]:
		close()
		get_viewport().set_input_as_handled()
	elif click != null and click.pressed and not get_global_rect().has_point(click.global_position):
		close()
		get_viewport().set_input_as_handled()
