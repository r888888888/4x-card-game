---
id: 087
title: Collapse territory groups in the Realm
type: feature
status: done
branch: feat/087-collapse-territories
---

## Goal
With several settled territories the Realm fills the screen with full-size city and building cards. The player can
collapse a territory group to its territory card, header (slots, pop, Grow) and a one-line summary of what's built on
it, and collapse or expand all groups at once, so they see more territories without scrolling.

## Acceptance criteria
- [x] AC1 (engine): Given a settled territory holding 1 city and 3 buildings with pop 3 (so 1 building idle, population
  on), `territory_summary(uid)` returns `{"cities": 1, "buildings": 3, "idle": 1}`. The territory card itself isn't
  counted. With population off, `idle` is 0.
- [x] AC2 (engine): `territory_summary(uid)` returns `{}` for a uid that is not a settled territory in the tableau
  (a building's uid, a frontier territory, an unknown uid).
- [x] AC3: Given the main scene with that territory's group expanded, when its collapse toggle is pressed
  (`tableau.set_collapsed(uid, true)`), then the city and building views in the group are hidden, the territory card,
  header label and Grow button stay visible, a summary label reads `1 city · 3 buildings (1 idle)`, and the tableau's
  minimum height is less than when expanded. `set_collapsed(uid, false)` shows all 5 views again and hides the summary.
- [x] AC4: Given a collapsed group, when the board refreshes after a building is played onto that territory, then the
  group stays collapsed, the new building's view is hidden, and the summary reads `1 city · 4 buildings …`.
- [x] AC5: Given 2 settled territories and cards on no territory, when "Collapse all" is pressed, both territory groups
  collapse and the no-territory group (uid -1) doesn't (it has no toggle); "Expand all" expands both. A territory
  settled afterwards starts expanded. A new game starts with every group expanded (the state isn't saved).
- [x] AC6: A collapsed group is still a drop target: `group_at(point)` inside its frame returns its uid, and
  `move_ghost(uid)` shows the ghost in that group right after the territory card.
- [x] AC7: Given a collapsed group holding a card that targeting lights (a card that targets a city or building), when
  targeting starts, that group expands so the lit card is visible and reachable with ←/→; it stays expanded afterwards.
- [x] AC8 (review feedback): a group's territory is its title bar, not a card in the row: the territory's view sits in
  the group's header (`tableau.group_header(uid)`), is one line tall (shorter than `CardView.COMPACT_SIZE`), and shows
  the name, slots, housing and keywords (for example "River Meadow", "▢3", "Grassland"). The row holds the other cards.
- [x] AC9: a collapsed group keeps its title bar (visible, in the header).
- [x] AC10: with two lit territories while placing a building, ←/→ moves the focus between their title bars and
  Enter plays the building on the focused one (guard: the title bar is still a card view, so this already works).

## Out of scope
- A separate buildings modal or screen (considered; the in-place toggle was chosen instead).
- Saving collapse state across sessions or in save games.
- Mini icons for each building in the collapsed view.
- Fixing the wide-group overflow (078); this item doesn't depend on it.

## Design notes
- New engine query `territory_summary(territory_uid) -> Dictionary` (`{cities, buildings, idle}`), probably in
  `engine/territories.gd` using `Population.is_idle`, so the UI doesn't count card types itself. Counts use
  `CardDef.CITY` / `CardDef.BUILDING`; other permanents on the territory (if any) aren't counted.
- UI state only: `TableauView` keeps a `_collapsed` set of territory uids, a ▸/▾ toggle in each `TerritoryGroup` header,
  and a summary label. The Collapse all / Expand all button sits above the Realm. No data or config change.
- Hiding a view hides its slot, so `CardFocus` rows built from visible views skip it; AC7 covers targeting.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_ui_queries::test_territory_summary_counts_cities_buildings_and_idle` |
| AC2 | `test_ui_queries::test_territory_summary_is_empty_for_anything_but_a_settled_territory` |
| AC3 | `test_collapse_territories::test_collapsing_a_group_hides_its_city_and_buildings` |
| AC4 | `test_collapse_territories::test_a_collapsed_group_stays_collapsed_when_a_building_arrives` |
| AC5 | `test_collapse_territories::test_collapse_all_and_expand_all`, `::test_new_territories_and_new_games_start_expanded` |
| AC6 | `test_collapse_territories::test_a_collapsed_group_is_still_a_drop_target` |
| AC7 | `test_collapse_territories::test_revealing_a_card_expands_its_group` |
| AC8 | `test_collapse_territories::test_the_territory_is_the_groups_title_bar`; changed: `::test_a_collapsed_group_is_still_a_drop_target` (nothing before the ghost now), `test_territory_row::test_bug_078_every_card_stays_in_its_group` (territory in the header) |
| AC9 | `test_collapse_territories::test_a_collapsed_group_keeps_its_title_bar` |
| AC10 | `test_collapse_territories::test_keyboard_targeting_moves_between_title_bars` (guard) |

## Manual check
- [ ] Every territory box starts with a one-line title bar (toggle, name, ▢ slots, ⌂ housing, keywords) and no
  separate territory card. Hovering it shows the territory's tooltip; clicking it opens its details.
- [ ] Settle a territory from the Frontier: its card flies into the new box's title bar.
- [ ] Collapse a territory with 4+ buildings: the box shrinks to its title bar, stats line and a readable summary,
  and keeps its own height beside an expanded box.
- [ ] Collapse all with 4 territories at 1920×1080: all fit without scrolling the Realm.
- [ ] Drag a building onto a collapsed territory: the box lights (its title bar too), and the building lands with the
  summary updated. Place a building by keyboard: ←/→ moves between the lit title bars.

## Log
- 2026-09-29: Red at 594 tests (was 586), 8 failing. Resolved while writing tests: AC1's "pop 3 (so 1 idle)" can't
  hold with 3 buildings (a building is idle when its index on the territory is ≥ pop), so the tests use pop 2, which
  is also the real seed-1 start. AC7: no card targets a city or building yet, so it is tested through a public
  `tableau.reveal(uid)`, which targeting calls for each lit card. AC3's "minimum height" is the group frame's laid-out
  height (minimum sizes mean nothing before layout, 088). Fixed `test_case.home_uid`: it looked for `homeland`
  only, so on the real data it returned -1 and 078's tests used the no-territory group; it now uses
  `config.starting.territory` (078's tests still pass, now on River Meadow).
- Approved at red. Green: `Territories.summary` / `GameEngine.territory_summary`; `TableauView` keeps the collapsed
  set, a ▾/▸ toggle per group, a summary label, `reset()` (called by `start_game`), `reveal()` (called by
  targeting for each lit uid; a lit territory card doesn't expand its group, so dragging a building keeps groups
  collapsed) and a `collapse_changed` signal the board refreshes on.
- Design choice made during green (not in the spec): **a collapsed group's territory card is shown compact** (the
  frontier size: name, slots, housing, keywords). With a full-size territory card plus the summary line, a one-line
  group was taller collapsed (276px) than expanded (249px), so AC3's test failed; compact, collapsing saves height
  as well as width. `CardView.is_compact()` lets the board resize the view when its group toggles.
- Collapse all sits on the Realm heading's right end (no extra row, so End turn stays on screen) and reads Expand
  all once every territory group is collapsed. Rendered at 1920×1080 with 4 territories: all collapsed fit in two
  lines of groups.
- 2026-09-29: Specced. The user chose an in-place collapse toggle over a buildings modal, a header + count summary,
  groups expanded by default with Collapse all / Expand all, and collapsed groups staying drop targets.
- Review feedback (user): a box holds one territory, so its information belongs in the box, not a separate card.
  Folded into 087 (AC8-AC10), with the header doing the card's jobs in both states. Approach: the territory keeps its
  CardView (focus ring, details on click, lit target, the settle flight from the Frontier) but drawn as a flat
  one-line title bar in the header. This replaces the compact territory card from the green phase. Red again at 597
  tests; two approved tests change (see Test plan).
- The runner now frees any node a test leaves in the tree (a test that crashes before `close_main`), so one crash no
  longer fails every later UI test (the red run showed 735 failures from 4 real ones).
- Approved. Green: `CardView.setup(..., banner)` draws a settled territory as a flat title bar (`BANNER_SIZE`, no
  fill, a border only while lit or hovered; `CardFace.build_banner`); `TableauView` places a group's territory in
  its header's banner slot and the rest in the row (`is_banner`, `group_header`); collapsing hides the whole row.
  The compact collapsed territory card is gone. Boxes keep their own height on a shared line
  (`SIZE_SHRINK_BEGIN`). Rendered at 1920×1080 with 4 territories, one and all collapsed. 597 tests.
