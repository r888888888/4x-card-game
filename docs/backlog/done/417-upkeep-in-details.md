---
id: 417
title: A building's details leave out its wealth upkeep
type: bug
status: done
branch: fix/417-upkeep-in-details
---

## Reproduction
- Seed: any (no randomness); a game with `"building_upkeep": 1` in the config (405's Manual check setup).
- Steps:
  1. Open the details of a base building that pays upkeep 1.
- Expected: the details' rules list the upkeep, as the card face does ("⟳ Upkeep 1 wealth", 405 AC8).
- Actual: `CardDef._face_rules` appends `upkeep_text()`, but `CardDef.rules_tooltip`, which `CardDetails._details`
  uses for `def_details(id).rules`, has no upkeep line.

## Acceptance criteria
- [x] AC1: Given 405's fixtures with `building_upkeep` 1, when reading `def_details("hut").rules`, then it contains the
  line "Each upkeep: pay 1 wealth"; for Big Hall (its own upkeep 2) "Each upkeep: pay 2 wealth".
- [x] AC2: Given the same game, when reading `def_details(id).rules` for Free Shed (upkeep 0), Hut Loft (an upgrade)
  and Colossus (a project), then no line mentions upkeep pay ("pay … wealth" under "Each upkeep").

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_building_upkeep::test_bug_417_a_paying_buildings_details_list_its_upkeep` |
| AC2 | `test_building_upkeep::test_bug_417_buildings_that_pay_nothing_have_no_upkeep_line_in_their_details` (a guard: passes already) |

## Design notes
- Wording follows the tooltip's other upkeep lines ("Each upkeep: " + the long effect text); the face keeps its short
  "⟳ Upkeep 1 wealth". New helper `CardDef.upkeep_long_text()` beside `upkeep_text()`.

## Root cause
405 added the upkeep line to the face (`_face_rules`) but not to `rules_tooltip`, which the details modal builds its
rules from; 405's AC8 tests read only `rules_text` (the face), so nothing checked the details.

## Manual check
With `"building_upkeep": 1` added to `data/config.json` locally (don't commit it), `godot --path . -- --seed 5`:
- [ ] A building's details show "Each upkeep: pay 1 wealth"; an upgrade's and a wonder's show none.

## Log
- 2026-10-08: specced from 405's Manual check.
- 2026-10-08: red tests written. Wording picked: "Each upkeep: pay N wealth". AC2's test already passes (nothing
  adds the line yet); it guards the fix.
- 2026-10-08: green. `CardDef.upkeep_long_text()`; `rules_tooltip` adds it after training when `upkeep > 0`.
  Tests 2636 → 2638.
