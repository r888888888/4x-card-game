class_name Counter
extends HBoxContainer
## One counter (181): an optional glyph (180) or word, its figure as an Odometer, then the next upkeep's change as a quieter figure of its own ("+1", 201). A change rolls the figure; the roll is the only mark
## of it (218: a "+N" tag beside the figure pushed the counters after it along, then back). The glyph can breathe, a
## slow fade and back, held still with Reduce motion (228).

const GLYPH_GAP := 6  # px between the glyph and the figure

var _prefix: Label  # "Wealth: " on the Supply screen; empty in the top bar, where the glyph names it
var _figure: Odometer
var _forecast: Label  # next upkeep's change, "+1", in the Forecast look; hidden with none (201)
var _glyph: TextureRect  # null without one
var _breathe := false  # whether the owner wants the glyph breathing (228)
var _breath: Tween  # the glyph's looping breath while it runs


## glyph_key: an Icons.RESOURCES key for the glyph ("" for none); prefix: a word before the figure ("" for none);
## variation: the Label variation the text and figure use (BarStat in the top bar, Stat on a screen).
func _init(glyph_key := "", prefix := "", variation := &"BarStat") -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	var glyph: TextureRect = null
	if glyph_key != "":
		glyph = Icons.glyph(glyph_key, TopBar.GLYPH)
		_glyph = glyph
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
	_figure.widened.connect(_sort_now)  # the forecast after it follows the figure as it widens mid-roll
	add_child(_figure)
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
	Settings.changed.connect(_apply_breath)


## The counter's glyph, or null without one.
func glyph() -> TextureRect:
	return _glyph


## Whether the glyph is breathing now (228).
func breathing() -> bool:
	return _breath != null and _breath.is_running()


## Breathes the glyph while on, unless Reduce motion holds it still at full opacity (228).
func set_breathing(on: bool) -> void:
	_breathe = on
	_apply_breath()


## The counter's figure.
func figure() -> Odometer:
	return _figure


## The whole reading but the forecast: the word and the figure's value ("3", "Wealth: 10").
func text() -> String:
	return _prefix.text + str(_figure.value)


## The forecast shown ("+1"), or "" for none (201).
func forecast_text() -> String:
	return _forecast.text if _forecast.visible else ""


## Shows next upkeep's change as text ("+1"), or no forecast for "".
func set_forecast(text_: String) -> void:
	_forecast.text = text_
	_forecast.visible = text_ != ""


## Shows v: at once when fresh (a new game, an opened screen), else rolling the figure after delay, sounding
## its steps if sound (188). Returns the change from the value it was heading to (0 when fresh).
func show_value(v: int, fresh: bool, delay := 0.0, sound := true) -> int:
	var change := 0 if fresh else v - _figure.value
	if fresh:
		_figure.show_now(v)
	elif change != 0:
		_figure.set_value(v, delay, sound)
	return change


## The figure's and its words' colour (TEXT, WARN at a limit, or a counter's own on a screen).
func set_color(c: Color) -> void:
	_figure.color = c
	_prefix.add_theme_color_override("font_color", c)


## Starts or stops the glyph's breath to match what the owner wants and Reduce motion.
func _apply_breath() -> void:
	var go := _breathe and _glyph != null and not UIKit.calm()
	if go == breathing():
		return
	if _breath != null:
		_breath.kill()
		_breath = null
	if _glyph == null:
		return
	_glyph.modulate.a = 1.0
	if go:
		_breath = create_tween().set_loops()
		_breath.tween_property(_glyph, "modulate:a", Anim.BREATH_ALPHA, Anim.BREATH_TIME / 2).set_trans(Tween.TRANS_SINE)
		_breath.tween_property(_glyph, "modulate:a", 1.0, Anim.BREATH_TIME / 2).set_trans(Tween.TRANS_SINE)


## Lays the row out now rather than next frame, so the forecast after the figure moves with it.
func _sort_now() -> void:
	notification(NOTIFICATION_SORT_CHILDREN)


func _text(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
	return label
