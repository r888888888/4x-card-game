---
id: 049
title: Engine queries for the rules the UI works out itself
type: feature
status: done
branch: feat/049-engine-queries-for-ui
---

## Goal
`ui/main.gd` re-derives rules that belong in the engine: `_hand_error`, `_supply_block_reason`, the End turn
button's condition, which era unlocks are still ahead, and which cards sit on which territory. Move each into
an engine query and have the UI call it (CLAUDE.md architecture rule).

## Acceptance criteria
<!-- Fixtures: TEST_CARDS; Capital on Grassland (2 slots) unless stated. -->
- [x] AC1: `playable_error(uid)` is "" when the card can be played on at least one target. Given a Farm in hand,
  plenty of food and two settled territories with room, then `play_error(uid)` is "Choose a territory for Farm."
  and `playable_error(uid)` is "". Given 1 food, it is "Farm needs 2 food (you have 1).". Given Grassland full
  (2 Farms) and no other territory, it is "No territory with a free slot.".
- [x] AC2: `end_turn_error()` is "" normally; "Choose a territory first." with an explore choice open; "Buy a tech
  or decline first." with techs revealed; "Discard down to 7 cards first." with a discard owed; "The game is
  over." after the game ends. `end_turn()` does nothing whenever it isn't "".
- [x] AC3: `supply_error()` (can the supply screen open) is "" normally and while a discard is owed (you can
  browse), and gives the AC2 messages for game over, an explore choice and open research.
- [x] AC4: Given `era_unlocks` `{"2": {"pop": 8}, "3": {"wealth": 30}}`, then `upcoming_era_unlocks()` is
  `{2: {pop: 8}, 3: {wealth: 30}}` at the start and `{3: {wealth: 30}}` after `add_era(2)`.
- [x] AC5: `territory_groups()` returns the tableau as `[{territory: uid, cards: [uids]}]`: each settled territory
  first in its own group, then the cards on it in tableau order; groups in order of first appearance; cards with
  no territory last in a group with `territory: -1`. Given the Capital on Homeland, a Farm on Homeland and a
  settled River with a City, then `[{homeland, [homeland, capital, farm]}, {river, [river, city]}]`.
- [x] AC6: `main.gd` uses these queries and no longer has `_hand_error`, `_supply_block_reason` or its own
  grouping or era filtering.

## Out of scope
- Changing what the UI shows.
- The pending-decision model (050).

## Design notes
- Update the `tdd` skill's refactor step: check for logic added to `ui/`.

## Test plan
| AC | Test (`tests/test_ui_queries.gd`) |
|---|---|
| AC1 | `test_playable_error_ignores_the_choice_of_territory`, `test_playable_error_reports_a_missing_cost`, `test_playable_error_reports_no_free_slot` |
| AC2 | `test_end_turn_error_is_empty_normally`, `test_end_turn_error_names_what_blocks_it_and_end_turn_does_nothing` |
| AC3 | `test_supply_error_allows_browsing_normally_and_while_discarding`, `test_supply_error_blocks_during_choices_and_after_the_game` |
| AC4 | `test_upcoming_era_unlocks_drops_eras_already_reached` |
| AC5 | `test_territory_groups_put_each_territory_first_with_its_cards`, `test_territory_groups_put_cards_with_no_territory_last` |
| AC6 | UI refactor, no engine test; `test_ui_smoke` and the Manual check cover it |

## Manual check
- [ ] Hand cards grey out exactly as before, with the same reasons (too expensive, no slot, needs keyword).
- [ ] The End turn and Supply buttons disable and show the same tooltips as before; the research info tooltip
  lists only eras still to come; tableau groups look the same.

## Log
- 2026-09-29: spec approved (AC1 starts on Grassland; `playable_error` checks the first valid target, as `_hand_error` did).
  Engine: `supply_error` is the old `_busy_error` minus the discard check (`_choice_error`); `end_turn_error` is
  `_busy_error`, and `end_turn` refuses on it. `main.gd` lost `_hand_error`, `_supply_block_reason`, its grouping and
  era filtering. The `tdd` skill's refactor step now checks `ui/` for logic. 331 → 341 tests.
