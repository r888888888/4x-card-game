---
id: 087
title: Collapse territory groups in the Realm
type: feature
status: ready
branch: feat/087-collapse-territories
---

## Goal
With several settled territories the Realm fills the screen with full-size city and building cards. The player can
collapse a territory group to its territory card, header (slots, pop, Grow) and a one-line summary of what's built on
it, and collapse or expand all groups at once, so they see more territories without scrolling.

## Acceptance criteria
- [ ] AC1 (engine): Given a settled territory holding 1 city and 3 buildings with pop 3 (so 1 building idle, population
  on), `territory_summary(uid)` returns `{"cities": 1, "buildings": 3, "idle": 1}`. The territory card itself isn't
  counted. With population off, `idle` is 0.
- [ ] AC2 (engine): `territory_summary(uid)` returns `{}` for a uid that is not a settled territory in the tableau
  (a building's uid, a frontier territory, an unknown uid).
- [ ] AC3: Given the main scene with that territory's group expanded, when its collapse toggle is pressed
  (`tableau.set_collapsed(uid, true)`), then the city and building views in the group are hidden, the territory card,
  header label and Grow button stay visible, a summary label reads `1 city · 3 buildings (1 idle)`, and the tableau's
  minimum height is less than when expanded. `set_collapsed(uid, false)` shows all 5 views again and hides the summary.
- [ ] AC4: Given a collapsed group, when the board refreshes after a building is played onto that territory, then the
  group stays collapsed, the new building's view is hidden, and the summary reads `1 city · 4 buildings …`.
- [ ] AC5: Given 2 settled territories and cards on no territory, when "Collapse all" is pressed, both territory groups
  collapse and the no-territory group (uid -1) doesn't (it has no toggle); "Expand all" expands both. A territory
  settled afterwards starts expanded. A new game starts with every group expanded (the state isn't saved).
- [ ] AC6: A collapsed group is still a drop target: `group_at(point)` inside its frame returns its uid, and
  `move_ghost(uid)` shows the ghost in that group right after the territory card.
- [ ] AC7: Given a collapsed group holding a card that targeting lights (a card that targets a city or building), when
  targeting starts, that group expands so the lit card is visible and reachable with ←/→; it stays expanded afterwards.

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

## Manual check
- [ ] Collapse a territory with 4+ buildings: the group shrinks to one card wide and the summary is readable.
- [ ] Collapse all with 4 territories at 1920×1080: all fit without scrolling the Realm.
- [ ] Drag a building onto a collapsed territory: the group lights, the ghost appears after the territory card, and the
  building lands with the summary updated.

## Log
- 2026-09-29: Specced. The user chose an in-place collapse toggle over a buildings modal, a header + count summary,
  groups expanded by default with Collapse all / Expand all, and collapsed groups staying drop targets.
