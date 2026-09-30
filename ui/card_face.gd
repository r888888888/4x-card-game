class_name CardFace
extends VBoxContainer
## The content of one card (backlog 086): title, type line with the cost on a hand card, rules, a territory's info
## line and VP, plus the gold info lines and the reason strip that CardView adds. CardView owns the panel around it,
## the tooltip and the border.

# A shape per type, so types can be told apart without colour. Drawn as icons (see Icons).
const TYPE_MARKS := {
	CardDef.ACTION: "◆",
	CardDef.BUILDING: "■",
	CardDef.CITY: "●",
	CardDef.TERRITORY: "▲",
	CardDef.TECH: "✦",
	CardDef.EVENT: "❖",
}
const STRIP_BG := Color("4a1f22")  # the reason strip at the bottom of a dimmed card
const STRIP_TEXT := Color("ffd6d1")

var rules_tip := ""  # the full card text; CardView starts every tooltip with it


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)


## Builds the content for card in color. in_hand adds the cost to the type line; compact leaves out the type line
## and rules (for frontier territories, to save height).
func build(card: CardInstance, card_db: Dictionary, in_hand: bool, compact: bool, color: Color) -> void:
	var def := card.def
	add_child(label(def.name, 22))  # the title gets the full width

	# Type line, with the cost at its right on a hand card.
	var type_row := HBoxContainer.new()
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var subtitle: String = TYPE_MARKS.get(def.type, "") + " " + def.type.capitalize()
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	var subtitle_label := rich_label(subtitle, 18, color.lightened(0.5))
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(subtitle_label)
	if in_hand:
		var cost := label(cost_text(def.cost), 19, CardView.HIGHLIGHT_COLOR)
		cost.name = "Cost"
		cost.autowrap_mode = TextServer.AUTOWRAP_OFF  # the type line wraps around it instead
		type_row.add_child(cost)
	if not compact:
		add_child(type_row)
	else:
		type_row.free()

	rules_tip = def.rules_tooltip(card_db)
	var rolled := card.keywords.slice(def.keywords.size())  # resource keywords rolled onto this copy
	var rolled_names := ", ".join(PackedStringArray(rolled.map(func(k): return k.capitalize())))
	if not rolled.is_empty():
		rules_tip += "\nResources: " + rolled_names
	var rules_text := "" if compact else def.rules_text(card_db)
	if rules_text != "":  # territories have none; an empty label would still take a line
		var rules := rich_label(rules_text, 19)
		rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(rules)

	if def.type == CardDef.TERRITORY:
		var info_label := rich_label(_territory_info(card), 18, color.lightened(0.5))  # "Hills + Gold": rolled last
		info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		add_child(info_label)

	if def.vp > 0:
		add_child(label("%d VP" % def.vp, 20, Color("ffd966")))


## Builds a settled territory's one-line title bar (087): the name, then slots, housing and keywords (printed and
## rolled), the same info a territory card shows.
func build_banner(card: CardInstance, color: Color) -> void:
	var def := card.def
	rules_tip = def.name
	var rolled := card.keywords.slice(def.keywords.size())
	if not rolled.is_empty():
		rules_tip += "\nResources: " + ", ".join(PackedStringArray(rolled.map(func(k): return k.capitalize())))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 14)
	add_child(line)
	var title := label(def.name, 21)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.add_child(title)
	var info := rich_label(_territory_info(card), 18, color.lightened(0.5))
	info.autowrap_mode = TextServer.AUTOWRAP_OFF
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.clip_contents = true
	line.add_child(info)


## A territory's info: "▢3 ⌂5 · Grassland, Fresh Water", plus " + Gold" for rolled resources.
static func _territory_info(card: CardInstance) -> String:
	var def := card.def
	var info := "▢%d ⌂%d" % [def.slots, def.housing]  # explained in the tooltip
	var names := def.keywords.map(func(k): return k.capitalize())
	if not names.is_empty():
		info += " · " + ", ".join(PackedStringArray(names))
	var rolled := card.keywords.slice(def.keywords.size())
	if not rolled.is_empty():
		info += " + " + ", ".join(PackedStringArray(rolled.map(func(k): return k.capitalize())))
	return info


## The text of every label on the face, one per line, glyphs included (for tests).
func text() -> String:
	var lines: PackedStringArray = []
	for child in find_children("*", "", true, false):
		if child is Label:
			lines.append(child.text)
		elif child is RichTextLabel:
			lines.append(child.get_meta("source", child.get_parsed_text()))
	return "\n".join(lines)


## Replaces the gold info line called label_name at the bottom of the card with text.
func replace_info(label_name: String, text: String) -> void:
	var old := get_node_or_null(label_name)
	if old != null:
		remove_child(old)
		old.queue_free()
	var info := label(text, 19, CardView.HIGHLIGHT_COLOR)
	info.name = label_name
	add_child(info)


## Sets the text of the gold info line called label_name, adding it at the bottom the first time.
func update_info(label_name: String, text: String) -> void:
	var info := get_node_or_null(label_name) as Label
	if info == null:
		info = label("", 19, CardView.HIGHLIGHT_COLOR)
		info.name = label_name
		add_child(info)
	info.text = text


## The text of the info line called label_name, or "" when there is none.
func info_text(label_name: String) -> String:
	var info := get_node_or_null(label_name) as Label
	return info.text if info != null else ""


## Shows reason in a strip at the bottom of the card, or removes the strip when reason is "".
func set_reason(reason: String) -> void:
	var strip := get_node_or_null("Reason") as PanelContainer
	if reason == "":
		if strip != null:
			remove_child(strip)
			strip.queue_free()
		return
	if strip == null:
		strip = PanelContainer.new()
		strip.name = "Reason"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = STRIP_BG
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		strip.add_theme_stylebox_override("panel", style)
		strip.add_child(rich_label("", 18, STRIP_TEXT))
		add_child(strip)
	Icons.fill(strip.get_child(0) as RichTextLabel, reason, 18, STRIP_TEXT)


## A cost as text: "2 food, 1 wealth", or "Free".
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		if cost[r] > 0:
			parts.append("%d %s" % [cost[r], r])
	return "Free" if parts.is_empty() else ", ".join(parts)


## A card label. It wraps, so long text makes the card taller rather than wider than its slot.
static func label(text: String, font_size: int, color := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A card label for text that can hold glyphs (see Icons), which it draws as icons. Like label it
## wraps and never takes mouse input. One line is exactly as tall as a Label's; wrapped lines sit 3px
## closer (a RichTextLabel adds its line_separation after the last line too, so it can't match both).
static func rich_label(text: String, font_size: int, color := Color.WHITE) -> RichTextLabel:
	var result := RichTextLabel.new()
	result.fit_content = true
	result.scroll_active = false
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("normal_font_size", font_size)
	result.add_theme_color_override("default_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.set_meta("source", text)  # the text with its glyphs, which are drawn as icons (see text())
	Icons.fill(result, text, font_size, color)
	return result
