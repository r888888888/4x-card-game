---
id: 204
title: "In Hand" heading with the actions count on its line
type: feature
status: review
branch: feat/204-in-hand-header
---

## Goal
The hand's heading is the mock's short "IN HAND" (`docs/design/transitions.html`); the long how-to moves into a
tooltip, and the actions count sits right-aligned on the same line as "2 / 2".

## Acceptance criteria
- [x] AC1: Given a game in progress, then the hand's heading reads "In Hand" (shown in capitals by the Heading
  variation), and its tooltip is the current how-to text ("Drag a card into the realm, double-click it, or ←/→ then
  Enter. Right-click or D discards.").
- [x] AC2: Given 2 actions left of 2, then on the heading's line, right-aligned to the hand's width, a label reads
  "2 / 2"; after playing one card it reads "1 / 2"; its tooltip reads "Actions left this turn".
- [x] AC3: Given unlimited actions (no government action count, 127), the count label is hidden, as today.
- [x] AC4: The old "Actions: N / M" label beside the heading is gone (`main.actions_label` shows the new text).

## Out of scope
- The Realm's heading.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_actions::test_the_hand_is_headed_in_hand_with_the_how_to_as_its_tooltip`; changed: `test_board_row::test_the_only_section_headings_are_realm_and_hand` (whole heading texts), `test_board_labels::test_the_tableau_section_is_headed_realm_and_the_hand_hint_says_realm` (the hint is the tooltip) |
| AC2 | `test_actions::test_the_actions_count_sits_right_on_the_headings_line`; changed: `test_actions::test_top_bar_counts_actions_and_spent_hands_dim` ("2 / 2", "1 / 2") |
| AC3 | `test_actions::test_top_bar_counts_actions_and_spent_hands_dim` (Council: the count hidden) |
| AC4 | `test_actions::test_the_actions_count_sits_right_on_the_headings_line` (no "Actions:" label) |

## Manual check
- [ ] The count lines up with the hand's right edge (left of the sidebar) at 1280×720 and 1920×1080.

## Log
- Specced 2026-10-02 from the notes list. Decided 2026-10-02: the count is actions left / per turn, as today.
- 2026-10-02: Built in `BoardLayout._build_hand`: the heading expands, the count (BarStat, right-aligned) ends the line.
