class_name IdentityModal
extends ColorRect
## The civilization and government modal (backlog 119), opened by the top bar's button: one section each, the
## civilization first, written like their card details (flavor, quote, rules). It follows the engine while open (a
## new government shows at once). While open it takes every key: Esc closes it, and so do Close and a click outside.

const ZONES: Array[String] = ["civilization", "government"]

var close_button: Button

var _body: RichTextLabel
var _names: Array[String] = []  # the names shown, top to bottom


## Builds the modal on parent, hidden.
func _init(parent: Control) -> void:
	color = Palette.SCRIM
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20  # above the log drawer, the board and flying cards, like the details modal
	visible = false
	gui_input.connect(_on_dimmer_input)
	parent.add_child(self)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a click beside the panel reaches the dimmer and closes
	add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(620, 0)
	_body.add_theme_font_size_override("normal_font_size", 19)
	_body.add_theme_font_size_override("bold_font_size", 19)
	_body.add_theme_font_size_override("italics_font_size", 19)
	column.add_child(_body)
	close_button = UIKit.button("Close (Esc)", close)
	column.add_child(close_button)


## Test hook: the names shown, top to bottom; [] while closed.
func shown() -> Array[String]:
	return _names if visible else ([] as Array[String])


## Test hook: the text shown, without markup.
func body_text() -> String:
	return _body.get_parsed_text()


func open() -> void:
	_fill(Game.engine)
	get_parent().move_child(self, -1)  # input goes by tree order: last takes the keys first
	show()


func close() -> void:
	hide()


## Shows engine e's civilization and government again, if open.
func refresh(e: GameEngine) -> void:
	if visible:
		_fill(e)


func _fill(e: GameEngine) -> void:
	_names = []
	var sections: PackedStringArray = []
	for zone_name in ZONES:
		var z := e.zone(zone_name)
		if z.is_empty():
			continue
		var details := e.def_details(z.cards[0].def.id)
		_names.append(details.name)
		var text := CardDetailsModal.body_bbcode(details)
		var heading := "[font_size=30][b]%s[/b][/font_size]\n%s" % [details.name, zone_name.capitalize()]
		sections.append(heading + "\n\n" + (text if text != "" else "No bonus."))
	_body.text = "\n\n\n".join(sections)


## While open, every key stops here: Esc closes, the rest do nothing.
func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()
