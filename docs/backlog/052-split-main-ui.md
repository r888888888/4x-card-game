---
id: 052
title: Split ui/main.gd into components
type: feature
status: draft
branch: feat/052-split-main-ui
---

## Goal
`ui/main.gd` is 1,521 lines. After 049 and 050 remove its rules, split what's left into components so UI changes
touch one small file. No visible change.

## Acceptance criteria
- [ ] AC1: The supply screen, choice overlays (explore and research), top bar, tableau view, drag controller and
  keyboard focus each live in their own script under `ui/`, and `main.gd` is 500 lines or fewer.
- [ ] AC2: The UI smoke test (045) passes unchanged, and no component reads engine state that has an engine query.

## Out of scope
- Any visual or behavior change; scene files for layout (layout stays built in code).

## Manual check
- [ ] Drag to play, double-click targeting, keyboard play (arrows, Enter, D, E, S, Esc), supply screen buying,
  explore and research choices, hand-limit discard, menu (seed, restart, reduce motion), game over and replay:
  all as before.

## Log
