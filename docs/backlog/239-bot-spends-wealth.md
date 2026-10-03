---
id: 239
title: The bot buys food cards and, at random, spends its wealth before Anarchy's drain
type: feature
status: red-review
branch: feat/239-bot-spends-wealth
---

## Goal
The sim's bot hoards wealth: outside the wealth strategy it never buys, and baseline games end with about 1,900 wealth
on average. Since 156, Anarchy eats 20% of stored food and wealth each turn (a probe over seeds 1–8 counted 900–1,750
wealth drained per strategy), and since 232 Farm can be bought. After this, growth and tall buy food cards the way
wealth buys wealth cards, and before Anarchy falls the bot sometimes (seeded at random) spends its wealth on the supply
instead of letting the drain take it. The sim then shows both kinds of player: those who spend first and those who don't.

## Acceptance criteria
- [ ] AC1: Given the growth strategy (and, separately, tall) with 5 wealth and open supply piles of a food card A
  (⟳ +1 food, price 2), a food card B (⟳ +2 food, price 3) and a non-food card (price 1), when the bot takes its turn,
  then it buys one A and has 3 wealth left. A tie in price goes to the pile listed first in config `supply`.
- [ ] AC2: Given growth with 1 wealth (no food card affordable), or with no food card's pile open, when the bot takes
  its turn, then it buys nothing. Given baseline or wide with 5 wealth, when the bot takes a turn with no Anarchy
  ahead, then it buys nothing (unchanged).
- [ ] AC3: `ScriptedBot.spends_before_drain(engine)` returns the same answer for the same seed and turn, every time
  and on a fork; over seeds 1–20 on turn 1 it returns both true and false; and calling it changes nothing in the game:
  after it, the engine draws the same cards and events as an untouched twin.
- [ ] AC4: Given Anarchy falls at the next turn's start (a revolution is under way, or `anarchy_ahead()`),
  `spends_before_drain` true, 20 wealth and open piles at price 2, when the bot closes the turn (after any famine
  relief, before the discard), then it buys one card at a time, while the purchase leaves it at least SPEND_RESERVE
  (6) wealth: 7 cards, 6 wealth left. It picks the cheapest card its strategy prefers (wealth: makes wealth; growth
  and tall: makes food on upkeep; baseline and wide: any card), and once none of those can be bought, the cheapest of
  any. Ties go to config order.
- [ ] AC5: Given the same setup with `spends_before_drain` false, when the bot closes the turn, then it buys nothing
  beyond its usual once-a-turn buy (wealth and food cards for those strategies; nothing for baseline).
- [ ] AC6: Given Anarchy already rules (buying is blocked), when the bot closes the turn, then it tries no buy and
  its restore-order rule is unchanged.

## Out of scope
- Tuning the 50% chance, SPEND_RESERVE or the food buy for balance: the balance item does that.
- Spending on anything but the supply before the drain (growing pop already has its own rule).

## Design notes
- New bot API: `static func spends_before_drain(engine: GameEngine) -> bool`: a 50% coin from a hash of
  `engine.seed_value` and `engine.turn`. It never reads or advances `engine.rng`, so the game's draws don't move,
  and a lookahead fork (same seed) decides the same way.
- New bot constant `SPEND_RESERVE := 6`, enough to buy order with 2 turns of Anarchy left on the real data. It keeps
  wealth for the restore-order rule (155).
- "Anarchy falls next turn" is `engine.revolt_error() == "A revolution is already under way."` or
  `engine.anarchy_ahead()`. If testing it needs a public query (for example `revolt_pending()`), add it to the engine
  test-first.
- `_buy_wealth_card` generalises to a cheapest-preferred-card buy that wealth, growth and tall share.

## Test plan
<!-- Filled in at the red checkpoint. -->
| AC | Test |
|---|---|
| AC1 | `test_sim_strategies::test_growth_and_tall_buy_the_cheapest_food_card_once_a_turn`, `test_a_food_card_price_tie_goes_to_the_pile_listed_first` |
| AC2 | `test_sim_strategies::test_growth_buys_no_food_card_it_cant_afford_or_that_isnt_open`, `test_baseline_and_wide_buy_nothing_on_a_turn_with_no_anarchy_ahead` (guards) |
| AC3 | `test_bot_spending::test_the_coin_is_the_same_for_the_same_seed_and_turn_and_on_a_fork`, `test_the_coin_falls_both_ways_over_seeds_1_to_20`, `test_the_coin_changes_nothing_in_the_game` |
| AC4 | `test_bot_spending::test_with_a_revolution_declared_and_the_coin_on_spend_the_bot_buys_down_to_6_wealth`, `test_the_bot_spends_on_its_preferred_cards_then_on_the_cheapest_of_any`, `test_with_anarchy_ahead_from_unrest_the_bot_spends_too` |
| AC5 | `test_bot_spending::test_with_the_coin_on_keep_the_bot_buys_nothing_extra` |
| AC6 | `test_bot_spending::test_under_anarchy_the_bot_buys_nothing` (guard) |

## Log
- 2026-10-03: Specced with 238 and 240 from a check of the bot against 156, 157, 232 and 235. The user chose the random
  spend-before-drain decision. Balance worry: buying many cheap cards before Anarchy bloats the deck; watch the
  score and how often the bot draws them in the balance item.
- 2026-10-03: Red. The spend runs at the end of `take_turn`, after the revolt decision (so a revolution the bot
  declares that turn counts), rather than in `_close_turn`: tests drive `take_turn`, and famine relief (5 wealth on
  the real data) still fits in the 6 reserve. "Anarchy falls next turn" is `Anarchy.rules_next_turn(engine) or
  engine.anarchy_ahead()`: no new engine query needed.
