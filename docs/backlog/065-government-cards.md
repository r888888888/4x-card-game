---
id: 065
title: Government cards (one at a time, swap by playing)
type: feature
status: review
branch: feat/065-government-cards
---

## Goal
Your people have a government (TODO 15). You start with a basic one. Techs give government cards, and playing one from
your hand replaces the current government. The old one leaves the game. A government's bonuses apply while it rules.

## Acceptance criteria
Fixtures added to TEST_CARDS:
- `council`, "Council", government, no effects
- `kingdom`, "Kingdom", government, cost 2 food, vp 1, effects: play +1 wealth, upkeep +1 food
Config: `starting.government: "council"`.

- [x] AC1 (loader): type `government` is valid. `starting.government` is optional. An unknown id or a non-government is
  a load error naming config.json and `starting.government`. A government in `deck`, `supply`, `territory_deck` or
  `research_deck` is a load error naming that field. A government effect that needs a target is a load error.
- [x] AC2 (setup): after `new_game`, the `government` zone holds Council, and `government()` returns its uid. With no
  `starting.government`, the zone is empty and `government()` is -1.
- [x] AC3 (play): With Kingdom in hand and 2 food, `play_card(kingdom)` pays 2 food, moves Kingdom to `government`,
  moves Council to `removed`, and gives +1 wealth. `government()` is Kingdom's uid.
- [x] AC4 (bonuses): While Kingdom rules, each upkeep gives +1 food (`upkeep_forecast` includes it), and the score
  counts its 1 VP. After it's replaced, neither applies.
- [x] AC5 (errors): `play_error` for a government with the same id as the ruling one is "Kingdom is already your
  government." Other errors (cost, blocked, game over) work as for any card.
- [x] AC6 (fork): `fork()` copies the government and removed zones.

## Out of scope
- Rule modifiers, anarchy or transition turns, and government-specific restrictions.
- Choosing a government at research time (rejected: governments come as cards).

## Design notes
- `CardDef.GOVERNMENT`, in `SEPARATE_DECK_TYPES` for config lists, but `create` may put one in the discard (like
  Library). New zones `government` and `removed`. Governments join the 062 list of always-on permanents for upkeep
  and score.
- Play resolution: a government is neither an action (discard) nor a tableau card. `CardPlay` sends it to the
  `government` zone.
- Proposed content (for review): starting **Chiefdom** (no bonus). **Kingship** from Code of Laws (058), with
  ⟳ +1 wealth. **Theocracy** from Priesthood, with ⟳ +1 VP. The two techs `create` their government in the discard.
- UI: the government card sits next to the civilization card. Playing one flies it there.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_government::test_government_cards_load`, `::test_government_outside_its_place_is_a_load_error`, `::test_starting_government_validation`, `::test_starting_government_is_optional`, `::test_government_effect_needing_a_target_is_a_load_error` |
| AC2 | `test_government::test_starting_government_is_in_the_government_zone`, `::test_without_a_starting_government_the_zone_is_empty` |
| AC3 | `test_government::test_playing_a_government_replaces_the_ruling_one`, `::test_playing_a_government_reports_the_government_zone` |
| AC4 | `test_government::test_ruling_government_gives_its_upkeep_and_forecast`, `::test_score_counts_the_ruling_government_vp`, `::test_replaced_government_bonuses_stop` |
| AC5 | `test_government::test_playing_the_ruling_government_again_is_an_error`, `::test_government_cost_is_checked_like_any_card` |
| AC6 | `test_government::test_fork_copies_government_and_removed` |
| Content | `test_content::test_starting_government_and_every_other_government_comes_from_a_tech` |

## Manual check
Run `godot --path .` and start any seed.
- [ ] A "Government" row below Civilization shows Chiefdom; its heading tooltip explains governments.
- [ ] Research Code of Laws (era 2): a Kingship lands in the discard. When it's drawn and played, it flies to the
  Government row, Chiefdom disappears, and the log says "Kingship replaces Chiefdom."
- [ ] With Kingship ruling, the wealth forecast is 1 higher. A second Kingship in hand can't be played (tooltip:
  "Kingship is already your government."); Theocracy can.
- [x] Sim (20 seeds, Log).

## Log
- 2026-09-29: Red at 544 tests (was 529). Fixtures went in `TEST_GOVS` (with `gov_db` / `gov_engine`), not
  `TEST_CARDS`, as 062 did, so the red phase doesn't fail every `make_engine` test. Approved at red, with the
  original content plan (Chiefdom, Kingship, Theocracy; Monarchy stays a plain era-3 tech for now).
- Added `test_playing_a_government_reports_the_government_zone` (outcome `to_zone`) so the UI can fly the card.
- Governments joined `NO_TERRITORY_TYPES` (no target, `keyword` or own-territory effects), and the loader reads
  `starting.civilization` and `starting.government` through one `_parse_starting_card`.
- Content: `test_content::test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks` now exempts governments like
  wonders (approved by the user): a government can't have a supply pile. Code of Laws' own ⟳ +1 wealth moved onto
  Kingship; Priesthood gives Theocracy besides the Pyramids. Both cost nothing to play.
- UI: a separate Government row below Civilization (not in the same row, as the design note had it).
- Sim (20 seeds), main → this: score 60.30 (45–82) → 61.05 (45–81); techs 7.70 → 7.75; cities, pop, era
  unchanged. The sim doesn't count government switches; a `governments` metric is a follow-up for 066.
