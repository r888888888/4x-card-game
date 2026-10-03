---
id: 243
title: Supply cards stand one height
type: feature
status: review
branch: feat/243-supply-cards-one-height
---

## Goal
A supply card whose text wraps no longer leaves the row uneven: every pile card takes the height of the tallest.

## Acceptance criteria
- [x] AC1: Given a supply row where one pile card's text wraps taller than the other's, when the screen is open, then every pile card has the height of the tallest.

## Out of scope
- Clipping text to the nominal 175px (chosen against: the row takes the tallest height instead).

## Design notes
`CardView.min_height` is a floor under the fitted height (`CardMotion._fit_size`); `SupplyScreen` sets it to the tallest card's minimum height whenever a pile card's content resizes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply_screen::test_pile_cards_share_the_height_of_the_tallest` |

## Manual check
- [ ] Open the supply with piles of differing text length: the cards line up at one height.

## Log
- Written after the fact (a small UI fix made on main); the test was confirmed failing without the change (175 vs 198).
