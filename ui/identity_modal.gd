class_name IdentityModal
extends Modal
## The civilization and government modal (backlog 119), opened by the top bar's button: one section each, the
## civilization first, written like their card details (flavor, quote, rules). It follows the engine while open (a
## new government shows at once). While on top it takes every key: Esc closes it, and so do Close and a click outside.

const ZONES: Array[String] = ["civilization", "government"]

var close_button: Button

var _body: RichTextLabel
var _names: Array[String] = []  # the names shown, top to bottom


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
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
	present()


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
	var deck: Array = e.zone("governments").cards.map(func(c): return c.def.name)
	if not deck.is_empty():
		sections.append("Government deck: %s" % ", ".join(deck))  # 154
	_body.text = "\n\n\n".join(sections)
