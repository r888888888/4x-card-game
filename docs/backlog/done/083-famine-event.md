---
id: 083
title: Famine — a lasting event that replaces starvation
type: feature
status: done
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

- [x] AC1 (arrives): Homeland has 4 pop and food is 0 when the turn ends. At the next upkeep the Capital gives +2
  and the 4 pop eat 2 (food 0). A Famine becomes active with 1 counter (`famine_counters()` is 1), and 1 pop dies:
  Homeland 3. The old rule (1 pop per food short, which would leave 2) is gone.
- [x] AC2 (escalates): Continuing AC1, food is 0 when the turn ends. At the next upkeep (+2, need 3, short) the
  Famine goes to 2 counters and 2 pop die: Homeland 1. Deaths use the `lose_pop` rule (072), one at a time: the
  territory with the most pop, ties first in tableau order. Pop never goes below 0, and with no pop left the rest
  of the deaths do nothing.
- [x] AC3 (cap and one Famine): Given a Famine at 3 counters, a short upkeep kills 3 pop and leaves it at 3
  (`max_counters`). A short upkeep while a Famine is active never adds a second Famine: `active_events` holds at
  most one.
- [x] AC4 (ends): Given a Famine at 2 counters, an upkeep where pop is fed in full (even with food exactly 0 after
  eating) kills nobody, and the Famine leaves the game: it is in no zone (not `active_events`, not
  `event_discard`), and `famine_counters()` is 0. A later short upkeep brings a new Famine with 1 counter. The
  Famine is never in the event deck, and the event phase never draws it.
- [x] AC5 (no growth): While a Famine is active, `grow_error(home)` is "Famine: pop can't grow." and `grow` changes
  nothing. A `grow` op (Rally, Festival, Granary upkeep) adds no pop. Once the Famine ends, both work again.
- [x] AC6 (Granary guard, replaces 060's starvation guard): Homeland has 4 pop and a working Silo, a Famine is at
  1 counter, and food is 0 when the turn ends. At the next upkeep (short) the Famine goes to 2 counters. The first
  famine death on Homeland is saved and the second happens: Homeland 3. Without the Silo: 2. A guard only saves
  deaths on its own territory, once per guard per upkeep, and an idle Silo saves none.
- [x] AC7 (forecast): `upkeep_forecast().starve` is the pop the Famine would kill at the next upkeep after guards:
  1 in AC1's starting state, 2 in AC2's, 0 when pop would be fed. The food forecast is unchanged
  (net of what pop eats).
- [x] AC8 (loader): with population on, `population.famine` is required. `card` must name an event card
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
| AC1 | `test_famine::test_a_short_upkeep_brings_a_famine_with_1_counter` |
| AC2 | `test_famine::test_a_famine_escalates_each_hungry_upkeep`, `::test_famine_deaths_use_the_most_pop_rule` |
| AC3 | `test_famine::test_counters_stop_at_max_and_there_is_one_famine` |
| AC4 | `test_famine::test_a_fed_upkeep_ends_the_famine_and_it_leaves_the_game`, `::test_fed_with_exactly_0_food_left_ends_the_famine`, `::test_a_later_short_upkeep_brings_a_new_famine` |
| AC5 | `test_famine::test_no_growth_during_a_famine`, `::test_growth_works_again_after_the_famine` (guard) |
| AC6 | `test_famine::test_a_guard_saves_the_first_famine_death_on_its_territory` |
| AC7 | `test_famine::test_forecast_starve_is_the_famines_deaths` |
| AC8 | `test_famine::test_famine_config_validation`, `::test_the_famine_card_is_never_in_the_event_deck_and_has_no_discard` |

Rewritten approved tests (old rule: 1 death per food short; new: 1 death per Famine counter):
| File | Test | Was → now |
|---|---|---|
| `test_food_upkeep` | `test_each_unpaid_food_rechecks_the_biggest_territory` → `test_a_deeper_shortfall_still_kills_1_pop_at_the_first_famine` | 2 short: 2 deaths → 1 |
| `test_forecast` | `test_forecast_starve_with_no_food` | starve 2 → 1 |
| `test_famine_guard` | `test_silo_saves_the_first_starving_pop` | Homeland 3 → 4 |
| `test_famine_guard` | `test_without_silo_both_starve` → `test_without_silo_the_famine_kills_1` | 2 → 3 |
| `test_famine_guard` | `test_silo_on_another_territory_does_not_save_homeland` | Homeland 1 → 2 |
| `test_famine_guard` | `test_idle_silo_saves_none` | 0 → 1 |
| `test_famine_guard` | `test_forecast_starve_counts_the_guard` / `test_forecast_starve_without_guard` | starve 1 → 0 / 2 → 1 |
| `test_tech_eras` | `test_pop_that_starves_does_not_count` | total pop 2 → 3 |
| `test_wealth` | `test_starvation_does_not_spend_wealth` | pop 0 → 1 |

## Manual check
Run `godot --path .`, start any seed, and end turns without playing food cards until pop outgrows food (or grow pop
with food first).
- [ ] Going hungry puts a Famine in the Events row with "1 counter", and it disappears on the first fed upkeep.
- [ ] The top bar warns in the famine turn with the right death count.
- [ ] The log names the territory for each death and the pop a Granary saved.

## Log
- Decided (user, 2026-09-29): Famine replaces starvation; deaths use `lose_pop` (largest territory, no choice);
  counters cap at 3; fed check after eating; one Famine at a time; no growth during a Famine; the Granary guard
  applies to famine deaths; a Famine leaves the game when it ends.
- 2026-09-30: Red at 623 tests (was 610), 23 failing (13 new, 9 rewritten, 1 loader warning). Fixtures:
  `TEST_CARDS` gains the Famine event and `raw_config` adds `FAMINE` to a population block without one, so the 19
  files that turn population on need no edits. Most starvation tests keep their numbers: a first shortfall of any
  size now kills 1, the same as the old rule for 1 short.
- Approved at red. Green: `Population.feed` brings, worsens and ends the Famine; `Population.famine`,
  `GameEngine.famine_counters()`; guards now save the Famine's `lose_pop` deaths (`GameEngine._famine_guards`, set
  only during `feed`); `Events.resolve_upkeep` skips the Famine; no growth during it (`grow_error`, `add_pop`);
  `CardInstance.counters` (copied by `copy()`); `CardDef.has_discard` for the loader's no-discard rule.
- The normalized famine block lives in `config.famine`, not `config.population.famine`, so the two approved
  `test_population` tests that compare the population block exactly stay as they are.
- **Changed at green, approved test**: `test_content::test_every_real_event_is_in_the_event_deck` now skips the
  configured famine card: AC8 forbids it in `event_deck`, so the test and the spec couldn't both hold.
- Added test-first: `GameEngine.event_counters(uid)` (the Famine's counters, else 0), for the event panel's
  "N counters" (`CardView.set_event_info(turns_left, counters)`). The top bar's food tooltip says "famine, N pop
  will die". Real data: a `famine` event whose `text` is the design note's wording, and the famine block in config.
- Sim (20 seeds), main → this: identical (score 78.85, pop 13.00): the bot never goes hungry in these seeds.
