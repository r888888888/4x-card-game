---
id: 307
title: New urban upgrades for markets, stores, walls, houses, workshops and harbours; Aqueduct needs a Town
type: feature
status: red-review
branch: feat/307-urban-upgrade-chains
---

## Goal
After 306 only temples and libraries reward a big settlement. After this, the other institutions that marked a city
in the Bronze and Iron Ages do too: a merchant quarter and a mint, a central storehouse, city walls, multi-storey
houses, textile workshops and a dockyard, each an upgrade that needs a Town or a Metropolis, several scaling with pop
(304). The Aqueduct, which fed cities (Sennacherib's Jerwan aqueduct, c. 690 BC), stops being a building any hamlet can
raise. Several era 3 techs that unlock nothing today get a purpose. Content only. Follows 306.

## Acceptance criteria
Content tests, naming no card id (306's invariants cover tiers, eurekas and unrest limits):
- [ ] AC1: Every tech that unlocks nothing (no `unlock`, `create` or `add_era`) is listed in a content-test allowlist of
  pure discount techs, so a tech left empty by a content change is a deliberate choice. (Today: Mathematics, Astronomy.)
- [ ] AC2: Every building with a tier of Metropolis that isn't a wonder is an upgrade: stand-alone Metropolis buildings
  are for 308's one-per-realm buildings only, which set `once`.

## Out of scope
- Gap buildings (Palace, Shipyard…): 308. Tuning: the balance item after 308.

## Design notes
- New upgrades (first-pass numbers; techs that unlock nothing today marked *):
  - **Merchant Quarter**: upgrade of Market, Town, Credit*: ⟳ +1 wealth per 3 pop here. The Old Assyrian merchant
    quarter at Kanesh (c. 1900 BC) ran on loans and credit.
  - **Mint**: upgrade of Merchant Quarter, Metropolis, Coinage*: ⟳ +2 wealth, 1 VP. Coinage began in Lydia, c. 600 BC.
  - **Storehouse**: upgrade of Granary, Town, Clay Tokens*: housing 1, famine guard 1 more. Clay tokens counted stored
    goods; Bronze Age palace economies gathered harvests in central stores. Clay Tokens' eureka counts a Granary: fine.
  - **City Walls**: upgrade of Palisade, Town, Masonry: defence +2. City walls were a mark of the city; raids prefer the
    most pop at equal defence, so tall needs them.
  - **Multi-storey Houses**: upgrade of Courtyard Houses, Town, Engineering: housing 2. Tyre and Arwad built upward.
  - **Textile Works**: upgrade of Weavers' Workshop, Town, Weaving: ⟳ +1 wealth per 3 pop here. Ur III's temple and
    palace workshops employed thousands of weavers.
  - **Dockyard**: upgrade of Harbor (305), Town, Navigation*: ⟳ +1 wealth per 3 pop here.
- **Aqueduct**: stays a stand-alone building (Engineering) and gains tier Town; housing 2 → 3. A fresh-water keyword
  from an aqueduct would need a new rule; not in this item.
- Left as pure discount techs: Mathematics, Astronomy (AC1's allowlist).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_tech_that_opens_nothing_is_a_listed_discount_tech` |
| AC2 | `test_content::test_every_metropolis_building_is_an_upgrade_a_wonder_or_once` |

## Manual check
- [ ] Merchant Quarter (Market, Town, Credit, 5 wealth, ⟳ +1 wealth per 3 pop here).
- [ ] Mint (Merchant Quarter, Metropolis, Coinage, 8 wealth, ⟳ +2 wealth, 1 VP).
- [ ] Storehouse (Granary, Town, Clay Tokens, 4 wealth, housing 1, famine guard 1).
- [ ] City Walls (Palisade, Town, Masonry, 5 wealth, defence 2).
- [ ] Multi-storey Houses (Courtyard Houses, Town, Engineering, 5 wealth, housing 2).
- [ ] Textile Works (Weavers' Workshop, Town, Weaving, 5 wealth, ⟳ +1 wealth per 3 pop here).
- [ ] Dockyard (Harbor, Town, Navigation, 6 wealth, ⟳ +1 wealth per 3 pop here).
- [ ] Aqueduct: Engineering, tier Town, 5 wealth, housing 3.

## Log
- 2026-10-05: specced from the realism pass of the tall-buildings design.
