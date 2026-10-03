class_name Counter
extends HBoxContainer
## One counter (181): an optional glyph (180) or word, its figure as an Odometer, any words after it (" / 5"), then the
## next upkeep's change as a quieter figure of its own ("+1", 201). A change rolls the figure; the roll is the only mark
## of it (218: a "+N" tag beside the figure pushed the counters after it along, then back).

const GLYPH_GAP := 6  # px between the glyph and the figure

var _prefix: Label  # "Wealth: " on the Supply screen; empty in the top bar, where the glyph names it
var _figure: Odometer
var _suffix: Label  # words after the figure: the unrest limit, " / 5"
var _forecast: Label  # next upkeep's change, "+1", in the Forecast look; hidden with none (201)


## glyph_key: an Icons.RESOURCES key for the glyph ("" for none); prefix: a word before the figure ("" for none);
## variation: the Label variation the text and figure use (BarStat in the top bar, Stat on a screen).
func _init(glyph_key := "", prefix := "", variation := &"BarStat") -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	var glyph: TextureRect = null
	if glyph_key != "":
		glyph = Icons.glyph(glyph_key, TopBar.GLYPH)
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(glyph)
		var gap := Control.new()
		gap.custom_minimum_size.x = GLYPH_GAP
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(gap)
	_prefix = _text(variation)
	_prefix.text = prefix
	_prefix.visible = prefix != ""
	_figure = Odometer.new(variation)
	_figure.widened.connect(_sort_now)  # the words after it follow the figure as it widens mid-roll
	add_child(_figure)
	_suffix = _text(variation)
	_forecast = _text(&"Forecast")
	_forecast.name = "Forecast"
	var apart := StyleBoxEmpty.new()
	apart.content_margin_left = Tokens.SPACE_1
	_forecast.add_theme_stylebox_override("normal", apart)
	_forecast.hide()
	UIKit.painted(self, func():  # 183: a refresh or the owner sets any other colour after this
		if glyph != null:
			glyph.self_modulate = Icons.hue(glyph_key)
		set_color(Palette.TEXT))


## The counter's figure.
func figure() -> Odometer:
	return _figure


## The whole reading but the forecast: the word, the figure's value and the words after it ("3", "2 / 5", "Wealth: 10").
func text() -> String:
	return _prefix.text + str(_figure.value) + _suffix.text


## The forecast shown ("+1"), or "" for none (201).
func forecast_text() -> String:
	return _forecast.text if _forecast.visible else ""


## Shows next upkeep's change as text ("+1"), or no forecast for "".
func set_forecast(text_: String) -> void:
	_forecast.text = text_
	_forecast.visible = text_ != ""


## Shows v and suffix: at once when fresh (a new game, an opened screen), else rolling the figure after delay, sounding
## its steps if sound (188). Returns the change from the value it was heading to (0 when fresh).
func show_value(v: int, suffix: String, fresh: bool, delay := 0.0, sound := true) -> int:
	_suffix.text = suffix
	var change := 0 if fresh else v - _figure.value
	if fresh:
		_figure.show_now(v)
	elif change != 0:
		_figure.set_value(v, delay, sound)
	return change


## The figure's and its words' colour (TEXT, WARN at a limit, or a counter's own on a screen).
func set_color(c: Color) -> void:
	_figure.color = c
	for label in [_prefix, _suffix]:
		label.add_theme_color_override("font_color", c)


## Lays the row out now rather than next frame, so the words after the figure move with it.
func _sort_now() -> void:
	notification(NOTIFICATION_SORT_CHILDREN)


func _text(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
	return label
