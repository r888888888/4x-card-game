class_name Surfaces
extends RefCounted
## Wood and paper under the Palette's colours (341, the texture spike's option G): walnut grain under the board, the
## Rail and the Strip; paper under every card, Sheet and DarkPanel, on soft shadows. Each mode's textures are baked
## once (the source tiled at its drawn size, with the Palette colour laid over it) and cached; a Day mode switch reads
## the other mode's. The UI asks for a SurfaceBox here and keeps asking the theme and UIKit.painted as before.

const WALNUT := preload("res://assets/background/walnut.png")
const NIGHT_PAPER := preload("res://assets/background/dark-gray-paper.png")
const DAY_PAPER := preload("res://assets/background/white-paper.png")
const GRAIN_TILE := 960  # px a walnut tile is drawn at (×0.77, the mock's scale at 1920 × 1080)
const PAPER_TILE := 700  # px a paper tile is drawn at (×0.56)
## How much of the colour covers the grain: Night, Day.
const GRAIN_VEIL := {false: 0.90, true: 0.88}
const DIM_VEIL := 0.60  # DIM_BG over a dimmed card's paper

## The surfaces: the board (and the Rail), the Strip, a card's or a sheet's paper, a dimmed card's.
const BOARD := &"board"
const STRIP := &"strip"
const PAPER := &"paper"
const DIMMED_PAPER := &"dimmed_paper"

## Soft shadows, straight down: [offset, size, Night alpha, Day alpha].
const CARD_REST := [Vector2(0, 4), 8, 0.35, 0.20]
const CARD_HOVER := [Vector2(0, 8), 16, 0.45, 0.28]
const CARD_DRAG := [Vector2(0, 14), 24, 0.50, 0.32]
const SHEET := [Vector2(0, 16), 32, 0.55, 0.35]

static var _baked := {}  # "<surface>/<day>" -> ImageTexture


## The texture of surface in the current mode.
static func texture(surface: StringName) -> Texture2D:
	var key := "%s/%s" % [surface, Palette.day]
	if not _baked.has(key):
		var image := _bake(surface)
		image.convert(Image.FORMAT_RGB8)  # opaque: a screen sliding under the Rail stays hidden (224)
		_baked[key] = ImageTexture.create_from_image(image)
	return _baked[key]


static func _bake(surface: StringName) -> Image:
	match surface:
		BOARD:
			return _veiled(_tile(WALNUT, GRAIN_TILE), Palette.BACKGROUND, GRAIN_VEIL[Palette.day])
		STRIP:
			return _veiled(_tile(WALNUT, GRAIN_TILE), Palette.RAISED, GRAIN_VEIL[Palette.day])
		DIMMED_PAPER:
			return _veiled(_bake(PAPER), Palette.DIM_BG, DIM_VEIL)
	var paper := _tile(DAY_PAPER if Palette.day else NIGHT_PAPER, PAPER_TILE)
	return _veiled(paper, Palette.PAPER_SHADE, 1.0)


## source as an RGBA image size px square.
static func _tile(source: Texture2D, size: int) -> Image:
	var image := source.get_image().duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return image


## image with color laid over it at alpha (times the colour's own).
static func _veiled(image: Image, color: Color, alpha: float) -> Image:
	var veil := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	veil.fill(Color(color, color.a * alpha))
	image.blend_rect(veil, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	return image


## A box of surface inside frame's rule. The frame keeps its fill (the paper covers it): a StyleBoxFlat with no fill
## draws its shadow as a ring that starts a few px out, leaving a pale gap under the rule.
static func box(surface: StringName, frame: StyleBoxFlat) -> SurfaceBox:
	return SurfaceBox.new(frame, texture(surface))


## The board's grain, as a box at origin on screen (the Rail's, beside the board) whose rule is frame (none by default).
static func board(origin := Vector2.ZERO, frame: StyleBoxFlat = null) -> SurfaceBox:
	if frame == null:
		frame = StyleBoxFlat.new()
	var surface := box(BOARD, frame)
	surface.origin = origin
	return surface


## A sheet: paper in a 2 px rule of border, cut square, padded SPACE_5, on the soft sheet shadow (a Modal's Sheet,
## a UIKit.overlay's DarkPanel).
static func sheet(border: Color) -> SurfaceBox:
	var frame := UIKit.panel_style(Palette.RAISED, border, Tokens.SPACE_5)
	frame.set_border_width_all(2)
	lift(frame, SHEET)
	return box(PAPER, frame)


## Puts frame on the soft shadow look (CARD_REST, …, SHEET) in the current mode.
static func lift(frame: StyleBoxFlat, look: Array) -> void:
	frame.shadow_color = Color(Palette.SHADOW, look[3] if Palette.day else look[2])
	frame.shadow_offset = look[0]
	frame.shadow_size = look[1]
	frame.anti_aliasing = true
