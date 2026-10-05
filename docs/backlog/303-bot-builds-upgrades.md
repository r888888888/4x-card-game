---
id: 303
title: The sim bot builds upgrades, the tall strategy first
type: feature
status: ready
branch: feat/303-bot-builds-upgrades
---

## Goal
After 300–301 upgrades can be built, but `ScriptedBot` only builds onto territories (298), so the sim would show no
effect from them and the balance item couldn't measure whether they close the gap between tall and wide (tall 54 vs
wide 187 in the 295 spike). After this, every strategy builds upgrades like other build-menu entries, and the tall
strategy, which is short of slots rather than of buildings, tries upgrades before new buildings. Follows 298 and 301.

## Acceptance criteria
Fixture: 300 and 301's cards and `build_menu` (Plough, Ditch, Chapel, Sanctum with tier Village), a fixture game of a
few turns with Homeland at pop 4 holding a Farm and a Chapel, 2 actions and plenty of food.

- [ ] AC1: Upgrade entries join 298's play order as build-menu entries: the baseline bot with no hand cards it prefers
  builds the costliest affordable entry first, upgrades included. An upgrade is built on the first base in
  `build_targets(id)` order that `build_error` allows; one `build_error` refuses everywhere is skipped, as entries are.
- [ ] AC2: The growth bot prefers an upgrade that makes food on upkeep (the Plough) as it prefers such a building, by
  its effects, never by id.
- [ ] AC3: The tall bot tries every affordable upgrade entry before any non-upgrade building entry: given the Plough
  and a Farm both affordable and 1 action, it builds the Plough. With no upgrade it can build, it builds the Farm as
  298 does.
- [ ] AC4: The bot never builds an upgrade whose play effects would push unrest to the limit (the `_unrest_ok` check),
  and builds nothing `build_error` refuses (a Sanctum below a Village is never attempted; the turn ends with it
  unbuilt and no error logged).

## Out of scope
- Growing toward a tier on purpose to unlock an upgrade (283's "where needed most" growth already leans that way).
- Costs and strategy weights: the balance item after 307.

## Design notes
- In `sim/bot.gd`, `_build` (298) walks entries × `build_targets`; an upgrade's targets are building uids, so the walk
  needs no change beyond the tall ordering. Name upgrades by data (`upgrade_of` set), not by id.
- Fixture games only (`tests/test_bot_spending.gd` and kin); real-data bot games stay in `tests/balance/`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_bot_spending::test_…` |

## Log
- 2026-10-05: specced with 300–302.
