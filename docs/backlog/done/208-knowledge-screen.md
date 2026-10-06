---
id: 208
title: Knowledge as a screen of era rows, slid in on its rail
type: feature
status: done
branch: feat/208-knowledge-screen
---

## Goal
The tech tree becomes the mock's Knowledge screen (`docs/design/mocks/transitions.html` transition 1): a navigated screen
with a breadcrumb ("Realm / Knowledge"), each era a row of tech tiles, sliding in from the right while the Realm
shifts 24 px left under it. It keeps everything the modal does today (state, cost, eureka, prerequisite, Learn,
details).

## Acceptance criteria
- [x] AC1: Given a game in progress, when Knowledge (top strip) or T is pressed, then a Knowledge screen is pushed on
  the board's play-area navigator (the one whose root is the Realm, 101), with a `ScreenHeader` reading
  "Realm / Knowledge" and context caps "Turn N · <era name>"; the `TechTreeModal` is gone and nothing opens it.
- [x] AC2: The screen shows one row per era from `tech_eras()`, top to bottom, headed with `era_name(n)` in caps; each
  tech of the era from `tech_tree()` is a tile showing its name and its state with a mark and a word (researched ✓,
  available with its cost now, locked with "needs <prerequisite>", future), as the modal does today (059, 140).
  An era not reached yet is dimmed (`FUTURE`) and shows its unlock thresholds.
- [x] AC3: An available tech's tile has its Learn button (enabled when `buy_tech_error` is "", else disabled with the
  error as tooltip); pressing it learns the tech and the tile updates in place, the screen staying open. A met
  eureka shows ✔ (141).
- [x] AC4: Clicking a tile (not its Learn button) opens the card details modal over the screen.
- [x] AC5: Back, Esc, T or the breadcrumb's "Realm" goes back to the Realm and gives focus back to what had it.
- [x] AC6: Push (Reduce motion off): the screen slides in from the right edge in 0.32 s (`Anim.MACHINED`) while the
  Realm moves 0 → −24 px; back: out in 0.26 s (`Anim.RELEASE`), the Realm returning to 0. Reduce motion: a 0.12 s
  fade, no movement.
- [x] AC7: Given a territory view is open, opening Knowledge pushes over it (breadcrumb "Realm / Delta Marsh /
  Knowledge"), and back returns to the territory view.

## Out of scope
- Tech rules.

## Design notes
- `ui/tech_tree_modal.gd` becomes `ui/knowledge_screen.gd`; its tests move with it.
- The navigator's rail slide (189) may already cover AC6's sheet; the Realm's 24 px shift is new.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_knowledge_screen::test_knowledge_is_a_screen_on_the_play_areas_navigator_with_a_header`, `test_t_opens_knowledge_by_era_and_esc_closes_it`, `test_the_knowledge_button_opens_the_screen` |
| AC2 | `test_each_era_is_a_row_headed_in_caps`, `test_a_future_era_row_is_dimmed_and_shows_its_unlocks`, `test_a_locked_tech_says_what_it_needs_and_has_no_learn_button`, the header tests (`test_hints_*`, `test_the_tree_header_counts_insight_and_names_the_research_card`) |
| AC3 | `test_an_available_tech_has_a_learn_button_that_learns_it`, `test_a_learn_button_you_cant_use_is_disabled_with_the_reason`; `test_eurekas::test_the_tree_shows_a_eureka_and_ticks_it_when_met` (on the screen) |
| AC4 | `test_a_click_on_a_tile_opens_its_details_over_the_screen` |
| AC5 | `test_back_esc_t_and_the_realm_link_go_back_and_give_the_focus_back` |
| AC6 | `test_it_slides_in_from_the_right_as_the_realm_shifts_left`, `test_with_reduce_motion_it_only_fades` |
| AC7 | `test_over_a_territory_view_it_pushes_on_top_and_back_returns_to_the_view` |

Moved: `tests/test_tech_tree_modal.gd` → `tests/test_knowledge_screen.gd` (its tests now on `main.knowledge`).
Changed because the tree is no longer a modal: `test_modal_stack` uses the civilization modal as the lower of its two
modals (its "the tree opens on the stack" test goes); `test_sheet_sounds` stacks the civilization modal and the menu,
and its player-input test opens the menu with Esc; `test_day_mode` keeps the civilization modal open across the switch;
`test_toasts` hides them under Knowledge; `test_button_widths` checks the civilization modal's Close, and its "tech
tiles fill their era column" test goes (era rows replace the columns; their layout is the manual check);
`test_cabinet_doors` and `test_era_sheet` check that T opens nothing; `each_screen` visits Knowledge and closes it.

## Manual check
- [ ] Compare with `transitions.html` transition 1 at ¼ speed in both palettes; a 3-era tree fits at 1280×720 (rows
  wrap or scroll).

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: a navigated screen with era rows, not a restyled modal.
- 2026-10-02: Built. `ui/tech_tree_modal.gd` became `ui/knowledge_screen.gd` (`KnowledgeScreen`, `main.knowledge`), on the
  territory view's navigator (now public, `TerritoryView.nav`). `Navigator.push(..., slide)` runs a screen in from the
  right while the one below moves `SHIFT` px left (`offset_of`, `below`); back runs it out. Era rows wrap their tiles
  (`HFlowContainer`) and scroll. main hands Esc and T to it before the territory view; toasts hide under it.
