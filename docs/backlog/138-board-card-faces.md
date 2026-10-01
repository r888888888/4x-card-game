---
id: 138
title: Fixed-height board cards with kind badges and a distinct frontier look
type: feature
status: in-progress
branch: feat/138-board-card-faces
---

## Goal
Every card in the board row has the same height, so the row is a tidy grid however many cards it holds. A card shows
one line per field; the full text is in its details (a click away). Frontier territories look unclaimed (hatched, with
a dashed border) and events carry a badge, so both are told apart from the realm at a glance. Prototyped on
`spike/unified-tableau` (commit 84fd386). Builds on 137.

## Acceptance criteria
- [ ] AC1: Given a board row with an active event, a frontier territory, a settled territory with 4 keywords and a
  tableau card on no territory whose rules run over several lines, then every one rests in a slot of
  `CardView.BOARD_SIZE` (245 × 150), and the row's slots all have that height.
- [ ] AC2: Given a frontier territory, then its face shows a badge reading "Frontier · unsettled", its name, its
  keyword line and its printed slots and housing (▢ N ⌂ N), and no type line or "Free" cost. A settled territory's
  face has no badge.
- [ ] AC3: Given an active event with 1 turn left, then its face shows a badge reading "Event" with "1 turn left"
  beside it, its name, and the first line of its rules other than the "Lasts N turns" line (no line for an event with
  no effects). An active Famine shows its counters ("2 counters") beside the badge instead.
- [ ] AC4: Given a frontier territory on the board, when a city settles it, then its view switches to the settled
  face (badge gone, live line "▢ … ⌂ …/… ⚒ …" shown) and stays at `BOARD_SIZE`.
- [ ] AC5: Given a settled territory whose keyword line doesn't fit on one line, when its card is clicked, then the
  details modal's body names every one of its keywords (nothing clipped on the face is lost).
- [ ] AC6: The frontier style's colours come from `Palette` (the colour-literal check stays green), and a hand card's
  face and size are unchanged (`HAND_SIZE`, with type line and full rules).

## Out of scope
- The row's order and which zones it shows: 137.
- Keyword icons in place of words (a later idea; the clipped keyword line is the cost of fixed height).
- Restyling the details modal's card to match the board look.
- The territory view (101) and supply cards keep their current faces.

## Design notes
- UI only. `CardView.setup` takes a board kind ("realm", "frontier", "event"; "" off the board) and uses
  `BOARD_SIZE`; `CardFace.build_board` builds the one-line face (Label ellipsis; RichTextLabel clipped to one line —
  a clip with no "…" for text with icons, fine for now). The badge is a small pill in the type colour with
  `Palette.TEXT_ON_ACCENT` text; badge words are card kinds, not content names.
- Frontier look: `Palette.FRONTIER_BG` background, a dashed border in the territory colour and faint diagonal hatching
  (`Palette.FRONTIER_HATCH`), drawn in `CardView._draw` (StyleBoxFlat has no dashes). The spike's `SPIKE_FRONTIER`
  switch (dashed / hatched / faded) is not kept: hatched won; faded hurt legibility.
- `COMPACT_SIZE` and `TABLEAU_SIZE` go if nothing else uses them. Supersedes
  `test_card_slots::test_bug_075_frontier_slot_starts_at_compact_height`,
  `test_territory_cards::test_the_realm_shows_one_card_per_territory` (its size check) and
  `test_territory_cards::test_frontier_cards_keep_their_printed_slots_and_housing` (glyph spacing); rewriting them
  needs the user's OK at the red checkpoint.
- Settled titles sit one line higher than badged ones; judge under Manual check whether that needs a fix.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_board_faces::test_every_card_in_the_row_rests_at_board_size`; changed: `test_card_slots::test_bug_075_frontier_slot_starts_at_board_height` (was `…_compact_height`), `test_territory_cards::test_the_realm_shows_one_card_per_territory` (size check: board size) |
| AC2 | `test_board_faces::test_a_frontier_card_has_a_badge_its_keywords_and_printed_slots_and_housing`; kept: `test_territory_cards::test_frontier_cards_keep_their_printed_slots_and_housing` |
| AC3 | `test_board_faces::test_an_event_card_has_a_badge_with_its_turns_left_then_its_first_rules_line`, `test_board_faces::test_a_famine_card_shows_its_counters_beside_its_badge` |
| AC4 | `test_board_faces::test_a_settled_frontier_card_switches_to_the_settled_face_at_board_size`; removed: `test_board_row::test_a_settled_frontier_card_grows_to_tableau_size` (137's guard; same check, new size) |
| AC5 | `test_board_faces::test_the_details_of_a_board_card_name_every_keyword` (guard: passes already) |
| AC6 | `test_board_faces::test_a_hand_card_keeps_its_size_type_line_and_rules` (guard: passes already); colours: `test_theme::test_no_colour_literals_outside_the_palette` (kept) |

## Manual check
- [ ] Frontier cards read as unsettled at a glance (hatched, dashed border, badge) and stay legible.
- [ ] Event badge and turns left are readable; a turn-30 board is a tidy grid.
- [ ] Hover, focus ring and target highlight still show on a frontier card (its border is drawn, not styled).

## Log
- Red: the fixtures have 3 keyword ids, so "a territory with 4 keywords" is Grassland with 3 rolled keywords
  (Fresh Water, Flood Plain, Mountain). The frontier's printed line keeps 123's "▢N ⌂N" format so its approved test
  stands. Tests read `CardView.BOARD_SIZE` through `board_size()` (test_case.gd) until it exists; the refactor step
  replaces it with the constant.
- `with_main` / `board_engine` (with `BOARD_TERRITORIES`, `HUNGRY_POP`) moved from test_board_row.gd to test_case.gd.
