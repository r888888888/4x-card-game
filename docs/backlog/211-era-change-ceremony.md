---
id: 211
title: A new era opens with a ceremonial sheet
type: feature
status: red-review
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
| AC1 | `test_era_sheet::test_a_new_era_covers_the_window_with_its_name_and_the_turn` |
| AC2 | `test_the_sheet_wipes_in_then_rings_then_the_name_letter_by_letter`, `test_with_reduce_motion_the_finished_sheet_fades_in` |
| AC3 | `test_a_click_skips_to_the_end_and_a_second_closes_it`, `test_a_key_skips_and_closes_and_nothing_else_takes_keys` |
| AC4 | `test_two_eras_on_one_turn_show_one_sheet_naming_the_later` |
| AC5 | `test_a_new_game_that_starts_in_a_later_era_shows_no_sheet` (the headless sim has no UI: nothing to test there) |
| AC6 | `test_an_event_drawn_the_same_turn_opens_after_the_sheet_closes` |

New hook: `main.era_sheet` (`is_open()`, `finished()`, `covered_rect()`, `kicker_text()`, `era_text()`, `name_label`,
`turn_text()`, `rings()`). No engine change: the sheet listens to `milestone(MILESTONE_ERA)`.

## Manual check
- [ ] Play to the second era (or use a fixture): the sheet, rings and flap read well; skip and continue feel right.

## Log
- Specced 2026-10-02 from the notes list.
