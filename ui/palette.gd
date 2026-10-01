class_name Palette
extends RefCounted
## Every colour the UI uses (backlog 106), named for what it's for rather than its hue, so a look changes in one place
## (and a later light theme can swap values). Colours derived at run time (lightened, darkened) stay derived where
## they're used. GameTheme builds the controls' theme from these.

# Surfaces, darkest first.
const BACKGROUND := Color("1d2126")  # the board behind everything
const FIELD := Color("14171a")  # a text field
const PANEL := Color("171a1e")  # the side panel's log
const TILE := Color("1f2328")  # a tech in the tech tree
const RAISED := Color("262b31")  # an overlay's or a modal's panel
const CONTROL := Color("2f353d")  # a button
const CONTROL_DISABLED := Color("24282d")
const CONTROL_BORDER := Color("78828e")
const CONTROL_DISABLED_BORDER := Color("4a5058")

# Text.
const TEXT := Color("e6ebf0")
const TEXT_DIM := Color("b4bcc6")  # headings
const TEXT_DISABLED := Color("8d96a0")
const TEXT_ON_ACCENT := Color("1d2126")
const LOG_TEXT := Color("dde3ea")

# Meaning.
const ACCENT := Color("e8c547")  # the main action's button (End turn)
const GAIN := Color("ffd966")  # resources and VP gained, food, score, lit targets, the upkeep mark
const COST := Color("ff8a80")  # resources paid, error text
const WARN := Color("ff6b6b")  # a failing drop, food that would starve
const FOCUS := Color("5ec8ff")  # the keyboard focus ring; distinct from gold (target) and red (warning)
const WEALTH := Color("f2b46d")
const POP := Color("9fd89f")
const PILES := Color("c3cad3")  # deck, discard and pile counts

# A dimmed card (can't be played, idle) and its reason strip.
const DIM_BG := Color("202328")
const DIM_BORDER := Color("50565e")
const STRIP_BG := Color("4a1f22")
const STRIP_TEXT := Color("ffd6d1")

# Card types (the card border and type marks).
const ACTION := Color("4a7fb5")
const BUILDING := Color("5f9a45")
const CITY := Color("c08a3e")
const TERRITORY := Color("8a6fb5")
const TECH := Color("3fa7a0")
const EVENT := Color("b5566f")

# An unsettled territory on the board (138): open land, not yet yours.
const FRONTIER_BG := Color("1a1c21")  # barely off the board
const FRONTIER_HATCH := Color(1, 1, 1, 0.05)  # its diagonal lines

# Tech tree states.
const RESEARCHED := Color("7fd48a")
const AVAILABLE := Color("5ec8ff")
const FUTURE := Color("6b7280")
const LOST := Color("b5566f")

# See-through layers.
const DIMMER := Color(0, 0, 0, 0.65)  # behind an overlay
const SCRIM := Color(0, 0, 0, 0.7)  # behind a modal
const SHADOW := Color(0, 0, 0, 0.45)  # under a lifted card
const OUTLINE := Color(0, 0, 0, 0.8)  # around effect text
const EDGE := Color(1, 1, 1, 0.25)  # an overlay panel's border
const FAINT_EDGE := Color(1, 1, 1, 0.08)  # the log panel's border
const GHOST_BG := Color(1, 1, 1, 0.04)  # the slot a dragged card will land in
const GHOST_EDGE := Color(1, 1, 1, 0.35)
const DROP_BG := Color(1, 0.85, 0.4, 0.03)  # the lit drop zone
const HINT_BG := Color(0.08, 0.09, 0.11, 0.92)  # behind a hint or an error message
