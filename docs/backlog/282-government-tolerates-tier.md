---
id: 282
title: Governments tolerate territories up to a tier; bigger ones add unrest
type: feature
status: review
branch: feat/282-government-tolerates-tier
---

## Goal
Each government names the largest settlement tier (281) it keeps calm. Every territory above that tier adds +1 unrest
per tier above it, each upkeep. Growing tall then costs order unless the government can hold it, and choosing a
government decides how big your territories can get calmly. This mirrors the TODO idea that a government supports N
territories for free (going wide); this item handles going tall. Needs 281.

## Acceptance criteria
Fixtures: 281's tiers (hamlet 0, village 4, town 8, metropolis 13), unrest on, and a government with
`unrest_limit` 10 and `"tolerates": "village"`.

- [x] AC1: Size unrest at upkeep: given four settled territories at pop 2 (Hamlet), 5 (Village), 9 (Town) and 13
  (Metropolis) with ample food and unrest 0, when the turn ends, then the next turn starts with unrest 3 (0 + 0 + 1 +
  2), and `size_unrest()` was 3 before the end. With one territory at pop 9 alone it is 1.
- [x] AC2: It counts the pop at upkeep, before pop eats: given a lone territory at pop 8 (Town) and a Famine that will
  take 1 pop at this upkeep, when the turn ends, then size unrest still adds 1 (the tier is read when upkeep starts,
  like idle buildings). The next upkeep, at pop 7 (Village), adds 0.
- [x] AC3: It stops at the limit: given unrest 9 and the AC1 territories, when the turn ends, then unrest is 10, not 12
  (the same stop as `gain`), and the turn then falls into Anarchy as usual.
- [x] AC4: When it doesn't apply: a government with no `tolerates` adds no size unrest, even with a Metropolis. With no
  government (Anarchy rules) none is added. With unrest off (`resources` without unrest) none is added and
  `size_unrest()` is 0. With tiers off it is 0 too.
- [x] AC5: Forecast: given the AC1 territories, `upkeep_forecast()[UNREST]` includes the +3, alongside any card
  upkeep unrest. With a working Temple-like building (⟳ −1 unrest), the forecast is +2 and the next turn starts with
  unrest 2.
- [x] AC6: Loader and text: `tolerates` is a government-only field (on another type it gets the usual "only applies to
  governments" warning) whose value must be the `id` of a tier in `population.tiers`. An unknown id is a load error
  naming the card, `tolerates` and the id. A `tolerates` with tiers off is a warning that it is ignored. The
  government's generated card text gains a line naming the tier, e.g. "Tolerates up to Village.". Real data: every
  government in `data/cards.json` sets `tolerates` (content invariant, no ids or numbers).

## Out of scope
- The TODO's free-territory count and its cost for going wide (its own item later).
- The bot choosing a government by tolerance: `best_government` keeps its ranking (most actions, then highest unrest
  limit). A modifier that raises tolerance (e.g. a wonder giving "+1 tier tolerated").
- Tuning limits or the unrest buildings around the new drain: a balance item. Log worries below.

## Design notes
- Data: government field `"tolerates": "<tier id>"`, added to `DataLoader.TYPE_FIELDS` for `CardDef.GOVERNMENT`.
  Cards are parsed before the config, so the cross-check against `population.tiers` happens in `ConfigLoader` (like
  `_check_homes_house_start`). That is also where the def gets the tier's name for its text (`CardDef` has no config):
  e.g. `def.tolerates` holds the id and `def.tolerates_name` the name.
- Engine: `size_unrest() -> int` (EngineQueries) = Σ over settled territories of max(0, `tier(uid)` − index of the
  tolerated tier). It is 0 with unrest off, tiers off, no government, or a government with no `tolerates`.
  `TurnLoop.resolve_upkeep` adds it through `gain` (so `set_unrest`'s limit applies) **first**, before the working
  cards and the events (the Famine's `lose_pop` runs in `Events.resolve_upkeep`, so reading the tiers later would
  break AC2). Calming upkeep (Temple) then applies after it. Being inside `resolve_upkeep` puts it in the fork
  `upkeep_forecast` already runs. Log it as one line (e.g. "Crowded territories: +3
  unrest."). Notice level is the implementer's call.
- Being an engine rule rather than a card effect, it doesn't go through `Effect.upkeep_ok`. It changes only unrest,
  which `upkeep_forecast` already reports.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_size_unrest::test_each_tier_above_the_tolerated_one_adds_1_unrest_at_upkeep`, `test_a_lone_town_adds_1_unrest` |
| AC2 | `test_size_unrest::test_size_unrest_counts_the_pop_before_upkeep_takes_any` |
| AC3 | `test_size_unrest::test_size_unrest_stops_at_the_unrest_limit` |
| AC4 | `test_size_unrest::test_a_government_without_tolerates_adds_no_size_unrest`, `test_no_government_adds_no_size_unrest`, `test_anarchy_adds_no_size_unrest`, `test_without_unrest_there_is_no_size_unrest`, `test_without_tiers_there_is_no_size_unrest` |
| AC5 | `test_size_unrest::test_the_forecast_counts_size_unrest`, `test_size_unrest_comes_before_calming_upkeep` |
| AC6 | `test_size_unrest::test_tolerates_loads_and_shows_in_the_government_text`, `test_tolerates_only_applies_to_governments`, `test_tolerates_must_be_a_tier_id`, `test_tolerates_with_tiers_off_is_a_warning`; `test_content::test_every_government_sets_tolerates` |

## Manual check
- [ ] Shipped tolerances: Chiefdom tolerates Village, Kingship Town, Theocracy Town (review before merging).
- [ ] The top bar's "Unrest: N (+M)" counts size unrest once a territory passes the tolerated tier. The government
  card reads "Tolerates up to …".

## Log
- 2026-10-04: specced with the user: +1 unrest per tier above the tolerated one, and none under Anarchy. Assumed the
  bot's government ranking stays as it is.
- Red: AC2 uses a fixture event with ⟳ −1 pop (Plague, 2 turns) instead of the Famine: the Famine takes pop while
  feeding, after `resolve_upkeep`, so it couldn't tell whether the tier is read before or after the upkeep effects.
  A ⟳ lose_pop event resolves in `Events.resolve_upkeep`, after the working cards, the same path as Anarchy's.
- Built. `size_unrest()` is `Population.size_unrest`, exposed on EngineQueries; `TurnLoop.resolve_upkeep` adds it
  first through `set_unrest` (not `gain`, which needs a source card) and logs "Crowded territories: +N unrest."; no
  notice (the forecast and the top bar already show it). `ConfigLoader._check_tolerates` validates the id and sets
  `CardDef.tolerates_name` for the text. Shipped: Chiefdom Village, Kingship Town, Theocracy Town.
- Balance worries for a later balance item: Chiefdom (limit 8, tolerates Village) now drains 1 unrest per Town each
  turn, which pushes early growth past pop 8 toward Anarchy; the bot doesn't weigh tolerance when choosing a
  government or a growth target, so sim games under Chiefdom may fall into Anarchy more often.
- Suite 1874 → 1890 tests.
