---
id: 047
title: Field readers in their own helper; card type and resource constants
type: feature
status: draft
branch: feat/047-loader-fields-and-constants
---

## Goal
The field readers `read_int` / `read_string` live on `Effect` but read card and config fields too, and `Effect`
and `DataLoader` depend on each other. Card types and the resources `food` / `wealth` are string literals across
the engine and UI. Pure refactor: no loader message, rule or data format changes.

## Acceptance criteria
- [ ] AC1: `engine/fields.gd` (`class_name Fields`) holds `read_int`, `read_string` and `as_int`; `Effect` and
  `DataLoader` call it, and `Effect` no longer references `DataLoader`.
- [ ] AC2: Card-type-specific fields come from one table (type -> allowed fields). The "only applies to …"
  warnings and unknown-field warnings are derived from it, with the same messages as today.
- [ ] AC3: Card types and the two special resources are constants (e.g. `CardDef.BUILDING`,
  `GameEngine.FOOD`). `engine/` and `ui/` have no string literals `"building"`, `"territory"`, `"city"`,
  `"tech"`, `"action"`, `"food"` or `"wealth"` outside those definitions.
- [ ] AC4: The suite is green without editing any test, the real data loads with the same errors (none) and
  warnings (none), and the 20-seed sim (042) output is identical before and after.

## Out of scope
- Making food and wealth configurable (decided: they stay built in, as named constants).
- Zone name constants in tests.

## Test plan
| AC | Test |
|---|---|

## Log
