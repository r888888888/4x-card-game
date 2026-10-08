class_name RaidModal
extends Modal
## The raid modal (backlog 271): when a raid strikes at a turn's start, its card on the left and, on the right, whether
## it was repelled or pillaged and what that cost or gave (GameEngine.raid_outcome_text). It opens above the turn's
## event. While on top it takes every key and click; Esc, Enter, OK or a click outside closes it.
## Above the verdict, a drawing of how it ended (389); the verdict is a Verdict headline in capitals.

## The drawing per outcome; placeholders until the final art replaces these files (389).
## Closed (its OK, Enter or Esc): what it showed is past (388: the veterans' pips light).
signal dismissed

const ART := {true: "res://assets/art/raid_repelled.svg", false: "res://assets/art/raid_pillaged.svg"}
const ART_SIZE := Vector2(420, 236)  # the body's width at 16:9

var _art: TextureRect
var verdict: Label
var _result: Label
var ok_button: Button
var _shown := {}  # what is shown; {} while hidden


## Builds the modal on stack's host, hidden: the raid's card in the aside, the drawing, the verdict and the result line
## in the body, OK in the footer.
func _init(p_stack: ModalStack) -> void:
	super(p_stack)
	close_keys = [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]
	aside.visible = true
	body.custom_minimum_size.x = ART_SIZE.x
	_art = TextureRect.new()
	_art.custom_minimum_size = ART_SIZE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.clip_contents = true
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_art)
	verdict = Label.new()
	verdict.theme_type_variation = &"Verdict"
	verdict.uppercase = true
	body.add_child(verdict)
	_result = UIKit.heading("")
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_result)
	ok_button = add_footer_button(UIKit.button("OK (Enter)", close), true)


## Test hook: {uid, id, repelled, result, title, context, art} on show, {} while hidden.
func shown() -> Dictionary:
	return _shown if is_open() else {}


## Shows the raid a raid_resolved outcome reports and how it ended.
func open(outcome: Dictionary) -> void:
	var e := Game.engine
	var def: CardDef = e.card_db[outcome.id]
	title = def.name
	context = "Turn %d" % e.turn
	_shown = {"uid": outcome.uid, "id": def.id, "repelled": outcome.repelled, "result": e.military.outcome_text(outcome),
		"title": title, "context": context, "art": ART[outcome.repelled]}
	_art.texture = load(_shown.art)
	verdict.text = "Repelled" if outcome.repelled else "Pillaged"
	_result.text = _shown.result
	show_card(def, e.card_db)
	present()
	FocusRing.focus(ok_button)


func closed() -> void:
	_shown = {}
	dismissed.emit()
