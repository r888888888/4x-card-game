---
id: 083
title: Famine — a lasting event that replaces starvation
type: feature
status: ready
branch: feat/083-famine-event
---

## Goal
Today each food short at upkeep starves 1 pop, and the next turn starts over. Replace that with a Famine: a
lasting event that arrives when pop goes hungry, gets worse each hungry upkeep, blocks growth, and ends only
once the pop is fed. Hunger becomes a crisis the player has to answer, not a one-off fine.

## Acceptance criteria
Population is on (`population: {start: 3, food_upkeep: 1, vp_per_pop: 1, famine: {card: "famine",
max_counters: 3}}`). Fixture event `famine`, "Famine": `{"op": "lose_pop", "amount": 1, "trigger": "upkeep"}`,
no `discard`. The Capital gives +2 food at upkeep. "Short" means pop needs more food than is on hand after upkeep
effects.

- [ ] AC1 (arrives): Homeland has 4 pop and food is 0 when the turn ends. At the next upkeep the Capital gives +2
  and the 4 pop eat 2 (food 0). A Famine becomes active with 1 counter (`famine_counters()` is 1), and 1 pop dies:
  Homeland 3. The old rule (1 pop per food short, which would leave 2) is gone.
- [ ] AC2 (escalates): Continuing AC1, food is 0 when the turn ends. At the next upkeep (+2, need 3, short) the
  Famine goes to 2 counters and 2 pop die: Homeland 1. Deaths use the `lose_pop` rule (072), one at a time: the
  territory with the most pop, ties first in tableau order. Pop never goes below 0, and with no pop left the rest
  of the deaths do nothing.
- [ ] AC3 (cap and one Famine): Given a Famine at 3 counters, a short upkeep kills 3 pop and leaves it at 3
  (`max_counters`). A short upkeep while a Famine is active never adds a second Famine: `active_events` holds at
  most one.
- [ ] AC4 (ends): Given a Famine at 2 counters, an upkeep where pop is fed in full (even with food exactly 0 after
  eating) kills nobody, and the Famine leaves the game: it is in no zone (not `active_events`, not
  `event_discard`), and `famine_counters()` is 0. A later short upkeep brings a new Famine with 1 counter. The
  Famine is never in the event deck, and the event phase never draws it.
- [ ] AC5 (no growth): While a Famine is active, `grow_error(home)` is "Famine: pop can't grow." and `grow` changes
  nothing. A `grow` op (Rally, Festival, Granary upkeep) adds no pop. Once the Famine ends, both work again.
- [ ] AC6 (Granary guard, replaces 060's starvation guard): Homeland has 4 pop and a working Silo, a Famine is at
  1 counter, and food is 0 when the turn ends. At the next upkeep (short) the Famine goes to 2 counters. The first
  famine death on Homeland is saved and the second happens: Homeland 3. Without the Silo: 2. A guard only saves
  deaths on its own territory, once per guard per upkeep, and an idle Silo saves none.
- [ ] AC7 (forecast): `upkeep_forecast().starve` is the pop the Famine would kill at the next upkeep after guards:
  1 in AC1's starting state, 2 in AC2's, 0 when pop would be fed. The food forecast is unchanged
  (net of what pop eats).
- [ ] AC8 (loader): with population on, `population.famine` is required. `card` must name an event card
  ("population.famine.card 'x' is not an event"), and `max_counters` must be an integer ≥ 1. The Famine card in
  `event_deck`, or any `discard` on it, is a load error naming the card.

## Out of scope
- Paying wealth to end a Famine: 084.
- Scaling deaths with how short the food is: a shortfall of 1 or 5 counts the same.
- A Famine that spreads, idles buildings on its own, or changes other rules.

## Design notes
- Upkeep order (`TurnLoop.start_turn`): card, tech and event upkeep, then `Population.feed`. `feed` eats what it
  can, then: short → create the Famine if none is active (`e._make_card(config.population.famine.card)` into
  `active_events`), add 1 counter up to `max_counters`, and resolve the Famine's `upkeep` effects once per counter;
  fed → remove an active Famine from the game and log "Famine ends.".
- `Events.resolve_upkeep` skips the Famine: its effects run only from `feed`, and it has no `turns_left`.
- Counters live on `CardInstance` (a new `counters` field, 0 by default), and `GameState.copy()` copies them so the
  forecast fork sees them. New query `famine_counters() -> int` (0 with no Famine).
- Depends on 072 (`lose_pop`) and 060 (`famine_guard`). The guard check moves from starvation into `lose_pop`
  deaths caused by the Famine; share one helper between `feed` and `upkeep_forecast`.
- **Supersedes approved tests**: the starvation tests from 011 (`tests/test_food_upkeep.gd`, plus starvation cases
  in `test_population`, `test_workers`, `test_forecast`, `test_events`, `test_wealth`, `test_tech_eras`) and 060's
  guard tests (in the 060 worktree, at red-review) describe the old rule. The user decided the new rule
  (2026-09-29). Flag each rewritten test at the red checkpoint.
- The test fixtures that turn population on need the `famine` block; the fixture Famine card joins the fixture
  data that `make_engine` loads.
- Real data: a `famine` event in `data/cards.json` and the `famine` block in `data/config.json`. Run the `balance`
  skill after it: deaths now scale with how long hunger lasts, not how deep.
- Card text: "Each hungry upkeep: +1 counter (max 3), −1 pop (largest territory) per counter. Ends when your pop
  is fed." The event panel (068) shows "N counters" instead of "N turns left".
- The top bar's starve warning (`ui/top_bar.gd`) keeps reading `starve`; its wording may need "famine".

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_famine::test_…` |

## Manual check
- [ ] Going hungry puts a Famine in the Events row with "1 counter", and it disappears on the first fed upkeep.
- [ ] The top bar warns in the famine turn with the right death count.
- [ ] The log names the territory for each death and the pop a Granary saved.

## Log
- Decided (user, 2026-09-29): Famine replaces starvation; deaths use `lose_pop` (largest territory, no choice);
  counters cap at 3; fed check after eating; one Famine at a time; no growth during a Famine; the Granary guard
  applies to famine deaths; a Famine leaves the game when it ends.
