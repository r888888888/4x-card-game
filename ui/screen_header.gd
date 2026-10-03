class_name ScreenHeader
extends PanelContainer
## The header every navigated screen carries (backlog 104): a title bar filled with the screen's colour (241), so a
## coloured bar always means you are off the Realm. Its left end is the way back (118): a divider tab, the index tab
## of the sheet underneath ("◂ Realm", the screen below's title), then the screen's title, then any context at the
## right (add_context). At the root it shows just the root's title. It follows the navigator, except while its own
## screen is on its way out.

var back_button: Button  # the divider tab, the parent's title; hidden at the root

var _nav: Navigator
var _row: HBoxContainer
var _title: Label


## A header for a screen on nav, its bar filled with the Palette colour named role. on_back runs when the back
## button is pressed (default: nav.back()).
func _init(nav: Navigator, on_back := Callable(), role := &"RAISED") -> void:
	_nav = nav
	clip_contents = true  # the tab's slanted left edge runs off the bar
	UIKit.painted(self, func():
		var bar := UIKit.panel_style(Palette.color(role), Palette.color(role), Tokens.SPACE_0)
		bar.set_border_width_all(0)
		bar.content_margin_right = Tokens.SPACE_4
		add_theme_stylebox_override("panel", bar))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", Tokens.SPACE_4)
	add_child(_row)
	back_button = UIKit.button("", func(): on_back.call() if on_back.is_valid() else nav.back())
	back_button.theme_type_variation = &"DividerTab"
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_row.add_child(back_button)
	_title = UIKit.title("")
	_title.theme_type_variation = &"BarTitle"
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_row.add_child(_title)
	nav.changed.connect(_follow)
	_follow()


## The screen's title, in the bar after the tab ("Homeland").
func title_text() -> String:
	return _title.text


## Adds context (a Label) at the bar's right end, in the bar's caps look: Knowledge's turn and era.
func add_context(context: Label) -> void:
	context.theme_type_variation = &"BarHeading"
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL | Control.SIZE_SHRINK_END
	context.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_row.add_child(context)


func _follow() -> void:
	var node: Node = self
	while node != null:  # a screen on its way out keeps the header it had
		if node.get_meta(Navigator.LEAVING, false):
			return
		node = node.get_parent()
	var titles := _nav.titles()
	back_button.visible = titles.size() > 1
	if back_button.visible:
		back_button.text = "◂ " + titles[-2]
		back_button.tooltip_text = "Back to %s" % titles[-2]
	_title.text = titles[-1] if not titles.is_empty() else ""
