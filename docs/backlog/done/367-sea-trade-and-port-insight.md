---
id: 367
title: Sea Trade, and ports bring insight
type: feature
status: done
branch: feat/367-sea-trade-and-port-insight
---

## Goal
The `port` tag pays off only in era 3 (Navigation), and coastal play has no verb of its own: Caravan needs 2 cities
and scales with them, which suits a wide land empire, not a lone trading port. Sailing should open sea trade that
pays per port, and ports should bring in ideas as well as goods. This needs one small engine change: `gain_per_tag`
learns to count "per N cards".

## Acceptance criteria
- [x] AC1: Given a fixture card with ⟳ `{ "op": "gain_per_tag", "resource": "insight", "amount": 1, "tag": "t",
  "per": 2, "trigger": "upkeep" }` in the tableau and 5 other cards tagged `t` in the tableau, when upkeep resolves,
  then insight rises by 2 (5 ÷ 2 rounded down), and `upkeep_forecast` reports +2 insight beforehand; with 1 tagged
  card it gives 0.
- [x] AC2: Given a `gain_per_tag` with no `per`, then it gains `amount` per tagged card as today (3 tagged cards,
  amount 2: +6).
- [x] AC3: Given a card whose `gain_per_tag` sets `per` to 0, a negative number or a non-integer, then loading fails
  with an error naming the card and `per`.
- [x] AC4: Given `per` 2, then the short card text is "+1 insight per 2 t" and the long text "+1 insight per 2 t
  cards"; given no `per` (or `per` 1), both read as today.
- [x] AC5: Given a fixture action with play `gain_per_tag` +2 wealth per `t` card and 3 `t` cards in the tableau,
  when it is played, then wealth rises by 6; with none, it can still be played and gains 0.

## Out of scope
- A Caravan-style formula for sea trade (√cities, a city minimum); Sea Trade counts ports only.
- `per` on any op but `gain_per_tag`.
- The sea slot (366); Fishing Huts, Salt Pans, Harbor (364); the Lighthouse (365).
- Balance tuning.

## Design notes
- Format: `gain_per_tag` gains an optional int field `per` (default 1, at least 1): it gains `amount × ⌊tagged ÷
  per⌋`. It stays `upkeep_ok`. Text: "+%d %s per %d %s" when `per` > 1. Follow the `add-effect` skill's checklist for
  a changed op (loader tests, rules tests, card text).
- AC5 may pass at once (a play-trigger `gain_per_tag` is supported); it pins what Sea Trade relies on.
- Content in `data/cards.json` and `data/config.json`:
  - **Sea Trade** (`sea_trade`): action, tags `["trade"]`, cost 1 food, play: +2 wealth per `port` card. Supply pile
    `{ "price": 2, "count": 6, "locked": true }`.
  - **Sailing**: adds `{ "op": "create", "card": "sea_trade", "zone": "discard" }` and `{ "op": "unlock", "card":
    "sea_trade" }` (as The Wheel does for Caravan; `test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks`
    holds it), and ⟳ +1 insight per 2 `port` cards.
- Flavor for Sea Trade follows the style guide §18.
- PLAN.md: the effect-op list (`per`) and the Sailing line.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_gain_per_tag::test_per_gains_once_for_every_per_tagged_cards` |
| AC2 | `test_gain_per_tag::test_without_per_it_gains_per_tagged_card` |
| AC3 | `test_gain_per_tag::test_per_validation` |
| AC4 | `test_gain_per_tag::test_per_card_text` |
| AC5 | `test_gain_per_tag::test_a_played_gain_per_tag_gains_per_tagged_card_and_plays_with_none` (passes already) |

## Manual check
- [ ] Shipped numbers: Sea Trade costs 1 food (supply price 2, 6 copies) and gives +2 wealth per port; Sailing gives
  ⟳ +1 insight per 2 ports.
- [ ] Sailing's card text lists the Sea Trade it gives, the pile it opens and the insight line, and reads right.
- [ ] Research Sailing in a coastal game with two port buildings: a Sea Trade lands in the discard, the supply offers
  more, and upkeep shows +1 insight.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Balance worry: Sea Trade, Navigation and the Lighthouse (365) all pay per port, and the sea slot (366) adds a port
  slot to every coastal territory, so the port count is now worth a lot; revisit together in a balance item.
- Flavor fact: Bronze Age coastal trade ran port to port (Ugarit, Byblos, Cyprus, Crete), carrying Lebanese cedar,
  Cypriot copper, oil and wine (the Uluburun wreck's cargo).
- Card text checked on the real data: Sea Trade "+2 wealth per port"; Sailing "⟳ +1 insight per 2 port" (tooltip "+1
  insight per 2 port cards"), "Add a Sea Trade to your discard", "Sea Trade can now be bought in the supply."
