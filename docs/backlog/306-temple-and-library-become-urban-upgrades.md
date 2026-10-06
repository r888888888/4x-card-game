---
id: 306
title: Temple and Library become urban upgrades (Shrine → Temple → Great Temple, Scribal School → Library)
type: feature
status: red-review
branch: feat/306-temple-and-library-upgrades
---

## Goal
The two buildings most tied to cities historically are flat buildings any hamlet can raise. After this they are urban
upgrades that need a settlement tier (301): a Shrine grows into a **Temple** in a Village and a **Great Temple** in a
Metropolis (Eridu's temple was rebuilt some 18 times on one spot, from a one-room shrine to a monumental temple, as the
town grew), and writing first brings a **Scribal School** (the Sumerian *edubba*, c. 2500 BC), which becomes a
**Library** in a Town (real libraries are urban and much later: Ashurbanipal's, 7th century BC). Wide realms keep their
basics (Shrine, Scribal School with today's Library numbers); tall ones earn the rest. Content only. Follows 301 and 304.

## Acceptance criteria
Content tests (`tests/test_content.gd`), naming no card id:
- [ ] AC1: Every building with a `tier` names a tier of `population.tiers`, and every tier-gated upgrade's tier is at
  least its base's tier (a chain never asks for less as it rises).
- [ ] AC2: No tech's eureka counts a card that only that tech (or a tech that needs it) makes available: a eureka can be
  met before its tech is learned.
- [ ] AC3: Every upgrade's `unrest_limit` modifier, if any, is ≥ 0: falling back never lowers the unrest limit below
  what its base gives (the "no Anarchy from shrinking" rule of the design).
- [ ] AC4: An upgrade that scales with its territory's pop (`gain_per_pop`, 304) has a tier: per-pop output is urban.

## Out of scope
- New urban chains (Market, Granary, Palisade, houses, harbour, workshop): 307. Gap buildings: 308.
- Numbers beyond a first pass: the balance item after 308.

## Design notes
- Changes (first-pass numbers):
  - **Shrine** keeps 3 wealth, 1 VP, unrest limit +1, and gains ⟳ +1 VP on a mountain, moved from the Temple: hilltop
    "high places" were shrines, and a mountain territory (2–3 housing, 1 slot) could almost never reach a Village.
  - **Temple** becomes an upgrade of Shrine, tier Village (Mysticism, as now): ⟳ −1 unrest. No longer a stand-alone
    entry. Priesthood's eureka (1 Temple) and Philosophy's (2 Temples) now need a Village, which fits.
  - **Great Temple** (new): upgrade of Temple, tier Metropolis (Philosophy, which unlocks nothing today): ⟳ +1 VP and
    ⟳ +1 food per 3 pop here (temples ran estates). Philosophy's eureka counts Temples, which Mysticism opens: AC2 holds.
  - **House of Life** becomes an upgrade of Temple, tier Town (Medicine, as now): housing 1, ⟳ +1 insight. The Egyptian
    *per-ankh* was part of a temple. Medicine's eureka counts Bathhouses, unaffected.
  - **Scribal School** (new id `scribal_school`): what the Library is today (5 wealth, 1 VP, ⟳ +2 insight), unlocked by
    Writing in the Library's place.
  - **Library** becomes an upgrade of Scribal School, tier Town (Alphabet, which unlocks nothing today): ⟳ +1 insight
    per 3 pop here. Alphabet's eureka (2 Libraries) would count what it unlocks, so it counts 2 Scribal Schools (AC2).
  - **Great Library** (wonder) stays on Writing.
- Interaction: a Temple that falls back loses its ⟳ −1 unrest, but the Shrine under it keeps its unrest limit +1 (an
  upgrade adds to its base), so shrinking never lowers the limit (AC3).
- Bot: growth and tall pick these by effect (303); nothing new.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_tier_is_real_and_no_upgrade_needs_less_than_its_base` |
| AC2 | `test_content::test_no_eureka_counts_only_what_its_own_tech_makes_available` |
| AC3 | `test_content::test_no_upgrade_lowers_the_unrest_limit` |
| AC4 | `test_content::test_every_upgrade_that_scales_with_pop_needs_a_tier` |

## Manual check
- [ ] Shrine: 3 wealth, 1 VP, unrest limit +1, ⟳ +1 VP on a mountain; open from turn 1.
- [ ] Temple: upgrade of Shrine, Village, Mysticism, 3 wealth, ⟳ −1 unrest.
- [ ] Great Temple: upgrade of Temple, Metropolis, Philosophy, 9 wealth, ⟳ +1 VP, ⟳ +1 food per 3 pop here.
- [ ] House of Life: upgrade of Temple, Town, Medicine, 5 wealth, housing 1, ⟳ +1 insight.
- [ ] Scribal School: Writing, 5 wealth, 1 VP, ⟳ +2 insight (today's Library).
- [ ] Library: upgrade of Scribal School, Town, Alphabet, 6 wealth, ⟳ +1 insight per 3 pop here. Alphabet's eureka
  counts 2 Scribal Schools.
- [ ] In a game: shrink a Village with a Temple to a Hamlet and see the unrest relief stop and the notice name it.

## Log
- 2026-10-05: specced. The user asked for Temple as an upgrade card and for the Library split.
