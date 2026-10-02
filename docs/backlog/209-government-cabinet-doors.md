---
id: 209
title: The government choice opens behind cabinet doors
type: feature
status: ready
branch: feat/209-government-cabinet-doors
---

## Goal
Choosing a government after Anarchy is a moment: two steel doors slide shut over the Realm and part to show the choice
(`docs/design/transitions.html` transition 5), and choosing closes them over it and opens them on the Realm.

## Acceptance criteria
- [ ] AC1: Given the engine's pending decision becomes the government choice (`PENDING_GOVERNMENT`), when the board
  refreshes (Reduce motion off), then two door panels (`CONTROL` fill, `TEXT` seam edge, labels "CHOOSE A" and
  "GOVERNMENT") slide in from the left and right edges and meet at the centre in 0.20 s (`Anim.MACHINED`), hold
  0.06 s, then the government overlay is shown under them and they part back to the edges in 0.26 s (`Anim.LATCH`).
  `Sfx.CABINET_CLOSE` plays as they meet and `Sfx.CABINET_PART` as they part.
- [ ] AC2: While the doors move, clicks and keys don't reach the overlay or the board.
- [ ] AC3: When a government is chosen, then the doors close over the overlay (0.20 s), the overlay hides, and they
  part on the Realm (0.26 s); the choice itself happens at the click (the engine state changes at once).
- [ ] AC4: With Reduce motion: no doors; the overlay fades in and out over 0.12 s.
- [ ] AC5: Given a game loaded or restarted while the choice is pending, the overlay shows (with its doors once) and
  never twice.

## Out of scope
- The explore and renewal overlays.

## Design notes
- Sounds `CABINET_CLOSE` / `CABINET_PART` already exist in `Sfx` (189 left them for the board).

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Revolt, play through Anarchy to its end: the doors close, part, and close/part again after choosing; compare
  with the mock at ¼ speed.

## Log
- Specced 2026-10-02 from the notes list.
