---
id: 362
title: The Knowledge screen, the renewal ledger and the Realm scroll smoothly
type: feature
status: ready
branch: feat/362-smooth-scroll-everywhere
---

## Goal
356 made the Build modal's list glide (`SmoothScroll`, guide §7.17): a wheel notch eases and coasts instead of
jumping. The game's other vertical scroll areas still jump on Godot's `ScrollContainer`: the Knowledge screen's era
rows, the renewal modal's ledger and the Realm (`TableauView`). Give them the same glide, so scrolling feels the same
everywhere.

## Acceptance criteria
- [ ] AC1: Given the Knowledge screen open with more era rows than fit (a 1280 × 720 window), when one wheel-down notch
  reaches its rows with Reduce motion off, then its scroll area is a `SmoothScroll` and, once it settles, has moved
  `Anim.SCROLL_STEP` px (± 2).
- [ ] AC2: Given the renewal modal open (Anarchy's Renewal, 255) with more ledger rows than its column shows, then its
  ledger sits in a `SmoothScroll` and a wheel notch over the ledger settles `Anim.SCROLL_STEP` px down.
- [ ] AC3: Given the Realm with more cards than one row shows, when a wheel-down notch reaches it over a card (not
  only over the gaps), then the Realm (`TableauView`, now a `SmoothScroll`) settles `Anim.SCROLL_STEP` px down.
- [ ] AC4: Given the Realm scrolled, when a card is dragged onto it, then it still lands as before (the Realm stays the
  drop zone: the existing drag tests hold).
- [ ] AC5: Given Reduce motion on, then a wheel notch on each of the three jumps the step at once (356's AC3, per
  area).

## Out of scope
- The hand: it scrolls sideways (363).
- Keyboard follow on these areas (none has keyboard selection that leaves the view today).

## Design notes
- `TableauView extends SmoothScroll` instead of `ScrollContainer`; the Knowledge screen and the renewal modal build a
  `SmoothScroll` where they build a `ScrollContainer`. No change to `SmoothScroll` expected.
- Tests: the Knowledge and renewal cases in their own files (`test_knowledge_*`, `test_renewal_*`); the Realm in
  `test_tableau_*` or `test_board_*`. A wheel helper shared with `test_smooth_scroll.gd` moves to `tests/lib/`
  (the suite checks copies).
- Guide §7.17: "used by" grows; tokens.md's Scroll areas row lists them.
- `docs/testing.md` is at its 25 KB cap: adding no new test file avoids a new index row.

## Test plan
<!-- Filled in by Claude during the red phase. -->

## Manual check

## Log
- 2026-10-06: Follow-up from 356's Log.
