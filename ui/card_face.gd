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
# The badge naming what a board card is (138); a Realm card has none.
const BADGES := {
	CardView.BOARD_FRONTIER: TYPE_MARKS[CardDef.TERRITORY] + " Frontier · unsettled",
	CardView.BOARD_EVENT: TYPE_MARKS[CardDef.EVENT] + " Event",
}
const BAND := 5.0  # the type band's height, under the name (179)

var rules_tip := ""  # the full card text; CardView starts every tooltip with it
var board := false  # a board face (build_board, 138): one line per field, the rest in the details


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", Tokens.SPACE_2)


## Builds the content for card in color. in_hand adds the cost at the right of the name (180).
func build(card: CardInstance, card_db: Dictionary, in_hand: bool, color: Color) -> void:
	var def := card.def
	var title_row := HBoxContainer.new()
	title_row.name = "TitleRow"
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := title_label(def.name)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	if in_hand:
		var e := Game.engine
		var now: Dictionary = e.play_cost(card.uid) if e != null else {}  # after discounts (108)
		title_row.add_child(cost_glyphs(now if not now.is_empty() else def.cost))
	add_child(title_row)
	if in_hand and Game.engine != null:
		show_shortfall(Game.engine.play_shortfall(card.uid))
	_add_band(color)

	var type_row := HBoxContainer.new()
	type_row.name = "TypeRow"
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var subtitle: String = TYPE_MARKS.get(def.type, "") + " " + def.type.capitalize()
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	var subtitle_label := rich_label(subtitle, Tokens.TYPE_BODY_S, Palette.TEXT_DIM)
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(subtitle_label)
	add_child(type_row)

	_set_rules_tip(card, card_db)
	var rules_text := def.rules_text(card_db)
	if rules_text != "":  # territories have none; an empty label would still take a line
		var rules := rich_label(rules_text, Tokens.TYPE_BODY)
		rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(rules)

	if def.type == CardDef.TERRITORY:
		var info_label := rich_label(territory_info(card), Tokens.TYPE_BODY_S, Palette.TEXT_DIM)  # "Hills + Gold": rolled last
		info_label.name = "PrintedInfo"
		info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		add_child(info_label)

	if def.vp > 0:
		add_child(label("%d VP" % def.vp, Tokens.TYPE_BODY, Palette.GAIN))


## Builds the fixed-height face of a card in the Realm's row (138) for kind (CardView.BOARD_*), in color. A frontier
## territory or an event starts with a badge naming what it is (an event's turns left go beside it, set_event_info);
## then the name, and one line: a territory's keywords (a frontier one adds its printed slots and housing; a settled
## one gets its live line from show_settled), any other card the first line of its rules other than how long it lasts.
## Every line is clipped to the card's width; the details hold the rest.
func build_board(card: CardInstance, card_db: Dictionary, kind: String, color: Color) -> void:
	board = true
	var def := card.def
	if kind != CardView.BOARD_REALM:
		var badge_row := HBoxContainer.new()
		badge_row.name = "BadgeRow"
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_child(badge(BADGES[kind], color))
		add_child(badge_row)
	add_child(one_line(title_label(def.name)))
	if kind != CardView.BOARD_FRONTIER:  # an unsettled territory keeps its hatching and dashed border instead
		_add_band(color)
	_set_rules_tip(card, card_db)
	if def.type == CardDef.TERRITORY:
		if kind == CardView.BOARD_FRONTIER:
			var keywords := keyword_line(card)
			if keywords != "":
				var keyword_label := one_line(label(keywords, Tokens.TYPE_BODY_S, Palette.TEXT_DIM))
				keyword_label.name = "Keywords"
				add_child(keyword_label)
			var printed := rich_label("▢%d ⌂%d" % [def.slots, def.housing], Tokens.TYPE_BODY, Palette.TEXT_DIM)
			printed.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
			printed.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			add_child(printed)
		return
	var rules := Array(def.rules_text(card_db).split("\n")).filter(func(line: String):
		return line != "" and line != def.lasts_text())
	if not rules.is_empty():
		add_child(one_line(rich_label(rules[0], Tokens.TYPE_BODY_S)))
	if def.vp > 0:
		add_child(label("%d VP" % def.vp, Tokens.TYPE_NUMERAL_S, Palette.GAIN))


## The card's type as a BAND px strip of color under its name (179).
func _add_band(color: Color) -> void:
	var band := ColorRect.new()
	band.name = "Band"
	band.color = color
	band.custom_minimum_size.y = BAND
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)


## Recolours the type band (a dimmed card's is CardView.DIM_BORDER); nothing on a card without one.
func set_band_color(color: Color) -> void:
	var band := get_node_or_null("Band") as ColorRect
	if band != null:
		band.color = color


## A small pill in color naming what a board card is (138).
static func badge(text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = "Badge"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(Tokens.RADIUS_2)  # a badge
	style.content_margin_left = Tokens.SPACE_2
	style.content_margin_right = Tokens.SPACE_2
	style.content_margin_top = Tokens.SPACE_0
	style.content_margin_bottom = Tokens.SPACE_0
	pill.add_theme_stylebox_override("panel", style)
	var text_label := rich_label(text, Tokens.TYPE_LABEL_CAPS, Palette.TEXT_ON_ACCENT)
	text_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	pill.add_child(text_label)
	return pill


## Clips control (a card label) to one line: an ellipsis on a Label, a clip on a RichTextLabel (138).
static func one_line(control: Control) -> Control:
	if control is Label:
		control.autowrap_mode = TextServer.AUTOWRAP_OFF
		control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	elif control is RichTextLabel:
		control.fit_content = false
		control.clip_contents = true
		control.custom_minimum_size.y = control.get_theme_font_size("normal_font_size") + 8
	return control


## rules_tip: the card's full text, plus the resources rolled onto this copy.
func _set_rules_tip(card: CardInstance, card_db: Dictionary) -> void:
	rules_tip = card.def.rules_tooltip(card_db)
	var rolled := card.keywords.slice(card.def.keywords.size())  # resource keywords rolled onto this copy
	if not rolled.is_empty():
		rules_tip += "\nResources: " + ", ".join(PackedStringArray(rolled.map(func(k): return k.capitalize())))


## Turns a territory's face into a settled one's (123): its name, then keywords (its keyword line, "" for none),
## then live (the "▢ 6   ⌂ 2/5   ⚒ 2" line, drawn with icons) at the bottom. The type line and printed info go.
func show_settled(keywords: String, live: String) -> void:
	for gone in ["TypeRow", "PrintedInfo"]:
		var node := get_node_or_null(gone)
		if node != null:
			remove_child(node)
			node.free()
	var keyword_line := get_node_or_null("Keywords") as Label
	if keyword_line == null:
		keyword_line = label("", Tokens.TYPE_BODY_S, Palette.TEXT_DIM)
		if board:
			one_line(keyword_line)
		keyword_line.name = "Keywords"
		add_child(keyword_line)
		move_child(keyword_line, 1)  # under the name
	keyword_line.text = keywords
	keyword_line.visible = keywords != ""
	var line := get_node_or_null("LiveInfo") as RichTextLabel
	if line == null:
		line = rich_label("", Tokens.TYPE_BODY, CardView.HIGHLIGHT_COLOR)
		line.name = "LiveInfo"
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
		line.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		add_child(line)
	if line.get_meta("source", "") != live:
		line.set_meta("source", live)
		Icons.fill(line, live, Tokens.TYPE_BODY, CardView.HIGHLIGHT_COLOR)


## A settled territory's keyword line: "Grassland · Fresh Water", plus " + Gold" for rolled resources (123).
static func keyword_line(card: CardInstance) -> String:
	var names := card.def.keywords.map(func(k): return k.capitalize())
	var text := " · ".join(PackedStringArray(names))
	var rolled := card.keywords.slice(card.def.keywords.size())
	if not rolled.is_empty():
		text += (" + " if text != "" else "") + ", ".join(PackedStringArray(rolled.map(func(k): return k.capitalize())))
	return text


## A territory's info: "▢3 ⌂5 · Grassland, Fresh Water", plus " + Gold" for rolled resources.
static func territory_info(card: CardInstance) -> String:
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
		if child is CanvasItem and not child.visible:  # e.g. a settled territory's empty keyword line
			continue
		if child is Label:
			lines.append(child.text)
		elif child is RichTextLabel:
			lines.append(child.get_meta("source", child.get_parsed_text()))
	return "\n".join(lines)


## Replaces the gold info line called label_name at the bottom of the card with text.
func replace_info(label_name: String, text: String) -> void:
	var old := find_child(label_name, true, false)
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	var info := label(text, Tokens.TYPE_BODY, CardView.HIGHLIGHT_COLOR)
	info.name = label_name
	var badge_row := get_node_or_null("BadgeRow")
	if badge_row != null:  # a board card's info (an event's turns left) sits beside its badge (138)
		info.add_theme_font_size_override("font_size", Tokens.TYPE_BODY_S)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge_row.add_child(info)
		return
	add_child(info)


## Sets the text of the gold info line called label_name, adding it at the bottom the first time.
func update_info(label_name: String, text: String) -> void:
	var info := get_node_or_null(label_name) as Label
	if info == null:
		info = label("", Tokens.TYPE_BODY, CardView.HIGHLIGHT_COLOR)
		info.name = label_name
		add_child(info)
	info.text = text


## The text of the info line called label_name, or "" when there is none.
func info_text(label_name: String) -> String:
	var info := find_child(label_name, true, false) as Label
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
		style.bg_color = Palette.STRIP_BG  # the reason strip at the bottom of a dimmed card
		style.set_corner_radius_all(Tokens.RADIUS_0)
		style.set_content_margin_all(Tokens.SPACE_2)
		strip.add_theme_stylebox_override("panel", style)
		strip.add_child(rich_label("", Tokens.TYPE_BODY_S, Palette.STRIP_TEXT))
		add_child(strip)
	Icons.fill(strip.get_child(0) as RichTextLabel, reason, Tokens.TYPE_BODY_S, Palette.STRIP_TEXT)


## A hand card's cost (180) as a row named Cost: per resource above 0, food, wealth and insight first, an entry
## named for the resource holding its glyph (20 px) and figure 3 px apart, entries 12 px apart, no box; any other
## resource reads "N name". Empty for a free card.
static func cost_glyphs(cost: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Cost"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.SPACE_3)
	var order: Array = [GameEngine.FOOD, GameEngine.WEALTH, GameEngine.INSIGHT]
	order.append_array(cost.keys().filter(func(r): return not order.has(r)))
	for r: String in order:
		if cost.get(r, 0) <= 0:
			continue
		var entry := HBoxContainer.new()
		entry.name = r
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_theme_constant_override("separation", Tokens.GLYPH_GAP)
		var glyphed := Icons.RESOURCES.has(r)
		if glyphed:
			var glyph := Icons.glyph(r, 20)
			glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			entry.add_child(glyph)
		var figure := label(str(cost[r]) if glyphed else "%d %s" % [cost[r], r], Tokens.TYPE_BODY)
		figure.autowrap_mode = TextServer.AUTOWRAP_OFF
		entry.add_child(figure)
		row.add_child(entry)
	return row


## Colours each cost figure (cost_glyphs) WARN for a resource in short (GameEngine.play_shortfall), else TEXT.
func show_shortfall(short: Array[String]) -> void:
	var row := find_child("Cost", true, false)
	if row == null:
		return
	for entry in row.get_children():
		var figure := entry.get_child(entry.get_child_count() - 1) as Label
		figure.add_theme_color_override("font_color", Palette.WARN if short.has(String(entry.name)) else Palette.TEXT)


## A cost as text: "2 food, 1 wealth", or "Free" (the details, Relieve famine, Restore order).
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		if cost[r] > 0:
			parts.append("%d %s" % [cost[r], r])
	return "Free" if parts.is_empty() else ", ".join(parts)


## A card label. It wraps, so long text makes the card taller rather than wider than its slot.
static func label(text: String, font_size: int, color := Palette.TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A card's name (198): a wrapping label in the CardTitle variation (the semibold label face at body size).
static func title_label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	result.theme_type_variation = &"CardTitle"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


## A card label for text that can hold glyphs (see Icons), which it draws as icons. Like label it
## wraps and never takes mouse input. One line is exactly as tall as a Label's; wrapped lines sit 3px
## closer (a RichTextLabel adds its line_separation after the last line too, so it can't match both).
static func rich_label(text: String, font_size: int, color := Palette.TEXT) -> RichTextLabel:
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
