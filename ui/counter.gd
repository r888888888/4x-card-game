class_name Counter
extends HBoxContainer
## One counter (181): an optional glyph (180) or word, its figure as an Odometer, then a forecast such as " (+1)". A
## change rolls the figure and shows a "+N" / "−N" tag right of it for Anim.TAG_HOLD (Anim.CALM_TAG_HOLD with Reduce
## motion), instead of a token floating off it.

const GLYPH_GAP := 6  # px between the glyph and the figure
const TAG_GAP := 4  # px between the figure and its tag

var _prefix: Label  # "Wealth: " on the Supply screen; empty in the top bar, where the glyph names it
var _figure: Odometer
var _tag: Label
var _suffix: Label  # the forecast, " (+1)", or the unrest limit and forecast, " / 5 (+1)"
var _tag_tween: Tween


## glyph_key: an Icons.RESOURCES key for the glyph ("" for none); prefix: a word before the figure ("" for none);
## variation: the Label variation the text and figure use (BarStat in the top bar, Stat on a screen).
func _init(glyph_key := "", prefix := "", variation := &"BarStat") -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_PASS  # for the tooltip
	if glyph_key != "":
		var glyph := Icons.glyph(glyph_key, TopBar.GLYPH)
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
	_figure.widened.connect(_sort_now)  # the tag follows the figure as it widens mid-roll
	add_child(_figure)
	_tag = _text(variation)
	_tag.name = "Tag"
	var room := StyleBoxEmpty.new()
	room.content_margin_left = TAG_GAP
	_tag.add_theme_stylebox_override("normal", room)
	_tag.hide()
	_suffix = _text(variation)


## The counter's figure.
func figure() -> Odometer:
	return _figure


## The whole reading: the word, the figure's value and the forecast ("3 (+1)", "Wealth: 10").
func text() -> String:
	return _prefix.text + str(_figure.value) + _suffix.text


## Shows v and suffix: at once when fresh (a new game, an opened screen), else rolling the figure. Returns the change
## from the value it was heading to (0 when fresh).
func show_value(v: int, suffix: String, fresh: bool) -> int:
	_suffix.text = suffix
	var change := 0 if fresh else v - _figure.value
	if fresh:
		_figure.show_now(v)
		_hide_tag()
	elif change != 0:
		_figure.set_value(v)
	return change


## The figure's and its words' colour (TEXT, WARN at a limit, or a counter's own on a screen).
func set_color(c: Color) -> void:
	_figure.color = c
	for label in [_prefix, _suffix]:
		label.add_theme_color_override("font_color", c)


## Shows change as a tag right of the figure after delay (at once with Reduce motion), in UIKit.GAIN_COLOR or UIKit.COST_COLOR, for Anim.TAG_HOLD
## (Anim.CALM_TAG_HOLD in place with Reduce motion), then hides it.
func show_tag(change: int, delay: float) -> void:
	_hide_tag()
	_tag.text = "%s%d" % ["+" if change > 0 else "−", absi(change)]
	_tag.add_theme_color_override("font_color", UIKit.GAIN_COLOR if change > 0 else UIKit.COST_COLOR)
	_tag_tween = create_tween()
	if UIKit.calm():
		delay = 0.0
	if delay > 0.0:
		_tag_tween.tween_interval(delay)
	_tag_tween.tween_callback(_show_tag)
	if UIKit.calm():
		_tag_tween.tween_interval(Anim.CALM_TAG_HOLD)
	else:
		_tag_tween.tween_interval(Anim.TAG_HOLD)
		_tag_tween.tween_property(_tag, "modulate:a", 0.0, Anim.CALM_FADE_TIME)
	_tag_tween.tween_callback(func(): _tag.hide(); _tag.modulate.a = 1.0)
	if delay <= 0.0:
		_show_tag()


func _show_tag() -> void:
	_tag.show()
	_sort_now()


## Lays the row out now rather than next frame, so the tag sits right of the figure from the moment it shows.
func _sort_now() -> void:
	notification(NOTIFICATION_SORT_CHILDREN)


func _hide_tag() -> void:
	if _tag_tween != null and _tag_tween.is_valid() and _tag_tween.is_running():
		_tag_tween.kill()
	_tag_tween = null
	_tag.hide()
	_tag.modulate.a = 1.0


func _text(variation: StringName) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(label)
	return label
