---
id: 277
title: Remove the Winnow card from the supply
type: feature
status: review
branch: feat/277-remove-winnow-from-supply
---

## Goal
Winnow (trash another card in hand) is no longer for sale, so the player can't thin their deck from the supply. It
was listed in `docs/TODO.md`.

## Acceptance criteria
- [ ] AC1: Given the real data, when the supply is built for a new game, then it has no Winnow pile, and no other
  supply pile changes.
- [ ] AC2: Given the real data, when it loads, then the loader accepts it and every real card still reaches a game:
  Winnow's card definition is deleted too (the `every real card can reach a game` invariant requires it).
- [ ] AC3: Given the `trash` op, when the two UI tests that target a card in hand run, then they use a fixture Purge,
  not a real card, and pass.

## Out of scope
- Removing the `trash` op (the engine keeps it; `test_trash.gd` covers it).
- Replacing Winnow with another card, or rebalancing anything (note balance worries in the Log).

## Design notes
- Data change only: delete the `winnow` entry from `supply` in `data/config.json`. No engine change.
- `PLAN.md` says the `trash` op's real card is "Winnow, supply only": reword to say no card in the supply uses it.
- Content tests assert invariants and never name a card id, so AC1 is a Manual check (exact shipped content).
- Remove the line from `docs/TODO.md`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | Manual check |
| AC2 | `test_content::test_every_real_card_can_reach_a_game` (existing) |
| AC3 | `test_trash_targeting`, `test_toasts::test_the_targeting_hint_is_a_toast_until_targeting_ends` |

## Manual check
- [ ] Start a game and open the supply: no Winnow pile; the other piles are as before.

## Log
- Deleting only the supply entry failed the reachability invariant; user chose to delete the card too. Winnow tests moved to a fixture Purge.
