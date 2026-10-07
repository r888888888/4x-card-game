---
id: 366
title: Coastal territories have a sea slot for port buildings
type: feature
status: review
branch: feat/366-sea-slot
---

## Goal
Today the coast only offers alternatives: a Fishing Huts or a Harbor takes the slot a Farm would have used, so being
coastal adds nothing on top of a territory. Give every coastal territory one extra building slot that only port
buildings can fill, so a coastal city builds its farms and its harbour.

## Acceptance criteria
- [x] AC1: Given the config sets `sea_slots: { "keyword": "coastal", "tag": "port", "slots": 1 }`, a settled
  fixture territory with `coastal` and 1 printed slot, and a settled one without `coastal` and 1 printed slot, then
  the coastal one has `total_slots` 1, `free_slots` 1, `sea_slots` 1 and `free_sea_slots` 1, and the other has
  `sea_slots` 0 and `free_sea_slots` 0 with its slots as before. Without the config entry, the coastal one has
  `sea_slots` 0.
- [x] AC2: Given that coastal territory empty with free workers, when a fixture `port` building is built there, then
  it takes the sea slot (`free_sea_slots` 0, `free_slots` still 1); when a second `port` building is built there, it
  takes the regular slot (`free_slots` 0). Neither is idle.
- [x] AC3: Given that coastal territory with a non-port building in its regular slot and its sea slot free, with free
  workers, then a `port` building lists it in `build_targets` and builds there, and is not idle.
- [x] AC4: Given that coastal territory with its regular slot full and its sea slot free, with free workers, when a
  second non-port building is built on it, then `build_error` is "Its sea slot takes only port buildings.", the
  territory is not in that building's `build_targets`, and nothing is built.
- [x] AC5: Given a coastal territory with 2 regular slots (1 printed, 1 from its tier) and the sea slot, holding, in
  the order built, `port` building A, `port` building C and non-port building B, with a worker each, when it loses its
  tier slot but keeps its workers, then B is idle and A and C are not (A keeps the sea slot, C the regular one).
- [x] AC6: Given a coastal territory with a sea slot, then `territory_status` includes `sea_slots` and
  `free_sea_slots`, and `territory_tooltip` has the line "Sea slot: 1 free of 1 (port buildings only)" right after
  the building slots line; a territory with no sea slot has neither the keys nor the line.
- [x] AC7: Given a config whose `sea_slots` names an unknown keyword, or sets `slots` below 1, then loading fails
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
| AC1 | `test_sea_slots::test_a_territory_with_the_keyword_has_a_sea_slot` |
| AC2 | `test_sea_slots::test_a_port_building_takes_the_sea_slot_first_then_a_regular_one` |
| AC3 | `test_sea_slots::test_a_port_building_fits_the_sea_slot_beside_a_full_regular_slot` |
| AC4 | `test_sea_slots::test_the_sea_slot_refuses_a_building_without_the_tag` |
| AC5 | `test_sea_slots::test_losing_a_slot_idles_the_untagged_building_not_the_ones_in_the_sea_slot` |
| AC6 | `test_sea_slots::test_the_status_and_tooltip_show_the_sea_slot` |
| AC7 | `test_sea_slots::test_sea_slots_validation` |

## Manual check
- [ ] Start as Phoenicia (`godot --path . -- --civ phoenicia --seed 5`; home Cedar Coast): the home's live line reads
  "▢ F   ⚓ 1   …" with an anchor icon, its view shows one more empty outline, and the Build modal's preview of Fishing
  Huts there shows "Free sea slots 1 → 0".
- [ ] Build a Farm and then a Fishing Huts on a 1-slot coastal territory: both fit.
- [ ] The tooltip's sea-slot line reads right.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry: every coastal territory gains a slot, so coastal homes (Phoenicia, Greece, Sumer) get one more
  building than before.
- `config_loader.gd` is capped at 450 lines since 339; the `sea_slots` parser went into `PopulationConfig`, beside the
  settlement tiers (the other rule that adds slots).
- The slot rule lives in `Territories.slot_use`; `building_targets` (294) and `Modifiers.working_cards` (150) keep their
  one-pass counts and follow it: a territory's tagged buildings fill its sea slots before any regular one.
- The refusal reads the tag from config ("…only port buildings."), so the engine names neither `coastal` nor `port`.
- New icon `assets/icons/anchor.svg` (⚓ in `Icons.GLYPHS`), drawn like the slot icon.
- Follow-up idea: an unsettled coastal territory's printed "▢2 ⌂5" doesn't mention its sea slot; its keyword line says
  Coastal. Showing "⚓1" there needs an engine query for a territory def's sea slots.
