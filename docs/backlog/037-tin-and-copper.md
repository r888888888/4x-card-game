---
id: 037
title: Tin and copper roll on Hills and Highlands and pay off on Forge
type: feature
status: review
branch: feat/037-tin-and-copper
---

## Goal
Hills and Highlands can hold tin and copper as well as gold, so exploring rough ground is a gamble on
metals. A Forge (from Bronze Working) scores more on a territory with tin or copper, and most with both,
since bronze needs both.

## Acceptance criteria
<!-- All on the real data (data/*.json), in tests/test_content.gd. -->
- [x] AC1: Given the shipped data, when it loads, then there are no errors or warnings and
  `resource_keywords` is exactly `["gold", "tin", "copper"]`.
- [x] AC2: Given the shipped config, then `territory_resources.hills` is
  `[{gold, 1}, {tin + copper, 1}, {nothing, 2}]` and `territory_resources.highlands` is
  `[{tin, 1}, {copper, 1}, {tin + copper, 1}, {nothing, 1}]` (keywords, weight), in that order.
- [x] AC3: Given the shipped Forge, then it keeps its cost (2 food, 2 wealth), 2 printed VP and no
  `requires`, and has exactly two effects: score 1 at upkeep with keyword `copper`, then score 1 at upkeep
  with keyword `tin`.
- [x] AC4: Every resource keyword is in at least one option of a `territory_resources` table for a
  territory in the territory deck, and is used by at least one card's `requires` or effect `keyword`.

## Out of scope
- New cards (a Bronze Foundry or similar).
- Changing Mine or Market.
- Tables for other terrains.

## Design notes
- Data only: `config.json` (`resource_keywords`, `territory_resources`) and `cards.json` (Forge effects).
  No engine change: rolling (036) and keyword effects (005) already work for any keyword.
- Odds: a Hills has gold 1 in 4, tin and copper 1 in 4. A Highlands has at least one metal 3 in 4, and
  both 1 in 4.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_real_resource_keywords_are_gold_tin_copper` |
| AC2 | `test_content::test_real_hills_and_highlands_roll_metals` (also changes 036's `test_real_hills_roll_gold_and_iron_is_gone`, see Log) |
| AC3 | `test_content::test_real_forge_scores_on_copper_and_tin` |
| AC4 | `test_content::test_every_resource_keyword_is_rolled_and_used` (a guard: passes today for gold) |

## Manual check
- [ ] Forge's card text shows its two upkeep bonuses (Copper, Tin), and its tooltip spells them out.
- [ ] A Forge on a Hills or Highlands with tin and copper raises score by 2 each turn; with one metal, by 1.

## Log
- 036's `test_real_hills_roll_gold_and_iron_is_gone` no longer checks the Hills table (approved at the red
  checkpoint); `test_real_hills_and_highlands_roll_metals` owns it now.
- Forge's card text reads "Copper: ⟳ +1 VP" and "Tin: ⟳ +1 VP" on two lines (no base effect to merge into).
