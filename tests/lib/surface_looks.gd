extends RefCounted
## What a textured surface shows (341): the mean colour of a surface's texture, and the means the item's criteria
## expect in the current mode: walnut grain under a Palette colour, a card's paper (Night paper: dark gray paper under
## black at 30 %; Day paper: white paper as it is) and dimmed paper (paper under DIM_BG at 60 %). Tile scales are
## tuned by eye, so the checks compare means, which scaling keeps, plus whether the grain still shows.

const WALNUT := "res://assets/background/walnut.png"
const NIGHT_PAPER := "res://assets/background/dark-gray-paper.png"
const DAY_PAPER := "res://assets/background/white-paper.png"
## How far (per channel, 0..1) a drawn mean may stray from the expected one.
const TOLERANCE := 0.015
## The criteria's veils.
const GRAIN_NIGHT := 0.90
const GRAIN_DAY := 0.88
const NIGHT_SHADE := 0.30
const DIM := 0.60
const STEP := 4  # px between sampled pixels

static var _means := {}  # instance id or path -> Color


## The mean colour of tex (sampled every STEP px), cached by texture.
static func mean(tex: Texture2D) -> Color:
	var key: Variant = tex.get_instance_id()
	if not _means.has(key):
		_means[key] = _image_mean(tex.get_image())
	return _means[key]


## The mean colour of the image at path.
static func source_mean(path: String) -> Color:
	if not _means.has(path):
		_means[path] = _image_mean((load(path) as Texture2D).get_image())
	return _means[path]


static func _image_mean(image: Image) -> Color:
	var sum := Vector3.ZERO
	var n := 0
	for y in range(0, image.get_height(), STEP):
		for x in range(0, image.get_width(), STEP):
			var c := image.get_pixel(x, y)
			sum += Vector3(c.r, c.g, c.b)
			n += 1
	sum /= n
	return Color(sum.x, sum.y, sum.z)


## base with veil laid over it at alpha a.
static func over(base: Color, veil: Color, a: float) -> Color:
	return Color(base.lerp(veil, a), 1.0)


## Walnut grain under c at the mode's opacity (90 % Night, 88 % Day).
static func grain(c: Color) -> Color:
	return over(source_mean(WALNUT), c, GRAIN_DAY if Palette.day else GRAIN_NIGHT)


## The mode's paper.
static func paper() -> Color:
	return source_mean(DAY_PAPER) if Palette.day else over(source_mean(NIGHT_PAPER), Color.BLACK, NIGHT_SHADE)


## The mode's paper under DIM_BG at 60 %.
static func dimmed_paper() -> Color:
	return over(paper(), Palette.DIM_BG, DIM)


## box's texture (a surface's "texture" property), or null.
static func texture_of(box: StyleBox) -> Texture2D:
	if box == null or not "texture" in box:
		return null
	return box.get("texture") as Texture2D


## box's rule and shadow (a surface's "frame"), or null.
static func frame_of(box: StyleBox) -> StyleBoxFlat:
	if box == null or not "frame" in box:
		return null
	return box.get("frame") as StyleBoxFlat


## Why box doesn't show a surface whose mean is expected ("" when it does): it has a texture, its mean is within
## TOLERANCE, and its grain shows (it isn't one flat colour).
static func mismatch(box: StyleBox, expected: Color) -> String:
	var tex := texture_of(box)
	if tex == null:
		return "no texture (%s)" % box
	var m := mean(tex)
	for i in 3:
		if absf(m[i] - expected[i]) > TOLERANCE:
			return "mean %s, expected %s" % [m.to_html(false), expected.to_html(false)]
	var image := tex.get_image()
	var lo := 1.0
	var hi := 0.0
	for i in 64:
		var v := image.get_pixel(i * 37 % image.get_width(), i * 53 % image.get_height()).get_luminance()
		lo = minf(lo, v)
		hi = maxf(hi, v)
	if hi - lo < 0.004:
		return "flat: no grain shows"
	return ""


## WCAG relative luminance of c.
static func luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


## WCAG contrast ratio of a on b.
static func contrast(a: Color, b: Color) -> float:
	var la := luminance(a)
	var lb := luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
