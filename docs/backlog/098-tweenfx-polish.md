---
id: 098
title: Evaluate TweenFX for card animation polish
type: feature
status: wontfix
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
- 2026-09-30: Researched; closed as wontfix with the user. TweenFX (github.com/EvilBunnyMan/TweenFX, MIT, v1.2.0, last
  commit 2026-03-28) loads and runs on Godot 4.7.2 (probed in a throwaway project), and frees cleanly with its node.
  It doesn't fit: it tweens `scale` / `position` directly, so on a card it overrides `CardMotion`'s per-frame scale
  and position (hover, drag, slide) instead of composing with them (probe: a tween wins over a `_process` writer
  while it runs); it captures the "original" value when an effect starts, so an effect started mid-hover or slide
  restores a stale value; it sets no pivot on Controls; it has no reduce-motion switch. The effects it would replace
  (shake, pop-in, land squash, pulse, fade) are 3–6 lines each here, so it adds a 1,095-line autoload to save ~20
  lines. 104's transitions (grow from a card's rect) aren't among its effects either. If one-off flourishes on
  non-card UI are wanted later, copy the two or three functions with attribution rather than install the addon.
