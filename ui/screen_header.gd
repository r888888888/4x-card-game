class_name ScreenHeader
extends HBoxContainer
## The header every navigated screen carries (backlog 104): a back button naming the screen below ("← Realm") and a
## breadcrumb naming where you are ("Realm › River Meadow"), both from its Navigator's titles. At the root it shows
## just the root's title. It follows the navigator, except while its own screen is on its way out.

var back_button: Button

var _nav: Navigator
var _breadcrumb: Label


## A header for a screen on nav. on_back runs when the back button is pressed (default: nav.back()).
func _init(nav: Navigator, on_back := Callable()) -> void:
	_nav = nav
	add_theme_constant_override("separation", 16)
	back_button = UIKit.button("", func(): on_back.call() if on_back.is_valid() else nav.back())
	add_child(back_button)
	_breadcrumb = UIKit.title("")
	add_child(_breadcrumb)
	nav.changed.connect(_follow)
	_follow()


func breadcrumb_text() -> String:
	return _breadcrumb.text


func _follow() -> void:
	var node: Node = self
	while node != null:  # a screen on its way out keeps the header it had
		if node.get_meta(Navigator.LEAVING, false):
			return
		node = node.get_parent()
	var titles := _nav.titles()
	back_button.visible = titles.size() > 1
	if back_button.visible:
		back_button.text = "← " + titles[-2]
	_breadcrumb.text = " › ".join(PackedStringArray(titles))
