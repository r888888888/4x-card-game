class_name Modal
extends ColorRect
## The base of every modal (backlog 153; a drafting sheet since 207): a scrim over the whole board with a sheet centred
## on it. The sheet (panel, the Sheet variation: paper in a 2 px ink rule, cut square, on a soft shadow, 341) holds a
## title block (a 4 px ink bar, the title at left and an optional context in caps at right), an optional aside (a card),
## the body (at most BODY_MAX_WIDTH wide) and a footer of buttons, right-aligned under a 1 px rule, the primary in the
## signal colour (251). Subclasses set title and context and fill body, aside and footer (add_footer_button) instead
## of building their own headers.
## It opens on a ModalStack (present), over any modal already open; while it is the top modal it takes every key: its
## close_keys close it, the rest do nothing. A click on its scrim, outside its sheet, closes it (unless it can't be
## dismissed). Opening, the sheet rises RISE px into place and its scrim fades in (a stacked one's scrim shows at
## once); closing, it drops DROP px and fades with its scrim, taking no input while it goes. Reduce motion: fades only.

const BODY_MAX_WIDTH := 640
const STACK_SHIFT := Vector2(8, 8)  # each level opens this far right and down of the one below: paper on paper
const RISE := 24.0  # px below its place a sheet starts
const DROP := 12.0  # px below its place a closing sheet ends
const RISE_TIME := 0.24  # Anim.MACHINED
const FADE_TIME := 0.12  # the sheet's opacity in; Reduce motion's whole fade
const SCRIM_TIME := 0.16
const CLOSE_TIME := 0.16  # Anim.RELEASE

var stack: ModalStack
var panel: PanelContainer  # the sheet
var close_keys: Array[Key] = [KEY_ESCAPE]
var dismissable := true  # false: Esc and a click outside leave it open (the game-over sheet)
var title := "":
	set(value):
		title = value
		title_label.text = value
var context := "":
	set(value):
		context = value
		context_label.text = value
		context_label.visible = value != ""
var bar: ColorRect  # the title block's ink bar
var title_label: Label
var context_label: Label
var aside: Control  # left of the body (a card); hidden while empty
var body: VBoxContainer
var footer_rule: ColorRect
var footer: HBoxContainer

var _center: CenterContainer
var _shift := Vector2.ZERO  # the stack's offset for its level
var _offset := Vector2.ZERO  # the motion's offset from its place
var _tween: Tween


## Builds the modal on stack's host, hidden.
func _init(p_stack: ModalStack) -> void:
	stack = p_stack
	UIKit.painted(self, func(): color = Palette.SCRIM)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 20  # above the board, the drawer and flying cards; tree order stacks modals among themselves
	visible = false
	gui_input.connect(_on_scrim_input)
	stack.host.add_child(self)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE  # a click beside the sheet reaches the scrim and closes
	add_child(_center)
	panel = PanelContainer.new()
	panel.theme_type_variation = &"Sheet"
	_center.add_child(panel)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", Tokens.SPACE_4)
	panel.add_child(sheet)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", Tokens.SPACE_2)
	sheet.add_child(block)
	bar = ColorRect.new()
	bar.custom_minimum_size.y = 4
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.painted(bar, func(): bar.color = Palette.TEXT)
	block.add_child(bar)
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", Tokens.SPACE_5)
	block.add_child(heads)
	title_label = UIKit.title("")
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heads.add_child(title_label)
	context_label = UIKit.heading("")
	context_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	context_label.visible = false
	heads.add_child(context_label)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", Tokens.SPACE_6)
	sheet.add_child(content)
	aside = Control.new()
	aside.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.visible = false
	content.add_child(aside)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", Tokens.SPACE_3)
	content.add_child(body)
	footer_rule = ColorRect.new()
	footer_rule.custom_minimum_size.y = 1
	footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_rule.visible = false
	UIKit.painted(footer_rule, func(): footer_rule.color = Palette.CONTROL_DISABLED_BORDER)
	sheet.add_child(footer_rule)
	footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", Tokens.SPACE_3)
	footer.visible = false
	sheet.add_child(footer)


## Adds button to the footer: a primary one at the right end in the signal colour (AccentButton, 251), the others
## before the primary.
func add_footer_button(button: Button, primary := false) -> Button:
	footer.add_child(button)
	if primary:
		button.set_meta("primary", true)
		button.theme_type_variation = &"AccentButton"
	else:
		for b in footer.get_children():
			if b.get_meta("primary", false):
				footer.move_child(button, b.get_index())
				break
	footer.visible = true
	footer_rule.visible = true
	return button


## Puts card def, face up and not clickable, alone in the aside (the event and raid modals' card).
func show_card(def: CardDef, card_db: Dictionary) -> void:
	for child in aside.get_children():
		child.queue_free()
	var card := CardView.new()
	card.setup(CardInstance.new(-1, def), card_db, true)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aside.custom_minimum_size = card.slot_size()
	card.attach(aside)


## Shows it on top of the open modals.
func present() -> void:
	stack.push(self)


## Whether it is open on the stack (a closing sheet still drawn is not).
func is_open() -> bool:
	return stack.has(self)


## Moves its sheet level steps along the stack (0: centred), as the stack opens it at that depth.
func cascade(level: int) -> void:
	_shift = STACK_SHIFT * level
	_place()


## Closes it, and any modal opened over it.
func close() -> void:
	if is_open():
		stack.close(self)


## Called by the stack once it is closed: subclasses forget what they showed.
func closed() -> void:
	pass


## A key pressed while it is the top modal.
func key_pressed(keycode: Key) -> void:
	if keycode in close_keys and dismissable:
		close()


## Test hooks (207): how far the sheet is from its place, its opacity and its scrim's.
func sheet_offset() -> Vector2:
	return _offset


func sheet_alpha() -> float:
	return panel.modulate.a


func scrim_alpha() -> float:
	return self_modulate.a


## Lays the sheet down (the stack calls it on opening): it rises into place and its scrim fades in, unless stacked
## (over another modal), when the scrim shows at once.
func enter(stacked: bool) -> void:
	_stop()
	_take_input(true)
	show()
	panel.modulate.a = 0.0
	self_modulate.a = 1.0 if stacked else 0.0
	_tween = create_tween().set_parallel()
	if UIKit.calm():
		_set_offset(Vector2.ZERO)
		_tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
		if not stacked:
			_tween.tween_property(self, "self_modulate:a", 1.0, FADE_TIME)
		return
	_set_offset(Vector2(0, RISE))
	_tween.tween_method(_set_offset, Vector2(0, RISE), Vector2.ZERO, RISE_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	if not stacked:
		_tween.tween_property(self, "self_modulate:a", 1.0, SCRIM_TIME)


## Lifts the sheet off (the stack calls it on closing): it drops and fades with its scrim, taking no input, then hides.
func leave() -> void:
	_stop()
	_take_input(false)
	_tween = create_tween().set_parallel()
	var time := FADE_TIME if UIKit.calm() else CLOSE_TIME
	if not UIKit.calm():
		_tween.tween_method(_set_offset, _offset, Vector2(0, DROP), CLOSE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(panel, "modulate:a", 0.0, time)
	_tween.tween_property(self, "self_modulate:a", 0.0, time)
	_tween.chain().tween_callback(_rest)


func _rest() -> void:
	hide()
	_set_offset(Vector2.ZERO)
	panel.modulate.a = 1.0
	self_modulate.a = 1.0
	_take_input(true)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _take_input(on: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	panel.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED if on else Control.MOUSE_BEHAVIOR_DISABLED


func _set_offset(value: Vector2) -> void:
	_offset = value
	_place()


func _place() -> void:
	var at := _shift + _offset
	_center.offset_left = at.x
	_center.offset_top = at.y
	_center.offset_right = at.x
	_center.offset_bottom = at.y


## The top modal takes every key: its close keys close it; with one of its own controls focused, the rest go on to that
## control (Tab, the arrows, Enter, typing), and the board never sees them (main checks for an open modal).
func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or stack.top() != self:
		return
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.note_input()  # the top modal takes its keys before the player could hear them (189)
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused) and not (event.keycode in close_keys and dismissable):
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo:
		key_pressed(event.keycode)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		if dismissable:
			close()
