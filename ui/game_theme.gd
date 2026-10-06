class_name GameTheme
extends RefCounted
## The UI's theme, built in code at startup from the Palette (backlog 106; 097: no editor-generated .tres, so it can't
## go stale). Buttons, the accent button and text fields, plus type variations for the looks the UI repeats:
## Display, Title, Heading, Body, BodySmall, Caption, Stat and BarStat labels, RichBody text, DarkPanel (an overlay's or a modal's panel),
## IconButton (227), a notification's Flag, FlagText and FlagClose (250), the selectable list's ListWell and ListRow (217), and a screen's title bar's BarTitle,
## BarHeading and DividerTab (241). A control takes one with
## theme_type_variation instead of its own overrides.

const DEFAULT_FONT_SIZE := Tokens.TYPE_BODY  # everything without a size of its own (log, buttons, inputs)
# The style guide's typefaces (178, §5): each is used through tabular(), so figures never shift width as they change.
const BODY_FONT := preload("res://assets/fonts/Barlow-Regular.ttf")
const ITALIC_FONT := preload("res://assets/fonts/Barlow-Italic.ttf")  # RichBody's [i], e.g. flavor (216)
const LABEL_FONT := preload("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")
const LABEL_SEMIBOLD := preload("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
const DISPLAY_FONT := preload("res://assets/fonts/Jost-Variable.ttf")
const PLINTH := Vector2(2, 2)  # a control's hard shadow (guide shadow.plinth)
const PRESS := 2  # px a pressed control travels into its shadow (guide travel.press)
const SELECTED_SHADOW := Vector2(4, 4)  # a selected row's hard shadow (217, guide §4.4 "Selected")
const PULL := Tokens.SPACE_2  # px a selected row is pulled out of its list (217, guide §10.5)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = tabular(BODY_FONT)
	t.default_font_size = DEFAULT_FONT_SIZE
	_controls(t)
	_label(t, "Display", Tokens.TYPE_DISPLAY, Palette.TEXT, display())
	_label(t, "DisplayXL", Tokens.TYPE_DISPLAY_XL, Palette.TEXT, display())  # the era ceremony's name (211)
	_label(t, "Title", Tokens.TYPE_TITLE, Palette.TEXT, display())
	_label(t, "Heading", Tokens.TYPE_HEADING, Palette.TEXT_DIM, heading_font())  # UIKit.heading sets the capitals
	_label(t, "Body", Tokens.TYPE_BODY, Palette.TEXT)
	_label(t, "BodySmall", Tokens.TYPE_BODY_S, Palette.TEXT)
	_label(t, "Caption", Tokens.TYPE_CAPTION, Palette.TEXT_DIM)
	_label(t, "Refusal", Tokens.TYPE_BODY_S, Palette.COST)  # why an action can't be done, beside its disabled key (259)
	_label(t, "Stat", Tokens.TYPE_NUMERAL, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # each stat also sets its own colour: what it counts
	_label(t, "CardTitle", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a card's name, bold beside its rules (198)
	_label(t, "BigLabel", Tokens.TYPE_TITLE, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # a BigButton's caps label (213)
	_label(t, "Forecast", Tokens.TYPE_NUMERAL_S, Palette.TEXT_DIM, tabular(LABEL_SEMIBOLD))  # a counter's next change (201)
	_label(t, "BarStat", Tokens.TYPE_BODY, Palette.TEXT, tabular(LABEL_SEMIBOLD))  # body size like the bar's buttons, so it fits 1920 px (144)
	t.set_type_variation("RichBody", "RichTextLabel")  # modal text and the log (194)
	for size in ["normal_font_size", "bold_font_size", "italics_font_size"]:
		t.set_font_size(size, "RichBody", Tokens.TYPE_BODY)
	t.set_font("italics_font", "RichBody", tabular(ITALIC_FONT))
	t.set_font("bold_font", "RichBody", tabular(LABEL_SEMIBOLD))  # a real bold for [b] headers, not a synthesized one
	t.set_color("default_color", "RichBody", Palette.TEXT)  # Godot's default is white, unreadable on Day's paper (323)
	_link(t)
	_big_buttons(t)
	_end_turn_key(t)
	_select_list(t)
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", dark_panel())
	t.set_type_variation("Sheet", "PanelContainer")
	t.set_stylebox("panel", "Sheet", sheet())
	_price_tag(t)
	_board_frame(t)
	_icon_button(t)
	_tech_tiles(t)
	_identity_cards(t)
	_upgrades(t)
	_tooltips(t)
	_flags(t)
	return t


## A notification flag (250, guide §15.9): Flag, a RAISED strip in a 2 px ink rule open on its right (the rail's
## side, where its hue bar sits flush), cut square on a hard plinth; FlagText its one line at the label size; FlagClose
## its ×, flat text, ink on hover.
static func _flags(t: Theme) -> void:
	var strip := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_0)  # the bar runs its full height
	strip.border_width_right = 0
	strip.content_margin_left = Tokens.SPACE_3
	strip.shadow_color = Palette.SHADOW
	strip.shadow_offset = PLINTH
	strip.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	strip.anti_aliasing = false
	t.set_type_variation("Flag", "PanelContainer")
	t.set_stylebox("panel", "Flag", strip)
	_label(t, "FlagText", Tokens.TYPE_LABEL, Palette.TEXT, tabular(LABEL_FONT))
	t.set_type_variation("FlagClose", "Button")
	t.set_font_size("font_size", "FlagClose", Tokens.TYPE_TITLE)  # Barlow's × is small
	t.set_color("font_color", "FlagClose", Palette.TEXT_DIM)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "FlagClose", Palette.TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:  # no box: it reads as a printed ×
		t.set_stylebox(state, "FlagClose", StyleBoxEmpty.new())


## A tooltip, and the locked tip that uses the same types (187): a printed tab (233, guide §11.11), ink with sheet text
## in Night and Day alike, cut square, with room around the text.
static func _tooltips(t: Theme) -> void:
	var tab := UIKit.panel_style(Palette.TEXT, Palette.TEXT, Tokens.SPACE_4)
	tab.content_margin_top = Tokens.SPACE_3
	tab.content_margin_bottom = Tokens.SPACE_3
	t.set_stylebox("panel", "TooltipPanel", tab)
	t.set_color("font_color", "TooltipLabel", Palette.RAISED)
	t.set_font_size("font_size", "TooltipLabel", Tokens.TYPE_BODY_S)


## The civilization modal's cards (231): IdentityCard a card on the desk (the board's fill in a 2 px rule, cut square,
## lifted onto its plinth with an ink rule on hover), Flavor its italic foot, and DeckTab a small tab per card in the
## government deck (the well in a rule of the government colour, thicker along its top).
static func _identity_cards(t: Theme) -> void:
	t.set_type_variation("IdentityCard", "Button")
	var card := UIKit.panel_style(Palette.BACKGROUND, Palette.CONTROL_BORDER, Tokens.SPACE_0)
	card.anti_aliasing = false
	var lifted := card.duplicate() as StyleBoxFlat
	lifted.border_color = Palette.TEXT
	lifted.shadow_color = Palette.SHADOW
	lifted.shadow_offset = SELECTED_SHADOW
	lifted.shadow_size = 1  # solid, unblurred
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "IdentityCard", card)
	t.set_stylebox("hover", "IdentityCard", lifted)
	t.set_stylebox("focus", "IdentityCard", focus_ring())
	# GivesCard: a card a tech gives, just its face (289); SlotButton: a free slot's "+ Build" (297), just its words
	for look in ["GivesCard", "SlotButton"]:
		t.set_type_variation(look, "Button")
		for state in ["normal", "hover", "pressed", "disabled"]:
			t.set_stylebox(state, look, StyleBoxEmpty.new())
		t.set_stylebox("focus", look, focus_ring())
	_label(t, "Flavor", Tokens.TYPE_BODY_S, Palette.TEXT_DIM, tabular(ITALIC_FONT))
	t.set_type_variation("DeckTab", "Button")
	t.set_font_size("font_size", "DeckTab", Tokens.TYPE_BODY_S)
	t.set_font("font", "DeckTab", tabular(LABEL_SEMIBOLD))
	var tab := UIKit.panel_style(Palette.FIELD, Palette.GOVERNMENT, Tokens.SPACE_2)
	tab.set_border_width_all(1)
	tab.border_width_top = 3
	tab.content_margin_top = Tokens.SPACE_1
	tab.content_margin_bottom = Tokens.SPACE_1
	var tab_hover := tab.duplicate() as StyleBoxFlat
	tab_hover.border_color = Palette.TEXT
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "DeckTab", tab)
	t.set_stylebox("hover", "DeckTab", tab_hover)
	t.set_stylebox("focus", "DeckTab", focus_ring())


## Upgrades (302): Ribbon an upgrade along its base's foot (a hairline over it), RibbonName its name in semibold,
## UpgradeChip the "+ Upgrade" key (a free slot's ghost outline at chip size, in caption capitals) and TierStamp the tier
## an upgrade's face needs (Caption in the territory colour, in a 2 px rule).
static func _upgrades(t: Theme) -> void:
	t.set_type_variation("Ribbon", "PanelContainer")
	var ribbon := StyleBoxFlat.new()
	ribbon.draw_center = false
	ribbon.border_color = Palette.HAIRLINE
	ribbon.border_width_top = 1
	ribbon.content_margin_left = Tokens.SPACE_1
	ribbon.content_margin_right = Tokens.SPACE_1
	ribbon.content_margin_top = Tokens.SPACE_1
	ribbon.content_margin_bottom = Tokens.SPACE_1
	t.set_stylebox("panel", "Ribbon", ribbon)
	_label(t, "RibbonName", Tokens.TYPE_BODY_S, Palette.TEXT, tabular(LABEL_SEMIBOLD))
	t.set_type_variation("UpgradeChip", "Button")
	t.set_font("font", "UpgradeChip", tabular(LABEL_SEMIBOLD))
	t.set_font_size("font_size", "UpgradeChip", Tokens.TYPE_CAPTION)
	t.set_color("font_color", "UpgradeChip", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "UpgradeChip", Palette.TEXT)
	var chip := UIKit.panel_style(Palette.GHOST_BG, Palette.GHOST_EDGE, Tokens.SPACE_1)
	chip.set_border_width_all(1)
	chip.content_margin_left = Tokens.SPACE_2
	chip.content_margin_right = Tokens.SPACE_2
	var chip_hover := chip.duplicate() as StyleBoxFlat
	chip_hover.border_color = Palette.TEXT
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "UpgradeChip", chip)
	t.set_stylebox("hover", "UpgradeChip", chip_hover)
	t.set_stylebox("focus", "UpgradeChip", focus_ring())
	_label(t, "TierStamp", Tokens.TYPE_CAPTION, Palette.TERRITORY, tabular(LABEL_SEMIBOLD))
	var stamp := UIKit.panel_style(Color.TRANSPARENT, Palette.TERRITORY, Tokens.SPACE_1)
	stamp.set_border_width_all(2)
	t.set_stylebox("normal", "TierStamp", stamp)


## The Knowledge screen's tech tiles (222, guide §11.3), index cards cut square: TechTile (available, or a later
## era's under its vellum) the sheet with an ink border; TechTileShort the same with muted text, for an available tech
## the insight doesn't cover yet (325); TechTileResearched the teal plane; TechTileLocked the well
## with a rule border. On hover each takes the index cards' ink rule on a 4 px shadow and the buttons' lighter fill
## (280). Each has a <name>Linked twin, the same with a TECH_LINK border at rest, for the tiles linked to the hovered
## tech (278). TechTileText* is the text on each, and EraVellum the sheet at 88% laid over an era not reached.
static func _tech_tiles(t: Theme) -> void:
	var looks := {
		"TechTile": [Palette.TILE, Palette.TEXT, Palette.TEXT],
		"TechTileShort": [Palette.TILE, Palette.TEXT, Palette.TEXT_DISABLED],
		"TechTileResearched": [Palette.RESEARCHED_FILL, Palette.TEXT, Palette.TEXT_ON_PLANE],
		"TechTileLocked": [Palette.FIELD, Palette.CONTROL_BORDER, Palette.TEXT_DISABLED],
	}
	for type: String in looks:
		var look: Array = looks[type]
		t.set_type_variation(type, "Button")
		var box := UIKit.panel_style(look[0], look[1], Tokens.SPACE_2)
		box.set_border_width_all(2)
		t.set_stylebox("normal", type, box)
		var lifted := box.duplicate() as StyleBoxFlat
		lifted.border_color = Palette.TEXT  # the index cards' hover (179, 231): an ink rule on a 4 px shadow
		lifted.bg_color = look[0].lightened(0.08)  # and the buttons' lighter fill, which shows in Night too
		lifted.shadow_color = Palette.SHADOW
		lifted.shadow_offset = SELECTED_SHADOW
		lifted.shadow_size = 1  # solid, unblurred
		lifted.anti_aliasing = false
		t.set_stylebox("hover", type, lifted)
		t.set_stylebox("pressed", type, box)
		t.set_stylebox("disabled", type, box)
		t.set_stylebox("focus", type, focus_ring())
		_label(t, type.replace("TechTile", "TechTileText"), Tokens.TYPE_LABEL, look[2], tabular(LABEL_SEMIBOLD))
		t.set_type_variation(type + "Linked", type)
		var link := box.duplicate() as StyleBoxFlat
		link.border_color = Palette.TECH_LINK
		t.set_stylebox("normal", type + "Linked", link)
		t.set_stylebox("hover", type + "Linked", lifted)  # the hovered tile wins over its link mark
		t.set_stylebox("pressed", type + "Linked", link)
		t.set_stylebox("disabled", type + "Linked", link)
	t.set_type_variation("EraVellum", "PanelContainer")
	var vellum := UIKit.panel_style(Color(Palette.RAISED, 0.88), Color.TRANSPARENT, 0)
	vellum.set_border_width_all(0)  # no clear edge for the tiles to show through
	t.set_stylebox("panel", "EraVellum", vellum)


## IconButton, a Button whose icon (Grow's food, 227) is sized to sit beside its text.
static func _icon_button(t: Theme) -> void:
	t.set_type_variation("IconButton", "Button")
	t.set_constant("icon_max_width", "IconButton", 20)


## "Link": a flat Button that reads as a title you can click: dim, accent on hover.
## "TitleLink": the same in ink.
static func _link(t: Theme) -> void:
	t.set_type_variation("Link", "Button")
	t.set_font_size("font_size", "Link", Tokens.TYPE_TITLE)
	t.set_font("font", "Link", display())
	t.set_color("font_color", "Link", Palette.TEXT_DIM)
	t.set_color("font_hover_color", "Link", Palette.ACCENT)
	t.set_color("font_pressed_color", "Link", Palette.ACCENT)
	t.set_color("font_focus_color", "Link", Palette.ACCENT)
	for state in ["normal", "hover", "pressed", "disabled"]:  # no box or padding: it reads as text
		t.set_stylebox(state, "Link", StyleBoxEmpty.new())
	_divider_tab(t)
	t.set_type_variation("TitleLink", "Link")  # a name you can click, in ink (the sidebar's civilization, 202)
	t.set_color("font_color", "TitleLink", Palette.TEXT)
	t.set_type_variation("CapsLink", "Link")  # a small caps link, ink on hover (the sidebar's government, 221)
	t.set_font_size("font_size", "CapsLink", Tokens.TYPE_HEADING)
	t.set_font("font", "CapsLink", heading_font())
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "CapsLink", Palette.TEXT)


## A navigated screen's title bar (241): BarTitle and BarHeading, the title and its context printed on the bar's
## colour; DividerTab, the way back at its left end, the index tab of the sheet underneath: the board's colour, its
## right edge slanted (a skewed box whose left edge runs off the bar, which clips it), the sheet colour on hover.
static func _divider_tab(t: Theme) -> void:
	_label(t, "BarTitle", Tokens.TYPE_TITLE, Palette.TEXT_ON_PLANE, display())
	_label(t, "BarHeading", Tokens.TYPE_HEADING, Palette.TEXT_ON_PLANE, heading_font())
	t.set_type_variation("DividerTab", "Button")
	t.set_font("font", "DividerTab", tabular(LABEL_SEMIBOLD))
	t.set_font_size("font_size", "DividerTab", Tokens.TYPE_LABEL)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "DividerTab", Palette.TEXT)
	var tab := UIKit.panel_style(Palette.BACKGROUND, Palette.BACKGROUND, Tokens.SPACE_3)
	tab.set_border_width_all(0)
	tab.skew = Vector2(-0.3, 0)
	tab.expand_margin_left = Tokens.SPACE_5
	tab.content_margin_left = Tokens.SPACE_4
	tab.content_margin_right = Tokens.SPACE_6
	var hover := tab.duplicate() as StyleBoxFlat
	hover.bg_color = Palette.RAISED
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "DividerTab", tab)
	t.set_stylebox("hover", "DividerTab", hover)
	t.set_stylebox("focus", "DividerTab", focus_ring())


## The selectable list (217, guide §7): ListWell, the list's recessed well, with room on its trailing side for the
## pulled-out row; ListRow, a row printed on it with no box, and when selected (pressed) a sheet strip pulled PULL px
## out onto a hard shadow; ListRowQuiet, a ListRow with no focus ring. SelectList draws the selected row's index tab.
static func _select_list(t: Theme) -> void:
	t.set_type_variation("ListWell", "PanelContainer")
	var well := UIKit.panel_style(Palette.FIELD, Palette.FIELD, 0)
	well.set_border_width_all(0)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_top = Tokens.SPACE_2
	well.content_margin_bottom = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_4  # the pull and its shadow
	t.set_stylebox("panel", "ListWell", well)
	t.set_type_variation("ListRow", "Button")
	var flat := UIKit.panel_style(Palette.RAISED, Palette.RAISED, 0)
	flat.set_border_width_all(0)
	flat.content_margin_left = Tokens.SPACE_4
	flat.content_margin_right = Tokens.SPACE_4
	flat.content_margin_top = Tokens.SPACE_2
	flat.content_margin_bottom = Tokens.SPACE_2
	var printed := flat.duplicate() as StyleBoxFlat
	printed.draw_center = false
	t.set_stylebox("normal", "ListRow", printed)
	t.set_stylebox("hover", "ListRow", printed)
	var pulled := flat.duplicate() as StyleBoxFlat
	pulled.shadow_color = Palette.SHADOW
	pulled.shadow_offset = SELECTED_SHADOW
	pulled.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	pulled.anti_aliasing = false
	pulled.expand_margin_left = -PULL
	pulled.expand_margin_right = PULL
	pulled.content_margin_left += PULL
	pulled.content_margin_right -= PULL
	t.set_stylebox("pressed", "ListRow", pulled)
	t.set_stylebox("hover_pressed", "ListRow", pulled)
	t.set_font("font", "ListRow", tabular(LABEL_FONT))
	t.set_color("font_color", "ListRow", Palette.TEXT_DIM)
	for state in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(state, "ListRow", Palette.TEXT)
	t.set_type_variation("ListRowQuiet", "ListRow")  # a row the keyboard didn't focus: no ring (220)
	t.set_stylebox("focus", "ListRowQuiet", StyleBoxEmpty.new())


## The board's frame (221, the transitions mock's desk): Strip, the top bar's band, walnut grain under RAISED with a
## 3 px ink rule under it (341); Rail, the sidebar open on the board with a hairline on its left, on the board's grain
## so a screen sliding in passes under it (224). The Sidebar lines its grain up with the board's (rail()).
static func _board_frame(t: Theme) -> void:
	var strip := UIKit.panel_style(Palette.RAISED, Palette.TEXT, Tokens.SPACE_2)
	strip.set_border_width_all(0)
	strip.border_width_bottom = 3
	strip.content_margin_left = Tokens.SPACE_4
	strip.content_margin_right = Tokens.SPACE_4
	t.set_type_variation("Strip", "PanelContainer")
	t.set_stylebox("panel", "Strip", Surfaces.box(Surfaces.STRIP, strip))
	t.set_type_variation("Rail", "PanelContainer")
	t.set_stylebox("panel", "Rail", rail())


## The Rail's box with its grain lined up for a rail at origin on screen.
static func rail(origin := Vector2.ZERO) -> SurfaceBox:
	var frame := UIKit.panel_style(Palette.BACKGROUND, Palette.HAIRLINE, Tokens.SPACE_4)
	frame.set_border_width_all(0)
	frame.border_width_left = 1
	return Surfaces.board(origin, frame)


## An overlay's panel (341: a sheet of paper); border defaults to DarkPanel's own.
static func dark_panel(border := Palette.EDGE) -> SurfaceBox:
	return Surfaces.sheet(border)


## A supply pile's price tag (232): a WEALTH plane hanging below the card, PriceTagText on it.
static func _price_tag(t: Theme) -> void:
	var style := UIKit.panel_style(Palette.WEALTH, Palette.WEALTH, Tokens.SPACE_1)
	style.content_margin_left = Tokens.SPACE_3
	style.content_margin_right = Tokens.SPACE_3
	t.set_type_variation("PriceTag", "PanelContainer")
	t.set_stylebox("panel", "PriceTag", style)
	_label(t, "PriceTagText", Tokens.TYPE_BODY, Palette.TEXT_ON_ACCENT, tabular(LABEL_SEMIBOLD))


## The keyboard focus ring drawn over a focused button or field; same colour as a focused card's.
## BigButton and BigButtonPrimary (213, guide §15.12): an index card on a hard plinth; RAISED at rest, CONTROL under
## the pointer or the focus, pressed TRAVEL px into the plinth. The label children draw the text, so the Button's own is
## clear.
static func _big_buttons(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["BigButton", "BigButtonPrimary"]:
		t.set_type_variation(type, "Button")
		t.set_stylebox("normal", type, _card(Palette.RAISED))
		t.set_stylebox("hover", type, _card(Palette.CONTROL))
		t.set_stylebox("focus", type, _card(Palette.CONTROL))
		var pressed := _card(Palette.CONTROL)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, _card(Palette.CONTROL_DISABLED))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)


## End turn's key (203, guide §15.12): EndTurnKey an ACCENT key in a 3 px ink border on a 4,4 plinth, pressed into it,
## disabled flat; EndTurnKeyBusy the same in CONTROL while the turn resolves. KeyLabel is its caps label; Plate the turn
## on a FIELD well, in tabular numerals (also the strip's turn, 201).
static func _end_turn_key(t: Theme) -> void:
	var travel := int(BigButton.TRAVEL)
	for type in ["EndTurnKey", "EndTurnKeyBusy"]:
		var fill := Palette.ACCENT if type == "EndTurnKey" else Palette.CONTROL
		t.set_type_variation(type, "Button")
		for state in ["normal", "hover", "focus"]:
			var box := _card(fill.lightened(0.08) if state == "hover" else fill)
			box.set_corner_radius_all(Tokens.RADIUS_1)
			t.set_stylebox(state, type, box)
		var pressed := _card(fill.darkened(0.1))
		pressed.set_corner_radius_all(Tokens.RADIUS_1)
		pressed.shadow_size = 0
		pressed.expand_margin_left = -travel
		pressed.expand_margin_top = -travel
		pressed.expand_margin_right = travel
		pressed.expand_margin_bottom = travel
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		var flat := _card(Palette.CONTROL_DISABLED)
		flat.set_corner_radius_all(Tokens.RADIUS_1)
		flat.border_color = Palette.CONTROL_DISABLED_BORDER
		flat.shadow_size = 0
		t.set_stylebox("disabled", type, flat)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color",
				"font_disabled_color"]:
			t.set_color(state, type, Color.TRANSPARENT)
	_label(t, "KeyLabel", Tokens.TYPE_BODY, Palette.TEXT_ON_ACCENT, heading_font())  # TYPE_BODY since 221
	_label(t, "Plate", Tokens.TYPE_NUMERAL_S, Palette.TEXT, tabular(LABEL_SEMIBOLD))
	_label(t, "StateWord", Tokens.TYPE_LABEL_CAPS, Palette.TEXT_DIM, heading_font())  # ON/OFF beside a toggle key (219)
	var well := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, Tokens.SPACE_1)
	well.set_border_width_all(1)
	well.content_margin_left = Tokens.SPACE_2
	well.content_margin_right = Tokens.SPACE_2
	t.set_stylebox("normal", "Plate", well)


## A BigButton's card in fill: a 3 px ink border, square, on a 4,4 shadow.
static func _card(fill: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(fill, Palette.TEXT, Tokens.SPACE_0)
	style.set_border_width_all(3)
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = Vector2(BigButton.TRAVEL, BigButton.TRAVEL)
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## A modal's sheet (207, guide §15.11): paper in a 2 px ink rule, cut square, on a soft shadow (341).
static func sheet() -> SurfaceBox:
	return Surfaces.sheet(Palette.TEXT)


static func focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Palette.FOCUS
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(0)
	ring.set_expand_margin_all(4)
	return ring


static func _controls(t: Theme) -> void:
	for type: String in ["Button", "AccentButton"]:
		var accent := type == "AccentButton"
		if accent:
			t.set_type_variation(type, "Button")
		var fill := Palette.ACCENT if accent else Palette.CONTROL
		var text := Palette.TEXT_ON_ACCENT if accent else Palette.TEXT
		var rim := 3 if accent else 2  # the guide's primary button has a 3 px ink border (§7.1, 251)
		t.set_stylebox("normal", type, _rim(_box(fill, Palette.TEXT if accent else Palette.CONTROL_BORDER), rim))
		t.set_stylebox("hover", type, _rim(_box(fill.lightened(0.08), Palette.TEXT), rim))
		t.set_stylebox("pressed", type, _pressed(_rim(_box(fill.darkened(0.1), Palette.TEXT), rim)))
		# a latched toggle
		t.set_stylebox("hover_pressed", type, _pressed(_rim(_box(fill.darkened(0.04), Palette.TEXT), rim)))
		t.set_stylebox("disabled", type, _flat(_box(Palette.CONTROL_DISABLED, Palette.CONTROL_DISABLED_BORDER)))
		t.set_font("font", type, tabular(LABEL_SEMIBOLD if accent else LABEL_FONT))
		t.set_stylebox("focus", type, focus_ring())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(state, type, text)
		t.set_color("font_disabled_color", type, Palette.TEXT_DISABLED)
	t.set_stylebox("normal", "LineEdit", _box(Palette.FIELD, Palette.CONTROL_BORDER))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())  # its caret shows the focus; Godot draws this box even when
	# FocusRing hides the focus (251)
	t.set_color("font_color", "LineEdit", Palette.TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Palette.TEXT_DIM)
	t.set_color("font_color", "Label", Palette.TEXT)  # a plain label; Godot's default is white, unreadable on Day's paper (355)
	_slider(t)


## A volume slider (185): a field-coloured slot with the travelled part filled like a lit lamp.
static func _slider(t: Theme) -> void:
	var slot := UIKit.panel_style(Palette.FIELD, Palette.CONTROL_BORDER, 0)
	slot.set_corner_radius_all(Tokens.RADIUS_1)
	slot.content_margin_top = Tokens.SPACE_1
	slot.content_margin_bottom = Tokens.SPACE_1
	t.set_stylebox("slider", "HSlider", slot)
	var filled := slot.duplicate() as StyleBoxFlat
	filled.bg_color = Palette.GAIN
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	t.set_stylebox("focus", "HSlider", focus_ring())


static func _label(t: Theme, variation: String, font_size: int, color: Color, font: Font = null) -> void:
	t.set_type_variation(variation, "Label")
	t.set_font_size("font_size", variation, font_size)
	t.set_color("font_color", variation, color)
	if font != null:
		t.set_font("font", variation, font)


## base with tabular lining figures (OpenType tnum and lnum), so a changing number keeps its width (178).
static func tabular(base: Font) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.opentype_features = {"tnum": 1, "lnum": 1}
	return f


## The heading face (§5.2 type.heading): Barlow SemiCondensed SemiBold, tracked +10% for its capitals (194).
static func heading_font() -> FontVariation:
	var f := tabular(LABEL_SEMIBOLD)
	f.spacing_glyph = roundi(Tokens.TYPE_HEADING * 0.1)
	return f


## Jost at Medium weight (500), the guide's display face: titles and the header's link back (178).
static func display() -> FontVariation:
	var f := tabular(DISPLAY_FONT)
	f.variation_opentype = {"wght": 500}
	return f


## A button's or field's box: the border 2 wide, a machined 2 px corner, room around the text, standing on a hard
## shadow (178, guide §6.5, §15.1).
static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var style := UIKit.panel_style(bg, border, 0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(Tokens.RADIUS_1)
	style.content_margin_left = Tokens.SPACE_4
	style.content_margin_right = Tokens.SPACE_4
	style.content_margin_top = Tokens.SPACE_2
	style.content_margin_bottom = Tokens.SPACE_2
	style.shadow_color = Palette.SHADOW
	style.shadow_offset = PLINTH
	style.shadow_size = 1  # with no anti-aliasing: a solid, unblurred offset
	style.anti_aliasing = false
	return style


## style with its border width px on every side.
static func _rim(style: StyleBoxFlat, width: int) -> StyleBoxFlat:
	style.set_border_width_all(width)
	return style


## style pressed into its shadow (178): a stylebox can't translate, so the drawn box moves PRESS px down and right
## through negative expand margins on the top and left and positive ones on the bottom and right, the content margins
## move its text with it, and the shadow is gone.
static func _pressed(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	style.expand_margin_left = -PRESS
	style.expand_margin_top = -PRESS
	style.expand_margin_right = PRESS
	style.expand_margin_bottom = PRESS
	style.content_margin_left += PRESS
	style.content_margin_right -= PRESS
	style.content_margin_top += PRESS
	style.content_margin_bottom -= PRESS
	return style


## style lying flat: no shadow (disabled controls).
static func _flat(style: StyleBoxFlat) -> StyleBoxFlat:
	style.shadow_size = 0
	return style
