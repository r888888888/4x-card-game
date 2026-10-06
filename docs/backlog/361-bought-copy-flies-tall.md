---
id: 361
title: A card bought from the supply flies to the Discard counter very tall
type: bug
status: in-progress
branch: fix/361-bought-copy-flies-tall
---

## Reproduction
- Seed: 5 (`godot --path . -- --civ sumer --seed 5`); any supply game shows it.
- Steps:
  1. Have at least 3 wealth (or set 30) and open the supply (Buy Cards).
  2. Click Scout and press Buy in its details.
- Expected: a copy the size of the pile's card (245 × 175) flies from the pile to the Discard counter.
- Actual: the copy is 245 × 753 as it starts flying, reaching past the bottom of the screen, and it aims above the
  Discard counter (its flight target is worked out from the tall size).

## Acceptance criteria
- [ ] AC1: Given a supply game and a pile whose card is at rest, when its details' Buy is pressed, then the copy in
  flight (uid -100) has the pile card's size on the frame it starts flying and on each frame after, until it is freed
  (no taller than the pile card's height + 1 px).
- [ ] AC2: Given the same, when Buy is pressed, then the copy's centre heads for the Discard counter: on the frame
  it starts flying its centre is the pile card's centre (within 1 px), so the flight is aimed from where the copy is
  drawn.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply_screen::test_bug_361_the_bought_copy_keeps_the_pile_cards_size_as_it_flies` |
| AC2 | `test_supply_screen::test_bug_361_the_bought_copy_starts_on_the_pile_card` |

## Root cause
<!-- Filled in by Claude after the fix: what was wrong and why the tests didn't catch it. -->
Found while specifying: `SupplyScreen.buy` (`ui/supply_screen.gd`) makes a fresh `CardView`, adds it to the effects
layer, sets `copy.size = view.size` and calls `leave()`. As it enters the tree its wrapped text is measured at zero
width, so its minimum height is ~753 px and the size set can't go below it; nothing shrinks a LEAVING card, and
`CardMotion.leave` works out its target (`point - size / 2`) from the tall size. Board cards that leave were already
laid out, so only this fresh copy shows it. `test_buy_flies_a_copy_to_the_discard_counter` checks only that a copy
flies, not its size.

## Manual check
- Buy a card from the supply at normal speed: the copy keeps the pile card's size as it shrinks into the Discard
  counter, and lands on it.

## Log
- 2026-10-06: reported as "when I buy a tech card, it appears briefly to be very tall"; reproduced with a supply buy
  (frames at 0.1× time). Learning a tech from the Knowledge screen shows nothing tall.
