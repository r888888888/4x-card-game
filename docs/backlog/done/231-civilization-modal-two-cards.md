---
id: 231
title: Show the civilization modal as two cards on the desk
type: feature
status: done
branch: feat/231-civilization-modal-two-cards
---

## Goal
The civilization modal (119, 205) is one long column of text. It says "Civilization" three times, the civ's name and
the government's name are both the Title size, the rules are bare lines, and Revolt… is jammed under the last rule.
Option B from [civilization-modal-options.html](../design/civilization-modal-options.html) fixes this: the
civilization and the government *are* cards, so the modal lays them down as two large card faces side by side. Under
them, the government deck is a row of small tabs. The player can see at a glance what their civ does, what their
government allows, how close the realm is to its unrest limit, and what they could switch to.

## Acceptance criteria
- [x] AC1 (engine): Given unrest is on, the government in play is Chiefdom (unrest limit 5) and unrest is 2, when
  `card_details(uid)` is asked about the government, then its `state` holds `"Unrest 2 / 5"`. With unrest at 5 (at
  Chiefdom's limit), it reads `"Unrest 5 / 5"`. With a modifier that adds 1 to the limit, it reads
  `"Unrest 2 / 6"`: it uses `unrest_limit()`.
- [x] AC2 (engine): Given a government with no unrest limit (Anarchy: `unrest_limit()` < 0), or a game with unrest
  off, when `card_details` is asked about the government, then `state` has no `Unrest` line. `def_details` of any
  government never has one, since it has no live state.
- [x] AC3: Given the modal is open on a Sumer game (seed 5, Chiefdom), then the body holds two card panels side by side,
  the civilization's on the left and the government's on the right, at the same height. Each shows, top to bottom:
  the name, a type band, the type line ("Civilization" / "Government"), every rule line, any `state` line from
  `card_details`, and the full flavor at the foot when the card has one. `shown()` is still
  `[civ name, government name]`. The quote is not on either card. The government card ends with Revolt…, which keeps
  its enabled state and tooltip from `revolt_error` (205).
- [x] AC4: Given the modal is open, when the player clicks the civilization card or the government card, then the card
  details modal opens on top (depth 2). It shows that card's `card_details` (its quote, its state and its terms), and
  closing it leaves the civilization modal open. A click on Revolt… still opens the revolution confirmation, not the
  details.
- [x] AC5: Given the government deck holds Kings (the `test_government_deck` fixture), then under the two cards there is
  a "Government deck" caption followed by one tab per card, in deck order, each showing the card's name. A click on
  the Kings tab opens Kings's details on top. Given an empty deck, then the caption reads "Government deck" with
  "empty" beside it and there are no tabs.
- [x] AC6: Given Palette's Night and Day sets, then each holds a `CIVILIZATION` and a `GOVERNMENT` colour, and
  `CardView.type_color` returns them for `CardDef.CIVILIZATION` and `CardDef.GOVERNMENT`. The modal's bands use these
  colours and follow a Day mode switch while the modal is open.

## Out of scope
- The sidebar, the revolution confirmation and the government choice overlay (they keep their current look).
- Showing civilizations or governments anywhere else as cards (the new game screen keeps its list, 212).
- The quote's place in card details (unchanged; details already show it).
- Balance or any change to rules text.

## Design notes
- AC1/AC2 add to `CardDetails._state` (engine): when the card is the government in play and the government has a limit,
  append `"Unrest %d / %d"`. This also shows in the ordinary card details. It's the only engine change.
- The modal fetches the government's details with `card_details(uid)` (live state) instead of `def_details`. It does
  the same for the civilization, which has no state lines today.
- The details modal opens by card id today (`open_def`) or by a view (`open`). Clicking a live card in this modal needs
  its live details: add an opener that takes a uid (e.g. `open_uid(uid)`) instead of building a fake CardView.
- Card faces: build them from the modal's own layout (a `DarkPanel`-like card box with the band, `CardTitle` name,
  `BodySmall` type line, `Body` rules, `Caption`/italic flavor), not from `CardFace.build`. CardFace is sized for the
  hand and adds cost, reason strip and info lines this modal doesn't need. If a shared piece turns up (the band), pull
  it into `CardFace` as a static helper.
- New theme looks the cards repeat go in `GameTheme` (e.g. `DeckTab` for the small tabs: top border in `GOVERNMENT`,
  `FIELD` fill, `Caption` text).
- Width: two cards side by side fit in `BODY_MAX_WIDTH` (640), each about 300 px wide. Anarchy's rule text is long and
  makes the government card tall. Both cards share the taller one's height (AC3), and the modal's body scrolls past
  the viewport as it does today.
- Tests that change wording (approved under 119 and 154): 119 AC2's "flavor, then quote, then rules" in
  `test_identity_lines.gd`, and 154's `"Government deck: Kings"` in `test_government_deck.gd`. This item replaces
  those criteria: the quote moves to details (AC3/AC4) and the deck line becomes tabs (AC5). Rewrite those tests
  against the new criteria at the red checkpoint and call them out for review.
- Palette colours: pick from the guide's secondary hues (§4.3) so the two are distinct from the six card planes in both
  modes. Update `docs/design/tokens.md`'s plane row.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_unrest::test_the_governments_details_show_unrest_against_its_limit` |
| AC2 | `test_unrest::test_no_unrest_line_without_a_limit_or_without_unrest` (a guard: passes before the change) |
| AC3 | `test_identity_cards::test_the_civilization_and_government_lie_side_by_side_as_cards`; rewritten: `test_identity_lines::test_pressing_it_opens_one_modal_with_the_civilization_then_the_government` (119 AC2: no quote, flavor after the rules) |
| AC4 | `test_identity_cards::test_a_click_on_a_card_opens_its_details_on_top`, `test_identity_cards::test_a_click_on_revolt_opens_the_confirmation_not_the_details` (a guard) |
| AC5 | `test_identity_cards::test_the_government_deck_is_a_row_of_tabs_that_open_details`, `test_identity_cards::test_an_empty_government_deck_says_so_with_no_tabs`; rewritten: `test_government_deck::test_the_identity_modal_lists_the_government_deck` (154: tabs, not a line) |
| AC6 | `test_identity_cards::test_civilization_and_government_have_their_own_band_colours`, `test_identity_cards::test_the_bands_follow_day_mode_while_open` |

## Manual check
- [ ] `godot --path . -- --civ sumer --seed 5`, then click "Sumer" in the sidebar. The two cards sit side by side and
  level: name, plum (Sumer) / indigo (Chiefdom) band, type, rules, "Unrest 0 / 5" on Chiefdom, Sumer's flavor in
  italics at its foot, Revolt… at the foot of Chiefdom. "Civilization" appears only as the title and Sumer's type.
- [ ] Hover a card: an ink rule and a hard 4,4 shadow. Click it: its details open on top, offset +8,+8, with the quote;
  Esc closes only the details.
- [ ] Settings → Day mode with the modal open: the bands, cards and tab switch to Day colours.
- [ ] Play until a government card (Kingship) joins the deck, or revolt and let Anarchy end: the "Government deck" row
  shows a tab per card, and a click opens its details. With an empty deck it reads "GOVERNMENT DECK empty".
- [ ] Revolt into Anarchy, then open the modal: Anarchy's long rule wraps on its card, both cards stay level, and the
  modal fits the 1080 px screen.
- [ ] The plum and indigo bands are distinct from each other and from the six card colours, in Night and Day.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- 2026-10-02: Chosen from five options in `docs/design/civilization-modal-options.html` (A ledger, B two cards,
  C charter, D index tabs, E control panel). Answers: new palette roles for both bands; full flavor at the foot and
  the quote only in details; live unrest as a `state` line from the engine; deck tabs open details.
- 2026-10-02: Built in worktree `../4x-231`. The cards are Buttons (IdentityCard) holding a margin and column whose
  minimum size the button copies, so a click anywhere on a card opens its details and Revolt…, a child, still takes
  its own clicks. `CardDetailsModal.open_card(card)` opens a live card's details; the modal asks for them with
  `details_requested(card)`. New theme looks: `IdentityCard`, `Flavor`, `DeckTab`.
- 2026-10-02: `test_modal_stack`'s "click on the lower modal beside the top one" (153) no longer had a spot to click:
  the civilization modal is now smaller than card details and sits wholly under them. With the user's OK the pair is
  swapped (details below, civilization modal on top), same assertions:
  `test_a_click_on_the_details_beside_the_civilization_modal_closes_only_the_civilization_modal`.
- 2026-10-02: The colours, plum `c48faf` / `b07d9c` and indigo `a39bcb` / `8f88b8` (Night / Day), aren't from the
  guide's six hues. They're for the manual check to confirm; §4.3 of the style guide doesn't list them yet.
