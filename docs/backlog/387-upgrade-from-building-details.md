---
id: 387
title: Upgrade a building from its details modal
type: feature
status: red-review
branch: feat/387-upgrade-from-building-details
---

## Goal
Today an upgrade is built only from the Build modal, reached by the "+ Upgrade" chip (302). After this, a building's
card details (opened on a building in the realm) gain an **Upgrades** section, design Y of
[building-upgrade-options.html](../design/mocks/building-upgrade-options.html): every upgrade its chain could take,
built or not, with its status, and an Upgrade button on the ones that can be built now. Everything about one building,
its upgrades included, is in one place. The chip and the Build modal stay as they are.

## Acceptance criteria
Fixture: `test_upgrades`' cards and menu (Farm ← Plough, Ditch, Weir; Chapel ← Sanctum, Rampart; Sanctum ← Cathedral),
Plough locked unless said otherwise.

- [ ] AC1 (engine, the rows): `upgrade_rows(uid)` on a building in the tableau returns one row per pair of a base and
  a build-menu entry (locked or not) that upgrades it, where the bases are uid then `upgrade_tree(uid)` in order, and
  the entries come in menu order: `{card_id, base, built, error}`. `built` is the uid of that upgrade on that base, or
  -1; `error` is `build_error(card_id, base)` when not built, "" when built. Given a Farm on Homeland (no fresh water)
  with a Ditch, then the rows are Plough (built -1, "Plough isn't unlocked yet."), Ditch (built = the Ditch's uid,
  ""), Weir (built -1, the Weir's requires error). Given a Chapel carrying a Sanctum, the rows are Sanctum (built),
  Rampart (on the Chapel, buildable: error ""), then Cathedral (on the Sanctum, buildable). A Cathedral row only appears
  once a Sanctum stands. It returns [] for a uid that isn't a building in the tableau, or a building nothing upgrades.
- [ ] AC2 (the section): Opening the details of a building in the realm whose `upgrade_rows` isn't empty shows an
  "Upgrades" section, one row per row in order, each reading the upgrade's name over its rules
  (`upgrade_rules_text`). A built row reads "Built", or its `fallen_back_reason` when it has fallen back. A row that
  could be built shows an Upgrade button with `build_cost(card_id)`. A refused row shows its `error` and no button. The
  section is hidden for a building with no rows, and for a hand card, a supply pile, a tech or a definition's details.
- [ ] AC3 (building): Pressing a row's Upgrade calls `build(card_id, base)`: the cost is paid, the upgrade is on the
  base, and the details close (the territory view shows the new ribbon and the build ceremony plays on the base, as a
  build from the Build modal does).
- [ ] AC4 (blocked): While a decision is owed or the game is over, each Upgrade button is disabled with
  `build_menu_error()` as its tooltip; a row whose only problem is cost (food 0) shows its "can't afford" reason with no
  button.

## Out of scope
- An upgrade's own details (upgrades have no card in the realm, only ribbons); clicking a ribbon.
- A preview of what the upgrade changes (the Build modal has it; the section doesn't).
- Upgrades an unbuilt link of the chain would take (Cathedral while no Sanctum stands).
- Changes to the chip or the Build modal.
- The bot: it builds upgrades through `build` already (303).

## Design notes
- New engine query `upgrade_rows(uid) -> Array[Dictionary]` (in `Upgrades`, via `GameEngine`), so the UI decides no
  status itself. It reads the config's whole `build_menu`, locked entries included, so a locked upgrade shows "isn't
  unlocked yet" (design Y's "Not unlocked").
- UI: a section in `CardDetailsModal` between the body and the Gives row, built like the Gives row; the row's status is a
  `Caption`, a refusal the `Refusal` variation, the button `UIKit.button` with the cost (as the supply screen shows
  one). `card_details_modal.gd` is ~420 lines; if the section pushes it past 500, put it in its own script
  (`ui/upgrade_list.gd`).
- Assumption (not asked): Upgrade closes the details, like Disband and Contribute do, rather than refreshing them.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_upgrades::test_a_farms_rows_are_every_upgrade_in_menu_order_built_or_not`, `test_a_chain_lists_its_bases_in_order_and_a_link_only_once_its_base_stands`, `test_no_rows_for_anything_but_a_building_something_upgrades` |
| AC2 | `test_upgrade_ribbons::test_a_buildings_details_list_its_upgrades_built_or_to_build`, `test_a_fallen_back_row_reads_its_reason_and_a_refused_one_its_error`, `test_no_upgrades_section_where_there_is_nothing_to_upgrade` |
| AC3 | `test_upgrade_ribbons::test_upgrade_builds_it_closes_the_details_and_plays_the_ceremony` |
| AC4 | `test_upgrade_ribbons::test_while_a_decision_is_owed_each_upgrade_button_is_disabled_with_why`, `test_a_row_short_of_its_cost_reads_why_with_no_button` |

## Manual check
- [ ] Compare with design Y in `docs/design/mocks/building-upgrade-options.html`, in Paper and Night.
- [ ] In a game with a Shrine (or any building with upgrades), open its details: a built Temple reads Built, and
  Upgrade on the next one builds it, with its ribbon and the ceremony on the territory view.

## Log
- 2026-10-06: specced; the user chose design Y (a section in the details that builds directly) over an Upgrade… button
  that opens the Build modal.
- 2026-10-07: red. Decisions: while a decision is owed or the game is over (`build_menu_error()` non-empty), every row
  not built keeps its Upgrade button, disabled with that reason (AC4); otherwise a row whose `error` isn't "" shows it
  and no button (AC2). The button reads "Upgrade for <cost>" (`Fields.amounts_text`), "Upgrade" when free. Hooks on
  CardDetailsModal: `upgrade_rows()` ({name, rules, status, button}) and `upgrades_shown()`. The hidden-section test
  covers a hand card and two definitions (Farm, Explorer), not a supply pile, which opens a definition's details too.
