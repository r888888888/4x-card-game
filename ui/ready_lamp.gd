class_name ReadyLamp
extends Control
## The ready lamp inside a key, before its label (288; the specimen's "Learn Pottery" lamp, guide §7.11): a 12 px disc,
## dark (a well with a 1 px ring) or lit (sage with a 2 px ring and a highlight dot). It sits on the key's icon, a
## blank of its size, so the key is as wide lit as dark. Lighting is quick and fires the confirmation starburst
## (§10.8): six rays wiping out from 9 px off its centre, then fading as they move to 13 px, with ui.confirm; going out
## is slower and silent. With Reduce motion the rays are drawn whole for CALM_RAYS, then go.

const SIZE := 12  # px across
const ON_TIME := 0.04  # ease.lamp on
const OFF_TIME := 0.12  # ease.lamp off
const RAYS := 6
const RAY := Vector2(2, 8)  # px: a ray's width and length
const RAY_FROM := 9.0  # px from the lamp's centre where a ray starts
const RAY_TO := 13.0  # ... and where it has moved to as it fades
const RAY_TIME := 0.4
const RAY_WIPE := 0.6  # of RAY_TIME: the ray drawn out, before it moves and fades
const CALM_RAYS := 1.5  # s the rays stay whole with Reduce motion

var _lit := false
var _glow := 0.0  # 0 dark .. 1 lit, eased between
var _burst := -1.0  # the starburst's progress 0..1; < 0 when none
var _glow_tween: Tween
var _burst_tween: Tween


## Puts a lamp on button's icon, before its label: the icon becomes a blank the lamp's size, SPACE_3 from the label.
static func attach(button: Button) -> ReadyLamp:
	var blank := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)  # transparent
	button.icon = ImageTexture.create_from_image(blank)
	button.add_theme_constant_override("h_separation", Tokens.SPACE_3)
	var lamp := ReadyLamp.new()
	button.add_child(lamp)
	button.resized.connect(lamp._place)
	lamp._place()
	return lamp


## The lamp on button, or null.
static func of(button: Button) -> ReadyLamp:
	for child in button.get_children():
		if child is ReadyLamp:
			return child
	return null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(SIZE, SIZE)
	UIKit.painted(self, queue_redraw)


func is_lit() -> bool:
	return _lit


## Lights the lamp or puts it out. quietly: at once, with no burst or sound (a new game's first refresh). Going from
## dark to lit otherwise fires the burst and ui.confirm.
func set_lit(on: bool, quietly := false) -> void:
	if on == _lit:
		return
	_lit = on
	if _glow_tween != null:
		_glow_tween.kill()
	if quietly or not is_inside_tree():
		_glow = 1.0 if on else 0.0
		queue_redraw()
		return
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, _glow, 1.0 if on else 0.0, ON_TIME if on else OFF_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN_OUT)
	if on:
		_fire()


func _set_glow(v: float) -> void:
	_glow = v
	queue_redraw()


func _set_burst(v: float) -> void:
	_burst = v
	queue_redraw()


func _fire() -> void:
	if _burst_tween != null:
		_burst_tween.kill()
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.play(Sfx.CONFIRM, 0.0, true)
	_burst_tween = create_tween()
	if UIKit.calm():
		_set_burst(RAY_WIPE)  # whole, at RAY_FROM
		_burst_tween.tween_interval(CALM_RAYS)
	else:
		_burst_tween.tween_method(_set_burst, 0.0, 1.0, RAY_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_burst_tween.tween_callback(_set_burst.bind(-1.0))


## Centres the lamp on its button's icon: the content's left edge, half way down.
func _place() -> void:
	var button := get_parent() as Button
	var box := button.get_theme_stylebox("normal")
	position = Vector2(box.get_margin(SIDE_LEFT), (button.size.y - SIZE) / 2.0)


func _draw() -> void:
	var c := Vector2(SIZE, SIZE) / 2.0
	var r := SIZE / 2.0
	draw_circle(c, r, Palette.FIELD.lerp(Palette.GAIN, _glow))
	var ring := 1.0 + _glow
	draw_arc(c, r - ring / 2.0, 0, TAU, 32, Palette.CONTROL_BORDER.lerp(Palette.GAIN.darkened(0.35), _glow), ring, true)
	if _glow > 0.0:
		var dot := Palette.GAIN.lightened(0.4)
		dot.a = _glow
		draw_circle(c - Vector2(r, r) * 0.3, r * 0.2, dot)
	if _burst >= 0.0:
		_draw_rays(c)


## The starburst at progress _burst: drawn out along RAY_WIPE, then moving from RAY_FROM to RAY_TO as it fades.
func _draw_rays(c: Vector2) -> void:
	var wipe := minf(_burst / RAY_WIPE, 1.0)
	var later := maxf((_burst - RAY_WIPE) / (1.0 - RAY_WIPE), 0.0)
	var colour := Palette.GAIN
	colour.a = 1.0 - later
	var from := lerpf(RAY_FROM, RAY_TO, later)
	for i in RAYS:
		var dir := Vector2.DOWN.rotated(TAU * i / RAYS)
		draw_line(c + dir * from, c + dir * (from + RAY.y * wipe), colour, RAY.x)
