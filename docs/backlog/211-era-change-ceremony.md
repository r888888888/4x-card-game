---
id: 211
title: A new era opens with a ceremonial sheet
type: feature
status: ready
branch: feat/211-era-change-ceremony
---

## Goal
Reaching a new era is the game's one centred, big moment (`docs/design/transitions.html` transition 7): a sheet wipes
across the screen, rings draw out from the middle, and the era's name split-flaps in.

## Acceptance criteria
- [ ] AC1: Given the engine emits `milestone(MILESTONE_ERA)` (an era is added, at a turn's start), then after the
  board's refresh an era sheet covers the whole window: caps "A NEW ERA", the era's name from `era_name(era())` at
  `Tokens.TYPE_DISPLAY_XL`, and the turn ("Turn N").
- [ ] AC2: Reduce motion off: the sheet wipes in from the left over 0.40 s, three concentric rings draw out from the
  centre, then the name appears letter by letter (one character per 0.06 s, each flapping). With Reduce motion: the
  finished sheet fades in over 0.12 s.
- [ ] AC3: A click or key while it animates jumps to its finished state; a click or key on the finished sheet closes it
  (0.16 s fade) and play continues. Nothing else takes clicks or keys while it shows.
- [ ] AC4: Two eras added on the same turn show one sheet, naming the later era.
- [ ] AC5: It never shows during `new_game` (the engine sends no milestone then) or in a headless sim.
- [ ] AC6: An event modal or notice that arrives the same turn opens after the sheet closes.

## Out of scope
- Sound beyond the existing era milestone sound (191).

## Test plan
| AC | Test |
|---|---|

## Manual check
- [ ] Play to the second era (or use a fixture): the sheet, rings and flap read well; skip and continue feel right.

## Log
- Specced 2026-10-02 from the notes list.
