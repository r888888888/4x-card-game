---
id: 247
title: Trim the starting deck's farms, settlers, lumber camps and research
type: feature
status: done
branch: feat/247-smaller-starting-deck
---

## Goal
The starting deck has fewer of the basics (farm, settler, lumber camp, research), so the opening turns are leaner.
Cards not named in the request (scout, barter, storyteller, hunt) are left alone.

## Acceptance criteria
<!-- Content item: criteria are invariants of the real data; exact shipped counts go under Manual check. -->
- [x] AC1: Given the real `data/config.json`, when it loads, then there are no loader errors and every card id in
  `deck` exists in `data/cards.json`.
- [x] AC2: Given a new game on any listed civilization, when it starts, then there is no error and each civilization's
  home still takes most of the starting building copies.

## Out of scope
- Balance: no sim run, no tuning of supply prices or counts (note worries in the Log).
- Changing `hand_size`, civilization start effects, the supply, or the counts of scout, barter, storyteller, hunt.

## Design notes
- Data only: `deck` in `data/config.json` changes; no new fields or engine API.
- Both criteria are already guarded by existing tests (`test_data_loader::test_real_data_loads`,
  `test_content::test_a_new_game_starts_as_each_listed_civilization`,
  `test_content::test_every_listed_civilization_has_its_own_home_that_takes_most_starting_buildings`), so there is no
  new failing test: the change is checked by keeping the suite green. Exact counts are a Manual check, per the spec rules.

## Test plan
| AC | Test |
|---|---|
| AC1 | existing `test_data_loader::test_real_data_loads` |
| AC2 | existing `test_content::test_a_new_game_starts_as_each_listed_civilization`, `…home_that_takes_most_starting_buildings` |

## Manual check
- [ ] `deck` in `data/config.json` is: farm 2, settler 1, lumber_camp 1, research 1, scout 2, barter 2,
  storyteller 1, hunt 1 (11 cards).
- [ ] Start a game (`godot --path .`): the opening hand draws 5 of those 11 cards without errors.

## Log
- Spec revised at build: the first draft read the request as "the deck is exactly these 5 cards", which would have
  orphaned barter (no supply pile). The user clarified that unmentioned cards are left alone.
