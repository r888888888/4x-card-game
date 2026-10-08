---
id: 407
title: Sumer as the breadbasket - drop the starting Farm and +1 housing
type: feature
status: done
branch: feat/407-sumer-breadbasket
---

## Goal
Sumer has five perks where every other civilization has two, and 406 makes its starting Farm worth 5 food a turn from
turn 1 on its flood-plain home. Sumer becomes the breadbasket civilization instead: it starts level with the others
and is best at stacking farm territories, which fits 406's specialisation. It keeps:
- ⟳ +1 food per farm-tagged building
- farm buildings cost 1 wealth less
- Start: a Research in the discard

It loses the starting Farm and "every territory houses 1 more pop" (the Hanging Gardens' effect, free).

Ships with 406 (same branch or merged right after it), so Sumer never plays on 406's numbers with its old perks.

## Acceptance criteria
- [x] AC1 (start gifts still check): The config loader's starting-tableau checks (133) still hold for every listed
  civilization, and the real data loads with no warnings. No civilization now starts with a building in its tableau,
  and the checks stay for future data (their `TEST_CARDS` tests are unchanged).
- [x] AC2 (real-data UI tests): The real-data tests that start a seed-5 Sumer game (`test_revolt_modal`, `test_day_mode`,
  `test_identity_cards`) pass unchanged. If one depends on the starting Farm, stop and say which, rather than rewrite it.

## Out of scope
- Other civilizations. Egypt's ⟳ +1 food per fresh-water territory also rises in value relative to 406's food, but it
  doesn't stack per building. Leave it to the balance run.
- Sumer's flavor text and quote. They speak of cities and writing, not the Farm. Check them under Manual check.

## Design notes
Data only, in `data/cards.json` (`sumer`):
- Remove the `create` farm `start` effect and `"modifiers": {"housing": 1}`.
- Keep the `create` research `start` effect, the `gain_per_tag` farm `upkeep` effect and the farm discount.

With 406's numbers, turn 1 makes Capital +2 food, +1 wealth against 2 pop: food +0 net, wealth +1, the same as Babylon.
Delta Marsh (1 slot) can take a Farm for 1 food + 1 wealth, making ⟳ 4 + 1 (flood plain) + 1 (Sumer) = 6 food. A
Farm on River Meadow makes 5 and Irrigation Canals 4 (1 food + 2 wealth). Each farm-tagged building gives Sumer 1 more
food than anyone else, about +25% on a 4-food Farm, where it was +50% on a 2-food one.

PLAN.md: the civilizations line (107) and 133's note that Sumer starts with a Farm.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_no_civilization_starts_with_a_building` (new); `test_content::test_real_data_loads_without_warnings` and the loader's 133 `TEST_CARDS` tests (unchanged) |
| AC2 | `test_revolt_modal`, `test_day_mode`, `test_identity_cards`, `test_settings_modal` (seed-5 Sumer games; unchanged) |

## Manual check
- [ ] `sumer` in `data/cards.json` has no Farm `create` and no `modifiers`. Its card face reads Start: Research, ⟳ +1
  food per farm and the farm discount, and nothing about housing.
- [ ] New game as Sumer: the home has no Farm and an empty slot, the forecast reads food +0 and wealth +1, and the
  Build menu prices a Farm at 1 food + 1 wealth.
- [ ] Sumer's flavor and quote still fit with no starting Farm.
- [ ] Balance (the user runs it, with 406): `scripts/sim.sh --level 3 --compare <main checkout>`. Sumer's final VP
  against the other five, and how many farm-tagged buildings it builds.

## Log

- 2026-10-08: red test written: the real data's one civilization starting with a building is Sumer. AC2's tests are
  existing ones that must pass unchanged (`test_settings_modal` also starts a seed-5 Sumer game).
- 2026-10-08: green. Sumer loses its Farm `create` and `modifiers`. One existing content test needed a fix, approved
  in chat: `test_every_per_keyword_and_per_tag_event_effect_can_fire` counted the deck, supply and created cards as
  in play but not the build menu (where buildings come from since 295), so with no civilization creating a Farm,
  Harvest Festival and Bumper Harvest looked dead. It now counts build-menu entries. The seed-5 Sumer UI tests
  pass unchanged (none depended on the Farm). Balance: run with 406, under Manual check.
