---
id: 379
title: Click a resource counter to see its next-upkeep change by source
type: feature
status: red-review
branch: feat/379-resource-breakdown-popover
---

## Goal
The bar shows food, wealth, insight and unrest with next upkeep's change beside each ("+1"), but not where that
change comes from. Clicking one of those counters opens a small popover listing every source of the change (each
card grouped by name, each event, crowding, overextension, the modifiers, pop eating, Anarchy's drain) and the net,
so the player can see why a number moves without adding up the board by hand. Unrest's popover also shows its limit:
the government's base and each modifier. Score and pop get the same popover in 380.

## Acceptance criteria
<!-- Setup unless stated: TEST_CARDS, population {start 2, food_upkeep 1, vp_per_pop 0} (test_forecast's
forecast_engine); Capital makes +2 food at upkeep, Farm +1 food, Stall +1 wealth, Granary +1 pop here. A row is
{label, count, amount}; label is the engine's text for the source. -->
- [ ] AC1: Given Capital and Farm, Farm and Stall on Homeland with 2 pop, when `upkeep_breakdown("food")` is called,
  then it returns, in order, `[{Capital, 1, +2}, {Farm, 2, +2}, {pop eats, 1, −2}]`, and `upkeep_breakdown("wealth")`
  returns `[{Stall, 1, +1}]`. Rows come in upkeep resolution order (crowding, overextension, working cards, events),
  then pop eating, then Anarchy's drain; copies of one card are one row whose count is the copies and amount their
  total; a source that changes the resource by 0 has no row. Nothing changes, is logged or emitted.
- [ ] AC2: For every resource, the rows' amounts sum to `upkeep_forecast()[resource]`, including when a clamp bites:
  Granary on Homeland with 2 pop gives food `[{Capital, 1, +2}, {pop eats, 1, −3}]` (it eats after growth); with
  unrest at its limit, a card's +1 unrest at upkeep that the limit holds back gives no row. On the last turn or after
  game over, every breakdown is `[]`.
- [ ] AC3: Given unrest on, a territory one tier past the government's tolerated tier (size unrest 1), two territories
  past its admin cap (admin unrest 1 + 2 = 3) and an active event that adds 1 unrest at upkeep, when
  `upkeep_breakdown("unrest")`, then it is `[{crowded territories, 1, +1}, {overextended realm, 1, +3}, {<event
  name>, 1, +1}]`.
- [ ] AC4: Given a working card with `modifiers: {insight_per_gain: 1}` and two working cards that each gain 2 insight
  at upkeep, when `upkeep_breakdown("insight")`, then the gaining cards' row has their printed +4 and the modifier
  card has its own row of +2 (1 per gain); the sum is the forecast's +6. With a −1 modifier and a single gain of 1 at
  upkeep, the rows are +1 and −1 (net 0, the floor not biting); where the 0 floor bites, the gaining card's row
  absorbs the difference so AC2 holds.
- [ ] AC5: Given Anarchy will rule next turn with a drain, when `upkeep_breakdown("food")`, then its last row is
  Anarchy's name with the drain as a negative amount, equal to what `upkeep_forecast()` subtracts for it.
- [ ] AC6: Given unrest on and a government with unrest_limit 4 plus two working cards with `unrest_limit` modifiers
  +1 and +2, when `unrest_limit_breakdown()` is called, then it returns `[{<government>, 1, 4}, {<card A>, 1, +1},
  {<card B>, 1, +2}]`, summing to `unrest_limit()` (7). With modifiers that would take it below 0, the rows still
  sum to `unrest_limit()` (the government's row absorbs the floor). It is `[]` when `unrest_limit()` is −1.
- [ ] AC7 (UI): Given a game in progress, when the player clicks the Food counter (or focuses it and presses Enter),
  then a popover opens under it showing one line per `upkeep_breakdown("food")` row (label, "×count" when count > 1,
  signed amount) and the net; the Unrest popover adds the limit rows from `unrest_limit_breakdown()` and their
  total. Clicking the same counter again, clicking anywhere outside, or Esc closes it (Esc does not also open the
  menu); clicking another counter swaps to that counter's popover. On the last turn it says there is no next upkeep.

## Out of scope
- Score and pop breakdowns (380, which reuses this popover).
- The odometer, the forecast figure and the hover tooltips: unchanged.
- Breaking down the stock on hand (only next upkeep's change; the player chose "just the change").
- Raids at the turn's start (turn_forecast's territory, not upkeep_forecast's).

## Design notes
- New engine queries (EngineQueries), each running upkeep on a fork like `upkeep_forecast`, so nothing changes:
  - `upkeep_breakdown(resource: String) -> Array[Dictionary]`: `[{label: String, count: int, amount: int}]`.
  - `unrest_limit_breakdown() -> Array[Dictionary]`: same row shape.
  The label is engine text (card name, event name, "Crowded territories", "Overextended realm", "Pop eats"), so the
  UI never names content.
- Attribution: record each resource's delta around each step `TurnLoop.resolve_upkeep` takes (size unrest, admin
  unrest, each working card's `_resolve`, each event's), then pop eating (`total_pop × food_upkeep` after upkeep
  growth) and Anarchy's drain. Recording actual deltas makes clamps (unrest limit, 0 floors) fall on the step they
  hit, so the rows always sum to the forecast. Avoid a second copy of the upkeep order: let resolve_upkeep take an
  optional per-step callback (or return per-step deltas) that the forecast and breakdown share.
- insight_per_gain (AC4): the gain op adds the modifier inside `EngineCore.gain`; the breakdown needs the bonus split
  out, e.g. the gain reports the printed part and the bonus part, and the bonus is credited to each working card
  with a nonzero insight_per_gain modifier in proportion to its modifier.
- Declared revolution (332): `Anarchy.before_upkeep` runs first on the fork, as in `upkeep_forecast`.
- UI: a new `Popover` control (ui/), not a `Modal` (no scrim, not centred): the §11.11 tooltip look (ink fill,
  inverse text, square, `label-caps` heading, then a two-column ledger: one row per source, a hairline, the net),
  anchored under its counter. main holds at most one; it takes Esc while open. Counter becomes focusable for Enter.
  TopBar gets a test hook for the open popover's lines. 380 reuses it.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_upkeep_breakdown::test_breakdown_groups_copies_and_ends_with_what_pop_eats`, `test_breakdown_changes_nothing` |
| AC2 | `test_pop_grown_at_upkeep_eats_in_the_pop_row`, `test_unrest_held_back_by_the_limit_gives_no_row`, `test_no_breakdown_on_the_last_turn_or_after_game_over`; `check_sums` in each engine test |
| AC3 | `test_unrest_rows_for_crowding_overextension_and_an_event` |
| AC4 | `test_insight_per_gain_has_its_own_row`, `test_a_negative_insight_per_gain_has_a_negative_row`, `test_where_the_floor_bites_the_gaining_card_absorbs_it` |
| AC5 | `test_anarchy_drain_is_the_last_row` |
| AC6 | `test_unrest_limit_breakdown_lists_the_government_then_its_modifiers`, `test_unrest_limit_rows_sum_to_the_floored_limit`, `test_no_unrest_limit_breakdown_without_a_limit` |
| AC7 | `test_clicking_a_counter_opens_its_breakdown_and_clicking_again_closes_it`, `test_the_popover_closes_on_esc_and_an_outside_click`, `test_enter_on_a_focused_counter_opens_it`, `test_the_unrest_popover_adds_the_limit`, `test_on_the_last_turn_the_popover_says_there_is_no_next_upkeep` |

## Manual check
- [ ] Mid-game with several farms, a Harvest event and a growing territory, click Food: rows read sensibly, copies
  grouped ("Farm ×3 +3"), the net matches the "+N" beside the counter.
- [ ] Click Unrest under a government with an unrest_limit modifier card in play: the limit rows and their total
  match the tooltip's limit.
- [ ] The popover reads in Night and Paper, doesn't run off the screen's edge at 1920 and at the smallest window,
  and closes on Esc, outside click and a second click; Tab focus reaches the counters in bar order.
- [ ] Sound: decide whether opening clicks like a key or is silent like a tooltip (§11.11).

## Log
- Red: AC1's Homeland has 3 pop, not 2: Farm, Farm and Stall need 3 workers, and with 2 the Stall would be idle (no
  wealth row). Labels are "Pop eats", "Crowded territories", "Overextended realm". The popover's test hooks are
  `main.breakdown_key()` ("" when closed) and `main.breakdown_rows()` ([[left, right], …]: "Farm ×2" / "+2", a
  real minus, then ["Net", "+N"]; Unrest adds the limit rows, the government unsigned, and ["Limit", "N"]; the last
  turn shows one line, "No next upkeep: this is the last turn."). `engine_queries.gd` is at 495 of its 500 lines, so
  the two queries need room: the plan is to move the raid queries down beside `defense` in `TerritoryQueries`
  (166 moved `defense`, `defense_parts` and `raid_warning` there).
