class_name RaidModal
extends Modal
## The raid modal (backlog 271): when a raid strikes at a turn's start, its card on the left and, on the right, whether
## it was repelled or pillaged and what that cost or gave (GameEngine.raid_outcome_text). It opens above the turn's
## event. While on top it takes every key and click; Esc, Enter, OK or a click outside closes it.

var _verdict: Label
var _result: Label
var ok_button: Button
var _shown := {}  # what is shown; {} while hidden


## Builds the modal on stack's host, hidden: the raid's card in the aside, the verdict and the result line in the body,
## OK in the footer.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]
	aside.visible = true
	body.custom_minimum_size.x = 420
	_verdict = UIKit.heading("")
	body.add_child(_verdict)
	_result = UIKit.heading("")
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_result)
	ok_button = add_footer_button(UIKit.button("OK (Enter)", close), true)


## Test hook: {uid, id, repelled, result, title, context} on show, {} while hidden.
func shown() -> Dictionary:
	return _shown if is_open() else {}


## Shows the raid a raid_resolved outcome reports and how it ended.
func open(outcome: Dictionary) -> void:
	var e := Game.engine
	var def: CardDef = e.card_db[outcome.id]
	title = def.name
	context = "Turn %d" % e.turn
	_shown = {"uid": outcome.uid, "id": def.id, "repelled": outcome.repelled, "result": e.raid_outcome_text(outcome),
		"title": title, "context": context}
	_verdict.text = "Repelled" if outcome.repelled else "Pillaged"
	_result.text = _shown.result
	for child in aside.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, def), e.card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.custom_minimum_size = card.slot_size()
	card.attach(aside)
	present()
	FocusRing.focus(ok_button)


func closed() -> void:
	_shown = {}
