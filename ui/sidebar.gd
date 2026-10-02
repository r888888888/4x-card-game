class_name Sidebar
extends PanelContainer
## The board's right rail (backlog 202, the mock's .rail): under a rule, a "Civilization" heading, the civilization's
## name and its government as a link ("Chiefdom ›"), each opening the civilization modal. A name with no card is
## hidden. End turn sits at its foot (203).

const WIDTH := Tokens.SPACE_9 * 3

var heading: Label
var name_button: Button  # the civilization's name
var government_button: Button  # "Chiefdom ›"
var column: VBoxContainer  # the rail's contents, top to bottom


## Builds the rail; on_open opens the civilization modal.
func _init(on_open: Callable) -> void:
	theme_type_variation = &"DarkPanel"
	custom_minimum_size.x = WIDTH
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", Tokens.SPACE_2)
	add_child(column)
	var rule := ColorRect.new()
	rule.name = "Rule"
	rule.custom_minimum_size.y = 2
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.painted(rule, func(): rule.color = Palette.TEXT)
	column.add_child(rule)
	heading = UIKit.heading("Civilization")
	column.add_child(heading)
	name_button = UIKit.button("", on_open)
	name_button.theme_type_variation = &"TitleLink"
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.tooltip_text = "Your civilization and government."
	column.add_child(name_button)
	government_button = UIKit.button("", on_open)
	government_button.theme_type_variation = &"Link"
	government_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	government_button.tooltip_text = "Your government: what it allows, and the government deck."
	column.add_child(government_button)
	name_button.focus_next = name_button.get_path_to(government_button)
	government_button.focus_previous = government_button.get_path_to(name_button)


## Shows engine e's civilization and government; a missing one's control is hidden.
func refresh(e: GameEngine) -> void:
	var civ := e.zone("civilization")
	name_button.text = civ.cards[0].def.name if not civ.is_empty() else ""
	name_button.visible = not civ.is_empty()
	var gov := e.zone("government")
	government_button.text = (gov.cards[0].def.name + " ›") if not gov.is_empty() else ""
	government_button.visible = not gov.is_empty()


## Where a card leaving for the government flies to (the government a player just played).
func government_point() -> Vector2:
	return government_button.get_global_rect().get_center()
