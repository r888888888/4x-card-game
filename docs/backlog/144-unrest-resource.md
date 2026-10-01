---
id: 144
title: Unrest, a resource capped by the government's unrest limit
type: feature
status: red-review
branch: feat/144-unrest-resource
---

## Goal
Civil unrest becomes something the player manages. Unrest starts at 0 and rises with expansion, hunger and bad
events; temples and feasts calm it. It can't pass a limit set by the ruling government plus modifiers (Theocracy
the most stable). This item adds only the pressure: reaching the limit does nothing yet (Anarchy is 145). From
`spike/unrest` (see Design notes).

## Acceptance criteria
- [ ] AC1: Given a government with `"unrest_limit": 5`, then it loads and its card text and tooltip include
  `"Unrest limit 5."`. Given `"unrest_limit": 0`, `-1` or `"5"`, then loading fails with
  `cards.json: card '<id>': unrest_limit must be an integer >= 1`. On any other card type the field is ignored with
  the warning `'unrest_limit' only applies to governments (ignored)`. `modifiers` accepts the key `unrest_limit`,
  with the text `"Unrest limit +1"` / `"Unrest limit −1"`.
- [ ] AC2: Given a game whose config lists `unrest`, with a government of unrest limit 5 ruling, then
  `unrest_limit()` is 5. With a working building with `"modifiers": {"unrest_limit": 1}` it is 6, and 5 again
  while that building is idle. With a modifier of −10 it is 0. With no government, or one without `unrest_limit`,
  it is -1 (no limit).
- [ ] AC3: Given unrest 4 and an unrest limit of 5, when a card with `{"op": "gain", "resource": "unrest",
  "amount": 3}` is played, then unrest is 5 and the outcome's `gained` has `unrest: 1`. With no limit (-1) the same
  play makes unrest 7. `lose` of unrest never goes below 0 (as for any resource).
- [ ] AC4: Given unrest in a card's `cost`, in a civilization discount, or in `population.famine.relief`, then
  loading fails with `<file>: <where>: unrest can't be paid (it is only gained and lost)`, where `<where>` names the
  card and field as other loader errors do (e.g. `card 'feast': cost`).
- [ ] AC5: Given unrest 2 of 5 and a building with `⟳ +1 unrest`, then `upkeep_forecast()` has `unrest: 1`, and the
  top bar shows `"Unrest: 2 / 5 (+1)"`, in `Palette.UNREST`, floating its change like Food and Wealth (126). At
  unrest 5 of 5 it is in the warning colour. With no limit it shows `"Unrest: 2 (+1)"`. The top bar still fits
  1920 px with its longest texts (alongside 139's Insight counter).
- [ ] AC6 (bot): `ScriptedBot`, every strategy, doesn't play a card whose play gains unrest when unrest plus the
  next upkeep's forecast plus 1 plus that gain would reach the limit, and doesn't play a card whose play loses unrest
  while that sum is below the limit − 2. Given unrest 3 of 5, no forecast change and a Settler (`+1 unrest`) as the
  only playable card, the bot doesn't play it; at unrest 2 it does.
- [ ] AC7 (content invariant, replaces `test_real_events_are_neutral_or_beneficial`): every real event's effects are
  `gain`, `gain_per_tag`, `score` or `grow`, or `lose` of unrest; gaining unrest is the only harm an event deals.

## Out of scope
- Anything happening at the limit: Anarchy, its lockout and ways out (145, 146), renewal (147), revolution events
  (148). Until 145, the limit only caps unrest.
- Unrest growing with the empire's size (cities, pop at housing): a later item if 145's pacing needs it.
- A balance pass; numbers below are the spike's.

## Design notes
- `EngineCore.UNREST := "unrest"`, a built-in resource like `FOOD`, `WEALTH` and 139's `INSIGHT`. The rules are on
  only when config `resources` lists it; test fixtures leave it out unless a test adds it.
- `EngineCore.gain` caps unrest at `unrest_limit()` (when ≥ 0) and reports what it actually added, like `lose`.
  Cheap because unrest is a resource: `gain`/`lose` ops, card text, the forecast and the outcome summary already work.
- `CardDef.unrest_limit` (governments, `DataLoader.TYPE_FIELDS`); `Modifiers.UNREST_LIMIT`;
  `GameEngine.unrest_limit()` = government's + modifier, never below 0, -1 when none (mirrors `actions_per_turn`).
- The loader check of AC4 sits beside the tech-cost check; `trade` naming unrest is also an error (same message).
- Content (spike values, for review under Manual check): config `resources` adds `unrest`; Chiefdom 5, Kingship 7,
  Theocracy 10; Settler `+1 unrest`; Famine `⟳ +1 unrest` per counter (its upkeep effects already resolve per
  counter; update its `text`); Temple `⟳ −1 unrest`; Shrine `modifiers: {unrest_limit: 1}`; Monument
  `{unrest_limit: 2}`; Harvest Festival `−1 unrest`; new supply action Feast (3 food: −2 unrest, tag `order`, price 2,
  6 copies); new events Grumbling (+1 unrest), Omen of Doom (+2 unrest), Bandit Raids (`⟳ +1 unrest`, 2 turns).
- Spike numbers (no Anarchy): with nothing that calms each upkeep, unrest only ratchets up and every strategy sits
  at the limit; two Temples cancel all sources. Expected, and the reason 145 gives the limit teeth.
- Changing AC7's test changes an approved test on purpose: the first harmful events arrive with unrest.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_unrest::test_a_government_unrest_limit_loads_and_shows_in_its_text`, `test_unrest_limit_validation`, `test_the_unrest_limit_modifier_loads_with_its_text` |
| AC2 | `test_unrest::test_the_unrest_limit_is_the_governments`, `test_a_working_modifier_adds_to_the_limit_and_an_idle_one_does_not`, `test_the_unrest_limit_never_goes_below_0`, `test_no_unrest_limit_without_a_government_that_sets_one`, `test_without_unrest_in_the_config_there_is_no_limit` |
| AC3 | `test_unrest::test_gaining_unrest_stops_at_the_limit`, `test_gaining_unrest_without_a_limit_is_uncapped`, `test_losing_unrest_never_goes_below_0` |
| AC4 | `test_unrest::test_unrest_cant_be_paid` (cost, discount, trade), `test_unrest_cant_be_famine_relief` |
| AC5 | `test_unrest::test_the_forecast_includes_unrest`, `test_the_top_bar_shows_unrest_out_of_the_limit_and_floats_its_change`, `test_the_top_bar_shows_unrest_alone_without_a_limit`, `test_the_top_bar_has_no_unrest_counter_when_unrest_is_off`; `test_board_layout::test_the_top_bar_fits_with_its_longest_texts` (now checks Unrest, at 10) |
| AC6 | `test_unrest::test_the_bot_doesnt_gain_unrest_that_would_reach_the_limit`, `test_the_bot_doesnt_calm_unrest_far_below_the_limit` |
| AC7 | `test_content::test_real_events_harm_only_by_unrest` (was `test_real_events_are_neutral_or_beneficial`) |

## Manual check
- [ ] `godot --path . -- --seed 5`: the top bar shows `Unrest: 0 / 5`; play a Settler and it floats +1; nothing
  overflows at 1920 px next to Insight.
- [ ] Shipped numbers as listed in Design notes (limits 5 / 7 / 10, the sources and sinks, Feast in the supply).

## Log
