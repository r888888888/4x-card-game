---
id: 321
title: The sim bot weighs the rising cost of expansion
type: feature
status: ready
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

- [ ] AC1: Wide's land weight stops at the cap: with `admin_cap()` 3, `GenericBot.value` for wide rises by the land
  weight from 2 to 3 settled territories but not from 3 to 4 (all else equal). With no cap (-1) every territory counts,
  as today.
- [ ] AC2: Unrest income costs, far from the limit: for every strategy, a position whose `turn_forecast` adds +3
  unrest a turn values less than the same position adding 0, with unrest 0 and the limit at 20. A position adding −1
  (a Temple calming) values more than one adding 0.
- [ ] AC3: The generic bot stops past the cap: with 2 territories and a Settler in hand, `take_turn` settles (the 3rd
  is within the cap). With 4 territories (1 past, +1 a turn), settling a 5th (+3 a turn in all) is not taken.
- [ ] AC4: Wide expands to the cap, not past it: with 1 territory, 3 frontier territories and 3 Settlers in hand
  (actions to play them all), wide settles until it holds 3 or 4 territories, never 5 or more.
- [ ] AC5: The price reaches the bot: the card value of the Settler (`card_value`) is lower with 6 territories than
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
| AC1 | `test_generic_bot::test_…` |

## Log
- 2026-10-05: specced with the user alongside 319 and 320. Assumed every strategy (not only wide) should count unrest
  income, since 319's drain otherwise looks free to the generic bot one or two past the cap.
