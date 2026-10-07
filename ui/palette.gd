class_name Palette
extends RefCounted
## Every colour the UI uses (backlog 106), named for what it's for rather than its hue, so a look changes in one place.
## Each name has two values (183): the style guide's Night shift set (178, docs/design/mcm-style-guide.md §4), the
## default, and its Paper set for Day mode. use() switches every name at once (Settings calls it at start-up and when
## Day mode changes), so read a colour when drawing; never copy one into a constant (test_ui_structure checks). Colours
## derived at run time (lightened, darkened) stay derived where they're used. GameTheme builds the theme from these.

static var day := false  # Day mode: the Paper values


# Surfaces, darkest first.
static var BACKGROUND: Color = NIGHT["BACKGROUND"]  # the board behind everything
static var FIELD: Color = NIGHT["FIELD"]  # a text field
static var PANEL: Color = NIGHT["PANEL"]  # the side panel's log
static var TILE: Color = NIGHT["TILE"]  # a tech in the tech tree
static var RAISED: Color = NIGHT["RAISED"]  # an overlay's or a modal's panel
static var CONTROL: Color = NIGHT["CONTROL"]  # a button
static var CONTROL_DISABLED: Color = NIGHT["CONTROL_DISABLED"]
static var CONTROL_BORDER: Color = NIGHT["CONTROL_BORDER"]
static var CONTROL_DISABLED_BORDER: Color = NIGHT["CONTROL_DISABLED_BORDER"]
static var HAIRLINE: Color = NIGHT["HAIRLINE"]  # a fine rule between parts of a sheet (guide rule-fine; 217)
static var PAPER_SHADE: Color = NIGHT["PAPER_SHADE"]  # laid over the paper texture (341): Night's gray paper darkened
static var ART_SHADE: Color = NIGHT["ART_SHADE"]  # laid over a card's art (381): Night dims the print

# Text.
static var TEXT: Color = NIGHT["TEXT"]
static var TEXT_DIM: Color = NIGHT["TEXT_DIM"]  # headings
static var TEXT_DISABLED: Color = NIGHT["TEXT_DISABLED"]
static var TEXT_ON_ACCENT: Color = NIGHT["TEXT_ON_ACCENT"]
static var LOG_TEXT: Color = NIGHT["LOG_TEXT"]
static var EMPHASIS: Color = NIGHT["EMPHASIS"]  # gold text that stands out: a glossary term, a hint, a log heading (395)

# Meaning.
static var ACCENT: Color = NIGHT["ACCENT"]  # the main action's button (End turn)
static var GAIN: Color = NIGHT["GAIN"]  # resources and VP gained, food, score, lit targets, the upkeep mark
static var COST: Color = NIGHT["COST"]  # resources paid, error text
static var WARN: Color = NIGHT["WARN"]  # a failing drop, food that would starve
static var FOCUS: Color = NIGHT["FOCUS"]  # the keyboard focus ring; distinct from gold (target) and red (warning)
static var WEALTH: Color = NIGHT["WEALTH"]
static var INSIGHT: Color = NIGHT["INSIGHT"]
static var UNREST: Color = NIGHT["UNREST"]  # the unrest stat (144); at the limit it turns WARN
static var POP: Color = NIGHT["POP"]
static var PILES: Color = NIGHT["PILES"]  # deck, discard and pile counts

# A dimmed card (can't be played, idle) and its reason strip.
static var DIM_BG: Color = NIGHT["DIM_BG"]
static var DIM_BORDER: Color = NIGHT["DIM_BORDER"]
static var STRIP_BG: Color = NIGHT["STRIP_BG"]
static var STRIP_TEXT: Color = NIGHT["STRIP_TEXT"]

# Card types (the card border and type marks).
static var ACTION: Color = NIGHT["ACTION"]
static var BUILDING: Color = NIGHT["BUILDING"]
static var CITY: Color = NIGHT["CITY"]
static var TERRITORY: Color = NIGHT["TERRITORY"]
static var TECH: Color = NIGHT["TECH"]
static var EVENT: Color = NIGHT["EVENT"]
static var CIVILIZATION: Color = NIGHT["CIVILIZATION"]  # plum: no card plane uses it (231)
static var GOVERNMENT: Color = NIGHT["GOVERNMENT"]  # indigo (231)
static var UNIT: Color = NIGHT["UNIT"]  # bronze (160): no guide hue, chosen apart from the other planes

# An unsettled territory on the board (138): open land, not yet yours.
static var FRONTIER_BG: Color = NIGHT["FRONTIER_BG"]  # barely off the board
static var FRONTIER_HATCH: Color = NIGHT["FRONTIER_HATCH"]  # its diagonal lines

# The tech tree (222).
static var RESEARCHED_FILL: Color = NIGHT["RESEARCHED_FILL"]  # a researched tech's tile: the teal plane (222)
static var TECH_LINK: Color = NIGHT["TECH_LINK"]  # the border of the tiles linked to the hovered tech (278)
static var TEXT_ON_PLANE: Color = NIGHT["TEXT_ON_PLANE"]  # text on a filled plane, such as a researched tile (222)

# The title screen's art (214): a sun over a hill, its own roles so it can drift from the cards' planes.
static var SUN: Color = NIGHT["SUN"]  # the sun at its height
static var SUN_LOW: Color = NIGHT["SUN_LOW"]  # the sun near the horizon
static var SKY_LOW: Color = NIGHT["SKY_LOW"]  # the sunset's bands near the horizon
static var SKY_HIGH: Color = NIGHT["SKY_HIGH"]  # and higher up
static var HILL: Color = NIGHT["HILL"]
static var HILL_LOW: Color = NIGHT["HILL_LOW"]  # the hill at sunset

# See-through layers.
static var DIMMER: Color = NIGHT["DIMMER"]  # behind an overlay
static var SCRIM: Color = NIGHT["SCRIM"]  # behind a modal
static var SHADOW: Color = NIGHT["SHADOW"]  # hard offset shadows under controls; soft ones under cards and sheets (341, Surfaces)
static var OUTLINE: Color = NIGHT["OUTLINE"]  # around effect text
static var EDGE: Color = NIGHT["EDGE"]  # an overlay's or a modal's frame: ink
static var FAINT_EDGE: Color = NIGHT["FAINT_EDGE"]  # the log panel's border
static var GHOST_BG: Color = NIGHT["GHOST_BG"]  # the slot a dragged card will land in
static var GHOST_EDGE: Color = NIGHT["GHOST_EDGE"]
static var DROP_BG: Color = NIGHT["DROP_BG"]  # the lit drop zone
static var HINT_BG: Color = NIGHT["HINT_BG"]  # behind a hint or an error message


## 178's Night shift values.
const NIGHT := {
	"BACKGROUND": Color("1f1e1c"),
	"FIELD": Color("171614"),
	"PANEL": Color("171614"),
	"TILE": Color("2a2825"),
	"RAISED": Color("2a2825"),
	"CONTROL": Color("3a3733"),
	"CONTROL_DISABLED": Color("171614"),
	"CONTROL_BORDER": Color("857d70"),
	"CONTROL_DISABLED_BORDER": Color("4a463f"),
	"HAIRLINE": Color("3a3733"),
	"PAPER_SHADE": Color(0, 0, 0, 0.3),
	"ART_SHADE": Color(0, 0, 0, 0.25),
	"TEXT": Color("ede6d6"),
	"TEXT_DIM": Color("b9b1a1"),
	"TEXT_DISABLED": Color("8e877a"),
	"TEXT_ON_ACCENT": Color("1f1e1c"),
	"LOG_TEXT": Color("ddd5c5"),
	"EMPHASIS": Color("ffd966"),
	"ACCENT": Color("e0703f"),
	"GAIN": Color("93b585"),
	"COST": Color("e07a63"),
	"WARN": Color("e07a63"),
	"FOCUS": Color("6cc3bc"),
	"WEALTH": Color("d9a441"),
	"INSIGHT": Color("86a9cc"),
	"UNREST": Color("e07a63"),
	"POP": Color("5fb0a9"),
	"PILES": Color("b9b1a1"),
	"DIM_BG": Color("232220"),
	"DIM_BORDER": Color("5a554d"),
	"STRIP_BG": Color("171614"),
	"STRIP_TEXT": Color("ede6d6"),
	"ACTION": Color("86a9cc"),
	"BUILDING": Color("a9b26c"),
	"CITY": Color("d9a441"),
	"TERRITORY": Color("93b585"),
	"TECH": Color("5fb0a9"),
	"EVENT": Color("e07a63"),
	"CIVILIZATION": Color("c48faf"),
	"GOVERNMENT": Color("a39bcb"),
	"UNIT": Color("bc8f72"),
	"FRONTIER_BG": Color("1f1e1c"),
	"FRONTIER_HATCH": Color(1, 1, 1, 0.05),
	"RESEARCHED_FILL": Color("5fb0a9"),
	"TECH_LINK": Color("e3b94f"),
	"TEXT_ON_PLANE": Color("1f1e1c"),
	"DIMMER": Color(0, 0, 0, 0.65),
	"SCRIM": Color(0, 0, 0, 0.6),
	"SHADOW": Color("0d0c0b"),
	"OUTLINE": Color(0, 0, 0, 0.8),
	"EDGE": Color("ede6d6"),
	"FAINT_EDGE": Color(1, 1, 1, 0.08),
	"GHOST_BG": Color(1, 1, 1, 0.04),
	"GHOST_EDGE": Color(1, 1, 1, 0.35),
	"DROP_BG": Color(1, 0.85, 0.4, 0.03),
	"HINT_BG": Color(0.08, 0.09, 0.11, 0.92),
	"SUN": Color("d9a441"),
	"SUN_LOW": Color("e0703f"),
	"SKY_LOW": Color("e07a63"),
	"SKY_HIGH": Color("d9a441"),
	"HILL": Color("93b585"),
	"HILL_LOW": Color("5fb0a9"),
}

## The guide's Paper values (§4); the see-through layers take ink at low alpha instead of white (the scrim: ink at 40%).
const DAY := {
	"BACKGROUND": Color("efe8da"),
	"FIELD": Color("e3daca"),
	"PANEL": Color("e3daca"),
	"TILE": Color("f8f4ec"),
	"RAISED": Color("f8f4ec"),
	"CONTROL": Color("dcd3c2"),
	"CONTROL_DISABLED": Color("e3daca"),
	"CONTROL_BORDER": Color("6f685c"),
	"CONTROL_DISABLED_BORDER": Color("cfc6b5"),
	"HAIRLINE": Color("cfc6b5"),
	"PAPER_SHADE": Color(0, 0, 0, 0),
	"ART_SHADE": Color(0, 0, 0, 0),
	"TEXT": Color("22211f"),
	"TEXT_DIM": Color("57534b"),
	"TEXT_DISABLED": Color("7a7468"),
	"TEXT_ON_ACCENT": Color("fbf6ec"),
	"LOG_TEXT": Color("22211f"),
	"EMPHASIS": Color("7a5200"),
	"ACCENT": Color("a8401b"),
	"GAIN": Color("4e6b47"),
	"COST": Color("9b3424"),
	"WARN": Color("9b3424"),
	"FOCUS": Color("1f6a68"),
	"WEALTH": Color("a07514"),
	"INSIGHT": Color("35597c"),
	"UNREST": Color("9b3424"),
	"POP": Color("1f6a68"),
	"PILES": Color("57534b"),
	"DIM_BG": Color("e8e1d3"),
	"DIM_BORDER": Color("b9af9c"),
	"STRIP_BG": Color("e3daca"),
	"STRIP_TEXT": Color("22211f"),
	"ACTION": Color("8aa7c4"),
	"BUILDING": Color("a3aa6a"),
	"CITY": Color("d9a441"),
	"TERRITORY": Color("9db592"),
	"TECH": Color("5e9c97"),
	"EVENT": Color("c9705c"),
	"CIVILIZATION": Color("b07d9c"),
	"GOVERNMENT": Color("8f88b8"),
	"UNIT": Color("a97f63"),
	"FRONTIER_BG": Color("efe8da"),
	"FRONTIER_HATCH": Color("22211f1a"),
	"RESEARCHED_FILL": Color("5e9c97"),
	"TECH_LINK": Color("9a6f12"),
	"TEXT_ON_PLANE": Color("22211f"),
	"DIMMER": Color("22211f66"),
	"SCRIM": Color("22211f66"),
	"SHADOW": Color("22211f"),
	"OUTLINE": Color("f8f4eccc"),
	"EDGE": Color("22211f"),
	"FAINT_EDGE": Color("22211f1f"),
	"GHOST_BG": Color("22211f0a"),
	"GHOST_EDGE": Color("22211f59"),
	"DROP_BG": Color("a8401b0d"),
	"HINT_BG": Color("f8f4ecf0"),
	"SUN": Color("d9a441"),
	"SUN_LOW": Color("a8401b"),
	"SKY_LOW": Color("c9705c"),
	"SKY_HIGH": Color("d9a441"),
	"HILL": Color("9db592"),
	"HILL_LOW": Color("5e9c97"),
}


## Switches every colour to the Day (Paper) values, or back to Night (183).
static func use(p_day: bool) -> void:
	day = p_day
	var script: GDScript = load("res://ui/palette.gd")
	var values: Dictionary = DAY if p_day else NIGHT
	for name: String in values:
		script.set(name, values[name])


## The colour called name as it reads now (a Palette role, e.g. "TEXT").
static func color(name: StringName) -> Color:
	return (DAY if day else NIGHT)[String(name)]


## text in BBCode coloured c (a Palette colour, read in the current mode): rich text's colours come from here (395).
static func bbcode(text: String, c: Color) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]
