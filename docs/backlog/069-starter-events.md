---
id: 069
title: Starter event deck — neutral and small beneficial events, Forage and Harvest Festival become events
type: feature
status: ready
branch: feat/069-starter-events
---

## Goal
Put the 039 event framework to use in the real game with a first event deck: mostly flavor events that do nothing,
plus a few small boons, and Forage and Harvest Festival moved out of the main deck into the event deck. It makes the event phase part of
the game before harmful events exist, without shifting the balance much. Needs 068 (event panel) first, so the
player can see what was drawn.

## Acceptance criteria
- [ ] AC1 (real event deck): In the real data, `event_deck` is non-empty, and every card of type `event` in
  `cards.json` is in `event_deck` (no unused events).
- [ ] AC2 (neutral or beneficial): Every real event's effects use only `gain`, `gain_per_tag`, `score` or `grow`
  (nothing that draws, creates, explores or needs a choice). At least one real event has no effects and at least
  one has an effect.
- [ ] AC3 (moved cards): `forage` and `harvest_festival` are events in `event_deck`, and neither is in `deck` or
  `supply`. Harvest Festival's effects are an upkeep `gain_per_tag` of food for tag `farm` (Farm and Pasture).
- [ ] AC4 (bot sweep): In the 20-seed `ScriptedBot` sweep, every game still ends, and in every game at least one
  event was drawn (`active_events` plus `event_discard` is non-empty at game over).
- [ ] AC5: The real data loads with no errors or warnings (`test_real_data_loads_without_warnings`).
- [ ] AC6 (growth invariant): `test_real_deck_has_growth_cards` counts cards with a `grow` effect in `deck`,
  `supply` and `event_deck`, and still needs at least 4. This changes an existing content test.
- [ ] AC7 (no silent `here`): A `grow` effect with `"where": "here"` on an event or a tech is a load error that names
  the card and the effect index (such a card has no territory, so the effect would do nothing). `"where": "each"`
  still loads.

## Out of scope
- Harmful events and the ops they need (lose food or pop, idle a building), and escalation by era.
- Any change to the other main-deck cards or the supply.
- Rebalancing beyond what the balance run below flags.

## Design notes
- Mostly content: new `event` cards in `data/cards.json`, `event_deck` in `data/config.json`. Forage's type changes
  from `action` to `event` (its +2 food stays; it had no cost). Harvest Festival becomes an event: no cost (it cost
  2 food), 1 copy (was 2), and `⟳ +1 food per farm, lasts 1 turn` instead of +1 pop in each territory.
- Only rule change (AC7): `DataLoader._no_territory_effect_problem` also rejects an effect that acts on its own
  card's territory. Give `Effect` a query for it (for example `needs_own_territory()`, true for `grow` with `here`)
  rather than naming the op in the loader.
- Growth: without the festival's `grow`, the deck and supply hold 2 growth cards (Granary 1 + 1). To keep 4, the
  supply's Granary pile goes from 1 to 3 copies (for review).
- Proposed deck (numbers for review, not tested):

  | Event | Effect | Copies |
  |---|---|---|
  | Quiet Season | none | 1 |
  | Travelers' Tales | none | 1 |
  | Comet Sighted | none | 1 |
  | Border Rumors | none | 1 |
  | Wild Berries | +1 food | 1 |
  | Wandering Trader | +1 wealth | 1 |
  | Local Legend | +1 VP | 1 |
  | Mild Spring | ⟳ +1 food, lasts 2 turns | 1 |
  | Market Day | ⟳ +1 wealth, lasts 1 turn | 1 |
  | Good Omens | +1 VP | 1 |
  | Forage (moved) | +2 food | 2 |
  | Harvest Festival (moved) | ⟳ +1 food per farm, lasts 1 turn | 1 |

  13 cards, so a 20-turn game reshuffles the event discard once. The main deck drops from 23 to 19 cards.
- Blank events have no effects, so their text is only "Lasts 1 turn"; each gets flavor `text` if the card face
  looks empty.
- Run the `balance` skill against `main` and record the result in the Log.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
- [ ] Review the deck table above (names, effects, copies) and the Granary supply pile going to 3.
- [ ] Balance: the `balance` skill's comparison with `main` shows no large jump in final score or food.
- [ ] Play a few turns: each end turn draws an event into the Events panel (068); Forage gives +2 food when drawn,
  Harvest Festival shows +1 food per farm in the forecast, and neither shows up in the hand.

## Log
