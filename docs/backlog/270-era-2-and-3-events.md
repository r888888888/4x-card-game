---
id: 270
title: Era 2 and 3 events, so the event deck escalates
type: feature
status: in-progress
branch: feat/270-era-2-and-3-events
---

## Goal
PLAN.md promises an event deck that escalates by era. Today era 2 adds one event, and era 3 (Writing) adds none. Every
amount is a flat ±1 or ±2, so events stop mattering in the second half of a 40-turn game. After this item:
- each later era adds its own events, harsher and richer than the last;
- some events scale with the realm (per farm, per coastal territory, a share of stores), so they keep mattering;
- the deck finally touches insight, pop and the turn itself (actions, hand size);
- it carries choice events.

Content only, apart from the ops and rules it uses (267, 268, 269). Numbers are a first guess until a balance item.
Duplicates are fine where they add flavour.

## Acceptance criteria
- [ ] AC1 (invariant): Every era a tech in `research_deck` belongs to, or adds with `add_era`, has at least one event of
  that era in `event_deck`.
- [ ] AC2 (invariant): Every era from 2 up has at least one harmful event and one helpful event in `event_deck`.
  - Harmful: gains unrest; takes food, wealth or insight (`lose`, `lose_pct`, `lose_per_keyword`); takes pop
    (`lose_pop`); or sets a negative `actions` or `hand_size` modifier.
  - Helpful: gains a resource other than unrest, scores, grows pop, or sets a positive modifier.

  Effects inside a choice event's options count.
- [ ] AC3 (invariant): Every era from 2 up has at least one event in `event_deck` whose effect scales with the realm:
  `gain_per_tag`, `gain_per_keyword`, `lose_per_keyword` or `lose_pct`.
- [ ] AC4 (invariant): Every per-keyword and per-tag effect on an event can fire.
  - Each keyword is on a territory in `territory_deck` or the starting territory, printed or a possible roll in
    `territory_resources`.
  - Each tag is on a card in `deck` or `supply`, or on a card some card creates.
- [ ] AC5 (invariant): Food, wealth and insight are each gained by some event in `event_deck` and lost by some event in
  `event_deck`, including raid triggers and choice options.
- [ ] AC6 (invariant): Unrest escalates by era. The most unrest any era-n event adds (267's measure, with 269's rule for
  choices) is at least the most any era-(n−1) event adds, for each era from 2 up.

## Out of scope
- New raids and units: 167 (era-2/3 raids, Spearmen, Swordsmen).
- Civilization-specific events (a TODO item; needs a rule for gating events by civilization).
- Reworking Calls for Reform and Radical Thinkers. They do nothing outside Anarchy, which is worth a look on its own.
- Balance tuning, and the sim.

## Design notes
- Data only: new event cards in `data/cards.json` and `event_deck` counts in `data/config.json`. They use existing ops
  and modifiers (`actions`, `hand_size`), plus `lose_pct` / `lose_per_keyword` (268) and `choices` (269).
- Depends on 267 (Omen of Doom and Bandit Raids already moved to era 2), 268 and 269. Build it last.
- Era-n events are shuffled into the event deck when era n is added (074); nothing about that changes.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_era_the_research_deck_reaches_has_events` |
| AC2 | `test_content::test_every_later_era_has_a_harmful_and_a_helpful_event`; `test_real_era_1_events_harm_only_by_unrest` (144's test, now era 1 only) |
| AC3 | `test_content::test_every_later_era_has_an_event_that_scales_with_the_realm` |
| AC4 | `test_content::test_every_per_keyword_and_per_tag_event_effect_can_fire` |
| AC5 | `test_content::test_events_both_give_and_take_food_wealth_and_insight` |
| AC6 | `test_content::test_the_most_unrest_an_event_adds_never_falls_from_one_era_to_the_next` |

## Manual check
Proposed cards, 1 copy each, for review. Flavour to be written in the item, in the voice of the existing events.

- [ ] Era 2, Bronze Age (with Omen of Doom, Bandit Raids, Radical Thinkers):
  - Plague: −1 pop, +1 unrest.
  - Granary Fire: −25% food.
  - Drought (2 turns): ⟳ −1 food per desert or grassland territory.
  - Silt Flood: +2 food per flood plain territory.
  - Bumper Harvest (2 turns): ⟳ +1 food per farm.
  - Busy Harbours (2 turns): ⟳ +1 wealth per coastal territory.
  - Visiting Scholar: +3 insight.
  - Labour Shortage: −1 action this turn.
  - Tax Revolt (choice): pay 4 wealth; or +2 unrest.
  - Wandering Smiths (choice): pay 3 wealth for +3 insight; or nothing.
- [ ] Era 3, Iron Age:
  - Pestilence: −2 pop, +1 unrest.
  - Library Burns: −50% insight.
  - Debased Coin: −30% wealth.
  - Storm at Sea: −2 wealth per coastal territory.
  - Golden Age (2 turns): +1 action and +1 hand size each turn.
  - School of Philosophers: +5 insight.
  - Succession Crisis (choice): pay 6 wealth; or +3 unrest; or −1 pop and +1 unrest.
  - Mercenaries' Offer (choice): pay 4 wealth for a Warriors in your discard (Swordsmen once 167 lands); or nothing.
- [ ] Each new event's modal and card text read correctly. Choice events show their options.
- [ ] Play to era 3: the event pile's tooltip counts the waiting events before each era, and the new events turn up
  after the era is added.

## Log
- Balance worry, for the next balance item: the deck grows from 22 to about 43 events over a game of 39 draws. Era-1
  boons get rarer late, and some era-3 events may never come up. Consider fewer era-3 cards, or removing era-1 blanks
  when era 2 arrives.
- Red: 144's `test_real_events_harm_only_by_unrest` forbade the new harms on every event (268's follow-up). It now
  checks era-1 events only, renamed `test_real_era_1_events_harm_only_by_unrest`: era 1 stays unrest-only.
- AC2: "a positive / negative modifier" reads as `actions` or `hand_size` only; renewal and the rest don't count either
  way. AC5 counts effects only, not an option's cost.
- AC4's test passes before the change (only Harvest Festival counts a tag today); it guards the new cards.
