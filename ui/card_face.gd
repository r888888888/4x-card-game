class_name CardFace
extends VBoxContainer
## The content of one card (backlog 086): title, type line with the cost on a hand card, rules, a territory's info
## line and VP, plus the gold info lines and the reason strip that CardView adds. On a hand-size face everything under
## the band is a CardSheet: the art plate, then the text on a sheet that keeps the card's size, cutting its rules at a
## whole one (383). CardView owns the panel around it, the tooltip and the border.

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
const STAMP_TILT := -0.07  # radians: an upgrade's tier stamp, set down by hand (302)

var rules_tip := ""  # the full card text; CardView starts every tooltip with it
var board := false  # a board face (build_board, 138): one line per field, the rest in the details
var sheet: CardSheet  # a hand-size face's art and text sheet (383); null on smaller faces


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
	add_child(title_row)
	if in_hand:
		var e := Game.engine
		var now: Dictionary = e.play_cost(card.uid) if e != null else {}  # after discounts (108)
		show_cost({} if def.project else now if not now.is_empty() else def.cost)  # a wonder is paid in over turns (286)
	if in_hand and Game.engine != null:
		show_shortfall(Game.engine.play_shortfall(card.uid))
	_add_band(color)
	var into: Container = self
	if in_hand:  # a hand-size face carries the card's art plate under its band (381), its text on a sheet (383)
		var art := CardArt.new()
		art.name = "Art"
		art.setup(def.id, color)
		add_child(art)
		sheet = CardSheet.new(art)
		add_child(sheet)
		into = sheet.body

	var type_row := HBoxContainer.new()
	type_row.name = "TypeRow"
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := Game.engine
	var base_name := e.upgrade_base_name(def.id) if e != null else ""  # an upgrade's face names its base (302)
	var subtitle: String = TYPE_MARKS.get(def.type, "") + " " + (def.type.capitalize() if base_name == "" else
		"Upgrade · " + base_name)
	var shown_tags := def.tags.filter(func(t): return t != def.type)
	if not shown_tags.is_empty():
		subtitle += " · " + ", ".join(PackedStringArray(shown_tags))
	var subtitle_label := rich_label(subtitle, Tokens.TYPE_BODY_S, Palette.TEXT_DIM)
	subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_row.add_child(subtitle_label)
	into.add_child(type_row)

	_set_rules_tip(card, card_db)
	var face := def.face(card_db)  # the ledger, the rules and the fine print (382)
	if not face.ledger.is_empty():
		into.add_child(_ledger(face.ledger))
	var lines := Array(face.rules)
	if base_name != "":  # an upgrade adds: each line led by "Also" (302)
		lines = lines.map(func(line: String): return "Also " + line)
	if not lines.is_empty() and sheet != null:
		sheet.add_rules(PackedStringArray(lines))
	elif not lines.is_empty():  # territories have none; an empty label would still take a line
		var rules := rich_label("\n".join(PackedStringArray(lines)), Tokens.TYPE_BODY)
		rules.name = "Rules"
		rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(rules)

	if def.type == CardDef.TERRITORY:
		var info_label := rich_label(territory_info(card), Tokens.TYPE_BODY_S, Palette.TEXT_DIM)  # "Hills + Gold": rolled last
		info_label.name = "PrintedInfo"
		info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL  # sits at the bottom of the card
		info_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		into.add_child(info_label)

	if in_hand and not face.fine.is_empty():  # the gates, at the foot of a hand-size face only, above the VP (382)
		_add_fine_print(face.fine, into)
	if def.vp > 0:
		into.add_child(label("%d VP" % def.vp, Tokens.TYPE_BODY, Palette.GAIN))
	var tier := e.card_tier_name(def.id) if base_name != "" else ""
	if tier != "":  # the tier an upgrade needs, as a stamp (302)
		var stamp := Label.new()
		stamp.name = "TierStamp"
		stamp.text = tier
		stamp.uppercase = true
		stamp.theme_type_variation = &"TierStamp"
		stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
		stamp.rotation = STAMP_TILT
		into.add_child(stamp)


## A two-column grid of a card's figures (382): each label in caps, then its figure.
func _ledger(rows: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = "Ledger"
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", Tokens.SPACE_3)
	grid.add_theme_constant_override("v_separation", Tokens.SPACE_0)
	for row: Array in rows:
		var name_label := Label.new()
		name_label.text = row[0]
		name_label.uppercase = true
		name_label.theme_type_variation = &"LedgerLabel"
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(name_label)
		var figure := Label.new()
		figure.text = row[1]
		figure.theme_type_variation = &"LedgerFigure"
		grid.add_child(figure)
	return grid


## The card's gates as one line of fine print under a hairline (382), added to into.
func _add_fine_print(gates: PackedStringArray, into: Container) -> void:
	var rule := ColorRect.new()
	rule.color = Palette.HAIRLINE
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(rule)
	var fine := Label.new()
	fine.name = "FinePrint"
	fine.text = " · ".join(gates)
	fine.uppercase = true
	fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fine.theme_type_variation = &"FinePrint"
	fine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	into.add_child(fine)


## Shows ribbons (UpgradeRibbon per upgrade, 302) at the foot of the card; replaces those shown.
func set_ribbons(ribbons: Array[UpgradeRibbon]) -> void:
	var old := get_node_or_null("Ribbons")
	if old != null:
		remove_child(old)
		old.queue_free()
	if ribbons.is_empty():
		return
	var foot := VBoxContainer.new()
	foot.name = "Ribbons"
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", Tokens.SPACE_0)
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END  # along the card's foot
	for ribbon in ribbons:
		foot.add_child(ribbon)
	add_child(foot)


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
	add_child(one_line(title_label(card.shown_name())))
	if kind != CardView.BOARD_FRONTIER:  # an unsettled territory keeps its hatching and dashed border instead
		_add_band(color)
	_set_rules_tip(card, card_db)
	if def.type == CardDef.TERRITORY:
		if card.shown_name() != def.name:  # a named city: its land under the name (248)
			var land := one_line(label(def.name, Tokens.TYPE_BODY_S, Palette.TEXT_DIM))
			land.name = "Land"
			add_child(land)
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
	var rules := Array(def.face(card_db).rules).filter(func(line: String):
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


## Dims the art plate and the sheet's paper with its card (381, 383); nothing on a face without them.
func set_art_dimmed(on: bool) -> void:
	if sheet != null:
		(sheet.art as CardArt).set_dimmed(on)
		sheet.set_dimmed(on)


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


## Turns a territory's face into a settled one's (123): its name, then live (the "▢ 6   ⌂ 2/5   ⚒ 2" line, drawn with
## icons) at the bottom. The type line, printed info and keywords go: the territory view shows the keywords (199).
func show_settled(live: String) -> void:
	for gone in ["TypeRow", "PrintedInfo", "Keywords"]:
		var node := get_node_or_null(gone)
		if node != null:
			remove_child(node)
			node.free()
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


## A territory's keyword line: "Grassland · Fresh Water", plus " + Gold" for rolled resources (123; a frontier card's).
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
		if not _shown(child):  # e.g. a settled territory's empty keyword line, a hidden rule, a foot not needed
			continue
		if child is Label:
			lines.append(child.text)
		elif child is RichTextLabel:
			lines.append(child.get_meta("source", child.get_parsed_text()))
	return "\n".join(lines)


## Whether node and everything above it on the face are visible.
func _shown(node: Node) -> bool:
	while node != self:
		if node is CanvasItem and not node.visible:
			return false
		node = node.get_parent()
	return true


## Shows a unit's veteran pips (388): total discs, the first filled lit in the unit colour, the rest dim; none at
## total 0. Replaces any row shown.
func set_veteran_pips(filled: int, total: int) -> void:
	var old := get_node_or_null("VeteranPips")
	if old != null:
		remove_child(old)
		old.queue_free()
	if total <= 0:
		return
	var row := HBoxContainer.new()
	row.name = "VeteranPips"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", Tokens.SPACE_1)
	for i in total:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(Tokens.SPACE_2, Tokens.SPACE_2)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var disc := StyleBoxFlat.new()
		disc.set_corner_radius_all(Tokens.RADIUS_FULL)
		pip.add_theme_stylebox_override("panel", disc)
		row.add_child(pip)
	add_child(row)
	light_veteran_pips(filled)


## Lights the first filled veteran pips and dims the rest (388); nothing without a row.
func light_veteran_pips(filled: int) -> void:
	var row := get_node_or_null("VeteranPips")
	if row == null:
		return
	var dim := Palette.UNIT
	dim.a = CardView.PIP_DIM
	for i in row.get_child_count():
		(row.get_child(i).get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Palette.UNIT if i < filled else dim


## Each veteran pip's tint, in order ([] with no row).
func veteran_pip_tints() -> Array[Color]:
	var out: Array[Color] = []
	var row := get_node_or_null("VeteranPips")
	if row != null:
		for pip in row.get_children():
			out.append((pip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color)
	return out


## Replaces the gold info line called label_name at the bottom of the card with text; "" removes it.
func replace_info(label_name: String, text: String, color: Variant = null) -> void:
	var old := find_child(label_name, true, false)
	if old != null:
		old.get_parent().remove_child(old)
		old.queue_free()
	if text == "":
		return
	var info := label(text, Tokens.TYPE_BODY, CardView.HIGHLIGHT_COLOR if color == null else color)
	info.name = label_name
	var badge_row := get_node_or_null("BadgeRow")
	if badge_row != null:  # a board card's info (an event's turns left) sits beside its badge (138)
		info.add_theme_font_size_override("font_size", Tokens.TYPE_BODY_S)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge_row.add_child(info)
		return
	add_child(info)


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


## Shows cost (cost_glyphs) at the right of the name, in place of any cost shown there before.
func show_cost(cost: Dictionary) -> void:
	var title_row := get_node("TitleRow")
	var old := title_row.get_node_or_null("Cost")
	if old != null:
		title_row.remove_child(old)
		old.queue_free()
	title_row.add_child(cost_glyphs(cost))


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

