---
id: 023
title: More wealth sinks (more culture copies, Amphitheater)
type: feature
status: draft
branch: feat/023-more-wealth-sinks
---

## Goal
After 022, wealth piles up unspent. In scripted games (20 seeds) players ended with 26–60 wealth
(mean ~36), and the mean score fell from ~43 to ~21. Only 6 deck cards spend wealth. Add more
places to spend it, so wealth turns into VP during the game.

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [ ] AC1: The real data loads with no errors or warnings, and has a building **Amphitheater**:
  cost 1 food + 4 wealth, 2 VP, tag `culture`, effect ⟳ +1 VP. Its short card text is "⟳ +1 VP".
- [ ] AC2: The real deck has at least 10 cards that cost wealth (today 6: Temple ×2, Monument ×2,
  Pyramids ×1, Forge ×1).
- [ ] AC3: The existing content tests stay green: the 20-seed City smoke test, the wealth smoke test
  (022 AC3) and wealth-source coverage (022 AC2).

## Out of scope
- Wealth VP at game end (possible later item).
- Changing wealth income (Capital, Caravan, Market) or Market's VP.
- Balance targets in tests. Scripted-bot numbers go in the Log only.

## Design notes
Data only (`data/cards.json`, `data/config.json`). No engine change.

| Change | Now | New |
|---|---|---|
| Temple copies | 2 | 3 |
| Monument copies | 2 | 3 |
| Amphitheater (new) | — | ×2: building, 1 food + 4 wealth, 2 VP, `culture`, ⟳ +1 VP |

- Wealth-cost cards in the deck: 6 → 10. Deck size: 36 → 40.
- Before/after bot numbers: rerun the 022 scratch stats (20 seeds: mean score, unspent wealth at the
  end, wealth-cost plays per game) and record them in the Log. The bot never buys growth, so treat
  the numbers as a trend, not a target.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
Run `godot --path .`.
- [ ] Amphitheater shows "1 food, 4 wealth" and "⟳ +1 VP" and can be built once wealth is saved up.
- [ ] Over a full game, wealth gets spent rather than piling up. Record the final score and the wealth
  left in the Log.

## Open questions
- Is this still needed? The premise predates the research deck: 12 techs now cost 2–6 wealth each, so wealth may
  no longer pile up. Rerun the stats before deciding.
- AC1 fixes Amphitheater's exact cost and VP in a test, which the content-test rule forbids; move those numbers
  to Manual check if the item goes ahead.

## Log
