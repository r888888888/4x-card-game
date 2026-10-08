class_name CardArt
extends Control
## A card's art plate (381), under the type band on a hand-size face: the picture at art_dir/<card id>.png when one
## has been imported, cropped to fill the plate from its centre; until then a placeholder printed in the card type's
## plane colour with one of four period motifs, picked by the id so a card keeps its motif. Palette.ART_SHADE lies
## over it (Night dims the print, as it darkens the card's paper), and a 1 px EDGE rule frames it (§4.3). A dimmed
## card's plate follows its band: the placeholder prints in DIM_BORDER, a picture goes under a veil of DIM_BG.

const ART_DIR := "res://assets/cards/"
const HAND_HEIGHT := 135.0  # px on a hand-size card (264 × 360): a 16:9 view of 84 % of the art's height (402)
const RULE := 1.0  # the frame's rule
const DIM_VEIL := 0.6  # the DIM_BG veil's alpha over a dimmed card's picture
enum Motif {SUN, RINGS, SPLIT_DISC, STEPS}

static var art_dir := ART_DIR  # where pictures are read from; tests point it at a fixture

var card_id := ""
var _type_color := Color.GRAY
var _dimmed := false
var _texture: Texture2D
var _shade := Color.TRANSPARENT
var _frame := Color.TRANSPARENT


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	custom_minimum_size.y = HAND_HEIGHT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Shows the art for id, in the type's plane colour while it is a placeholder, in the palette's current mode.
func setup(id: String, color: Color) -> void:
	card_id = id
	_type_color = color
	_shade = Palette.ART_SHADE
	_frame = Palette.EDGE
	var path := file_for(id)
	_texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
	queue_redraw()


## Dims the plate with its card (CardView's unplayable look), or undoes it.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	queue_redraw()


## The file a card's picture is read from: <art_dir><id>.png.
static func file_for(id: String) -> String:
	return art_dir + id + ".png"


## The card's placeholder motif (a Motif): the same for an id every call and every run.
static func motif_for(id: String) -> int:
	return absi(id.hash()) % Motif.size()


## The region of a texture of tex_size drawn into a plate of rect_size: scaled to cover it, centred, the overflow
## cropped (a 3:2 picture in the 16:9 hand plate shows its middle 84 %).
static func cover_region(tex_size: Vector2, rect_size: Vector2) -> Rect2:
	var shown := rect_size / maxf(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	return Rect2((tex_size - shown) / 2.0, shown)


## True when the card has a picture rather than the placeholder.
func has_picture() -> bool:
	return _texture != null


## The placeholder's plane colour: the type's, or DIM_BORDER while dimmed.
func color() -> Color:
	return Palette.DIM_BORDER if _dimmed else _type_color


## The veil over a dimmed card's picture; clear on a placeholder or a playable card.
func veil() -> Color:
	return Color(Palette.DIM_BG, DIM_VEIL if _dimmed and has_picture() else 0.0)


## The shade laid over the plate (Palette.ART_SHADE when set up).
func shade() -> Color:
	return _shade


## The frame's colour (Palette.EDGE when set up).
func frame() -> Color:
	return _frame


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _texture != null:
		draw_texture_rect_region(_texture, rect, cover_region(_texture.get_size(), rect.size))
		draw_rect(rect, veil())
	else:
		_draw_placeholder(rect)
	draw_rect(rect, _shade)
	draw_rect(rect.grow(-RULE / 2.0), _frame, false, RULE)  # inside the rect, so the clip keeps all of it


## A flat plate: the plane colour, and a darker and a lighter ink of it for the motif.
func _draw_placeholder(rect: Rect2) -> void:
	var plane := color()
	var dark := plane.darkened(0.45)
	var light := plane.lightened(0.45)
	draw_rect(rect, plane)
	var w := rect.size.x
	var h := rect.size.y
	match motif_for(card_id):
		Motif.SUN:  # a sun over a horizon
			draw_circle(Vector2(w * 0.68, h * 0.62), h * 0.36, light)
			draw_rect(Rect2(0, h * 0.62, w, h * 0.38), dark)
			draw_rect(Rect2(0, h * 0.62, w, RULE * 2), _frame)
		Motif.RINGS:  # concentric rings, off centre
			var centre := Vector2(w * 0.3, h * 0.55)
			for i in 3:
				draw_arc(centre, h * (0.12 + 0.12 * i), 0, TAU, 48, dark if i % 2 == 0 else light, h * 0.06)
		Motif.SPLIT_DISC:  # a disc, its left half dark
			var centre := Vector2(w * 0.5, h * 0.5)
			var radius := h * 0.38
			draw_circle(centre, radius, light)
			var half := PackedVector2Array()
			for i in 25:
				half.append(centre + Vector2.from_angle(PI / 2 + PI * i / 24.0) * radius)
			draw_colored_polygon(half, dark)
		Motif.STEPS:  # a stepped mound on the ground
			for i in 4:
				var step_w := w * (0.56 - 0.12 * i)
				draw_rect(Rect2(w * 0.5 - step_w / 2, h * (0.82 - 0.17 * i), step_w, h * 0.17),
					dark if i % 2 == 0 else light)
			draw_rect(Rect2(0, h * 0.82, w, h * 0.18), dark)
