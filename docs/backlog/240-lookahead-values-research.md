---
id: 240
title: The bot's government lookahead values research beyond its horizon
type: feature
status: red-review
branch: feat/240-lookahead-values-research
---

## Goal
The bot chooses a government, and decides whether to revolt, by the score a 12-turn lookahead reaches (159). Insight
pays off over more than 12 turns, so the lookahead undervalues it: since 157 Theocracy takes 1 insight off every
insight gain, yet the bot still rules Theocracy about half of every game. After this, a lookahead's value also counts
the insight the fork gathered, so a government that costs research scores lower.

## Acceptance criteria
- [ ] AC1: Given two governments, Scholars (⟳ +2 insight, unrest limit 6) and Plain (nothing, limit 6), no card that
  scores, and no tech in the research deck, when the bot looks ahead 12 turns under each, then Scholars' value is
  Plain's + 6 (24 insight ÷ INSIGHT_PER_POINT 4).
- [ ] AC2: Given a fork that learns one tech with a printed cost of 8 insight and 0 VP and ends with 0 insight, when the
  bot looks ahead, then the value counts the 8 spent: score + 2. Insight held at the lookahead's start doesn't count.
- [ ] AC3: Given the government choice is owed between Plain and Scholars (Plain first in the government deck), when
  the bot chooses, then it chooses Scholars. (Before, both scored the same and the tie went to Plain.)
- [ ] AC4: Given Pious (`insight_per_gain` −1, limit 6) and Plain, and a deck of cards that each gain 2 insight, when
  the government choice is owed (Pious first in the deck), then the bot chooses Plain.
- [ ] AC5: Given Glory (⟳ +3 VP) and Scholars, when the choice is owed, then the bot still chooses Glory (36 points
  beat 6).

## Out of scope
- Tuning INSIGHT_PER_POINT: the balance item does that, with the sim's government-turn metrics.
- Valuing other long-term assets (cards in the deck, pop) beyond the horizon.

## Design notes
- `ScriptedBot.lookahead` returns `f.score() + insight_gathered / INSIGHT_PER_POINT` (integer division). Insight
  gathered = the fork's insight at the end − the engine's insight at the start + the printed insight cost of each
  tech the fork learned (techs in the fork's `researched` zone and not in the engine's). Eureka discounts make the
  printed cost a slight overcount; that's accepted.
- New bot constant `INSIGHT_PER_POINT := 4`, a starting value.
- Revolts use the same `lookahead`, so they follow too.

## Test plan
<!-- Filled in at the red checkpoint. -->
| AC | Test |
|---|---|
| AC1 | `test_bot_lookahead::test_a_lookahead_values_insight_at_1_point_per_4` |
| AC2 | `test_bot_lookahead::test_insight_gathered_counts_techs_learned_and_not_insight_held_at_the_start` |
| AC3 | `test_bot_lookahead::test_the_bot_chooses_a_government_that_gathers_insight_over_a_tie` |
| AC4 | `test_bot_lookahead::test_the_bot_avoids_a_government_that_costs_insight` |
| AC5 | `test_bot_lookahead::test_score_still_beats_insight` (guard) |

## Log
- 2026-10-03: Specced with 238 and 239 from a check of the bot against 156, 157, 232 and 235 (157's log flagged the
  Theocracy worry). The value formula is my assumption; the user asked for research to be valued, not how.
- 2026-10-03: Red. AC2 is tested on a new public `ScriptedBot.insight_gathered(start, end) -> int` rather than
  through a whole lookahead: a fork that learns exactly one 8-insight tech is fiddly to set up, and the helper pins
  the formula directly (the fixture tech is Lore, 1 insight). AC4 uses TEST_CARDS' Research (+3 insight, +2 under
  Pious). A probe showed a 12-turn Scholars fork gathers 24–26 insight, so AC1's 6 is robust.
