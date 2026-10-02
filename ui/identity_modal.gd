class_name IdentityModal
extends Modal
## The civilization and government modal (backlog 119), opened by the top bar's button: one section each, the
## civilization first, written like their card details (flavor, quote, rules). It follows the engine while open (a
## new government shows at once). While on top it takes every key: Esc closes it, and so do Close and a click outside.

const ZONES: Array[String] = ["civilization", "government"]

var close_button: Button

var _sections: VBoxContainer  # per section a Title (its name) and a RichBody (zone, details); then the deck line
var _names: Array[String] = []  # the names shown, top to bottom


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Civilization"
	_sections = VBoxContainer.new()
	_sections.add_theme_constant_override("separation", Tokens.SPACE_5)
	body.add_child(_sections)
	close_button = add_footer_button(UIKit.button("Close (Esc)", close))


## Test hook: the names shown, top to bottom; [] while closed.
func shown() -> Array[String]:
	return _names if is_open() else ([] as Array[String])


## Test hook: the text shown, without markup: each section's name, then its text, sections three lines apart.
func body_text() -> String:
	var parts: PackedStringArray = []
	for section in _sections.get_children():
		var lines: PackedStringArray = []
		for c in section.get_children():
			lines.append(c.text if c is Label else (c as RichTextLabel).get_parsed_text())
		parts.append("\n".join(lines))
	return "\n\n\n".join(parts)


func open() -> void:
	_fill(Game.engine)
	present()


## Shows engine e's civilization and government again, if open.
func refresh(e: GameEngine) -> void:
	if is_open():
		_fill(e)


func _fill(e: GameEngine) -> void:
	_names = []
	for section in _sections.get_children():
		_sections.remove_child(section)
		section.queue_free()
	for zone_name in ZONES:
		var z := e.zone(zone_name)
		if z.is_empty():
			continue
		var details := e.def_details(z.cards[0].def.id)
		_names.append(details.name)
		var text := CardDetailsModal.body_bbcode(details)
		_add_section(details.name, zone_name.capitalize() + "\n\n" + (text if text != "" else "No bonus."))
	var deck: Array = e.zone("governments").cards.map(func(c): return c.def.name)
	if not deck.is_empty():
		_add_section("", "Government deck: %s" % ", ".join(deck))  # 154


## A section: title (a Title label, 194; none when "") over bbcode in the modal's body text.
func _add_section(title: String, bbcode: String) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", Tokens.SPACE_0)
	if title != "":
		section.add_child(UIKit.title(title))
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.custom_minimum_size = Vector2(BODY_MAX_WIDTH - Tokens.SPACE_6, 0)
	body.theme_type_variation = &"RichBody"
	body.text = bbcode
	section.add_child(body)
	_sections.add_child(section)
