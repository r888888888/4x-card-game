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
const ODOMETER_STEP := 0.07  # a counter's digits roll one value this often (181)
const ODOMETER_MAX_STEPS := 8  # a longer change jumps, then rolls only its last steps
const TAG_HOLD := 0.6  # a counter's "+N" tag shows this long (181)
const TAG_STAGGER := 0.06  # between the tags of several counters changed at once, left to right
const CALM_TAG_HOLD := 1.5  # a tag's hold with Reduce motion, where it appears in place
const PULSE_SCALE := 1.18
const PULSE_TIME := 0.25
const ERROR_SHOW_TIME := 1.8
const TOAST_TIME := 3.0  # a notice's toast shows this long before it fades (116)
const HIGHLIGHT_PULSE_TIME := 0.7
const SCREEN_TIME := 0.22  # a navigated screen growing out of its card, or fading, in and out (104)
# Reduce motion: cards jump to where they are going and fade in over this time instead.
const CALM_FADE_TIME := 0.15

# A key's travel (§9.4, §15.1), for timing its sounds (187): down on SNAP, back up on MACHINED.
const KEY_PRESS_TIME := 0.07
const KEY_RELEASE_TIME := 0.12
const ENDTURN_TURN_DELAY := 0.12  # the turn drum advances this long after End turn's relay closes
const SOUND_OFF_GRACE := 0.25  # turning interface sounds off mutes them after this, so the key's OFF is heard

# The style guide's easing curves (§9.3) as cubic-bezier control points (x1, y1, x2, y2), for timing sounds (186).
const SNAP := Vector4(0.3, 0, 0, 1)
const MACHINED := Vector4(0.2, 0, 0, 1)
const LATCH := Vector4(0.5, -0.2, 0.1, 1)
const RELEASE := Vector4(0.4, 0, 1, 1)


## When a motion of duration (s) on curve reaches 90% of its travel: its contact point (§16.5), where its sound plays.
static func contact(duration: float, curve: Vector4) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 40:  # the bezier's parameter where its progress first reaches 0.9
		var mid := (lo + hi) / 2
		if _bezier(mid, curve.y, curve.w) < 0.9:
			lo = mid
		else:
			hi = mid
	return duration * _bezier(hi, curve.x, curve.z)


## One coordinate of a cubic bezier from (0, 0) to (1, 1) with control points p1 and p2, at parameter s.
static func _bezier(s: float, p1: float, p2: float) -> float:
	return 3 * (1 - s) * (1 - s) * s * p1 + 3 * (1 - s) * s * s * p2 + s * s * s
