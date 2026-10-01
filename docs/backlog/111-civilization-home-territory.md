---
id: 111
title: Civilizations can start on their own home territory
type: feature
status: done
branch: feat/111-civilization-home-territory
---

## Goal
Each civilization starts where history put it: Egypt on the Nile's flood strip in the desert, Sumer in the southern
Mesopotamian marshes at the head of the Gulf, Babylon on the alluvial plain upriver, Phoenicia on the cedar coast of
Lebanon, Greece in the Aegean coastal hills, Persia in the Zagros upland valleys.

Depends on 131 (the territory set these homes come from).

## Acceptance criteria
Fixtures: a test civilization with `home: "<a second TEST territory>"`; TEST `starting.territory` is the default.

- [x] AC1 (loader): civilization field `home` is optional: a territory card id. An unknown id or a non-territory is a
  load error naming the card and `home`. `population.start` must fit each listed civilization's home housing, else
  a load error naming config.json, `population.start` and the civilization.
- [x] AC2: `new_game(seed, civ)` with a home settles that territory as the starting one (the capital on it, pop
  `population.start`); with no home it uses `starting.territory`, as today.
- [x] AC3 (seed): the same seed deals the same deck order, supply and territory deck whatever the civilization; the
  home territory is not drawn from the territory deck (so it isn't removed from it either).
- [x] AC5 (content): in the real data every listed civilization has a `home`, the listed homes are all different, and
  each home can take more than half of the starting deck's building copies (its keywords meet their `requires`), so a
  civilization never starts with mostly dead buildings.
- [x] AC4: the home territory's resource roll (if any) uses the same rng step as the default starting territory's, so
  the rolls after it don't shift between civilizations.

## Out of scope
- Choosing the starting territory separately from the civilization.

## Design notes
- New `CardDef` field `home` (civilization only). Card text: "Starts on: River Valley."
- Homes (territory ids from 131): Egypt → `desert_floodplain`, Sumer → `delta_marsh`, Babylon → `alluvial_plain`,
  Phoenicia → `cedar_coast`, Greece → `coastal_hills`, Persia → `highland_valley`. All have housing ≥ 2, so
  `population.start` (2) fits.
- Every home has `fresh_water` (true of every early civilization, and the starting deck's Farms and Irrigation need it).
  AC5 checks the effect (most starting buildings fit) without naming the keyword.
- Homes are ordinary territory types that also appear in the territory deck, so players learn one set of cards.
- Egypt's per-fresh-water food bonus (107) counts its home; revisit in balance.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_civ_home::test_home_loads_on_a_civilization`, `test_home_validation`, `test_population_start_must_fit_each_listed_home`, `test_home_is_on_the_card_text` |
| AC2 | `test_civ_home::test_new_game_settles_the_home`, `test_without_a_home_the_game_starts_on_starting_territory` |
| AC3 | `test_civ_home::test_same_seed_same_decks_with_or_without_a_home` |
| AC4 | `test_civ_home::test_home_roll_does_not_shift_the_rng`, `test_home_rolls_from_its_table` |
| AC5 | `test_content::test_every_listed_civilization_has_its_own_home_that_takes_most_starting_buildings` |

## Manual check
- [ ] Each civilization's game starts on its listed home; the territory view shows it with the capital.

## Log
- Red: AC4 read as "the starting territory's roll never moves the game rng": the home (or default) rolls from a copy
  of the rng, so a home with a table and a default without one leave the same rng behind. Guards that pass before the
  change: `test_without_a_home_…`, `test_same_seed_…`, `test_home_roll_does_not_shift_the_rng`. The card-text line
  ("Starts on: River") is tested under AC1.
- Red fix: a `home` on a non-civilization is a warning (ignored), like every other type-only field, not an error;
  the test was changed to match before green.
- `home_uid` in `tests/lib/test_case.gd` now returns the first territory on the tableau (the start, whichever it is),
  since a real game as Egypt no longer starts on `starting.territory`.
- Green: 893 → 903 tests.
