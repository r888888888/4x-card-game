class_name SurfaceBox
extends StyleBox
## A surface printed on a texture (341): frame (a StyleBoxFlat: the rule, and the shadow under it) drawn first, then
## texture tiled at its own size inside the rule. A StyleBoxFlat draws no texture and a StyleBoxTexture no shadow, so
## a card or a sheet needs both. origin is where the box sits on screen: tiles start from the screen's origin, so two
## boxes of one texture side by side (the board and the Rail) show one continuous grain. With no texture the frame
## draws alone, its own fill included (a frontier card).

var texture: Texture2D:
	set(value):
		texture = value
		emit_changed()
var origin := Vector2.ZERO:
	set(value):
		origin = value
		emit_changed()
var frame: StyleBoxFlat:
	set(value):
		if frame != null and frame.changed.is_connected(emit_changed):
			frame.changed.disconnect(emit_changed)
		frame = value
		if frame != null:
			frame.changed.connect(emit_changed)
		emit_changed()


## A box drawing p_frame with p_texture inside its rule; it takes the frame's content margins.
func _init(p_frame: StyleBoxFlat = null, p_texture: Texture2D = null) -> void:
	frame = p_frame if p_frame != null else StyleBoxFlat.new()
	texture = p_texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_content_margin(side, frame.get_margin(side))


## The pixel of texture that the box's local point local shows.
func source_at(local: Vector2) -> Vector2:
	var tile := texture.get_size()
	return Vector2(fposmod(local.x + origin.x, tile.x), fposmod(local.y + origin.y, tile.y))


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	frame.draw(to_canvas_item, rect)
	if texture == null:
		return
	var inner := rect.grow_individual(-frame.border_width_left, -frame.border_width_top, -frame.border_width_right,
		-frame.border_width_bottom)
	var tile := texture.get_size()
	var y := inner.position.y
	while y < inner.end.y:
		var height := minf(tile.y - source_at(Vector2(0, y)).y, inner.end.y - y)
		var x := inner.position.x
		while x < inner.end.x:
			var source := source_at(Vector2(x, y))
			var width := minf(tile.x - source.x, inner.end.x - x)
			RenderingServer.canvas_item_add_texture_rect_region(to_canvas_item, Rect2(x, y, width, height),
				texture.get_rid(), Rect2(source, Vector2(width, height)))
			x += width
		y += height
