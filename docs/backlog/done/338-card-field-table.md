---
id: 338
title: DataLoader reads per-type fields from one table; 'requires' only applies to buildings
type: feature
status: done
branch: feat/338-card-field-table
---

## Goal
`engine/data_loader.gd` is at 638 lines and `_parse_card` is one 180-line if/elif over card types. `TYPE_FIELDS`
already says which types take a field, and the branches say it again: `defense` is read in both the city and the
building branch, each with its own minimum and default. New card fields are a recurring item shape (164 training,
301 tier, 319 administers, 320 cost_per_territory), and each one grows the chain. And `requires` sits in
`CARD_FIELDS`, so an action, city or tech with `requires` loads silently and ignores it; only buildings use it.

## Acceptance criteria
- [x] AC1: Given a card of any type but building or unit with `"requires": ["coastal"]`, when the cards load, then
  there is no error, the warning "'requires' only applies to buildings (ignored)" is given, and the card's `requires`
  is empty. A building's `requires` loads as before; a unit's still errors with "a unit can't have 'requires' (it can
  move, so it has no fixed land)".
- [x] AC2: Each integer field in `TYPE_FIELDS` has its minimum and default declared once, in one table. A table-driven
  test covers every (field, type) pair: a value below the minimum gives "'<field>' must be an integer >= <min>, not
  <value>", and leaving the field out gives the default.
- [x] AC3: `_parse_card` is at most 60 lines, with each type's own checks in a function of its own, and
  `engine/data_loader.gd` is at most 550 lines (structure test).
- [ ] AC4: Behaviour is pinned: every existing loader and content test (as 340 left them) passes unedited, the real data loads with the
  same warnings (none), and `scripts/sim.sh 20` output is identical before and after.
- [x] AC5: A new `add-card-field` skill (`.claude/skills/add-card-field/SKILL.md`) gives the recipe for a new card
  field: the field table entry, the `CardDef` var and comment, the type's parse function, its card text and details
  line, a loader test, a content invariant if the real data uses it, and PLAN.md's card data format.
  `docs/development-process.md`'s Files table lists it.

## Out of scope
- ConfigLoader (339).
- New fields or changing any existing field's minimum or default.

## Design notes
- Data format: `requires` moves from `CARD_FIELDS` to `TYPE_FIELDS` (`[CardDef.BUILDING]`); the unit keeps its
  specific error, checked before the generic warning.
- The table could extend `TYPE_FIELDS` entries to `{types, min, default}` for ints, keeping its "first type is the one
  the field is for" rule for warnings.
- Balance: none (no data changes).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_requires_on_a_card_that_is_not_a_building_is_ignored_with_a_warning`, `test_requires_loads_on_a_building_and_is_an_error_on_a_unit` |
| AC2 | `test_data_loader::test_every_int_field_on_every_type_has_its_minimum_and_default`; era's message rows in `test_tech_eras::test_era_field_validation` and `test_event_eras::test_event_era_validation` (edited, see Log) |
| AC3 | `test_data_loader::test_parse_card_is_short_and_the_loader_under_550_lines` |
| AC4 | The whole suite; `test_real_data_loads_without_warnings`; `scripts/sim.sh 20` before/after (Log) |
| AC5 | Manual: the skill file and the Files table row |

## Log
- 2026-10-06: specced from the project review; the user chose to split the loader work into two items.

- 2026-10-06: the user chose the standard message for era too ("'era' must be an integer >= 1, not 0", was "era: must
  be an integer >= 1"), so three approved rows' fragments change (test_tech_eras "era 0", test_event_eras "era 0" and
  "era not an integer"): the one exception to AC4's "unedited".
- 2026-10-06: built. `DataLoader.INT_FIELDS` ({min, default}, a default by type for slots and housing, `REQUIRED`,
  `SLOTS_PLUS_2`) and `_read_int_fields`, which sets each CardDef var by name; `requires` in `TYPE_FIELDS`
  (building), the unit's error kept in `CardTypeFields._unit` and its warning skipped in `_warn_other_fields`. The
  per-type checks and the type-only parsers (raid, discounts, eureka, discard, city_names) moved to the new
  `engine/card_type_fields.gd` (243 lines), one function per type; `_parse_card` is 19 lines (was 177) and
  `data_loader.gd` 466 (was 638). Cost, tags and effects got functions of their own too.
  Suite 2294 → 2298 (4 new tests in test_data_loader.gd: no room for a new file's row under testing.md's cap).
- Error order within a card can differ from before (int fields now read after effects, type checks after modifiers
  and flavor); no test depended on it.
- The add-card-field skill is listed in development-process.md's Files table; CLAUDE.md's TYPE_FIELDS line points to it.
- 2026-10-06: merged at the user's word before AC4's `scripts/sim.sh 20` before/after comparison finished; that
  check follows (AC4 stays open until it does).
