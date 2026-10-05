---
id: 304
title: A gain_per_pop op: gain for every N pop on the card's own territory
type: feature
status: ready
branch: feat/304-gain-per-pop-op
---

## Goal
Every gain in the game is flat or counts things across the realm, so a building makes the same in a Hamlet as in a
Metropolis. After this, a card can gain for each N pop on its own territory ("⟳ +1 wealth per 3 pop here"): the output
of urban specialists, which grows with the city. The urban upgrades (306: Merchant Quarter, Textile Works, Library,
Great Temple) use it to reward growing tall. Independent of 300–303; needed by 306.

## Acceptance criteria
Fixture: an extra building Counting House `{"id": "counting_house", "name": "Counting House", "type": "building",
"effects": [{"op": "gain_per_pop", "resource": "wealth", "amount": 1, "per": 3, "trigger": "upkeep"}]}`, population on.

- [ ] AC1: Given a working Counting House on Homeland at pop 7, when upkeep resolves, then it gains 2 wealth (1 × ⌊7 /
  3⌋); at pop 2 it gains 0; at pop 9, 3. Pop on other territories doesn't count. `upkeep_forecast` reports the same.
- [ ] AC2: `amount` defaults to 1 and `per` to 1 (so `{"op": "gain_per_pop", "resource": "food"}` gains 1 per pop);
  both must be whole numbers ≥ 1, and `resource` a config resource, else a load error naming file, card and field.
  Unrest is allowed as `gain` allows it (stopped at the limit through `set_unrest`).
- [ ] AC3: The op needs the card's own territory: on a tech, event or government (`DataLoader.NO_TERRITORY_TYPES`) or
  a unit it is a load error, as `grow` with `where: "here"` is (069). An action played with no territory, or with
  population off, gains 0.
- [ ] AC4: It is upkeep-safe (`upkeep_ok()` true), so it may trigger on `upkeep`; idle, it gains nothing, as every
  upkeep effect of an idle building.
- [ ] AC5: Card text: "+1 wealth per 3 pop here" (with `per` 1: "+1 food per pop here"); long text in details: "+1
  wealth for every 3 pop on this territory".

## Out of scope
- A cap on the gain; scaling by tier rather than pop (a tier is pop thresholds, so per-pop already rises with it).
- Content using it (306).

## Design notes
- Follow the `add-effect` skill: loader tests, rules tests, `engine/effects/gain_per_pop_effect.gd`, registry entry,
  generated text. `needs_own_territory()` true, as `grow`'s `here`.
- The op reads the source card's `territory_uid` pop through `Population.pop`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_effects::test_…` |

## Log
- 2026-10-05: specced from the tall-buildings design (idea 1, the per-pop form).
