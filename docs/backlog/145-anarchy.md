---
id: 145
title: Anarchy when unrest reaches the limit
type: feature
status: red-review
branch: feat/145-anarchy
---

## Goal
Unrest gets teeth. A turn that starts with unrest at the government's limit falls into Anarchy: the government
falls, little can be done, and pop drifts away until order returns. With each new era stirring unrest, Anarchy
comes about once per era (with 143's pacing). This item covers falling into Anarchy, what it locks and burning out;
146 adds the ways out, 147 renewal. Follows 144. From `spike/unrest`.

## Acceptance criteria
- [ ] AC1: Config `unrest` (optional; only with `unrest` in `resources`) is `{"anarchy": <government id>,
  "fallback": <government id>, "max_counters": <int >= 1>, "era_unrest": <int >= 0, default 0>, "allowed_tag":
  <string, default "">}`. Given an id that isn't a government, `max_counters` 0 or `era_unrest` -1, then loading
  fails with `config.json: unrest.<field>: …` naming the field and what it must be. The anarchy government can't
  be `starting.government`, can't set `unrest_limit` (load error), and isn't in any deck or supply.
- [ ] AC2: Given Chiefdom (unrest limit 5) ruling and unrest 5 when a turn starts (after upkeep and feeding, before
  the draw), then the anarchy card is the government (`anarchy()` is its uid), Chiefdom is in the `deck` (the deck
  shuffled with the seeded rng), and a notice names Anarchy. Given unrest 4, or unrest 5 that an upkeep effect lowers
  to 4, then nothing happens. While Anarchy rules, `unrest_limit()` is -1, so unrest gains aren't capped.
- [ ] AC3: While Anarchy rules, `play_error` for a hand card that is neither a government nor tagged `allowed_tag`
  is `"Anarchy: only a government or an order card can be played."`; a card with that tag plays normally.
  `grow_error`, `buy_error`, and every way of learning a tech (`buy_tech_error`, the Research card) give
  `"Anarchy: nothing can be grown, bought or researched."`. Discarding, ending the turn and relieving a Famine work
  as usual. Actions per turn are the anarchy card's `actions` (data: 1).
- [ ] AC4: Each turn that starts with Anarchy already ruling adds a counter to it (`anarchy_counters()`: 0 on the turn
  it falls, then 1, 2, …); the anarchy card's own upkeep effects resolve like any government's (data: −1 pop). When a
  counter makes it reach `max_counters` (4), the fallback government (Chiefdom) is created as the government, the
  anarchy card goes to `removed`, unrest becomes min(unrest, the fallback's limit / 2, rounded down), and a notice
  says order returns.
- [ ] AC5: When an era is added (an `add_era` effect, an empty research deck, or `era_unlocks`), unrest rises by
  `era_unrest`, capped at the limit, with a notice; with `era_unrest` 0 nothing happens. Given unrest 3 of 5 and
  `era_unrest` 3, then adding era 2 makes unrest 5, and the next turn falls into Anarchy.
- [ ] AC6: The sim's bot plays through games with Anarchy to the end: `ScriptedBot.play` returns true for seeds 1–20
  of the real data, every strategy, and at least one of those games falls into Anarchy. While Anarchy rules, the bot
  plays a government from its hand before any other card.

## Out of scope
- Playing a government to end Anarchy (the half-limit rule) and paying to restore order: 146. Until then, playing a
  government during Anarchy replaces it like any government (no condition), and burning out is the other way out.
- Renewal (147) and choosing to revolt (148).
- Buildings razed during Anarchy: dropped in the spike (it fed back into more Anarchy by razing Temples).

## Design notes
- Rules in a new `engine/anarchy.gd` (static functions like `Famine`); `TurnLoop.start_turn` calls it after
  `Research.check_era_unlocks`, before the draw; `CardPlay.error`, `Population.grow_error`, `Supply.buy_error` and the
  research errors ask it. `Research.add_era` calls it for `era_unrest`.
- API: `anarchy()` (uid or -1), `anarchy_counters()`. The anarchy card's counters use `CardInstance.counters`
  (Famine's field).
- Data: a government card `anarchy` with `"actions": 1`, `⟳ −1 pop`, and a hand-written `text` for the rules the
  effects can't express (or generated lines from the config, if simpler). Feast (144) gets tag `order`; config
  `unrest: {"anarchy": "anarchy", "fallback": "chiefdom", "max_counters": 4, "era_unrest": 3, "allowed_tag": "order"}`.
- Content tests that need updating: governments that no tech creates (the anarchy card is created by the rule), and
  "every real card can reach a game" (the config's `unrest.anarchy` counts as a way in).
- Spike (sticky version, no razing, unrest-aware bot, 20 seeds): 0.9–2.2 Anarchies per game lasting 2.3–2.9 turns;
  score cost about 10–17% against no Anarchy. Era 1 ended by turn ~9 there; with 143's pacing (eras end around turns
  18 / 50 / 100) the era burst should give roughly one Anarchy per era. Note balance worries in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_anarchy::test_the_unrest_block_loads_with_its_defaults`, `test_unrest_block_validation` |
| AC2 | `test_anarchy::test_a_turn_starting_at_the_limit_falls_into_anarchy`, `test_unrest_below_the_limit_doesnt_fall`, `test_an_upkeep_that_calms_below_the_limit_prevents_anarchy`, `test_without_an_unrest_block_the_limit_only_caps`, `test_unrest_has_no_limit_under_anarchy` |
| AC3 | `test_anarchy::test_under_anarchy_only_governments_and_order_cards_play`, `test_anarchy_has_its_cards_actions`, `test_under_anarchy_nothing_is_grown_bought_or_researched`, `test_under_anarchy_discarding_and_ending_the_turn_work` |
| AC4 | `test_anarchy::test_each_turn_of_anarchy_adds_a_counter_and_takes_a_pop`, `test_anarchy_burns_out_at_max_counters_and_the_fallback_restores_order`, `test_burning_out_keeps_unrest_below_half_the_limit` |
| AC5 | `test_anarchy::test_a_new_era_adds_era_unrest_up_to_the_limit`, `test_era_unrest_0_adds_nothing` |
| AC6 | `test_anarchy::test_the_bot_plays_a_government_first_under_anarchy`; `test_content::test_every_strategy_finishes_real_games_with_anarchy` |
| content | `test_content::test_starting_government_and_every_other_government_comes_from_a_tech` (skips `unrest.anarchy`), `test_every_real_card_can_reach_a_game` (`reachable_cards` adds `unrest.anarchy` and `fallback`) |

## Manual check
- [ ] Set `"unrest": 4` in `starting.resources`, play a Settler on turn 1 and end the turn: Anarchy shows as the
  government on the identity button, a notice appears, cards other than governments and Feast refuse with the reason.
- [ ] Shipped numbers: max 4 counters, era unrest 3, Anarchy 1 action and −1 pop per upkeep.

## Log
