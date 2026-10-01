---
id: 123
title: A settled territory card shows only what you build with: free slots, pop, free workers
type: feature
status: red-review
branch: feat/123-simpler-territory-card
---

## Goal
A settled territory's card in the Realm shows four lines, two of them low value: "▲ Territory" (obvious there),
"▢3 ⌂5" (the printed base slots and housing, stale once a city or building adds more), and a live "0 / 6 slots used ·
Pop 2 / 5" that counts the wrong way for deciding where to build. And it never says how many free workers it has,
though every building needs one. Show the name, the keywords and one short live line of what you build with, and
move the wording to the tooltip.

```
River Meadow
Grassland · Fresh Water

▢ 6   ⌂ 2/5   ⚒ 2        (free slots, pop / housing, free workers)
```

## Acceptance criteria
<!-- AC1–AC2: engine tests with TEST_CARDS. AC3–AC6: UI tests in the real main.tscn on TEST_CARDS (territory fixtures). -->
- [ ] AC1: `GameEngine.territory_status(uid)` for a settled territory returns {free_slots, total_slots, pop, housing,
  free_workers} from the existing rules; {} for anything else. Given Homeland (5 slots) with a Capital (+slots) and
  pop 2, then free_slots and total_slots match `free_slots` / `total_slots`, and free_workers is 2; after building a
  Farm on it, free_slots and free_workers each drop by 1.
- [ ] AC2: `GameEngine.territory_tooltip(uid)` for a settled territory is, one per line: "Building slots: F free of
  T", then with population on "Pop P, housing H" and "Free workers: W (each building needs one)", then "Keywords: …"
  when it has any (rolled resources included, as today). Population off: no pop or worker line.
- [ ] AC3: A settled territory's card in the Realm shows its name, its keyword line ("Grassland · Fresh Water", rolled
  resources after " + "; no line when it has none), and the live line "▢ F   ⌂ P/H   ⚒ W" (F free slots, P pop, H
  housing, W free workers), and nothing else: no type line, no printed "▢3 ⌂5", no "slots used". Its tooltip is
  `territory_tooltip`.
- [ ] AC4: The live line follows the game: build a Farm there and it shows one fewer free slot and free worker; grow
  and P rises. With population off it is just "▢ F".
- [ ] AC5: "⚒" is drawn as an icon like "▢" and "⌂" (`Icons.GLYPHS`, a new `assets/icons/worker.svg`).
- [ ] AC6: The territory view's header shows the same live line (`stats_text()`); Frontier cards are unchanged:
  "▢3 ⌂5 · keywords", the printed numbers you compare when choosing where to settle (guard).

## Out of scope
- Frontier, hand and details-modal layouts (the details modal keeps its "Now" lines); city and building cards.
- Balance or any rule change.

## Design notes
- Engine: `territory_status(uid)` and `territory_tooltip(uid)` (text generated in the engine, like `territory_text`).
- UI: `CardFace` builds a settled territory's face from them; `CardView.set_territory_info` takes the status;
  `TerritoryView.stats` uses the same line. `test_territory_view`'s stats assertions ("slots used", "Pop P / H")
  change to the new line: name them at the red checkpoint.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_workers::test_territory_status_reports_free_slots_pop_housing_and_free_workers` |
| AC2 | `test_workers::test_territory_tooltip_spells_out_slots_pop_and_workers`, `test_territory_tooltip_without_population_names_only_slots` |
| AC3 | `test_territory_cards::test_a_settled_territory_card_shows_its_name_keywords_and_live_line_only` |
| AC4 | `test_territory_cards::test_the_live_line_follows_building_and_growth`, `test_without_population_the_live_line_is_free_slots_only` |
| AC5 | `test_territory_cards::test_the_worker_glyph_is_an_icon` |
| AC6 | `test_territory_cards::test_frontier_cards_keep_their_printed_slots_and_housing` (guard); changed: `test_territory_view` stats assertions (4 tests) now expect the live line, drawn with icons |

## Manual check
- [ ] The live line reads at a glance in the Realm; hovering gives the full wording.
- [ ] The worker icon reads as a worker next to the slot and housing icons.

## Log
