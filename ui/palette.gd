class_name Palette
extends RefCounted
## Every colour the UI uses (backlog 106), named for what it's for rather than its hue, so a look changes in one place
## (and a later light theme can swap values). Colours derived at run time (lightened, darkened) stay derived where
## they're used. GameTheme builds the controls' theme from these.
## The values are the style guide's Night shift set (178, docs/design/mcm-style-guide.md §4).

# Surfaces, darkest first.
const BACKGROUND := Color("1f1e1c")  # the board behind everything
const FIELD := Color("171614")  # a text field
const PANEL := Color("171614")  # the side panel's log
const TILE := Color("2a2825")  # a tech in the tech tree
const RAISED := Color("2a2825")  # an overlay's or a modal's panel
const CONTROL := Color("3a3733")  # a button
const CONTROL_DISABLED := Color("171614")
const CONTROL_BORDER := Color("857d70")
const CONTROL_DISABLED_BORDER := Color("4a463f")

# Text.
const TEXT := Color("ede6d6")
const TEXT_DIM := Color("b9b1a1")  # headings
const TEXT_DISABLED := Color("8e877a")
const TEXT_ON_ACCENT := Color("1f1e1c")
const LOG_TEXT := Color("ddd5c5")

# Meaning.
const ACCENT := Color("e0703f")  # the main action's button (End turn)
const GAIN := Color("93b585")  # resources and VP gained, food, score, lit targets, the upkeep mark
const COST := Color("e07a63")  # resources paid, error text
const WARN := Color("e07a63")  # a failing drop, food that would starve
const FOCUS := Color("6cc3bc")  # the keyboard focus ring; distinct from gold (target) and red (warning)
const WEALTH := Color("d9a441")
const INSIGHT := Color("86a9cc")
const UNREST := Color("e07a63")  # the unrest stat (144); at the limit it turns WARN
const POP := Color("5fb0a9")
const PILES := Color("b9b1a1")  # deck, discard and pile counts

# A dimmed card (can't be played, idle) and its reason strip.
const DIM_BG := Color("232220")
const DIM_BORDER := Color("5a554d")
const STRIP_BG := Color("171614")
const STRIP_TEXT := Color("ede6d6")

# Card types (the card border and type marks).
const ACTION := Color("86a9cc")
const BUILDING := Color("a9b26c")
const CITY := Color("d9a441")
const TERRITORY := Color("93b585")
const TECH := Color("5fb0a9")
const EVENT := Color("e07a63")

# An unsettled territory on the board (138): open land, not yet yours.
const FRONTIER_BG := Color("1f1e1c")  # barely off the board
const FRONTIER_HATCH := Color(1, 1, 1, 0.05)  # its diagonal lines

# Tech tree states.
const RESEARCHED := Color("5fb0a9")
const AVAILABLE := Color("ede6d6")
const FUTURE := Color("8e877a")
const LOCKED := Color("857d70")  # a tech whose prerequisite isn't researched (140)

# See-through layers.
const DIMMER := Color(0, 0, 0, 0.65)  # behind an overlay
const SCRIM := Color(0, 0, 0, 0.6)  # behind a modal
const SHADOW := Color("0d0c0b")  # hard offset shadows under controls and lifted cards: solid, never blurred (guide §6.5)
const OUTLINE := Color(0, 0, 0, 0.8)  # around effect text
const EDGE := Color("ede6d6")  # an overlay's or a modal's frame: ink
const FAINT_EDGE := Color(1, 1, 1, 0.08)  # the log panel's border
const GHOST_BG := Color(1, 1, 1, 0.04)  # the slot a dragged card will land in
const GHOST_EDGE := Color(1, 1, 1, 0.35)
const DROP_BG := Color(1, 0.85, 0.4, 0.03)  # the lit drop zone
const HINT_BG := Color(0.08, 0.09, 0.11, 0.92)  # behind a hint or an error message
