---
id: 360
title: Room between the Build modal's flavor and its preview
type: feature
status: in-progress
branch: feat/360-room-under-flavor
---

## Goal
On the Build modal's sheet the flavor has 24 px above it (under the card, 356) but only 4 px below it, so it reads as
the first line of the "If built on …" preview rather than as the card's caption. Give it the same room below, so the
card with its flavor and the preview (or the refusal) read as separate groups.

Builds on 356 and 358 (its branch is cut from `feat/358-flavor-on-build-card`); merge after them.

## Acceptance criteria
- [ ] AC1: Given the Build modal with the Kiln (with flavor) selected, then the "If built on Homeland" heading starts
  `Tokens.SPACE_5` (24 px) below the flavor's bottom; the flavor stays 24 px under the card (358's test).
- [ ] AC2: Given a refused row with flavor (the Oven), then its reason starts `Tokens.SPACE_5` below the flavor.
- [ ] AC3: Given a row with no flavor (Warriors, Farm), then the first line still starts 24 px under the card, with no
  gap left for a missing flavor (356's AC8, 354's AC5).
- [ ] AC4: The Lore Hall (the longest flavor and most lines) still keeps the modal inside a 1920 × 1080 window (354).

## Out of scope
- Spacing inside the preview (its lines stay `Tokens.SPACE_1` apart).

## Design notes
- The flavor leaves the preview's `_lines` box for its own label in the sheet between the card and `_lines`, so the
  sheet's `SPACE_5` separation falls on both sides of it; hidden when the entry has none.
- Guide §11.10's ledger row names the gap.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_build_modal::test_the_preview_has_room_under_the_flavor`; `test_the_flavor_has_room_under_the_card` (358) |
| AC2 | `test_build_modal::test_a_refusal_has_room_under_the_flavor` |
| AC3 | `test_build_modal::test_a_card_without_flavor_has_no_gap_for_one` (passes today: a guard), `test_the_card_has_room_under_it` (356) |
| AC4 | `test_build_modal::test_the_longest_flavor_keeps_the_modal_inside_the_window` (354) |

## Manual check

## Log
