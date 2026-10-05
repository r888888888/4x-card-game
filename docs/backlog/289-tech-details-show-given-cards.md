---
id: 289
title: A tech's details show the cards it gives
type: feature
status: review
branch: feat/289-tech-details-show-given-cards
---

## Goal
A tech's details say "Granary can now be bought in the supply." but never what a Granary does, so the player can't
judge a tech by what it gives without hunting the card down in the supply. After this, a tech's details show each card
the tech gives (creates or unlocks) as its compact card face in a **Gives** row, captioned with how you get it, and a
click on one opens that card's full details on top. Design B of
[tech-gives-options.html](../design/tech-gives-options.html).

## Acceptance criteria
- [x] AC1: Given a tech whose effects are `create` granary (zone discard), `unlock` granary and `unlock` houses, when
  `def_details(tech)` is asked, then its `gives` is `[{card_id: "granary", how: "1 to your discard · in the supply"},
  {card_id: "houses", how: "in the supply"}]`: one entry per card, in first-effect order. A card only created gives
  `how` "1 to your discard"; two `create` effects of one card give "2 to your discard".
- [x] AC2: Given that tech, when `def_details(tech)` is asked, then its `rules` no longer hold the lines of the
  `create` and `unlock` effects ("Add a Granary to your discard", "Granary can now be bought in the supply.") while
  its other lines stay (a `gain` effect's line, the prerequisite and eureka lines). `card_details(uid)` of a live copy
  of the tech gives the same `gives` and `rules`. The tech's card face text is unchanged.
- [x] AC3: Given a tech with no `create` or `unlock` effect, or a card of any other type (a civilization whose start
  effect creates a card included), when its details are asked, then `gives` is `[]` and its rules are as before.
- [x] AC4: Given the details modal opened on the AC1 tech (from the Knowledge screen, `open_tech`), then it shows a
  Gives row of two compact card faces, Granary then Houses, each with its `how` caption under it; opened on a card
  whose `gives` is empty, it shows no Gives row.
- [x] AC5: Given the AC4 modal, when a Gives card is clicked (or focused and Enter or I pressed), then a second details
  modal opens on top of the tech's showing that card's `def_details`, with no footer action (no Learn, Play, Buy); the
  tech's modal stays open beneath. When Esc is pressed, only the top modal closes and the tech's details are back on
  top. A given card's own details have no Gives row unless that card is a tech that gives cards.

## Out of scope
- A Gives row on non-tech cards (a civilization's start cards, a Settler's City).
- Live supply state on the given cards (price now, copies left, Buy from the tech's details).
- The tech tile tooltip on the Knowledge screen, which already lists what a tech gives.

## Design notes
- Engine: `CardDetails._details` adds `gives: Array[{card_id, how}]` for a tech, built from its `create` and `unlock`
  effects in order (Research's `tech_tree` already collects the same ids as `gives`; share the walk). The caption text
  is engine-made, since UI text never names counts or zones: `"%d to your %s" % [creates, zone]` and/or
  `"in the supply"`, joined by " · ". Every tech `create` in the data targets the discard, but don't assume it.
- Rules without the given lines: `rules_tooltip` joins one line per effect, so build the tech's rules from its effects
  minus `create`/`unlock` (a variant of `rules_tooltip` that skips ops, or filter by the effect's `describe` line). The
  card face keeps all lines.
- UI: `CardDetailsModal` adds the Gives row below the content row, spanning the sheet: per entry a `CardView` at
  `TABLEAU_SIZE` as a focusable button with a `Caption` label under it. The row is hidden when `gives` is empty.
- Stacking: `CardDetailsModal` is one instance on `main.modals`; pushing it again would just bring it back to the top.
  The given card opens on a second `CardDetailsModal` (built lazily by the first, on the same `ModalStack`) via
  `open_def`. That nested one can itself open a third only for a tech, which is out of scope, so one extra instance is
  enough.
- Test hooks on the modal: the Gives row's card ids and captions, and a way to press a Gives card.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_details::test_a_techs_details_list_each_card_it_gives_with_how_you_get_it` |
| AC2 | `test_card_details::test_a_techs_rules_leave_out_the_lines_of_what_it_gives` |
| AC3 | `test_card_details::test_cards_that_give_nothing_or_are_not_techs_have_no_gives` |
| AC4 | `test_tech_gives_modal::test_a_techs_details_show_a_gives_row_of_its_cards_with_captions`, `test_a_card_that_gives_nothing_shows_no_gives_row` |
| AC5 | `test_tech_gives_modal::test_clicking_a_gives_card_opens_its_details_on_top_and_esc_returns_to_the_tech`, `test_enter_or_i_on_a_focused_gives_card_opens_its_details` |

## Manual check
- [ ] Knowledge screen → Mysticism: three compact cards (Temple, Stone Circle, Oracle of Delphi) fit across the modal
  without scrolling at the default window size; captions read "1 to your discard · in the supply", "in the supply",
  "1 to your discard".
- [ ] Pottery's Rules list holds only its eureka line; its big card in the aside still lists everything.
- [ ] Click Granary: its details lay down 8 px down-right over Pottery's, with the How it works terms; Esc returns to
  Pottery; Esc again closes it. Tab reaches the Gives cards and shows the focus ring.
- [ ] Code of Laws: Kingship (a government) shows as a compact card and opens its details.
- [ ] Night and Day both read.

## Log
- 2026-10-05: Designs in [tech-gives-options.html](../design/tech-gives-options.html) (A links, B inline compact
  cards, C aside stack, D text section); the user picked B.
- 2026-10-05: Built. Engine: `CardDetails.gives(def)` (one walk, also used by `Research.tree`'s `gives`), the `gives`
  field on `def_details` / `card_details`, and `CardDef.rules_tooltip(card_db, skip_ops)` so a tech's details leave out
  `CardDetails.GIVES_OPS` lines while its face and tooltip keep them. UI: `CardDetailsModal`'s Gives row (heading, then a
  `GivesCard` button holding a `CardView` at `TABLEAU_SIZE` with a `Caption` under it), `given_details` built on first
  use, and I on a focused Gives card opening it (I otherwise closes). Fixture Silo stands in for Houses.
- Seen on the real data (Mysticism): the three cards fit, but a card with more text (Oracle of Delphi) grows taller
  than the others, so the captions don't line up across the row. Each caption still sits under its own card.
- The given card's sheet is smaller than the tech's and the stack centres each sheet, so it opens over the middle of
  the tech's sheet rather than visibly 8 px down-right of its corner. That is the existing `ModalStack` cascade, not
  something this item changed.
