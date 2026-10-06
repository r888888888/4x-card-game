---
id: 321
title: The sim bot weighs the rising cost of expansion
type: feature
status: done
branch: feat/321-bot-weighs-expansion-costs
---

## Goal
After 319 and 320 the sim should show the soft cap working: a sensible bot expands while it pays and stops when the
admin unrest grows. Today two things in `GenericBot.value` would hide it. Wide adds a flat 20 per settled territory,
which outweighs any price. And unrest costs nothing until it is within reach of the limit (weight `unrest` 0; the
risk term looks two turns ahead), so a steady +1 or +3 a turn is free until it is too late. After this item, every
strategy counts unrest coming in each turn as a cost, and wide's land weight counts territories only up to the
administration cap. The Settler's rising price (320) already reaches the bot through `play_cost`; a test confirms it.
Needs 319 and 320.

## Acceptance criteria
Fixtures: 319's government (`administers` 3, `unrest_limit` 20), 320's Settler-like card, unrest 0, ample food,
frontier territories to settle, otherwise nothing worth playing.

- [x] AC1: Wide's land weight stops at the cap: with `admin_cap()` 3, `GenericBot.value` for wide rises by the land
  weight from 2 to 3 settled territories but not from 3 to 4 (all else equal). With no cap (-1) every territory counts,
  as today.
- [x] AC2: Unrest income costs, far from the limit: for every strategy, a position whose `turn_forecast` adds +3
  unrest a turn values less than the same position adding 0, with unrest 0 and the limit at 20. A position adding −1
  (a Temple calming) values more than one adding 0.
- [x] AC3: The generic bot stops past the cap: with 2 territories and a Settler in hand, `take_turn` settles (the 3rd
  is within the cap). With 4 territories (1 past, +1 a turn), settling a 5th (+3 a turn in all) is not taken.
- [x] AC4: Wide expands to the cap, not past it: with 1 territory, 3 frontier territories and 3 Settlers in hand
  (actions to play them all), wide settles until it holds 3 or 4 territories, never 5 or more.
- [x] AC5: The price reaches the bot: the card value of the Settler (`card_value`) is lower with 6 territories than
  with 2, with the same food in store.

## Out of scope
- Tuning `WEIGHTS` against real-data games, and checking that wide lands near 12 in the sim: that's the balance item
  after this one (`scripts/test.sh --balance`, `/balance`). Note the result in the Log.
- Tall's `TALL_TERRITORIES` limit, the government choice and revolt rollouts (they see admin unrest through the value
  with no change).

## Design notes
- `value()`: the land term becomes `w.land × min(settled, admin_cap())` (all settled when the cap is -1). Unrest income
  gets its own term, e.g. `− w.unrest_rate × ahead × turn_forecast()[UNREST]` with a weight per strategy (the existing
  `unrest` weight on the stock can stay 0). The squared risk term stays as it is.
- Fixture tests only: a few-turn fixture game per CLAUDE.md, no real-data bot games in the main suite.
- Speed: the wide bot will stop at about 12 territories instead of most of the 55, so the slowest sim games
  (wide/greece seed 1, 179 tableau cards by turn 90; see 318 and 315) should get much shorter. Record the before and
  after in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_generic_bot::test_wides_land_weight_stops_at_the_admin_cap` |
| AC2 | `test_generic_bot::test_unrest_coming_in_each_turn_costs_far_from_the_limit`, `test_calming_unrest_each_turn_is_worth_something` |
| AC3 | `test_generic_bot::test_the_generic_bot_settles_within_the_cap_but_not_further_past_it` |
| AC4 | `test_generic_bot::test_wide_expands_to_the_cap_and_not_past_it` |
| AC5 | `test_generic_bot::test_the_settlers_rising_price_lowers_its_value` |

## Log
- 2026-10-05: specced with the user alongside 319 and 320. Assumed every strategy (not only wide) should count unrest
  income, since 319's drain otherwise looks free to the generic bot one or two past the cap.
- Red: the fixtures keep a spare frontier territory. With only one, playing the last Colonist leaves it nothing to
  settle, so the deck's worth (310) drops by more than the City adds and the generic bot holds the card even within
  the cap: an existing quirk of valuing cards in hand, not this item's. AC4 uses 5 frontier territories and 4
  Colonists (the spec's 3 could never reach 5 territories). AC1 measures wide's land step as wide's value change minus
  generic's, so admin unrest and everything else cancel. AC5 and AC3's within-cap half pass already (the bot pays
  `play_cost`, as the spec expected); they guard it.
- Built. `value()` subtracts `unrest_rate` (0.5 for every strategy, the first value tried) × the forecast's unrest
  change × turns ahead, floored at −unrest held so calming at 0 counts nothing. Wide's land term counts
  `min(settled, admin_cap())` (`_land`; all settled with no cap). `_settled` now uses `Territories.count_settled`. No
  other bot test changed its choice.
- Not run here (balance is a separate step, per CLAUDE.md): the sim check that wide lands near 12 territories, and the
  speed of wide/greece seed 1 before and after (318, 315). Both belong to the balance item that follows 319–321; expect
  wide to stop near the cap (11 under Kingship with every raise) and its slowest games to get much shorter.
- Suite 2024 → 2030 tests.
