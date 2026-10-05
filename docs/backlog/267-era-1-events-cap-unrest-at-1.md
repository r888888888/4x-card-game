---
id: 267
title: Era-1 events add at most 1 unrest
type: feature
status: review
branch: feat/267-era-1-events-cap-unrest-at-1
---

## Goal
No era-1 event adds more than 1 unrest. Two era-1 events add 2: Omen of Doom (+2 now) and Bandit Raids (+1 per upkeep
for 2 turns). Both move to era 2 at full strength, so harsher unrest arrives with the Bronze Age and the deck escalates
by era (PLAN.md's "Solo opposition"). Era 1 is balanced around +1 as the most any event adds. Duplicate cards stay:
they add flavour.

## Acceptance criteria
- [x] AC1 (invariant): Every era-1 event in config `event_deck` adds at most 1 unrest in total. The total is:
  - every `gain unrest` in its play effects,
  - plus every `gain unrest` in its upkeep effects × its `discard.turns`,
  - plus, for a raid, the larger of what its `pillage` and its `repel` effects gain.

  The Famine and Anarchy aren't in `event_deck` and aren't counted.
- [x] AC2 (invariant): Every era named in config `event_deck`'s events can be reached: it is 1, or some tech in
  `research_deck` adds that era with `add_era`, or `era_unlocks` names it. A moved event then still enters the game.

## Out of scope
- New era-2 or era-3 events (270), and new ops (268).
- Choice events (269). Once they exist, 269 extends AC1 to count the option that gains the most unrest.
- Tuning anything else. Era-1 events now add about 3 unrest per pass through the deck instead of 7; that is a balance
  question (see Log).

## Design notes
- Data only: Omen of Doom and Bandit Raids get `"era": 2` in `data/cards.json`. Their `event_deck` counts don't change.
  Era-2 events wait in `future_events` until era 2 is added (074).
- The AC1 sum lives in the content test, not the engine. It reads `CardDef` effects and triggers.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_no_era_1_event_adds_more_than_1_unrest` |
| AC2 | `test_content::test_every_event_era_can_be_reached` |

## Manual check
- [ ] Shipped numbers for review:
  - Era 1 keeps Grumbling ×2 and Peasant Uprising (+1 unrest each), plus Raiders' pillage (+1).
  - Omen of Doom (+2) and Bandit Raids (⟳ +1 unrest, 2 turns) are era 2.
- [ ] Start a game and play to era 2 (Bronze Working): the event pile's tooltip counts the 2 moved events among those
  waiting, and they turn up only after era 2 is added.

## Log
- Balance worry, for the next balance item: era-1 events now add about 3 unrest per pass through the deck, down from
  about 7. Settlers (+1 each) become the main source of early unrest. Chiefdom's limit (8) and Feast may now be loose.
- AC2's test passed before the change (Radical Thinkers was already a reachable era-2 event); it guards the move.
