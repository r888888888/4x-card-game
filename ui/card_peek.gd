class_name CardPeek
extends RefCounted
## A hand-row card's overflowing rules (383, guide §6.7, §11.11). The pointer resting on it Anim.OVERFLOW_INTENT
## raises its text sheet over the art as far as the hidden rules need (CardSheet.need, easing over OVERFLOW_SLIDE); if
## rules are still hidden the foot's meter fills over OVERFLOW_WAIT, then a RulesPopover opens beside the card on
## layer. A move before the intent starts the wait again; leaving the card and the popover lowers it; a press on the
## card cancels whatever step it is at (the press goes on). Keyboard focus raises the sheet at once, with no meter.
## With Reduce motion the sheet jumps and the meter fills in three steps. Its clock is advance(): the card calls it each
## frame unless manual_clock (tests drive it).

enum Step { REST, WAITING, SLIDING, FILLING, OPEN, UP }

const EPSILON := 0.000001
const CALM_STEPS := 3.0  # the meter's steps with Reduce motion

var layer: Control  # where the popover opens; null: not a hand-row card, so it never peeks
var manual_clock := false
var popover: RulesPopover  # the rules popover while open
var face: CardFace  # the card's face now (CardView.setup sets it)

var _view: CardView
var _step := Step.REST
var _t := 0.0
var _from := 0.0
var _then_fill := false  # after the slide up, fill the meter if rules are still hidden
var _meter := 0.0
var _on_card := false
var _on_popover := false
var _held := false  # a press cancelled the steps: no new wait until the pointer moves or leaves


func _init(view: CardView) -> void:
	_view = view


## Px the sheet is up over the art now.
func rise() -> float:
	return _sheet().rise if _sheet() != null else 0.0


## The foot's meter, 0 to 1, as shown.
func meter() -> float:
	return _sheet().meter if _sheet() != null else 0.0


## Back at rest at once (the face was rebuilt).
func reset() -> void:
	_close_popover()
	_step = Step.REST
	_meter = 0.0


## The pointer entered (on) or left the card.
func hover(on: bool) -> void:
	_on_card = on
	_held = false
	if not _active():
		return
	if on and _step == Step.REST:
		_wait()
	elif not on and popover == null:
		_lower()


## The card's input: a move with no button held starts the wait again; a press cancels every step.
func input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventMouseMotion and event.button_mask == 0:
		_held = false
		if _step == Step.WAITING or (_step == Step.REST and _on_card):
			_wait()
	elif event is InputEventMouseButton and event.pressed:
		_held = true
		_lower()


## Keyboard focus came (on) or went: the sheet rises at once with no meter, or lowers unless the pointer is on it.
func focus(on: bool) -> void:
	if not _active():
		return
	if on:
		_raise(false)
	elif not _on_card:
		_lower()


## Runs the steps on by delta seconds.
func advance(delta: float) -> void:
	if popover != null and not _on_card and not _on_popover:
		_lower()
	var left := delta
	while true:
		match _step:
			Step.WAITING:
				_t += left
				if _t < Anim.OVERFLOW_INTENT - EPSILON:
					return
				left = _t - Anim.OVERFLOW_INTENT
				_raise(true)
			Step.SLIDING:
				_t += left
				var p := clampf(_t / Anim.OVERFLOW_SLIDE, 0.0, 1.0)
				_sheet().set_rise(lerpf(_from, _sheet().target, ease(p, 0.4)))  # eases out
				if p < 1.0 - EPSILON:
					return
				left = maxf(0.0, _t - Anim.OVERFLOW_SLIDE)
				_arrived()
			Step.FILLING:
				_t += left
				_set_meter(clampf(_t / Anim.OVERFLOW_WAIT, 0.0, 1.0))
				if _t < Anim.OVERFLOW_WAIT - EPSILON:
					return
				_open()
				return
			_:
				return


func _active() -> bool:
	return layer != null and _view.in_hand and _sheet() != null and _view.state == CardView.State.REST


func _sheet() -> CardSheet:
	return face.sheet if face != null else null


func _wait() -> void:
	if _held:
		return
	_step = Step.WAITING
	_t = 0.0


## Starts the sheet up to what its hidden rules need; then_fill: the meter follows if rules are still hidden.
func _raise(then_fill: bool) -> void:
	_then_fill = then_fill
	_slide_to(_sheet().need())


## Lowers the sheet to rest, closing the popover and emptying the meter.
func _lower() -> void:
	_close_popover()
	_set_meter(0.0)
	_then_fill = false
	_slide_to(0.0)


func _slide_to(to: float) -> void:
	_from = rise()
	_sheet().set_target(to)
	_t = 0.0
	_step = Step.SLIDING
	if UIKit.calm() or is_equal_approx(_from, to):
		_sheet().set_rise(to)
		_arrived()


func _arrived() -> void:
	_t = 0.0
	if _sheet().target == 0.0:
		_step = Step.REST
	elif _then_fill and _sheet().hidden_rules() > 0:
		_step = Step.FILLING
	else:
		_step = Step.UP


func _set_meter(value: float) -> void:
	_meter = value
	var shown := floorf(value * CALM_STEPS + EPSILON) / CALM_STEPS if UIKit.calm() else value
	_sheet().set_meter(shown)


## Opens the rules popover beside the card: its name, its long-form rules, then why it can't be played.
func _open() -> void:
	_set_meter(1.0)
	_step = Step.OPEN
	var lines := face.rules_tip.split("\n")
	if _view.error_text != "":
		lines.append_array(_view.error_text.split("\n"))
	popover = RulesPopover.new(_view.shown_name, lines)
	popover.closed.connect(_on_popover_closed)
	popover.mouse_entered.connect(func(): _on_popover = true)
	popover.mouse_exited.connect(func(): _on_popover = false)
	popover.open_beside(layer, _view.get_global_rect(), UIKit.calm())


func _close_popover() -> void:
	if popover != null:
		popover.close()


func _on_popover_closed() -> void:
	popover = null
	_on_popover = false
	if _step == Step.OPEN:
		_step = Step.UP
		_set_meter(0.0)
