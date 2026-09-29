---
id: 047
title: Field readers in their own helper; card type and resource constants
type: feature
status: review
branch: feat/047-loader-fields-and-constants
---

## Goal
The field readers `read_int` / `read_string` live on `Effect` but read card and config fields too, and `Effect`
and `DataLoader` depend on each other. Card types and the resources `food` / `wealth` are string literals across
the engine and UI. Pure refactor: no loader message, rule or data format changes.

## Acceptance criteria
- [x] AC1: `engine/fields.gd` (`class_name Fields`) holds `read_int`, `read_string` and `as_int`; `Effect` and
  `DataLoader` call it, and `Effect` no longer references `DataLoader`.
- [x] AC2: Card-type-specific fields come from one table (type -> allowed fields). The "only applies to …"
  warnings and unknown-field warnings are derived from it, with the same messages as today.
- [x] AC3: Card types and the two special resources are constants (e.g. `CardDef.BUILDING`,
  `GameEngine.FOOD`). `engine/` and `ui/` have no string literals `"building"`, `"territory"`, `"city"`,
  `"tech"`, `"action"`, `"food"` or `"wealth"` outside those definitions.
- [x] AC4: The suite is green without editing any test, the real data loads with the same errors (none) and
  warnings (none), and the 20-seed sim (042) output is identical before and after.

## Out of scope
- Making food and wealth configurable (decided: they stay built in, as named constants).
- Zone name constants in tests.

## Test plan
| AC | Test |
|---|---|
| AC1–AC3 | refactor, guarded by the existing suite (no test edited) |
| AC4 | full suite; real data 0 errors / 0 warnings; `scripts/sim.sh 20` identical |

## Log
- 2026-09-29: Approved by the user ("do 047"). Pure refactor, no new tests; `git diff main -- tests` is empty.
- AC1: `engine/fields.gd` (`Fields.as_int`, `read_int`, `read_string`); the loader, registry and effects call it;
  `Effect` no longer references `DataLoader`.
- AC2: `DataLoader.TYPE_FIELDS` (field -> types, first = the type it's for) and `TYPE_PLURALS`; the "only applies
  to …" warnings and the unknown-field check come from it. Warnings keep their text and order.
- AC3: `CardDef.ACTION/BUILDING/CITY/TERRITORY/TECH` (+ `TYPES`) and `GameEngine.FOOD/WEALTH`. Left as literals:
  the config key `"territory"` in `starting.territory` (data_loader.gd, 2 places); it names a config field, not a
  card type.
- AC4: suite 325/325 green; real data loads with 0 errors, 0 warnings; `scripts/sim.sh 20` output identical
  before and after (score mean 27.75, cities 0.80, pop 6.20, techs 5.00, bought 0, era 2).
