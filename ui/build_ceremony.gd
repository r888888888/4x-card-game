class_name BuildCeremony
extends Control
## The build ceremony (357, guide §9.4, §10.8): a moment on a card just built, recruited or upgraded. Once the Build
## sheet has closed (Anim.BUILD_DELAY), a lamp ring blooms off the card's edge and 12 rays draw out from just off it, in
## the card's plane colour; then a BUILT or RECRUITED tag snaps onto its top-right corner, holds and wipes out (an
## upgrade's ceremony, on its base, has no tag). With Reduce motion it shows whole at once and holds Anim.BUILD_CALM_HOLD.
## It lives on main's fx layer, follows the card and frees itself. Its sound is EventSounds'.

const RING := "ring"
const RAYS := "rays"
const TAG := "tag"
const BUILT := "BUILT"
const RECRUITED := "RECRUITED"
const RAY_COUNT := 12
const LINE_WIDTH := 3.0  # the ring's and the rays' stroke
const ROOM := Tokens.SPACE_8  # around the card, for the rays and the tag

var view: CardView  # the card it plays on

var _tag := ""  # the tag's word, "" for none
var _colour: Color
var _ring := -1.0  # 0..1 while blooming, -1 before or after
var _rays := -1.0  # 0..1 while drawing out and fading
var _stamp := -1.0  # 0..1 landing, 1 holding, 1..2 wiping out; -1 before or after


## Starts a ceremony on p_view on layer, in colour (its card's plane), with a tag reading tag ("" for none).
static func play(p_view: CardView, layer: Control, colour_now: Color, tag: String) -> BuildCeremony:
	var c := BuildCeremony.new()
	c.view = p_view
	c._tag = tag
	c._colour = colour_now
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	c._follow()
	if UIKit.calm():
		c._ring = 1.0
		c._rays = 0.5  # drawn out, before any fade
		c._stamp = 1.0 if tag != "" else -1.0
		c.get_tree().create_timer(Anim.BUILD_CALM_HOLD).timeout.connect(c.queue_free)
		return c
	var t := c.create_tween()
	t.tween_interval(Anim.BUILD_DELAY)
	t.tween_method(func(v: float): c._ring = v, 0.0, 1.0, Anim.BUILD_RING_TIME) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(func(v: float): c._rays = v, 0.0, 1.0, Anim.BUILD_RAYS_TIME)
	t.tween_callback(func(): c._ring = -1.0; c._rays = -1.0)
	if tag != "":
		var s := c.create_tween()
		s.tween_interval(Anim.BUILD_DELAY + Anim.BUILD_TAG_DELAY)
		s.tween_callback(c._flap)
		s.tween_method(func(v: float): c._stamp = v, 0.0, 1.0, Anim.BUILD_TAG_IN) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		s.tween_interval(Anim.BUILD_TAG_HOLD)
		s.tween_method(func(v: float): c._stamp = v, 1.0, 2.0, Anim.BUILD_TAG_OUT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	c.get_tree().create_timer(Anim.BUILD_CEREMONY_TIME).timeout.connect(c.queue_free)
	return c


## Test hooks (357): what it shows, its word and colour, and where its parts stand now.
func parts() -> Array[String]:
	var out: Array[String] = [RING, RAYS]
	if _tag != "":
		out.append(TAG)
	return out


func tag_text() -> String:
	return _tag


func colour() -> Color:
	return _colour


## How far the ring stands off the card's edge (px).
func ring_out() -> float:
	return Tokens.SPACE_3 * maxf(_ring, 0.0)


## How long the rays are (px): drawn out in their first half.
func ray_length() -> float:
	return Tokens.SPACE_5 * minf(maxf(_rays, 0.0) * 2.0, 1.0)


## How far above its rest place the tag still is (px): it drops Tokens.SPACE_1 as it lands.
func tag_drop() -> float:
	return (1.0 - clampf(_stamp, 0.0, 1.0)) * Tokens.SPACE_1


## The ceremony's opacity now: its strongest part, the ring or the rays (each fades as it finishes).
func opacity() -> float:
	return maxf(_ring_alpha(), _rays_alpha())


## The ring fades as it blooms out.
func _ring_alpha() -> float:
	return 1.0 if UIKit.calm() else 1.0 - clampf(_ring, 0.0, 1.0)


## The rays hold while they draw out, then fade.
func _rays_alpha() -> float:
	return 1.0 if UIKit.calm() or _rays < 0.5 else 1.0 - (_rays - 0.5) * 2.0


## The tag's split-flap as it lands (guide §9.4).
func _flap() -> void:
	var sfx := Sfx.find(self)
	if sfx != null:
		sfx.play(Sfx.FLAP)


func _process(_delta: float) -> void:
	if not is_instance_valid(view):
		queue_free()
		return
	_follow()
	queue_redraw()


## Covers the card and the room around it.
func _follow() -> void:
	var r := view.get_global_rect()
	global_position = r.position - Vector2.ONE * ROOM
	size = r.size + Vector2.ONE * ROOM * 2
	z_index = 3  # over a flying card's 2


func _draw() -> void:
	var card := Rect2(Vector2.ONE * ROOM, view.size)
	if _ring >= 0.0:
		draw_rect(card.grow(ring_out() + 1.0), Color(_colour, _ring_alpha()), false, LINE_WIDTH)
	if _rays >= 0.0:
		_draw_rays(card, Color(_colour, _rays_alpha()))
	if _stamp >= 0.0:
		_draw_tag(card)


## RAY_COUNT rays from Tokens.SPACE_2 off the card's edge, ray_length() long.
func _draw_rays(card: Rect2, colour_now: Color) -> void:
	var centre := card.get_center()
	var half := card.size / 2
	for i in RAY_COUNT:
		var a := TAU * i / RAY_COUNT + PI / RAY_COUNT
		var d := Vector2(cos(a), sin(a))
		var to_edge := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
		var start := centre + d * (to_edge + Tokens.SPACE_2)
		draw_line(start, start + d * ray_length(), colour_now, LINE_WIDTH)


## The tag: its word in capitals on a signal plate at the card's top-right corner, wiping out to the right.
func _draw_tag(card: Rect2) -> void:
	var font := get_theme_font("font", "Label")
	var size_px := Tokens.TYPE_LABEL_CAPS
	var pad := Vector2(Tokens.SPACE_2, Tokens.SPACE_1)
	var box_size := font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px) + pad * 2
	var box := Rect2(Vector2(card.end.x - box_size.x + Tokens.SPACE_2, card.position.y - Tokens.SPACE_2 - tag_drop()),
		box_size)
	var shown := box
	if _stamp > 1.0:
		var gone := (_stamp - 1.0) * box.size.x
		shown = Rect2(box.position + Vector2(gone, 0), box.size - Vector2(gone, 0))
	var alpha := clampf(_stamp, 0.0, 1.0)
	var plate := Palette.ACCENT
	plate.a = alpha
	var ink := Palette.TEXT_ON_ACCENT
	ink.a = alpha
	var shadow := Palette.SHADOW
	shadow.a *= alpha
	draw_rect(Rect2(shown.position + GameTheme.PLINTH, shown.size), shadow)
	draw_rect(shown, plate)
	if _stamp <= 1.0:
		draw_string(font, box.position + Vector2(pad.x, pad.y + font.get_ascent(size_px)), _tag, HORIZONTAL_ALIGNMENT_LEFT,
			-1, size_px, ink)
