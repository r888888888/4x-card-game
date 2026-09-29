---
id: 077
title: Market earns wealth per city
type: feature
status: ready
branch: feat/077-market-scales-with-cities
---

## Goal
Stop Market from being an automatic early rush. Today it makes a flat +1 wealth per turn (+1 more on
Gold), so a cheap Market pays for itself fast and snowballs. After this it makes +1 wealth per city
each upkeep: it earns 1 per turn with only the Capital and grows as you settle, so wealth rewards
expansion, which is where food goes after 076. Depends on 076 (Market costs 3 wealth there).

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [ ] AC1: Rules, with `TEST_CARDS`: given a building in the tableau whose effect is upkeep
  `gain_per_tag` wealth ×1 per `city` tag, and a tableau with 3 cards tagged `city` (Capital + 2 Cities)
  and 0 wealth, when upkeep runs, then wealth is 3. With only the Capital, wealth is 1.
- [ ] AC2: Rules: `upkeep_forecast` for the tableau in AC1 (3 cities) shows +3 wealth from that building,
  and leaves resources unchanged.
- [ ] AC3: Content: in the real data, Market has an upkeep `gain_per_tag` effect with resource
  `GameEngine.WEALTH` and tag `city`, keeps an upkeep wealth bonus conditioned on the
  `gold` keyword, and has no flat (untagged) upkeep wealth `gain`.
- [ ] AC4: Content: Market's short card text in the real data mentions "per city".
- [ ] AC5: The existing guards stay green: real data loads without warnings, every wealth cost has a
  wealth source, and the 20-seed scripted sweep (`test_scripted_sweep_over_20_seeds`) passes unchanged.

## Out of scope
- Market's cost (set to 3 wealth in 076), VP, tag or deck count.
- Caravan, Capital and other wealth income.
- New effect ops or engine changes: `gain_per_tag` already counts tableau cards by tag and is
  upkeep-safe.

## Design notes
Data only (`data/cards.json`). Market effects:

| | Now | New |
|---|---|---|
| Base | ⟳ +1 wealth | ⟳ +1 wealth per city (`gain_per_tag`, tag `city`, zone tableau) |
| Gold | ⟳ +1 wealth on Gold | unchanged |

Capital and City both carry the `city` tag, so a Market earns at least 1 per turn. At 3 wealth it
pays back in 3 turns with only the Capital, 2 turns on Gold, and faster with each City.

AC1/AC2 may already pass: `gain_per_tag` at upkeep exists (Harvest Festival uses it). If so, they
stand as regression guards and the red checkpoint relies on AC3/AC4.

Run the `balance` skill after 076 and after this item, and record both in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_rules::test_…` |

## Manual check
Run `godot --path .`.
- [ ] Market's card reads "⟳ +1 wealth per city" plus the Gold bonus, and costs 3 wealth.
- [ ] Build a Market, then found a City: the upkeep forecast and the wealth gained rise by 1.

## Log
