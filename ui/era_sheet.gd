class_name EraSheet
extends Control
## The era ceremony (backlog 211, transitions.html transition 7): when the engine adds an era (milestone ERA), the next
## board refresh lays a sheet over the whole window: it wipes in from the left (WIPE_TIME), three rings draw out from the
## centre, and the era's name comes in a letter at a time (LETTER_TIME each) under "A NEW ERA", with the turn below.
## Reduce motion: the finished sheet fades in. A click or key while it moves finishes it; on the finished sheet one
## closes it (a CLOSE_TIME fade). Nothing else takes clicks or keys while it shows. Two eras in one turn: one sheet,
## naming the later.

signal closed

const WIPE_TIME := 0.40
const RING_TIME := 0.30  # each ring drawing out
const RING_STAGGER := 0.04
const LETTER_TIME := 0.06
const FADE_TIME := 0.12  # Reduce motion's fade in
const CLOSE_TIME := 0.16
const RING_RADII: Array[float] = [140.0, 220.0, 300.0]

var name_label: Label

var _paper: ColorRect  # the sheet itself, wiping in
var _content: VBoxContainer
var _kicker: Label
var _turn: Label
var _rings: Control
var _ring_progress: Array[float] = [0.0, 0.0, 0.0]
var _owed := false  # an era was added since the last refresh
var _closing := false
var _done := false  # the sheet has finished moving in
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30  # above everything, the modals too
	visible = false
	_paper = ColorRect.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.painted(_paper, func(): _paper.color = Palette.RAISED)
	add_child(_paper)
	_rings = Control.new()
	_rings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.draw.connect(_draw_rings)
	add_child(_rings)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", Tokens.SPACE_4)
	center.add_child(_content)
	_kicker = Label.new()
	_kicker.text = "A NEW ERA"
	_kicker.theme_type_variation = &"Heading"
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_kicker)
	name_label = Label.new()
	name_label.theme_type_variation = &"DisplayXL"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(name_label)
	_turn = Label.new()
	_turn.theme_type_variation = &"Caption"
	_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_turn)


## The engine's milestone(kind) (191): an era added owes a sheet at the next refresh.
func note(kind: StringName) -> void:
	if kind == GameEngine.MILESTONE_ERA:
		_owed = true


## Shows the sheet if an era was added since the last refresh (the latest era, so two eras show one sheet).
func refresh(e: GameEngine) -> void:
	if not _owed:
		return
	_owed = false
	open_era(e.era_name(e.era()), e.turn)


## Forgets an owed sheet and closes one showing (a new game).
func reset() -> void:
	_owed = false
	_stop()
	_closing = false
	hide()


## Lays the sheet for era_name on turn, moving unless Reduce motion is on.
func open_era(era_name: String, turn: int) -> void:
	_stop()
	_closing = false
	name_label.text = era_name
	_turn.text = "Turn %d" % turn
	modulate.a = 1.0
	show()
	var whole := get_viewport_rect().size if is_inside_tree() else size
	if UIKit.calm():
		_finish()
		modulate.a = 0.0
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
		return
	_done = false
	_paper.size = Vector2(0, whole.y)
	_paper.position = Vector2.ZERO
	_content.modulate.a = 0.0
	name_label.visible_characters = 0
	_set_rings(0.0)
	var reveal := maxf(RING_TIME + RING_STAGGER * 2, LETTER_TIME * era_name.length())
	_tween = create_tween()
	_tween.tween_property(_paper, "size:x", whole.x, WIPE_TIME).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_content, "modulate:a", 1.0, 0.0)
	_tween.tween_method(_reveal, 0.0, reveal, reveal)
	_tween.tween_callback(_finish)


## After the wipe, t seconds in: the rings drawing out and a letter of the name every LETTER_TIME.
func _reveal(t: float) -> void:
	_set_rings(t / (RING_TIME + RING_STAGGER * 2))
	name_label.visible_characters = mini(int(t / LETTER_TIME), name_label.text.length())


## Whether the sheet is up and not closing.
func is_open() -> bool:
	return visible and not _closing


## Test hooks (211).
func finished() -> bool:
	return visible and _done


func covered_rect() -> Rect2:
	return _paper.get_global_rect()


func kicker_text() -> String:
	return _kicker.text


func era_text() -> String:
	var shown := name_label.visible_characters
	return name_label.text if shown < 0 else name_label.text.substr(0, shown)


func turn_text() -> String:
	return _turn.text


## The rings drawn so far (their radii).
func rings() -> Array[float]:
	var out: Array[float] = []
	for i in RING_RADII.size():
		if _ring_progress[i] > 0.0:
			out.append(RING_RADII[i])
	return out


## A click or key: finishes a moving sheet, closes a finished one.
func _advance() -> void:
	if _closing:
		return
	if not _done:
		_stop()
		_finish()
		modulate.a = 1.0
		return
	_closing = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, CLOSE_TIME)
	_tween.tween_callback(func():
		hide()
		_closing = false
		closed.emit())


func _finish() -> void:
	var whole := get_viewport_rect().size if is_inside_tree() else size
	_paper.position = Vector2.ZERO
	_paper.size = whole
	_content.modulate.a = 1.0
	name_label.visible_characters = -1
	_set_rings(1.0)
	_done = true


func _set_rings(t: float) -> void:
	for i in RING_RADII.size():
		_ring_progress[i] = clampf((t * (RING_TIME + RING_STAGGER * 2) - RING_STAGGER * i) / RING_TIME, 0.0, 1.0)
	_rings.queue_redraw()


func _draw_rings() -> void:
	var centre := _rings.size / 2
	for i in RING_RADII.size():
		if _ring_progress[i] > 0.0:
			_rings.draw_arc(centre, RING_RADII[i], -PI / 2, -PI / 2 + TAU * _ring_progress[i], 128, Palette.TEXT_DIM, 2.0)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_advance()


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		_advance()
