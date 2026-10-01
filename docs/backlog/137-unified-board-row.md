---
id: 137
title: One board row for events, frontier and realm; known techs leave the board
type: feature
status: review
branch: feat/137-unified-board-row
---

## Goal
The play area has one card area above the hand instead of four stacked rows (Realm, Frontier, Known, Events). Active
events and frontier territories sit in the Realm's wrapping row, before the realm's own cards, so the cards that want
a decision stay at the top even when the realm is large. Known techs leave the board; the tech tree is where you see
them. Prototyped on `spike/unified-tableau` (commit d63e3e8 and the row order in 84fd386).

## Acceptance criteria
- [x] AC1: Given a game with 2 settled territories, 1 frontier territory and 1 active event, when the board
  refreshes, then the Realm row's views are, in order: the event, the frontier territory, then the 2 territory cards
  (then any tableau cards on no territory, as now). With 2 events and 2 frontier territories, each group keeps its
  zone order (events in draw order, frontier in zone order).
- [x] AC2: Given any started game, then the play area's section headings (`section_headings()`) are exactly the
  Realm heading and the Hand heading: no Frontier, Known or Events heading, even while those zones hold cards.
- [x] AC3: Given a game with 1 researched tech, then no card view on the board shows it (no view for its uid), and the
  tech tree still shows it as researched. When a tech is bought from the research choice, its view leaves the board
  instead of resting in a Known row.
- [x] AC4: Given frontier territories A and B and one settled territory T, when a city is played on A, then A's view
  stays on the board (no new view for its uid) and the row is B, T, A.
- [x] AC5: Given a frontier territory in the row, when a Settler is dropped on its card, then it settles that
  territory (the drop zone covers the whole row). A frontier card's tooltip carries the explanation the Frontier
  heading had ("Territories discovered, not yet settled. Play a city card on one to settle it.").
- [x] AC6: Given an active Famine with a relief price, then the Relieve button shows below the Realm (enabled or
  disabled with its reason, as now) and no Events heading shows; with no Famine it is hidden. The `event_panel()` hook
  lists the active events' views in row order with their turns left.

## Out of scope
- How board cards look (fixed height, badges, the frontier style): 138.
- Moving the Relieve button anywhere else, or changing the tech tree.

## Design notes
- UI only; no engine change. `TableauView` gains the row order (`ROW_ORDER`: active events, frontier, realm) and
  places those zones' cards into its `HFlowContainer`; main drops `_row_sections` and the Known row. `frontier`
  becomes the Realm row. `EventsSection` keeps only Relieve (or Relieve moves into main; decide at build time).
- When a card changes zone within the same row (frontier → tableau) `_place` must rebuild its face (the spike
  compares the view's board kind).
- Supersedes tests that assert the old layout: `test_board_labels::test_realm_frontier_known_and_hand_are_stacked_in_that_order`,
  `test_frontier_heading_is_one_word_with_the_explanation_as_its_tooltip`, `test_research_choice_is_titled_knowledge_and_the_researched_row_known`
  (its Knowledge-title half stays), `test_event_panel::test_the_events_section_shows_only_while_an_event_is_active`,
  and `test_card_slots::test_bug_075_known_slot_starts_at_compact_height`. Rewriting them needs the user's OK at the
  red checkpoint (approved tests).
- `ui/main.gd` is at 662 lines; this should shrink it. If it doesn't, watch the 700-line limit.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_board_row::test_events_then_frontier_then_the_realm_share_one_row` |
| AC2 | `test_board_row::test_the_only_section_headings_are_realm_and_hand` |
| AC3 | `test_board_row::test_a_bought_tech_has_no_view_on_the_board` |
| AC4 | `test_board_row::test_settling_a_frontier_territory_keeps_its_view_and_moves_it_into_the_realm` |
| AC5 | `test_board_row::test_a_city_dropped_on_a_frontier_card_in_the_row_targets_it`, `test_board_row::test_a_frontier_card_explains_the_frontier_in_its_tooltip` |
| AC4 | `test_board_row::test_a_settled_frontier_card_grows_to_tableau_size` (guard: passed before, when the card flew between rows) |
| AC5+ | `test_board_row::test_an_event_card_explains_events_in_its_tooltip` (added at the checkpoint: the Events heading's tooltip moves onto event cards) |
| AC6 | `test_board_row::test_relieve_shows_during_a_famine_with_no_events_heading`; turns left and row order: `test_event_panel::test_event_view_shows_its_turns_left`, `test_event_views_match_the_active_events_after_every_turn` (kept) |

Removed as superseded (old layout): `test_board_labels::test_realm_frontier_known_and_hand_are_stacked_in_that_order`,
`test_board_labels::test_frontier_heading_is_one_word_with_the_explanation_as_its_tooltip`,
`test_event_panel::test_the_events_heading_names_no_pile_counts`, `test_event_panel::test_the_events_section_shows_only_while_an_event_is_active`,
`test_card_slots::test_bug_075_known_slot_starts_at_compact_height`. Narrowed: `test_board_labels::test_research_choice_is_titled_knowledge`
(was `…_and_the_researched_row_known`; the Known heading check goes).

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`: play a Scout and keep a territory. It appears at the start of the
  Realm's row, compact; hovering it shows the frontier explanation at the end of its tooltip.
- [ ] Play a Settler on it: it moves to the end of the Realm's row and grows to a full territory card (no new card).
- [ ] End turns until an event is drawn: after the modal, its card leads the row with its turns left; its tooltip
  ends with "One event is drawn at the end of each turn…". When it ends it flies to the Log button.
- [ ] Play Insight and buy a tech: its card leaves the board; the Knowledge (T) tree shows it researched.
- [ ] No Frontier, Known or Events headings at any point; during a Famine, Relieve shows below the Realm's row.

## Log
- The Events heading's tooltip ("One event is drawn at the end of each turn…") now ends every event card's tooltip
  (user's call at the red checkpoint). `TableauView.LEADING_ZONES` holds both explanations.
- `EventsSection` became `ReliefButton` (`ui/relieve_button.gd`), placed in the Realm's section below the row. Relieve
  now shows whenever a Famine can be relieved, also with no event deck (before, the Events section hid it then).
- `event_panel()` keeps a `tooltip` (the event explanation) so `test_event_eras::test_event_tooltip_names_no_events_waiting_for_a_later_era`
  stays unchanged; `info` is gone.
- An ended event now flies to the Log button (there's no Events heading to fly to).
- `ui/main.gd` grew to 674 lines (two test hooks, the in-row rebuild); under 700 but close. A split is due soon.
