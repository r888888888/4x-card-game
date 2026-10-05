---
id: 282
title: Governments tolerate territories up to a tier; bigger ones add unrest
type: feature
status: ready
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

- [ ] AC1: Size unrest at upkeep: given four settled territories at pop 2 (Hamlet), 5 (Village), 9 (Town) and 13
  (Metropolis) with ample food and unrest 0, when the turn ends, then the next turn starts with unrest 3 (0 + 0 + 1 +
  2), and `size_unrest()` was 3 before the end. With one territory at pop 9 alone it is 1.
- [ ] AC2: It counts the pop at upkeep, before pop eats: given a lone territory at pop 8 (Town) and a Famine that will
  take 1 pop at this upkeep, when the turn ends, then size unrest still adds 1 (the tier is read when upkeep starts,
  like idle buildings). The next upkeep, at pop 7 (Village), adds 0.
- [ ] AC3: It stops at the limit: given unrest 9 and the AC1 territories, when the turn ends, then unrest is 10, not 12
  (the same stop as `gain`), and the turn then falls into Anarchy as usual.
- [ ] AC4: When it doesn't apply: a government with no `tolerates` adds no size unrest, even with a Metropolis. With no
  government (Anarchy rules) none is added. With unrest off (`resources` without unrest) none is added and
  `size_unrest()` is 0. With tiers off it is 0 too.
- [ ] AC5: Forecast: given the AC1 territories, `upkeep_forecast()[UNREST]` includes the +3, alongside any card
  upkeep unrest. With a working Temple-like building (⟳ −1 unrest), the forecast is +2 and the next turn starts with
  unrest 2.
- [ ] AC6: Loader and text: `tolerates` is a government-only field (on another type it gets the usual "only applies to
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
| AC1 | `test_size_unrest::test_…` |

## Manual check
- [ ] Shipped tolerances: Chiefdom tolerates Village, Kingship Town, Theocracy Town (review before merging).
- [ ] The top bar's "Unrest: N (+M)" counts size unrest once a territory passes the tolerated tier. The government
  card reads "Tolerates up to …".

## Log
- 2026-10-04: specced with the user: +1 unrest per tier above the tolerated one, and none under Anarchy. Assumed the
  bot's government ranking stays as it is.
