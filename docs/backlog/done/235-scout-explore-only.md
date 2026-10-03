---
id: 235
title: Scout only explores
type: feature
status: done
branch: feat/235-scout-explore-only
---

## Goal
The Scout card explores and nothing else: it no longer draws a card or gives +1 action, so playing it costs an action.

## Acceptance criteria
- [ ] AC1: Given the real data, when the loader validates `data/cards.json`, then it loads with no errors (existing content invariants stay green).

## Out of scope
- Rebalancing Scout's price or other cards; balance is a separate item.

## Design notes
Content-only change to `data/cards.json`: Scout's effects become `[{ "op": "explore" }]`. Rules tests use `TEST_CARDS`, so none cover the real Scout; a test naming the card id in `test_content.gd` would be a smell, so no new test.

## Manual check
- [ ] Scout's card face reads only the explore text.
- [ ] Playing Scout opens the explore choice, then the action count drops by 1 with no card drawn.

## Log
