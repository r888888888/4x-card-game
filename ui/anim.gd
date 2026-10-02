class_name Anim
extends RefCounted
## Animation tuning for the card UI, in one place. Sharpness values are the k in
## lerp(from, to, 1 - exp(-k * delta)): higher is snappier. Times are in seconds.

const HOVER_LIFT := 8.0  # px a hand card slides up under the mouse; it never grows (179)
# Room around the hand row so a hovered card (lifted, with its hard shadow) isn't clipped by the hand's scroll box.
const LIFT_ROOM := 40.0
const HAND_SIDE_ROOM := 24.0
const DRAG_START_DISTANCE := 6.0  # px the mouse must move while pressed before a drag starts
const DETAILS_CLICK_DELAY := 0.5  # a single click opens the card details after this, unless a second click came

const REST_SHARPNESS := 18.0  # hover lift, and sliding into place after the hand relayouts
const FOLLOW_SHARPNESS := 22.0  # dragged card chasing the cursor
const FLY_SHARPNESS := 11.0  # card flying to a new slot
const ARRIVE_DISTANCE := 1.5  # px from the target at which a flying card counts as landed

const MAX_TILT := deg_to_rad(3.0)  # a dragged card barely tilts (179)
const TILT_PER_SPEED := 0.00016  # radians per px/s of horizontal drag speed

const SHAKE_PX := 10.0
const SHAKE_TIME := 0.35
const POP_IN_TIME := 0.28
const DISCARD_POP_TIME := 0.12
const DISCARD_FLY_TIME := 0.45
const TARGET_FLY_TIME := 0.3  # a played action flying to its target before it is discarded
const DEAL_STAGGER := 0.06  # delay between cards dealt into the hand
const TOKEN_FLY_TIME := 0.55
const TOKEN_FLOAT_PX := 40.0  # how far a cost token rises from its counter (114)
const TOKEN_STAGGER := 0.08
const PULSE_SCALE := 1.18
const PULSE_TIME := 0.25
const ERROR_SHOW_TIME := 1.8
const TOAST_TIME := 3.0  # a notice's toast shows this long before it fades (116)
const HIGHLIGHT_PULSE_TIME := 0.7
const SCREEN_TIME := 0.22  # a navigated screen growing out of its card, or fading, in and out (104)
# Reduce motion: cards and tokens jump to where they are going and fade in over this time instead.
const CALM_FADE_TIME := 0.15
