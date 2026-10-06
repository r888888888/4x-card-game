---
id: 302
title: Show upgrades as ribbons on their base, and build them from the Build modal
type: feature
status: red-review
branch: feat/302-upgrades-on-territory-view
---

## Goal
After 300 and 301 the engine builds upgrades onto buildings, but nothing on screen shows or builds them. After this, a
territory's view draws each building's upgrades as **ribbons** along the foot of its card (design A of
[building-upgrade-options.html](../design/mocks/building-upgrade-options.html)), a fallen-back ribbon hatched with the idle
lamp and its reason, and a building that could take an upgrade shows a **+ Upgrade** chip that opens 297's Build modal
on it; the modal gains an **Upgrades** heading (design X). The upgrade's own card face says what it builds on and the
tier it needs. Follows 297 (and 299) and 301.

## Acceptance criteria
Fixture: 300 and 301's cards, with Ditch's tier left unset, and a territory view open on Homeland.

- [ ] AC1 (ribbons): Given a Farm on Homeland carrying a Plough and a Ditch, then the territory view's row shows one card
  for the Farm (no separate card for either upgrade), with two ribbons at its foot in `upgrades_on` order, each reading
  the upgrade's name and its rules (its card text without the "Builds on …" and "Needs …" lines). A chain is drawn on
  the first base: a Chapel → Sanctum → Cathedral shows one Chapel card with a Sanctum ribbon then a Cathedral ribbon.
  The row's other cards and its "+ Build" slot outlines are what they would be without the upgrades.
- [ ] AC2 (fallen back): Given the Sanctum fallen back (Homeland below a Village), then its ribbon, and the Cathedral's
  after it, are drawn hatched with the ochre idle lamp and `fallen_back_reason` under the name ("Needs a Village.");
  when Homeland grows back, the next refresh draws them plain.
- [ ] AC3 (the chip): A building that `build_targets(id)` lists for some upgrade entry in `build_menu()` shows a dashed
  "+ Upgrade" chip at its foot; one that no unlocked upgrade can take now (none unlocked, all already built on it, or
  below the tier) shows none. Clicking the chip opens the Build modal for Homeland with the first such upgrade row for
  that building selected. Disabled with `_blocked_error`'s message as tooltip while a decision is owed or the game is
  over, as 297's "+ Build" is.
- [ ] AC4 (the Build modal): The Build modal's list gains an "Upgrades" heading between "Buildings" and "Units", with
  one row per pair of an upgrade entry in `build_menu()` and a building on this territory it builds on (in tableau
  order, then menu order), reading the upgrade's name over "on <base name>" and its cost. A row `build_error(id, base)`
  refuses is dimmed with that reason (so a tier upgrade below its tier reads "Sanctum needs a Village (Homeland is a
  Hamlet)."). The heading is hidden when it has no rows. Selecting a row shows the upgrade's card face and "If built on
  <base name>" with `build_preview(id, base_uid)`'s lines, and the key reads "Build <name>"; pressing it or Enter calls
  `build(id, base_uid)` and the territory view shows the new ribbon.
- [ ] AC5 (the upgrade's face): An upgrade's card face (in the Build modal, a tech's Gives row, its details) has the type
  line "Upgrade · <base name>" in place of "Building", each rules line led by "Also", and, for one with a tier, a
  stamp naming the tier. The names come from the engine (`upgrade_base_name(card_id)`, `tier_name` for the card's
  tier); the UI names no card.

## Out of scope
- The bot (303); content (305–307).
- Upgrades in the building's details modal (design Y, not chosen).

## Design notes
- `build_preview` (299) must accept a building uid as target for an upgrade entry; the preview's lines are the same
  keys (an upgrade lists no `free_slots` or `free_workers` line, since it takes neither).
- Engine queries this needs, added test-first in this item: `upgrade_base_name(card_id) -> String` ("" for a
  non-upgrade), and a card's tier name for the stamp (`card_tier_name(card_id)`), so the UI reads no `CardDef` field to
  build text. The ribbon's rules text comes from the card text the engine generates, minus the two header lines; ask
  the engine for it (`upgrade_rules_text(uid)`), don't strip strings in `ui/`.
- Looks: the ribbon is a new `GameTheme` variation (a hairline over it, the name semibold); the hatch and lamp reuse the
  idle look (§11.6). The chip is the dashed "+ Build" outline's style at chip size. The stamp is `Caption` in the
  territory colour with a 2 px border. No new colour literal in `ui/`.
- Cards with ribbons are taller; the row aligns its cards to the bottom so their names stay in a line.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| Engine | `test_upgrades::test_upgrade_base_name_names_the_building_an_entry_builds_on`, `test_upgrade_rules_text_leaves_out_the_builds_on_line`, `test_upgrade_tree_lists_a_bases_upgrades_depth_first`, `test_upgrades_for_lists_the_entries_a_base_could_take_now`, `test_upgrade_options_pair_each_upgrade_entry_with_each_building_on_a_territory`, `test_an_upgrades_preview_reads_its_bases_territory`; `test_building_tiers::test_card_tier_name_names_the_tier_a_card_needs`, `test_upgrade_rules_text_leaves_out_the_tier_line_too` |
| AC1 | `test_upgrade_ribbons::test_upgrades_show_as_ribbons_on_their_base_not_as_cards`, `test_a_building_without_upgrades_has_no_ribbons` |
| AC2 | `test_a_fallen_back_ribbon_is_hatched_with_its_reason_until_it_works_again` |
| AC3 | `test_a_building_that_could_take_an_upgrade_shows_the_chip`, `test_the_chip_opens_the_build_modal_on_the_first_upgrade_it_could_take`, `test_the_chip_on_a_chain_selects_its_next_link`, `test_the_chip_is_disabled_while_a_decision_is_owed` |
| AC4 | `test_the_build_modal_lists_upgrades_under_their_own_heading`, `test_the_upgrades_heading_is_hidden_with_no_rows`, `test_an_upgrade_row_previews_it_on_its_base_and_builds_it` |
| AC5 | `test_an_upgrades_face_names_its_base_and_its_tier` |

## Manual check
- [ ] Compare with design A + X in `docs/design/mocks/building-upgrade-options.html`, in Paper and Night.
- [ ] A Farm with two ribbons and a Shrine with a fallen-back Great Temple read clearly at the territory view's size.
- [ ] Shrink a Town to a Village (a Famine) and watch the ribbons hatch; grow it back and they clear.

## Log
- 2026-10-05: specced from the mocks; the user chose design A (ribbons) with X (the chip opens the Build modal).
