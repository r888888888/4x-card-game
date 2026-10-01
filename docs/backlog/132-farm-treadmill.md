---
id: 132
title: Break the early farm treadmill (no Irrigation, stronger Farms, wealth from Mines)
type: feature
status: review
branch: feat/132-farm-treadmill
---

## Goal
In playtesting, the early game was a loop of playing Farms to keep up with pop: a Farm made +1 food, the same as the pop
it needs eats, and 7 of the 17 starting cards were food buildings. After this item fewer, stronger Farms carry the food
side, Irrigation is gone, a Farm in the starting deck becomes a second Barter, and Mines give the hills and mountains a wealth line instead of more VP.

## Acceptance criteria
- [x] AC1: (existing, keep green) Given the real data, when it is loaded, then there are no loader errors or warnings.
- [x] AC2: Given the real data, then every player card in `cards.json` (not a territory, event, tech, civilization or
  the Famine) can reach the game: it is in the starting deck or supply, or a tech, civilization, starting tableau or
  card effect (`create`, `settle`) names it, so a removed card can't leave an orphan behind.
- [x] AC3: Given the real data, then every tag a `gain_per_tag` effect counts is carried by at least one card that
  can reach the game (Sumer and Harvest Festival still count `farm`).
- [x] AC4: (existing, keep green) every wealth cost still has a wealth source, and every building requirement is
  still met by a territory in play.

## Out of scope
- Other balance changes (deck mix, growth cost, food upkeep); a later balance item can follow up on the sim.
- New effect ops: Farm and Mine use the existing `gain` op with `trigger: upkeep` (and `keyword` for flood plains).

## Design notes
- `data/cards.json`: delete `irrigation`. Farm: `gain` food 2 on upkeep, plus `gain` food 1 on upkeep with
  `keyword: flood_plain` (3 on a flood plain). Mine: `gain` wealth 1 on upkeep, replacing its `score` 1 on upkeep.
- `data/config.json`: drop `irrigation` from `deck`, and swap a Farm for a Barter (`farm` 4 → 3, `barter` 1 → 2):
  17 → 16 starting cards.
- Every building and tech costs 1 more wealth to play (supply prices unchanged).
- Sumer gets `discounts: [ { "tag": "farm", "wealth": 1 } ]` (existing discount field, 108).
- No engine or format change; card text is generated from the effects.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_real_data_loads_without_warnings` (existing) |
| AC2 | `test_content::test_every_real_card_can_reach_a_game` |
| AC3 | `test_content::test_every_gain_per_tag_tag_is_on_a_reachable_card` |
| AC4 | `test_content::test_every_wealth_cost_has_a_wealth_source`, `test_every_building_requirement_is_met_by_a_territory_in_play` (existing) |

## Manual check
- [ ] Farm reads "Upkeep: +2 food; +1 more on a flood plain" (or the generated equivalent); Mine reads "Upkeep: +1 wealth".
- [ ] Starting deck is 16 cards: 3 Farms, 2 Barters, no Irrigation; the Mine supply pile still unlocks with Mining.
- [ ] Sumer's Farm shows 1 food + 1 wealth to play; other civilizations' Farms show 1 food + 2 wealth.
- [ ] Play 10–15 turns as Egypt and as Sumer: does the early game still feel like a farm loop?

## Log
- Assumed Mine makes +1 wealth (replacing its +1 VP), and "+1 with flood plains" means 3 food on a flood plain.
- Balance worry: Sumer's +1 food per Farm now stacks on a +2 Farm; Egypt's flood-plain home makes 3 per Farm.
- The user added the Farm → Barter swap mid-item.
- Content only, so no red phase: AC2 and AC3 are new invariants that hold before and after. AC2 was checked to fail
  (`["irrigation"]`) with Irrigation out of the deck but still in cards.json, the orphan it guards against.
- Trace (scratch bot: plays cards, grows whenever it can, seed 1, 15 turns), before → after. Egypt score 49 → 43,
  wealth 10 → 23, food surplus at T15 3 → 3. Sumer score 57 → 55, wealth 13 → 41 (+7 a turn from Mines).
  Balance worry: wealth now piles up with too few things to spend it on, and with Mines no longer scoring, the bot's
  score dips. A balance item should look at wealth sinks.
- The user asked to raise building and tech play costs to soak up the extra wealth: every building's and tech's wealth
  cost +1 (Farm, Pasture, Lumber Camp, Fishing Huts 2; Quarry, Shrine, Mine, Granary 3; techs 3–7). Supply prices are
  unchanged. Trace at T15: Egypt score 43 → 39, wealth 23 → 15; Sumer score 55 → 27, wealth 41 → 12. Sumer's opening
  slows hard (Farms now cost 2 wealth against +1 a turn); a balance item should check whether that's too much.
- Sumer's opening stalled after the cost bump (no Farm in about 29% of opening hands; without one Sumer makes no food).
  Sumer now has `discounts: [{tag: farm, wealth: 1}]`, so its Farms cost 1 food + 1 wealth as before. Trace seed 1
  T15 score 27 → 37 (seeds 2, 3: 37, 42). The swingy start (no Farm, no food) is left to 133.
