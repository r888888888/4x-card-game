---
id: 265
title: Wonders for eras 1 and 2
type: feature
status: done
branch: feat/265-era-1-2-wonders
---

## Goal
Pyramids is the only wonder, so Egypt's wonder discount touches one card and the other civilizations have nothing
grand of their own to build. Add wonders for eras 1 and 2, roughly one for each civilization, each a big wealth
sink with a distinct lasting effect. Like Pyramids, they are created by techs, one copy each, and never sold. Content
only: no engine change. Follows 264.

## Acceptance criteria
- [x] AC1 (invariant): Eras 1 and 2 each have at least 2 wonders (tag `wonder`) created by a tech of that era in
  `research_deck`. Fails today: era 1 has none.
- [x] AC2 (invariant): Every wonder reaches a game only through one tech: exactly one tech in `research_deck`
  creates it, it has no supply pile, and it isn't in the starting `deck`.
- [x] AC3 (invariant): Every wonder costs more wealth than any non-wonder building and prints more VP than any
  non-wonder building.
- [x] AC4 (invariant): Every wonder also carries the `culture` tag, so it counts for culture eurekas (Writing) and
  Mathematics. Fails today: Pyramids.

## Out of scope
- The wonder rework from the TODO (high wealth cost paid in parts over several turns); these cards take that rule
  when it lands.
- Era 3 wonders.
- Balance tuning; the sim isn't run here.

## Design notes
Data only (`data/cards.json`). Each wonder is a `building` with tags `["wonder", "culture"]`, created into the
discard by its tech (a `create` effect, no `unlock`). All effects use existing ops, fields and modifiers.

| Wonder | Civ it suits | Created by | Needs | Cost | VP | Does |
|---|---|---|---|---|---|---|
| Oracle of Delphi | Greece | Mysticism (era 1) | anywhere | 10 wealth | 5 | ⟳ +2 insight |
| Walls of Uruk | Sumer | Masonry (era 1) | anywhere | 10 wealth | 5 | `defense` 4, unrest limit +1 |
| Pyramids (existing) | Egypt | Priesthood (era 2) | anywhere | 13 wealth | 10 | +3 VP on desert; gains `culture` |
| Great Ziggurat | Sumer | Code of Laws (era 2) | anywhere | 14 wealth | 8 | ⟳ −1 unrest, unrest limit +2 |
| Hanging Gardens | Babylon | Calendar (era 2) | fresh water | 16 wealth | 8 | every territory houses 1 more (`modifiers.housing` 1) |
| Great Library | (any) | Writing (era 2) | anywhere | 16 wealth | 8 | ⟳ +3 insight |
| Great Harbor of Tyre | Phoenicia | Sailing (era 2) | coastal | 15 wealth | 8 | ⟳ +1 wealth per coastal territory (`gain_per_keyword`) |
| Royal Road | Persia | Currency (era 2) | anywhere | 15 wealth | 8 | hand size +1 (`modifiers.hand_size` 1) |

- Royal Road with Greece's +1 makes a hand of 7, still within `hand_limit` (7); the loader only rejects one card
  pushing past it.
- Great Harbor of Tyre: Tyre's twin harbours, the Sidonian and the Egyptian, made it the Phoenician trade hub (id
  `great_harbor_of_tyre`).
- Mysticism, Masonry, Writing and Code of Laws already give buildings (some added by 264); a wonder is one more
  `create` on each.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_eras_1_and_2_each_have_2_wonders_from_their_techs` |
| AC2 | `test_content::test_every_wonder_comes_only_from_one_tech` (guard: passes today with Pyramids) |
| AC3 | `test_content::test_every_wonder_outcosts_and_outscores_every_other_building` (guard: passes today) |
| AC4 | `test_content::test_every_wonder_counts_as_culture` |

## Manual check
- [ ] Review the table's numbers and names in `data/cards.json`.
- [ ] Learn Mysticism: an Oracle of Delphi copy lands in the discard; build it and see ⟳ +2 insight.
- [ ] As Egypt, the wonders show the −3 wealth discount.
- [ ] As Greece with Royal Road built, the hand draws 7.
- [ ] Wonder card text reads well (Hanging Gardens' housing line, Walls of Uruk's defence).

## Log
- Balance worries for a later balance item: Oracle (+2 insight for 10 wealth) may rush era 1 research; Royal Road's
  extra card is worth more than its VP suggests; with eight wonders, Egypt's discount gets much stronger.
- Green: data only. Suite 1729 → 1733.
- Found while checking card text: Great Ziggurat (and Monument, already on main) read "Unrest limit +2s": `%.0s` in
  `CardDef.MODIFIER_TEXT` doesn't drop the plural in Godot. An engine text bug, flagged as its own task.
