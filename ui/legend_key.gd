class_name LegendKey
extends Button
## The legend key (182, guide §7.5, §15.4): a push key that latches. A toggle Button on the theme's button boxes, so
## latched is the pressed box sunk 2 px into its shadow (178); a lamp strip across its top lights when latched, and its
## legend prints the state, ON or OFF.

const LAMP_HEIGHT := 6.0
const MIN_SIZE := Vector2(64, 44)


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = MIN_SIZE
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 16)
	toggled.connect(func(_on: bool): _legend())
	_legend()


## The theme's boxes are only reachable once the key is in the tree: copy them with room above the legend for the
## lamp strip.
func _ready() -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if box == null:
			continue
		box.content_margin_top += LAMP_HEIGHT + 2
		add_theme_stylebox_override(state, box)


## set_pressed_no_signal emits nothing, so the legend also follows the state here.
func _process(_delta: float) -> void:
	if text != _legend_text():
		_legend()


## The lamp's colour: lit (GAIN) while latched, dark (FIELD) while up.
func lamp_color() -> Color:
	return Palette.GAIN if button_pressed else Palette.FIELD


func _legend_text() -> String:
	return "ON" if button_pressed else "OFF"


func _legend() -> void:
	text = _legend_text()
	queue_redraw()


func _draw() -> void:
	var travel := GameTheme.PRESS if button_pressed else 0  # the strip sinks with the latched box
	var strip := Rect2(Vector2(6 + travel, 6 + travel), Vector2(size.x - 12, LAMP_HEIGHT))
	draw_rect(strip, lamp_color())
	draw_rect(strip, Palette.CONTROL_BORDER, false, 1.0)
