---
id: 141
title: Eurekas: what you have built makes related techs cheaper
type: feature
status: review
branch: feat/141-tech-eurekas
---

## Goal
Research follows from what you are doing: 2 farms make Pottery cheaper, a Quarry makes Mining cheaper. A tech may
name a eureka, enough matching cards in the tableau, that takes Insight off its price. It rewards play that fits the
tech, and it's realistic, since need drives invention. Follows 140; tried on `spike/research-insight`.

## Acceptance criteria
- [x] AC1: Given a tech with `"eureka": {"card": "farm", "count": 2, "off": 2}` or `{"tag": "city", "count": 2,
  "off": 2}`, then it loads. Each of these fails to load with an error naming the card and `eureka`: both or neither
  of `tag` and `card`; `count` or `off` missing or below 1; a `card` that isn't a known card id
  (`"eureka: unknown card 'x'"`). A `eureka` on a non-tech card is ignored with the warning
  `"'eureka' only applies to techs (ignored)"`.
- [x] AC2: Given Writing (3 insight) in the research deck with eureka `{"card": "farm", "count": 2, "off": 2}`, then
  with 1 Farm in the tableau its `tech_cost` is 3, and with 2 Farms it is 1. Farms in the hand, deck or discard don't
  count; a Farm in the tableau that is idle (no free worker) does.
- [x] AC3: Given a tag eureka `{"tag": "city", "count": 2, "off": 2}` on Writing (3), then with the Capital alone its
  cost is 3, and with the Capital and a City it is 1. Given `"off": 5` with its condition met, its cost is 1 (never
  below 1).
- [x] AC4: `tech_tree()` entries carry `eureka`: true when the tech's eureka is met, else false (and false for a tech
  without one). The card text has `"Eureka: -2 insight with 2 Farms"` (tag form: `"… with 2 city cards"`), the
  rules tooltip `"Eureka: -2 insight with 2 Farms."`, and a met eureka shows in the details as
  `"Costs 1 insight now (printed 3, −2 eureka)"`.
- [x] AC5: In the tech tree, a tech with a eureka that isn't researched shows a line `"Eureka: -2 insight with 2
  Farms"`, prefixed `"✔ "` when it is met; a researched tech shows no eureka line.

## Out of scope
- Eurekas that count anything but tableau cards (keywords, pop, played cards).
- Diffusion (142). Which techs get which eurekas, and their sizes: 143.

## Design notes
- New tech field `eureka` in `DataLoader.TYPE_FIELDS` (techs only): `{"tag" | "card": String, "count": int >= 1,
  "off": int >= 1}`, held in `CardDef.eureka`; `CardDef.eureka_text(card_db)`. An unknown `card` is caught in the
  loader's cross-card pass, like `prereq`; tags are free-form, so any tag loads.
- `Research.eureka_met(def)` counts `tableau` cards whose id is `card` (or whose tags hold `tag`); `Research.cost`
  subtracts `off` when met, after civilization discounts, then floors at 1.
- Spike note: the spike's eurekas are all −2. At the spike's prices that is a quarter of an era-1 tech and a tenth of
  an era-3 one; 143 sizes them.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_eurekas::test_card_and_tag_eurekas_load`, `test_eureka_validation` |
| AC2 | `test_eurekas::test_a_card_eureka_needs_its_count_of_cards_in_the_tableau`, `test_an_idle_card_still_counts_for_a_eureka` |
| AC3 | `test_eurekas::test_a_tag_eureka_counts_tableau_cards_with_the_tag`, `test_a_eureka_never_takes_a_tech_below_1` |
| AC4 | `test_eurekas::test_tech_tree_entries_say_whether_the_eureka_is_met`, `test_eureka_card_text`, `test_a_met_eureka_shows_in_the_price_details` |
| AC5 | `test_eurekas::test_the_tree_shows_a_eureka_and_ticks_it_when_met` |

## Manual check
- [ ] `godot --path . -- --seed 5`: open Knowledge; Pottery shows its eureka. Build a second farm: the line gets a ✔
  and the price drops by its `off`.

## Log
- 2026-10-01: Built as designed: `eureka` in `TYPE_FIELDS` (techs), `DataLoader._parse_eureka` (errors say "eureka:
  needs exactly one of 'card' and 'tag'", "'count' must be an integer >= 1", …, with an example), the unknown card in
  the cross-card pass; `CardDef.eureka` and `eureka_text`; `Research.eureka_met` and the cost; `tech_tree`'s
  `eureka`; "−N eureka" in the details; the tree's line (✔ when met, none once researched). No approved test changed.
- No real data uses `eureka` yet: which techs get one, and how big, is 143. The Manual check waits for that content.

