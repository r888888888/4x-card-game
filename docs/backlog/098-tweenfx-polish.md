---
id: 098
title: Evaluate TweenFX for card animation polish
type: feature
status: draft
branch: feat/098-tweenfx-polish
---

## Goal
Card motion is hand-rolled today (`ui/anim.gd` tuning, and `Tween`s in `ui/card_motion.gd`, `ui/ui_kit.gd` and
`ui/supply_screen.gd`). TweenFX (MIT, "a simple, juicy tween animation library for Godot 4") offers ready-made
effects. Try it for card hover, draw and play feedback, and adopt it only if it replaces code rather than adding to it.

## Acceptance criteria
<!-- UI-only: no engine behaviour changes. -->
- [ ] AC1: Given TweenFX installed under `addons/`, when the suite runs, then it stays green and
  `test_ui_smoke` passes unchanged.
- [ ] AC2: Given Reduce motion is on (`UIKit.calm()` is true), when a card is drawn, played or hovered, then no
  TweenFX effect starts.
- [ ] AC3: Given an effect is running on a card view, when that view is freed (card leaves the board), then no
  errors are logged.

## Out of scope
- Drag following and tilt (`FOLLOW_SHARPNESS`, `MAX_TILT`). They are per-frame lerps, not tweens.
- New animations for events or the tech tree.

## Design notes
- Check that TweenFX works on Godot 4.7 and find its repository and licence before anything else.
- Timing constants stay in `Anim`; TweenFX calls read them from there.
- The addon lives in `addons/`, so it's exempt from the 700-line limit.

## Open questions
- Which effects move to TweenFX: pop-in, land squash, shake and discard pop in `card_motion.gd`, or only new
  hover/draw effects? Recommendation: swap the existing four first, and compare line count and feel.
- If it saves little code, drop it? Recommendation: yes, and record the verdict in the Log.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Draw, play, discard and a failed play (shake) feel at least as good as on `main`.
- [ ] With Reduce motion on, cards snap into place with no pulses or bounces.

## Log
