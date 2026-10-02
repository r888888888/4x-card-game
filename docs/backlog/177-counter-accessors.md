---
id: 177
title: Find the top bar's counters by name, not by their text
type: feature
status: review
branch: feat/177-counter-accessors
---

## Goal
The mid-century restyle (178–182, [docs/design/mcm-style-guide.md](../design/mcm-style-guide.md)) drops the words
from the top bar ("Food: 3 (+1)" becomes a glyph and "3 (+1)") and later turns the figures into rolling odometers.
About 60 tests find a counter today by the text it starts with ("Food:", "Wealth:", "Pop:", …), so each of those
changes would break them for no reason. This item gives the counters stable names first, with no visible change, so
the restyle items only change what they mean to change. The Godot spike (`spike/mcm-godot`) showed the breakage.

## Acceptance criteria
- [x] AC1: Given a started game, when a test asks `main.counter(key)` for each of `GameEngine.FOOD`,
  `GameEngine.WEALTH`, `GameEngine.INSIGHT`, `GameEngine.UNREST`, `TopBar.SCORE`, `TopBar.POP` and `TopBar.TURN`, then
  each returns a different Control inside the top bar, and an unknown key returns null.
- [x] AC2: Given a started game with 3 food and +1 food forecast for the next upkeep, then `main.counter_text(GameEngine.FOOD)`
  is "Food: 3 (+1)", exactly the text the bar shows today; for every other key it equals that counter's text as
  shown (for example "Turn 1 / 100" on turn 1 of 100); an unknown key gives "".
- [x] AC3: Given unrest is off (the config has none), then `main.counter(GameEngine.UNREST)` still returns its counter
  and the counter is not visible; with population off, the same for `TopBar.POP`.
- [x] AC4: Given the Supply screen is open, then `main.supply.counter(GameEngine.WEALTH)` returns the screen's own
  wealth counter and `main.supply.counter_text(GameEngine.WEALTH)` its text ("Wealth: 10" with 10 wealth); the discard
  counter is `main.supply.counter(SupplyScreen.DISCARD)`.
- [x] AC5: No test under `tests/` finds a counter by its text any more: `test_ui_structure` fails if a test file contains
  one of the string literals "Food:", "Wealth:", "Insight:", "Unrest:", "Score:" or "Pop:". The tests that did
  (`test_resource_tokens`, `test_grow_meter`, `test_insight`, `test_unrest`, `test_board_layout`) use `counter` and
  `counter_text` instead and assert the same things.

## Out of scope
- Any change to what the counters look like or say (180, 181).

## Design notes
- `TopBar.counter(key) -> Control` and `TopBar.counter_text(key) -> String`, with constants `TopBar.SCORE`,
  `TopBar.POP`, `TopBar.TURN` for the non-resource counters; `MainScreen.counter` / `counter_text` hand through to the
  top bar (tests never touch `_top_bar`). `SupplyScreen` gets the same pair for its wealth and discard counters.
- `counter_text` exists so 181 can turn a counter into a glyph + odometer + forecast without the text tests moving
  again: it keeps returning the whole reading.
- AC5 is a guard against the old habit coming back; it names the six prefixes, not every possible text.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_counters::test_each_counter_is_a_different_control_in_the_top_bar`, `test_an_unknown_key_has_no_counter` |
| AC2 | `test_counters::test_the_food_counter_text_is_the_reading_the_bar_shows`, `test_each_counter_text_is_that_counters_text`, `test_an_unknown_key_has_no_text` |
| AC3 | `test_counters::test_the_unrest_and_pop_counters_exist_but_hide_when_off` |
| AC4 | `test_counters::test_the_supply_screen_names_its_wealth_and_discard_counters` |
| AC5 | `test_ui_structure::test_no_test_finds_a_counter_by_its_text` (and the migrated tests in `test_resource_tokens`, `test_grow_meter`, `test_insight`, `test_unrest`, `test_board_layout`) |

## Log
- 2026-10-01: Specced from the mid-century style guide and the `spike/mcm-godot` findings (118 tests failed on the
  spike, about 60 of them only because they found counters by text).
- 2026-10-02: Built. `TopBar.counter` / `counter_text` (+ `SCORE`, `POP`, `TURN`), passed through by `MainScreen`;
  `SupplyScreen.counter` / `counter_text` (+ `DISCARD`). The five test files now ask for counters by key; their
  `only_label` helpers went with it. The AC5 guard matches the exact literals (`"Food:"`), so full readings like
  "Unrest: 2 / 5 (+1)" may still be asserted.
