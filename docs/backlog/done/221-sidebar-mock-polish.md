---
id: 221
title: Bring the board's strip, rail and End turn closer to the transitions mock
type: feature
status: review
branch: feat/221-sidebar-mock-polish
---

## Goal
The board still reads differently from `docs/design/transitions.html`'s desk: the top bar floats with no strip, the
sidebar is a boxed panel, its government link is set in the big display face, the spacing doesn't line up, and the End
turn key repeats the actions count that the hand's heading already shows ("2 / 2"). After this the board has the mock's
ruled strip and open rail, the sidebar's type matches the mock, and End turn is a bigger key filling the rail's foot.

## Acceptance criteria
- [x] AC1 (no actions count on End turn): Given a government with 2 actions per turn and 2 left, the End turn key's
  caption is empty (its lamp is still ochre); after both are spent it is still empty. Given a turn that can't end (a
  discard owed), the caption still shows `end_turn_error()`.
- [x] AC2 (the strip): At 1280×720 and 1920×1080, the top bar sits on a full-bleed strip: from x = 0 to the window's
  right edge, starting at y = 0, filled RAISED with a 3 px TEXT rule along its bottom edge and no other border.
- [x] AC3 (the open rail): The sidebar has no box: no fill of its own (the board shows through) and only a 1 px HAIRLINE
  rule on its left edge. It runs from the strip's bottom to the window's bottom edge and ends at the window's right edge.
- [x] AC4 (sidebar type): The "Civilization" heading stays in Heading caps; the civilization's name stays a TitleLink at
  TYPE_TITLE; the government ("Chiefdom ›") is a `CapsLink`: the heading face (Barlow SemiCondensed SemiBold, tracked)
  at TYPE_HEADING, in capitals, TEXT_DIM, TEXT on hover. The rule over the heading is 3 px of TEXT.
- [x] AC5 (bigger End turn): The End turn key is as wide as the rail's content (the rail's width less SPACE_4 each
  side) and 80 px tall, its label at TYPE_BODY; its right and bottom edges sit SPACE_4 from the window's right and
  bottom edges.
- [x] AC6 (alignment): The rail's padding and the play area's margins are SPACE_4: the "Realm" heading's top and the
  rail's rule's top are at the same y (SPACE_4 under the strip), and the Realm heading starts SPACE_4 from the window's
  left edge.

## Out of scope
- The hand's "2 / 2" actions count stays where it is (204).
- Card faces, the Realm row and the territory view.
- Moving the sidebar to the left (the mock's rail is on the left; ours stays on the right).

## Design notes
- `GameTheme`: new `CapsLink` (a Button variation like `Link`, in the heading face at TYPE_HEADING, uppercased by the
  sidebar), new `Strip` (PanelContainer: RAISED, 3 px TEXT bottom rule, SPACE_2 × SPACE_4 padding) and `Rail`
  (PanelContainer: no fill, 1 px HAIRLINE left rule, SPACE_4 padding). `DarkPanel` stays for overlays and modals.
- `BoardLayout`: no outer margin; the strip spans the window; the play area gets its own SPACE_4 margins.
- `EndTurnKey.SIZE` gives way to the rail's width (the key fills its column) and an 80 px height.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_end_turn_key::test_the_lamp_is_ochre_with_actions_left_and_sage_when_spent_with_no_count_under_it`; the reason case stays `test_a_discard_owed_lights_brick_and_disables_the_key_with_the_reason` |
| AC2 | `test_sidebar::test_the_top_bar_sits_on_a_full_bleed_strip_ruled_underneath` |
| AC3 | `test_sidebar::test_the_rail_is_open_on_the_board_with_a_hairline_to_its_left` |
| AC4 | `test_sidebar::test_the_government_link_is_in_the_heading_face_under_a_3_px_rule`, `test_the_sidebar_names_the_civilization_and_its_government`, `test_under_anarchy_the_sidebar_reads_anarchy` |
| AC5 | `test_end_turn_key::test_the_key_fills_the_rails_width_at_80_px_in_the_windows_bottom_right_corner` |
| AC6 | `test_sidebar::test_the_realm_heading_and_the_rails_rule_line_up_space_4_under_the_strip` |

## Manual check
- [ ] Start a game (`godot --path . -- --civ sumer --seed 5`) and compare with `docs/design/transitions.html` (night
  shift): a lighter strip with a heavy rule under it; the rail open on the board with a fine rule to its left; "SUMER"
  in the display face, "CHIEFDOM ›" in small tracked caps; End turn wide and tall in the bottom-right corner.
- [ ] With 2 actions left, End turn shows no "2 actions left"; the hand's heading still reads "2 / 2".
- [ ] Day mode: the strip, the rules and the rail read correctly on paper.
- [ ] 1280×720: nothing overlaps; the hand still fits beside the rail.

## Log
- The government's text is upper-cased in code (`name.to_upper()`): a Godot Button has no `uppercase`. That changed
  two older assertions in `test_identity_lines` (Council, Kingship) to the capitals, as AC4 asks.
- The key label went from TYPE_LABEL to TYPE_BODY (`KeyLabel` is only End turn's). The strip's padding is SPACE_2 ×
  SPACE_4 (mock 8 × 14) and the rail's SPACE_4 (mock 14).
