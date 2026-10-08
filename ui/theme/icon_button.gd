extends RefCounted
## IconButton, a Button whose icon (Grow's food, 227) is sized to sit beside its text.


static func apply(t: Theme) -> void:
	t.set_type_variation("IconButton", "Button")
	t.set_constant("icon_max_width", "IconButton", 20)
