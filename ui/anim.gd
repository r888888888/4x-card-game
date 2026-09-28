class_name Anim
extends RefCounted
## Animation tuning for the card UI, in one place. Sharpness values are the k in
## lerp(from, to, 1 - exp(-k * delta)): higher is snappier. Times are in seconds.

const HOVER_LIFT := 20.0  # px a hand card rises under the mouse
const HOVER_SCALE := 1.08
# Room around the hand row so a hovered card (lifted, scaled up about its centre, with a shadow)
# isn't clipped by the hand's scroll box. Above: lift 20 + half the growth of a 280px card (11) +
# shadow reach (6). Sides: half the growth of a 215px card (9) + shadow (14).
const LIFT_ROOM := 40.0
const HAND_SIDE_ROOM := 24.0
const DRAG_SCALE := 1.1
const DRAG_START_DISTANCE := 6.0  # px the mouse must move while pressed before a drag starts

const REST_SHARPNESS := 18.0  # hover lift, and sliding into place after the hand relayouts
const FOLLOW_SHARPNESS := 22.0  # dragged card chasing the cursor
const FLY_SHARPNESS := 11.0  # card flying to a new slot
const ARRIVE_DISTANCE := 1.5  # px from the target at which a flying card counts as landed

const MAX_TILT := deg_to_rad(12.0)
const TILT_PER_SPEED := 0.00016  # radians per px/s of horizontal drag speed

const LAND_SQUASH := Vector2(1.05, 0.95)
const LAND_TIME := 0.22
const SHAKE_PX := 10.0
const SHAKE_TIME := 0.35
const POP_IN_TIME := 0.28
const DISCARD_POP_TIME := 0.12
const DISCARD_FLY_TIME := 0.45
const TARGET_FLY_TIME := 0.3  # a played action flying to its target before it is discarded
const DEAL_STAGGER := 0.06  # delay between cards dealt into the hand
const TOKEN_FLY_TIME := 0.55
const TOKEN_STAGGER := 0.08
const PULSE_SCALE := 1.18
const PULSE_TIME := 0.25
const ERROR_SHOW_TIME := 1.8
const HIGHLIGHT_PULSE_TIME := 0.7
