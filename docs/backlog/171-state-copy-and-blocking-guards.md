---
id: 171
title: Guard tests for state copies and the pending-decision block
type: feature
status: ready
branch: feat/171-state-copy-and-blocking-guards
---

## Goal
Two regression guards before the refactors and the items that add state (155's revolt and Anarchy fields, 160's
`station_uid`, 163's `moved_units`): a field left out of `copy()` would silently break the forecast and 159's
lookahead, and an action added without the pending-decision block would act while a choice is owed. From the
2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: Given a `GameState` with every script variable set to a value other than its default (the test reads the
  variables from `get_property_list()`, naming none), `copy()` returns equal values for each, and changing the copy's
  zones, cards, dictionaries and arrays leaves the original unchanged. A variable added to `GameState` without a copy
  line fails the test.
- [ ] AC2: The same for `CardInstance.copy()` (`uid`, `def`, `territory_uid`, `pop`, `keywords`, `turns_left`,
  `counters`, read from the property list).
- [ ] AC3: For each owed decision (explore, hand-limit discard, renewal, government choice) and for game over, every
  player action refuses with a non-empty `*_error` and returns false with the game unchanged (compared with a copy taken
  before), except the decision's own actions: `choose` for explore; `discard_card`, `buy`, `buy_tech` and the supply
  screen for a discard; `renew` for renewal; `choose_government` for the government choice. The actions: `play_card`,
  `grow`, `buy`, `buy_tech`, `end_turn`, `discard_card`, `choose`, `renew`, `choose_government`, `relieve_famine`,
  `restore_order`, `revolt`.
- [ ] AC4: AC3's action list is checked against `GameEngine`'s public methods that have a `<name>_error` partner, so a
  new action with no row fails the table.
- [ ] AC5: CLAUDE.md, Architecture rules: "State that lasts between actions lives in `GameState` or `CardInstance`,
  never on the engine or a module, and `copy()` copies it (the suite checks)."

## Out of scope
- Changing any rule: these are guards. If one fails on today's code it has found a bug: stop, report it and spec a bug
  item rather than fixing it here.

## Design notes
- Unlike other items, these tests are expected to **pass** at the red checkpoint (they guard current behavior). Show
  them failing for the right reason by temporarily dropping one copy line and one `_blocked_error` call, then put both
  back.
- A `state_equal(a, b)` helper built for AC1 also serves AC3's "unchanged".
- Uses 170's `fixture_db` and the `anarchy_case.gd` games for renewal and the government choice.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Log
- 2026-10-01: Specced from the project review.
