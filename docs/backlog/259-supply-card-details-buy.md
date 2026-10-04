---
id: 259
title: A click on a supply pile opens its details, which offer Buy
type: feature
status: in-progress
branch: feat/259-supply-card-details-buy
---

## Goal
On the supply screen a click buys at once, so the player can't read a card in full before paying for it, and a
misclick spends wealth. After this, a click (or Enter) on a pile opens the card's details over the supply screen,
showing the pile as it stands (its price tag and copies left) with a Buy key; buying is a deliberate second step.

## Acceptance criteria
- [ ] AC1: Given the supply screen open with 10 wealth and a pile priced 3 with 6 left, when the player clicks that
  pile's card (or presses Enter on it while it has focus), then nothing is bought (wealth stays 10, 6 left, discard
  unchanged) and the card details modal opens over the supply screen, showing that card's details.
- [ ] AC2: Given that pile's details open, then the modal's aside shows the card with the pile's price tag below it
  reading "Buy" and "3" and, under the tag, "6 left"; the footer holds Close (Esc) and a visible, enabled primary
  **Buy** key, rightmost; and Play, Learn, Move… and Disband are hidden.
- [ ] AC3: Given that pile's details open, when the player presses Buy, then the modal closes, the supply screen
  stays open, one copy is bought (wealth 7, the pile shows 5 left, the discard holds one more copy of the card) and a
  copy flies to the screen's Discard counter as a click-buy did before.
- [ ] AC4: Given the supply screen open with 2 wealth and that pile priced 3, when the player opens its details, then
  Buy is disabled, the engine's `buy_error` for the pile is printed on the footer's left, and the aside's price tag is
  dimmed (as on the supply screen). The same holds for a sold-out pile (0 left).
- [ ] AC5: Given a hand card's, a tech's or a Realm card's details (not a supply pile's), then the footer shows no
  Buy key and no reason text, and the aside shows no price tag or copies-left line.
- [ ] AC6: Given a pile's details open over the supply screen, when the player presses Esc or Close, then only the
  modal closes and nothing is bought; the supply screen stays open.

## Out of scope
- Buying several copies from one opening of the modal (Buy closes it; the player clicks the pile again).
- A quick-buy shortcut on the supply screen (Enter now opens details too).
- Any change to the engine's buy rules, prices or `buy_error` reasons.

## Design notes
- Design confirmed with the user: `docs/design/supply-details-options.html`, option B (the tag hangs under the card).
  Buy closes the modal; a refusal's reason sits on the footer's left, not only in a tooltip; Enter opens details
  like a click.
- UI only (`ui/supply_screen.gd`, `ui/card_details_modal.gd`, `ui/main.gd`); no engine change: the modal reads
  `buy_error`, `buy_price` and `supply_left`, which exist.
- `SupplyScreen.pick(view)` (the pile's `picked` signal: click and Enter) now opens details; the old buy body becomes
  a public `SupplyScreen.buy(view)` the modal's Buy calls, which keeps the copy's flight. Tests that call
  `supply.pick(...)` to buy (`test_supply_screen`, `test_card_faces`, `test_counter_and_card_sounds`,
  `test_resource_tokens`) move to `supply.buy(...)`: the behaviour they check (the buy, its flight, sounds and
  counters) is unchanged, only the entry point.
- The price tag is built by one shared helper (today `SupplyScreen._price_tag`) so the modal's tag and the screen's
  match; it may move to `UIKit`.
- A refused click no longer happens: an unbuyable pile opens details with Buy disabled. The click path's shake, its
  floating error and the `refused` signal (main logs it) become unreachable; remove them in this item, keeping the
  modal's Buy re-checking `buy_error` before buying as Learn does.
- Test hooks on `CardDetailsModal`: `buy_button()`, the footer reason label, and the aside's tag and count.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_supply_screen::test_a_click_on_a_pile_opens_its_details_and_buys_nothing`, `test_enter_on_a_focused_pile_opens_its_details` |
| AC2 | `test_supply_screen::test_a_piles_details_show_its_tag_count_and_an_enabled_buy` |
| AC3 | `test_supply_screen::test_buy_in_a_piles_details_buys_a_copy_and_closes_them`, `test_buy_flies_a_copy_to_the_discard_counter` |
| AC4 | `test_supply_screen::test_an_unaffordable_piles_buy_is_disabled_with_the_reason_on_the_footer`, `test_a_sold_out_piles_buy_is_disabled_with_the_reason` |
| AC5 | `test_details_modal::test_buy_and_the_pile_tag_are_absent_outside_a_supply_pile` |
| AC6 | `test_supply_screen::test_esc_or_close_on_a_piles_details_buys_nothing` |

## Manual check
- [ ] `godot --path .`, press S, click a pile you can afford: details open over the supply with the tag and count
  under the card and Buy rightmost; press Buy: the modal closes and a copy flies to Discard; the count drops by one.
- [ ] Click a pile you can't afford: Buy is dashed (disabled), the reason sits on the footer's left, the tag is dim.
- [ ] Tab to a pile and press Enter: details open, with focus on Buy; Enter again buys.
- [ ] Open a hand card's details: no Buy, no tag, no reason.
- [ ] Both themes (paper and night): the tag's gold and the reason's colour read on the sheet.

## Log
