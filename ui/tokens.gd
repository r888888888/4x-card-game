class_name Tokens
extends RefCounted
## The style guide's spacing and corner radius scales (193; docs/design/mcm-style-guide.md §6.1, §6.3), named after its
## tokens (space.2 is SPACE_2) so a value in the guide is found here by name. Every spacing, margin and corner radius in
## ui/ is one of these (test_spacing_tokens checks): pick the step for what it separates, never a number.

# Spacing (4 px base): inside a control SPACE_2 down × SPACE_4 across; related controls SPACE_2; groups SPACE_5;
# sections SPACE_7; panel padding SPACE_5 (dense panels SPACE_4).
const SPACE_0 := 0
const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 24
const SPACE_6 := 32
const SPACE_7 := 48
const SPACE_8 := 64
const SPACE_9 := 96
# The guide's one spacing off the scale (§6.7): a cost's glyph and its figure, close enough to read as one.
const GLYPH_GAP := 3

# Corner radius is meaning, not softness.
const RADIUS_0 := 0  # panels, sheets, cards, modals, tabs, tooltips, zones: paper is cut square
const RADIUS_1 := 2  # buttons and fields: a machined edge
const RADIUS_2 := 4  # badges and keycaps
const RADIUS_FULL := 9999  # lamps, pips, dials: things that indicate (a StyleBoxFlat clamps it to a circle)
