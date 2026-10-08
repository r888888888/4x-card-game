---
id: 361
title: A card bought from the supply flies to the Discard counter very tall
type: bug
status: done
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
- [x] AC1: Given a supply game and a pile whose card is at rest, when its details' Buy is pressed, then the copy in
  flight (uid -100) has the pile card's size on the frame it starts flying and on each frame after, until it is freed
  (no taller than the pile card's height + 1 px).
- [x] AC2: Given the same, when Buy is pressed, then the copy's centre heads for the Discard counter: on the frame
  it starts flying its centre is the pile card's centre (within 1 px), so the flight is aimed from where the copy is
  drawn.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply_screen::test_bug_361_the_bought_copy_keeps_the_pile_cards_size_as_it_flies` |
| AC2 | `test_supply_screen::test_bug_361_the_bought_copy_starts_on_the_pile_card` |

## Root cause
Two things made the copy tall, both in `SupplyScreen.buy` (`ui/supply_screen.gd`):
1. The copy is a new `CardView` added straight to the effects layer, with no slot to fit it. As it enters the tree its
   wrapped text is measured at zero width, so its minimum height is ~753 px (a 175 px card) and `copy.size = view.size`
   can't go below it. Nothing shrinks a LEAVING card, and `CardMotion.leave` aims from the tall size, so the copy also
   flew above the Discard counter. Fix: `CardView.lay_out_now(at)` sorts the card's containers at once, has every part
   measure itself again (innermost first), and sets the size, so the card is right before its first frame.
2. `view.size` was read after `e.buy()`, whose refresh relays the pile card (selling the last copy adds a "⊘" reason
   line, measured at zero width too), so the copy could take a transiently tall pile size. Fix: read the pile card's
   rect before buying.

Tests didn't catch it: `test_buy_flies_a_copy_to_the_discard_counter` only counted the copies in flight. While
fixing, AC2's test was corrected (with the user's approval) to read the pile card's centre after the supply finished
opening: two frames in, the pile cards are still popping in at scale 0.

## Manual check
- Buy a card from the supply at normal speed: the copy keeps the pile card's size as it shrinks into the Discard
  counter, and lands on it.

## Log
- 2026-10-06: reported as "when I buy a tech card, it appears briefly to be very tall"; reproduced with a supply buy
  (frames at 0.1× time). Learning a tech from the Knowledge screen shows nothing tall.
- 2026-10-06: fixed; checked in the real game at 0.1× time (seed 5, Scout): the copy pops at the pile card's size.
