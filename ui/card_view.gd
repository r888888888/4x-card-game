class_name CardView
extends PanelContainer
## Visual for one card. Hand cards are interactive and emit clicked(uid);
## tableau cards are compact and display-only.

signal clicked(uid: int)

const TYPE_COLORS := {
	"action": Color("4a7fb5"),
	"building": Color("5f9a45"),
	"city": Color("c08a3e"),
}
const HAND_SIZE := Vector2(215, 280)
const TABLEAU_SIZE := Vector2(215, 150)

var uid := -1
var _interactive := false
var _style: StyleBoxFlat
var _color: Color


## play_error: "" if playable, otherwise the reason (shown as tooltip). Ignored for tableau cards.
func setup(card: CardInstance, card_db: Dictionary, in_hand: bool, play_error := "") -> void:
	uid = card.uid
	_interactive = in_hand
	var def := card.def
	_color = TYPE_COLORS.get(def.type, Color.GRAY)
	custom_minimum_size = HAND_SIZE if in_hand else TABLEAU_SIZE

	_style = StyleBoxFlat.new()
	_style.bg_color = _color.darkened(0.65)
	_style.border_color = _color
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(8)
	_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", _style)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var title := _label(def.name, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if in_hand:
		header.add_child(_label(_cost_text(def.cost), 19, Color("ffd966") if play_error == "" else Color("ff8a80")))

	var subtitle := def.type.capitalize()
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	box.add_child(_label(subtitle, 16, _color.lightened(0.5)))

	var rules := _label(def.rules_text(card_db), 19)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rules)

	if def.vp > 0:
		box.add_child(_label("%d VP" % def.vp, 20, Color("ffd966")))

	if in_hand:
		var playable := play_error == ""
		tooltip_text = "Click to play." if playable else play_error
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if playable else Control.CURSOR_FORBIDDEN
		if not playable:
			# Greyed but still readable; the red cost shows why.
			modulate = Color(0.68, 0.68, 0.68)
		mouse_entered.connect(func(): _style.border_color = Color.WHITE)
		mouse_exited.connect(func(): _style.border_color = _color)


func _gui_input(event: InputEvent) -> void:
	if _interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(uid)


static func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		if cost[r] > 0:
			parts.append("%d %s" % [cost[r], r])
	return "Free" if parts.is_empty() else ", ".join(parts)


static func _label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
