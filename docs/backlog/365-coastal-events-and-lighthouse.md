---
id: 365
title: Helpful coastal events and the Lighthouse of Pharos
type: feature
status: red-review
branch: feat/365-coastal-events-and-lighthouse
---

## Goal
The event deck mostly punishes the coast: Sea Raiders is a strength-3 raid and Storm at Sea takes 2 wealth per coastal
territory, while only Busy Harbours (era 2) helps. Farms get Bumper Harvest, Harvest Festival and Silt Flood. Add
era-1 events that reward coastal territories, and a second coastal wonder beside Tyre (which in practice is
Phoenicia's). Content only; numbers are a first guess until a balance item.

## Acceptance criteria
- [ ] AC1 (invariant): For every keyword that a `lose_per_keyword` event in the event deck counts, or that a raid in
  the event deck targets, at least one event in the event deck has a `gain_per_keyword` effect counting it, or the
  keyword is a terrain. The failure names the keyword. (Today `coastal` passes only through Busy Harbours; the
  terrains are exempt because their buildings already carry keyword bonuses.)
- [ ] AC2 (invariant): Every era-1 event in the event deck that counts a keyword gives rather than takes (no
  `lose_per_keyword` in era 1). The failure names the event.
- [ ] AC3: The existing content invariants hold with the new cards, in particular
  `test_every_per_keyword_and_per_tag_event_effect_can_fire`, `test_real_era_1_events_harm_only_by_unrest`,
  `test_every_wonder_outcosts_and_outscores_every_other_building`, `test_every_wonder_comes_only_from_one_tech` and
  `test_every_wonder_is_a_project_and_every_project_a_wonder`.

## Out of scope
- Changing Sea Raiders or Storm at Sea, or letting a building shelter the coast from them.
- Fishing Huts, Salt Pans, Net Fishing, Harbor (364); the sea slot (366); Sea Trade and port insight (367).
- Balance tuning.

## Design notes
- No engine or format change: everything uses `gain_per_keyword`, `gain_per_tag`, `discard.turns`, `project` and
  `once`. AC1–AC3 may pass at once; they guard the content. Keep AC1 and AC2 next to the other event invariants in
  `tests/test_content.gd`.
- New events in `data/cards.json`, one copy each in `event_deck`, all era 1:
  - **Tuna Run**: `discard: { "turns": 2 }`, ⟳ +1 food per coastal territory (the shape of Busy Harbours).
  - **Beached Whale**: once, +2 food per coastal territory.
  - **Shipwreck Salvage**: once, +2 wealth per coastal territory.
- New wonder **Lighthouse of Pharos** (`lighthouse_of_pharos`): building, `project: true`, tags
  `["wonder", "culture", "port"]`, `requires: ["coastal"]`, ⟳ `gain_per_tag` +1 wealth per `port` card. Build menu
  entry `{ "locked": true, "once": true }`; Navigation unlocks it.
- Flavor and the wonder's quote follow the style guide §18 (a real quote about the Pharos, attributed).
- PLAN.md: the event list and the wonder list.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_feature_keyword_the_events_punish_some_event_rewards` (passes already: Busy Harbours) |
| AC2 | `test_content::test_no_era_1_event_takes_per_keyword` (passes already) |
| AC3 | the existing `test_content` invariants named in AC3 |

## Manual check
- [ ] Shipped numbers: Tuna Run ⟳ +1 food per coastal territory for 2 turns; Beached Whale +2 food and Shipwreck
  Salvage +2 wealth per coastal territory; Lighthouse costs about 50 wealth, 8 VP, ⟳ +1 wealth per port.
- [ ] Card text and flavor read right on all four cards.
- [ ] Research Navigation in a coastal game: the Lighthouse appears in the Build menu only for coastal territories,
  and only once.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry: the Lighthouse's +1 wealth per port stacks with Navigation's own +1 per port, so Navigation is worth
  +2 per port once the wonder stands.
