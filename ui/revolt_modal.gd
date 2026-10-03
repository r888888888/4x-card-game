class_name RevoltModal
extends Modal
## The revolution's confirmation (backlog 205), stacked on the civilization modal: titled "Revolution" with the turn and
## the government it overthrows, the Anarchy card's flavor and quote, then what the coming Anarchy will do
## (GameEngine.revolt_summary, with this game's numbers). "Keep <government>" closes it; "Revolt" revolts.

var keep_button: Button
var confirm_button: Button

var _flavor: RichTextLabel
var _summary: RichTextLabel


## Builds the sheet on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	title = "Revolution"
	for label in 2:
		var text := RichTextLabel.new()
		text.bbcode_enabled = true
		text.fit_content = true
		text.custom_minimum_size.x = BODY_MAX_WIDTH - Tokens.SPACE_6
		text.theme_type_variation = &"RichBody"
		body.add_child(text)
		if label == 0:
			_flavor = text
		else:
			_summary = text
	keep_button = add_footer_button(UIKit.button("", close))
	confirm_button = add_footer_button(UIKit.button("Revolt", _revolt), true)
	confirm_button.tooltip_text = "Anarchy falls at the start of next turn."


## Opens it for engine e's ruling government, if a revolution may be declared.
func open(e: GameEngine) -> void:
	if e.revolt_error() != "":
		return
	var government: String = e.zone("government").cards[0].def.name
	context = "Turn %d · %s" % [e.turn, government]
	var details := e.def_details(e.anarchy_id())
	_flavor.text = CardDetailsModal.body_bbcode({"flavor": details.flavor, "quote": details.quote, "rules": [],
		"state": [], "terms": []})
	_flavor.visible = _flavor.text != ""
	_summary.text = "\n".join(e.revolt_summary().map(func(line): return "• " + line))
	keep_button.text = "Keep %s" % government
	present()
	FocusRing.focus(keep_button)


## Test hook: the sheet's text, without markup.
func body_text() -> String:
	return _flavor.get_parsed_text() + "\n\n" + _summary.get_parsed_text()


func _revolt() -> void:
	close()
	Game.engine.revolt()
