---
id: 244
title: The territory view's title line lists only keywords
type: feature
status: done
branch: feat/244-territory-view-keywords-only
---

## Goal
The territory detail screen showed the territory's printed slots and housing ("▢3 ⌂5") beside its name. The live
stats line below already shows slots and housing, so the numbers beside the name were redundant. After this the title
line is the name and the keywords only.

## Acceptance criteria
- [x] AC1: Given a territory view, then its title line is the name followed by `CardFace.keyword_line` (printed
  keywords, then any rolled ones) and contains neither ▢ nor ⌂.

## Out of scope
- Card faces (the Realm row, hand) keep the printed slots and housing (`CardFace.territory_info`).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_territory_view::test_the_territory_is_the_box_with_its_name_info_stats_and_grow_on_top`; `test_territory_cards::test_a_rolled_keyword_shows_in_the_view_but_not_on_the_realm_card` |

## Manual check
- [ ] Open a territory's view: beside the name only keywords show, e.g. "Grassland · Fresh Water".

## Log
- Built without a red checkpoint: the user asked for the change directly and it is a UI-only edit; the two existing
  tests that expected the numbers were updated with it.
