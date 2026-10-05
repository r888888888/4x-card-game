class_name AbandonModal
extends Modal
## Abandoning a wonder site (backlog 286), confirmed from its details' Abandon…: titled with the site, it says the
## wealth paid in will be lost and the card goes to the discard. "Keep building" closes it; "Abandon" abandons.

var keep_button: Button
var confirm_button: Button

var _text: RichTextLabel
var _site := -1


## Builds the sheet on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.custom_minimum_size.x = BODY_MAX_WIDTH - Tokens.SPACE_6
	_text.theme_type_variation = &"RichBody"
	body.add_child(_text)
	keep_button = add_footer_button(UIKit.button("Keep building", close))
	confirm_button = add_footer_button(UIKit.button("Abandon", _abandon), true)


## Opens it for engine e's site uid, if it can be abandoned.
func open(e: GameEngine, uid: int) -> void:
	if e.abandon_error(uid) != "":
		return
	_site = uid
	var name: String = e.zone("tableau").find(uid).def.name
	title = "Abandon %s?" % name
	context = "Turn %d" % e.turn
	var paid := e.site_progress(uid)
	_text.text = "%s goes to your discard. %s" % [name,
		"The %d wealth paid in is lost." % paid if paid > 0 else "Nothing has been paid in yet."]
	present()
	FocusRing.focus(keep_button)


## Test hook: the sheet's text, without markup.
func body_text() -> String:
	return _text.get_parsed_text()


func closed() -> void:
	_site = -1


func _abandon() -> void:
	var uid := _site
	close()
	if Game.engine.abandon_error(uid) == "":
		Game.engine.abandon(uid)
