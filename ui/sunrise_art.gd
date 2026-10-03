class_name SunriseArt
extends Control
## The title screen's art (backlog 214, title-screen-ledger-hill.html B1.1): a banded sun over one bare green hill,
## drawn in a DESIGN space scaled to fill the rect (cropped and centred, like SVG's slice). When the title screen opens
## the sun rises from below the horizon and the hill comes up (enter); then nothing moves. Hovering or focusing New
## game eases the sun up DAY_UP px; Exit sinks it SUNSET px into a sunset (aim, a critically damped spring). How low
## the sun is (warmth) reddens it, lays warm bands across the sky and deepens the hill. It processes only while
## something moves; with Reduce motion it rests and jumps. Its geometry is the design's, not spacing, so its numbers
## are named here rather than Tokens.

const DESIGN := Vector2(600, 675)
const SUN_X := 300.0
const SUN_RADIUS := 150.0
const HORIZON := 520.0  # y of the horizon, from the top
const HILL_WIDTH := 720.0
const HILL_CROWN := 150.0  # the hill's top above the horizon
const GAPS: Array[float] = [0.15, 0.33, 0.51, 0.69, 0.86]  # below the sun's centre, in radii
const BANDS: Array[Vector2] = [Vector2(474, 46), Vector2(416, 58), Vector2(346, 70), Vector2(260, 86)]  # y, height
const BAND_ALPHA: Array[float] = [0.55, 0.32, 0.22, 0.12]  # from the horizon up, at full warmth
const REST := 220.0  # the sun centre's height above the horizon at rest
const START := -170.0  # where the entrance starts it
const RISE_TIME := 2.6  # Anim.MACHINED
const HILL_DROP := 120.0  # px the hill starts below its place
const HILL_DELAY := 0.15
const HILL_TIME := 0.9
const DAY_UP := 70.0  # New game
const SUNSET := 190.0  # Exit
const SPRING := 7.0  # the aim's spring, per second (critically damped)
const STEP := 1.0 / 120.0  # the clock's step

var _time := RISE_TIME  # since the entrance began; at rest by default
var _aim := 0.0  # the offset the sun eases toward (DAY_UP, -SUNSET or 0)
var _offset := 0.0  # the spring's offset from the entrance's height
var _speed := 0.0
var _manual := false  # the tests' clock: _process doesn't advance it


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(false)
	UIKit.painted(self, queue_redraw)  # 183: Day mode redraws it


## The entrance: the sun rises and the hill comes up; with Reduce motion the art opens at rest.
func enter() -> void:
	_time = _entrance_time() if UIKit.calm() else 0.0
	_aim = 0.0
	_offset = 0.0
	_speed = 0.0
	_wake()


## Eases the sun offset px from its rest (DAY_UP for New game, -SUNSET for Exit, 0 to rest); at once with Reduce motion.
func aim(offset: float) -> void:
	_aim = offset
	if UIKit.calm():
		_offset = offset
		_speed = 0.0
		queue_redraw()
		return
	_wake()


## Test hooks (214): the tests' clock.
func use_manual_clock() -> void:
	_manual = true


func advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		_step(minf(STEP, left))
		left -= STEP
	queue_redraw()


## The sun centre's height above the horizon now.
func sun_height() -> float:
	return _entrance_height() + _offset


## How far the hill sits below its place now.
func hill_offset() -> float:
	var t := clampf((_time - HILL_DELAY) / HILL_TIME, 0.0, 1.0)
	return HILL_DROP * (1.0 - _ease_out(t))


## How low the sun is, from its centre's height above the horizon: 0 at 200 or more, 1 at 10 or less, smooth between.
static func warmth(height: float) -> float:
	var t := clampf((200.0 - height) / 190.0, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func sun_color(w: float) -> Color:
	return Palette.SUN.lerp(Palette.SUN_LOW, 0.85 * w)


## Band i's alpha (0 nearest the horizon) at warmth w.
static func band_alpha(i: int, w: float) -> float:
	return BAND_ALPHA[i] * w


static func hill_color(w: float) -> Color:
	return Palette.HILL.lerp(Palette.HILL_LOW, 0.6 * w).lerp(Palette.SHADOW, 0.25 * w)


## The scale that fills size with the design, cropping the rest (SVG's slice).
static func slice_scale(size_: Vector2) -> float:
	return maxf(size_.x / DESIGN.x, size_.y / DESIGN.y)


## The sun's gaps for radius r, top first: [offset below the centre, height], each thicker than the one above.
static func gap_rects(r: float) -> Array:
	var out := []
	for i in GAPS.size():
		out.append([GAPS[i] * r, (4.0 + 3.5 * i) * r / SUN_RADIUS])
	return out


func _process(delta: float) -> void:
	if not _manual:
		advance(delta)


func _wake() -> void:
	set_process(not _settled())
	queue_redraw()


func _step(dt: float) -> void:
	_time += dt
	# The critically damped spring's exact step, so it never overshoots (x: the offset from the aim).
	var x := _offset - _aim
	var decay := exp(-SPRING * dt)
	var c := _speed + SPRING * x
	_offset = _aim + (x + c * dt) * decay
	_speed = (_speed - SPRING * c * dt) * decay
	if absf(_offset - _aim) < 0.01 and absf(_speed) < 0.01:
		_offset = _aim
		_speed = 0.0
	if _settled():
		set_process(false)


func _settled() -> bool:
	return _time >= _entrance_time() and _offset == _aim and _speed == 0.0


## How long the entrance takes: the sun's rise or the hill's, whichever ends later.
static func _entrance_time() -> float:
	return maxf(RISE_TIME, HILL_DELAY + HILL_TIME)


func _entrance_height() -> float:
	return lerpf(START, REST, _ease_out(clampf(_time / RISE_TIME, 0.0, 1.0)))


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 4.0)


func _draw() -> void:
	var s := slice_scale(size)
	draw_set_transform((size - DESIGN * s) / 2.0, 0.0, Vector2(s, s))
	var h := sun_height()
	var w := warmth(h)
	for i in BANDS.size():
		var a := band_alpha(i, w)
		if a > 0.0:
			var c := Palette.SKY_LOW.lerp(Palette.SKY_HIGH, i / float(BANDS.size() - 1))
			draw_rect(Rect2(-DESIGN.x, BANDS[i].x, DESIGN.x * 3.0, BANDS[i].y), Color(c, a))
	_draw_sun(Vector2(SUN_X, HORIZON - h), sun_color(w))
	_draw_hill(hill_offset(), hill_color(w))


## The sun as horizontal slices of its disc, the gaps between them left empty so the sky shows through.
func _draw_sun(centre: Vector2, colour: Color) -> void:
	var r := SUN_RADIUS
	var cuts: Array[Vector2] = []  # [top, bottom] of each gap, in y below the centre
	for gap in gap_rects(r):
		cuts.append(Vector2(gap[0] - gap[1] / 2.0, gap[0] + gap[1] / 2.0))
	var top := -r
	for cut in cuts:
		_draw_slice(centre, r, top, cut.x, colour)
		top = cut.y
	_draw_slice(centre, r, top, r, colour)


## The part of a disc (centre, r) between y0 and y1 below its centre.
func _draw_slice(centre: Vector2, r: float, y0: float, y1: float, colour: Color) -> void:
	if y1 <= y0:
		return
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	var n := 24
	for i in n + 1:
		var y := lerpf(y0, y1, i / float(n))
		var half := sqrt(maxf(r * r - y * y, 0.0))
		right.append(centre + Vector2(half, y))
		left.append(centre + Vector2(-half, y))
	left.reverse()
	var points := right + left
	if points.size() >= 3:
		draw_colored_polygon(points, colour)


## The hill: an elliptical dome HILL_WIDTH wide whose crown is HILL_CROWN above the horizon, filled to the bottom,
## drop px below its place.
func _draw_hill(drop: float, colour: Color) -> void:
	var points: PackedVector2Array = []
	var half := HILL_WIDTH / 2.0
	var n := 64
	for i in n + 1:
		var a := PI * i / n  # left to right over the top
		points.append(Vector2(SUN_X - cos(a) * half, HORIZON + drop - sin(a) * HILL_CROWN))
	points.append(Vector2(SUN_X + half, DESIGN.y + HILL_DROP + 50.0))
	points.append(Vector2(SUN_X - half, DESIGN.y + HILL_DROP + 50.0))
	draw_colored_polygon(points, colour)
