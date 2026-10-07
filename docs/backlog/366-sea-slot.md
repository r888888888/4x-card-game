---
id: 366
title: Coastal territories have a sea slot for port buildings
type: feature
status: ready
branch: feat/366-sea-slot
---

## Goal
Today the coast only offers alternatives: a Fishing Huts or a Harbor takes the slot a Farm would have used, so being
coastal adds nothing on top of a territory. Give every coastal territory one extra building slot that only port
buildings can fill, so a coastal city builds its farms and its harbour.

## Acceptance criteria
- [ ] AC1: Given the config sets `sea_slots: { "keyword": "coastal", "tag": "port", "slots": 1 }`, a settled
  fixture territory with `coastal` and 1 printed slot, and a settled one without `coastal` and 1 printed slot, then
  the coastal one has `total_slots` 1, `free_slots` 1, `sea_slots` 1 and `free_sea_slots` 1, and the other has
  `sea_slots` 0 and `free_sea_slots` 0 with its slots as before. Without the config entry, the coastal one has
  `sea_slots` 0.
- [ ] AC2: Given that coastal territory empty with free workers, when a fixture `port` building is built there, then
  it takes the sea slot (`free_sea_slots` 0, `free_slots` still 1); when a second `port` building is built there, it
  takes the regular slot (`free_slots` 0). Neither is idle.
- [ ] AC3: Given that coastal territory with a non-port building in its regular slot and its sea slot free, with free
  workers, then a `port` building lists it in `build_targets` and builds there, and is not idle.
- [ ] AC4: Given that coastal territory with its regular slot full and its sea slot free, with free workers, when a
  second non-port building is built on it, then `build_error` is "Its sea slot takes only port buildings.", the
  territory is not in that building's `build_targets`, and nothing is built.
- [ ] AC5: Given a coastal territory with 2 regular slots (1 printed, 1 from its tier) and the sea slot, holding, in
  the order built, `port` building A, `port` building C and non-port building B, with a worker each, when it loses its
  tier slot but keeps its workers, then B is idle and A and C are not (A keeps the sea slot, C the regular one).
- [ ] AC6: Given a coastal territory with a sea slot, then `territory_status` includes `sea_slots` and
  `free_sea_slots`, and `territory_tooltip` has the line "Sea slot: 1 free of 1 (port buildings only)" right after
  the building slots line; a territory with no sea slot has neither the keys nor the line.
- [ ] AC7: Given a config whose `sea_slots` names an unknown keyword, or sets `slots` below 1, then loading fails
  with an error naming `sea_slots` and the field.

## Out of scope
- Sea slots from anything but a keyword (a city, a tier or a tech).
- Changing which buildings carry the `port` tag (365 adds the Lighthouse). Upgrades (Harbor, and 364's Salt Pans) take no slot, so the sea slot never holds them.
- Balance tuning.

## Design notes
- Config (`data/config.json`, validated in `ConfigLoader`): `"sea_slots": { "keyword": "coastal", "tag": "port",
  "slots": 1 }`. Every settled territory with the keyword gets that many extra slots that only a building with the
  tag may fill. The engine names neither `coastal` nor `port`; they come from config.
- `total_slots` and `free_slots` keep meaning the regular slots (anything may fill them), so the territory view's
  "▢ free" still means "any building fits". New queries `sea_slots(uid)` and `free_sea_slots(uid)` on the engine.
- Allocation, in the order buildings were placed: a building with the tag takes a free sea slot, else a regular slot;
  any other building takes a regular slot; one that finds none is idle (281's "placed last, idle first" holds).
  `Population.is_idle` and `Territories.building_targets` follow this rule; upgrades still take no slot.
- A sea slot still needs a worker, like any slot.
- `build_preview`'s readings add `free_sea_slots`, and `ui/build_modal.gd`'s `LINE_LABELS` gets a label for it; the
  territory view shows a sea-slot count and outline beside "▢" on territories that have one (glyph and look per the
  design tokens; Manual check).
- The bot sees it through `build_targets` (`legal_actions`, 312).
- Build after 339: `config_loader.gd` is near its 700-line cap, and this adds a validated config entry.
- PLAN.md: the building-slots rules.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_…::test_…` |

## Manual check
- [ ] On Cedar Coast, the territory view shows the sea slot apart from the regular slots, with its own empty-slot
  outline, and the Build modal's preview names it when a port building would take it.
- [ ] Build a Farm and then a Fishing Huts on a 1-slot coastal territory: both fit.
- [ ] The tooltip's sea-slot line reads right.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry: every coastal territory gains a slot, so coastal homes (Phoenicia, Greece, Sumer) get one more
  building than before.
