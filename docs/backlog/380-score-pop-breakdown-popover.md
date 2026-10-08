---
id: 380
title: Click Score or Pop to see what makes it up
type: feature
status: review
branch: feat/380-score-pop-breakdown-popover
---

## Goal
After 379, the resource counters open a popover with their sources. Score and Pop do the same: Score lists the VP
each card gives (grouped by name), the VP effects have added and the VP from pop; Pop lists each settled territory's
pop. The player sees where their points and people are without counting the board.

## Acceptance criteria
<!-- Setup unless stated: TEST_CARDS, population {start 2, food_upkeep 1, vp_per_pop 1}; Capital (city, 2 VP),
Temple (building, 1 VP), Nomads (civilization, 1 VP). Rows are 379's {label, count, amount}. Depends on 379. -->
- [x] AC1: Given Capital, two Temples working on Homeland with 2 pop, Nomads as the civilization and 3 bonus score
  from effects, when `score_breakdown()` is called, then it returns `[{Capital, 1, 2}, {Temple, 2, 2}, {Nomads, 1,
  1}, {<effects label>, 1, 3}, {<pop label>, 2, 2}]` (cards in tableau then always-on zone order, effects, then pop
  with count = pop and amount = pop × vp_per_pop), and the amounts sum to `score()` (10). A card with 0 VP has no
  row; zero bonus score and population off give no effects or pop row.
- [x] AC2: Given a card that has fallen back below its tier (301) and an unfinished site (286), each with printed VP,
  when `score_breakdown()`, then neither has a row, and the sum still equals `score()`.
- [x] AC3: Given Homeland with 3 pop and a settled Grassland with 1 pop, when `pop_breakdown()` is called, then it
  returns `[{Homeland, 1, 3}, {Grassland, 1, 1}]` in tableau order, one row per territory (not grouped: the label is
  `territory_name(uid)`, so a renamed territory shows its new name), summing to `total_pop()`. With population off
  it is `[]`.
- [x] AC4 (UI): Given a game in progress, when the player clicks the Score counter (or focuses it and presses Enter),
  then 379's popover opens under it with one line per `score_breakdown()` row and the total; clicking Pop shows
  `pop_breakdown()`'s rows and the total. It closes and swaps as 379's AC7 says.

## Out of scope
- Score from next turn's upkeep (`turn_forecast`): the popover shows the score as it stands.
- Splitting bonus score by the card or event that gave it: bonus_score is one stored total today, so effects VP is
  one row. A per-source split would need state recording each VP gain; spec it separately if wanted.

## Design notes
- New engine queries (EngineQueries): `score_breakdown()` and `pop_breakdown()`, both `Array[Dictionary]` of
  `{label, count, amount}`. `score_breakdown` walks the same zones and skips the same cards as `score()`; have
  `score()` sum the breakdown so the two can't drift.
- The effects and pop labels are engine text, so the UI names nothing.
- UI: TopBar wires Score and Pop to 379's Popover.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_score_breakdown::test_score_breakdown_lists_cards_then_effects_then_pop`, `test_no_effects_or_pop_row_without_them` |
| AC2 | `test_fallen_back_cards_and_unfinished_sites_have_no_row` |
| AC3 | `test_pop_breakdown_lists_each_territory_in_tableau_order`, `test_no_pop_breakdown_with_population_off` |
| AC4 | `test_clicking_score_opens_its_breakdown`, `test_enter_on_focused_pop_opens_it` |

## Manual check
- [ ] Mid-game, click Score: the rows read sensibly and total the figure; click Pop with a renamed territory: its new
  name shows.

## Log
- Red: labels "Effects" (bonus score) and "Pop" (count = pop). Popover lines: Score rows unsigned ("Capital" / "2",
  a real minus for negative VP) then ["Total", score]; Pop rows [territory name, pop] then ["Total", total pop]. Both
  under a heading ("Score", "Pop"). Nomads comes from TEST_CIVS via `starting.civilization`.
- Green: `ScoreBreakdown.score_rows` walks the zones `score()` did and skips the same cards; `score()` now sums its
  rows. `pop_rows` leaves out a territory with 0 pop, like every breakdown's 0 rows. 379's row bookkeeping moved into
  `Ledger` (`engine/ledger.gd`), which both breakdowns build on. The top bar's `BREAKDOWNS` gained Score and Pop:
  rows unsigned, then "Total". The pop VP row reads "Pop ×2 / 2" (count is the pop).
- Test fix (approved): `with_main` restarts the game, so the Score popover test's Temple and bonus-score reset moved
  inside its closure; its assertions are unchanged.
