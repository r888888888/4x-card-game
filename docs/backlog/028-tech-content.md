---
id: 028
title: First tech content (era 1 and 2 techs, Library)
type: feature
status: draft
branch: feat/028-tech-content
---

## Goal
Put techs in the real game: an era-1 and era-2 research deck, a Library, and some current deck cards
(Pyramids, Forge) moved behind techs so research unlocks them. The numbers are a first draft to
playtest. Depends on 025–027.

## Acceptance criteria
<!-- Content tests check shape, not balance numbers (see tests/test_content.gd). -->
- [ ] AC1: The real data loads with no errors or warnings. `research_deck` has at least 6 era-1 techs
  and at least 6 era-2 techs, and at least one era-1 tech has an `add_era` 2 effect.
- [ ] AC2: Every tech's `prereq` is in `research_deck`, and every `create` target of a tech is a
  non-tech card.
- [ ] AC3: A Library can be reached: it is in the deck, or a tech creates it.
- [ ] AC4: The scripted smoke game on real data (`play_scripted_game`, extended to research each turn
  and buy the cheapest tech it can afford), 3 seeds: the game finishes, wealth never goes negative,
  and in at least one seed a tech is bought.
- [ ] AC5: The existing content tests stay green (City smoke test, wealth smoke test, wealth-source
  coverage).

## Out of scope
- Balance targets in tests. Record the scripted-bot numbers in the Log only.
- Era 3.

## Design notes
Data only (`data/cards.json`, `data/config.json`). This is a first draft; finalize it at spec approval.

| Era | Tech | Cost | Prereq | Effect |
|---|---|---|---|---|
| 1 | Pottery | 2 | — | 1 VP, ⟳ +1 food |
| 1 | Animal Husbandry | 3 | — | create Pasture in discard |
| 1 | Bronze Working | 3 | — | create Forge in discard (Forge leaves the deck) |
| 1 | Writing | 3 | — | create Library in discard |
| 1 | Masonry | 4 | Pottery | create Pyramids in discard (Pyramids leave the deck) |
| 1 | Currency | 4 | Bronze Working | ⟳ +1 wealth |
| 1 | Philosophy | 5 | Writing | 2 VP, add era 2 |
| 2 | Iron Working | 5 | Bronze Working | 2 VP, ⟳ +1 VP |
| 2 | Mathematics | 5 | Currency | ⟳ +1 wealth per `trade` card |
| 2 | Sailing | 4 | — | create Harbor in discard |
| 2 | Monarchy | 6 | Philosophy | 3 VP, ⟳ +1 wealth |
| 2 | Astronomy | 6 | Mathematics | 4 VP |
| 2 | Engineering | 6 | Masonry | create Monument in discard |

- Library: building, 1 food + 2 wealth, 1 VP, ⟳ +1 research.
- 023 (more wealth sinks) is probably superseded by this. Rerun the 023 wealth stats before and after,
  then decide whether 023 is `wontfix`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_…` |

## Manual check
Run `godot --path .`.
- [ ] Research comes up from turn 1. Early techs are affordable within the first few turns.
- [ ] Over a full game, record techs bought, techs lost, final score and wealth left in the Log.

## Log
