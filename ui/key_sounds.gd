class_name KeySounds
extends Node
## Key sounds for every button in main (187, guide §10.1, §15.1): a press clicks as the key sinks into its shadow and
## ticks as it comes back up, at their contact points; hover and focus are silent. A press on a disabled key gives one
## dead tap and shows the key's reason at once (the locked tip), the visual twin of the tap. Buttons in OWN_SOUNDS (the
## legend key, End turn) make their own press and release sounds; their disabled tap is still made here. No component
## has to remember to add sound: every BaseButton entering main's tree is hooked.

const OWN_SOUNDS := &"own_key_sounds"

var _sfx: Sfx
var _tip: PanelContainer  # the locked tip: a disabled key's reason, shown at once
var _tip_label: Label
var _tip_for: Control  # the key it explains


func _init(sfx: Sfx) -> void:
	_sfx = sfx
	_tip = PanelContainer.new()
	_tip.theme_type_variation = &"TooltipPanel"
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 100  # above the modals and the menu
	_tip.hide()
	_tip_label = Label.new()
	_tip_label.theme_type_variation = &"TooltipLabel"
	_tip.add_child(_tip_label)
	add_child(_tip)


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	for b in get_parent().find_children("*", "BaseButton", true, false):
		_hook(b)


func _exit_tree() -> void:
	get_tree().node_added.disconnect(_on_node_added)


## The locked tip, shown while a disabled key's press explains itself.
func tip() -> Control:
	return _tip


func _on_node_added(node: Node) -> void:
	if node is BaseButton and get_parent().is_ancestor_of(node):
		_hook(node)


func _hook(b: BaseButton) -> void:
	if b.gui_input.is_connected(_on_input):
		return
	b.gui_input.connect(_on_input.bind(b))
	if not b.is_in_group(OWN_SOUNDS):
		b.button_down.connect(func(): _sfx.at_contact(Sfx.BUTTON_PRESS, Anim.KEY_PRESS_TIME, Anim.SNAP, true))
		b.button_up.connect(func(): _sfx.at_contact(Sfx.BUTTON_RELEASE, Anim.KEY_RELEASE_TIME, Anim.MACHINED, true))


func _on_input(event: InputEvent, b: BaseButton) -> void:
	var press := event as InputEventMouseButton
	if b.disabled and press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_sfx.play(Sfx.REJECT_LOCKED, 0.0, true)
		_show_tip(b)


func _show_tip(b: BaseButton) -> void:
	if b.tooltip_text == "":
		return
	_tip_label.text = b.tooltip_text
	_tip.reset_size()
	var r := b.get_global_rect()
	_tip.global_position = Vector2(r.position.x, r.end.y + Tokens.SPACE_1)
	_tip.show()
	_tip_for = b
	if not b.mouse_exited.is_connected(_hide_tip):
		b.mouse_exited.connect(_hide_tip, CONNECT_ONE_SHOT)
	get_tree().create_timer(Anim.ERROR_SHOW_TIME).timeout.connect(func():
		if _tip_for == b:
			_hide_tip())


func _hide_tip() -> void:
	_tip.hide()
	_tip_for = null
