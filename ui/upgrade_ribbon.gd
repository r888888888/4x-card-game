class_name UpgradeRibbon
extends PanelContainer
## One upgrade on its base's card (302, design A): a strip along the card's foot under a hairline, the upgrade's name in
## semibold and what it adds. A fallen-back one is hatched like an idle floor, with the ochre idle lamp and the reason
## under its name (guide §11.6).

const LAMP := Tokens.SPACE_2  # px across: the idle lamp
const HATCH_STEP := CardView.HATCH_STEP

var fallen := false


## A ribbon for upgrade name adding rules; reason "" while it works, else why it has fallen back.
func _init(upgrade_name: String, rules: String, reason: String) -> void:
	fallen = reason != ""
	theme_type_variation = &"Ribbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # the hatching stays inside
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", Tokens.SPACE_0)
	add_child(column)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", Tokens.SPACE_2)
	column.add_child(line)
	if fallen:
		var lamp := Panel.new()
		lamp.custom_minimum_size = Vector2(LAMP, LAMP)
		lamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(Tokens.RADIUS_FULL)
		UIKit.painted(lamp, func(): style.bg_color = Palette.WEALTH)  # ochre: the idle lamp
		lamp.add_theme_stylebox_override("panel", style)
		line.add_child(lamp)
	var name_label := Label.new()
	name_label.text = upgrade_name
	name_label.theme_type_variation = &"RibbonName"
	line.add_child(name_label)
	if rules != "":
		var rules_label := CardFace.rich_label(rules, Tokens.TYPE_BODY_S, Palette.TEXT_DIM)
		rules_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(rules_label)
	if fallen:
		var why := Label.new()
		why.text = reason
		why.theme_type_variation = &"Caption"
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(why)


func _draw() -> void:
	if not fallen:
		return
	var k := -size.y
	while k < size.x:
		draw_line(Vector2(k, size.y), Vector2(k + size.y, 0), Palette.HAIRLINE, 1.0)
		k += HATCH_STEP
