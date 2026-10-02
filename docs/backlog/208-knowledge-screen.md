---
id: 208
title: Knowledge as a screen of era rows, slid in on its rail
type: feature
status: ready
branch: feat/208-knowledge-screen
---

## Goal
The tech tree becomes the mock's Knowledge screen (`docs/design/transitions.html` transition 1): a navigated screen
with a breadcrumb ("Realm / Knowledge"), each era a row of tech tiles, sliding in from the right while the Realm
shifts 24 px left under it. It keeps everything the modal does today (state, cost, eureka, prerequisite, Learn,
details).

## Acceptance criteria
- [ ] AC1: Given a game in progress, when Knowledge (top strip) or T is pressed, then a Knowledge screen is pushed on
  the board's play-area navigator (the one whose root is the Realm, 101), with a `ScreenHeader` reading
  "Realm / Knowledge" and context caps "Turn N · <era name>"; the `TechTreeModal` is gone and nothing opens it.
- [ ] AC2: The screen shows one row per era from `tech_eras()`, top to bottom, headed with `era_name(n)` in caps; each
  tech of the era from `tech_tree()` is a tile showing its name and its state with a mark and a word (researched ✓,
  available with its cost now, locked with "needs <prerequisite>", future), as the modal does today (059, 140).
  An era not reached yet is dimmed (`FUTURE`) and shows its unlock thresholds.
- [ ] AC3: An available tech's tile has its Learn button (enabled when `buy_tech_error` is "", else disabled with the
  error as tooltip); pressing it learns the tech and the tile updates in place, the screen staying open. A met
  eureka shows ✔ (141).
- [ ] AC4: Clicking a tile (not its Learn button) opens the card details modal over the screen.
- [ ] AC5: Back, Esc, T or the breadcrumb's "Realm" goes back to the Realm and gives focus back to what had it.
- [ ] AC6: Push (Reduce motion off): the screen slides in from the right edge in 0.32 s (`Anim.MACHINED`) while the
  Realm moves 0 → −24 px; back: out in 0.26 s (`Anim.RELEASE`), the Realm returning to 0. Reduce motion: a 0.12 s
  fade, no movement.
- [ ] AC7: Given a territory view is open, opening Knowledge pushes over it (breadcrumb "Realm / Delta Marsh /
  Knowledge"), and back returns to the territory view.

## Out of scope
- Tech rules.

## Design notes
- `ui/tech_tree_modal.gd` becomes `ui/knowledge_screen.gd`; its tests move with it.
- The navigator's rail slide (189) may already cover AC6's sheet; the Realm's 24 px shift is new.

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Compare with `transitions.html` transition 1 at ¼ speed in both palettes; a 3-era tree fits at 1280×720 (rows
  wrap or scroll).

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: a navigated screen with era rows, not a restyled modal.
