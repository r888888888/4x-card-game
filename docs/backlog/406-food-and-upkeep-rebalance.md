---
id: 406
title: Early food and building upkeep rebalance - Farm 4, Fishing Huts 3, Irrigation Canals and Salt Pans stand alone, every building ⟳ 1 wealth
type: feature
status: ready
branch: feat/406-food-and-upkeep-rebalance
---

## Goal
Early food is too scarce and wealth piles up with nothing to drain it. Farms make 4 food and Fishing Huts 3, and the
other food buildings rise to match. To offset that, every base building costs 1 wealth upkeep (405). Wealth buildings
make 1 more so they pay for themselves: the new drain falls on food, insight, housing, order, defence and VP buildings.

Irrigation Canals and Salt Pans become buildings of their own again, no longer upgrades of the Farm and Fishing Huts,
so territories can specialise. A fresh-water territory can fill its slots with food (Farm beside Irrigation Canals),
and a coast can mix Fishing Huts, Salt Pans and its trade buildings. Each building takes a slot, a worker and its
upkeep, so where you put it is a real choice.

Needs 405.

## Acceptance criteria
- [ ] AC1 (everyone pays): In the real data, the config's `building_upkeep` is ≥ 1. Every building that is neither an
  upgrade nor a project has an effective upkeep ≥ 1, and every upgrade and project has 0.
- [ ] AC2 (wealth buildings pay their way): Every base building with a ⟳ wealth effect makes at least its upkeep in
  wealth from effects with no keyword (a keyword bonus or a per-city/per-pop amount doesn't count toward it).
- [ ] AC3 (the text matches): Every base building's generated text carries its upkeep line, and PLAN.md's Resources
  row and building lines carry the new numbers (305's and 364's lines say Irrigation Canals and Salt Pans stand alone).
  Card text is generated, so no `text` field changes. The card-art briefs in `docs/design/card-art.md` stop calling
  them upgrades.
- [ ] AC4 (stand-alone buildings still fit): With the two moved out of `upgrade_of`, these hold in the real data (add
  the check where no content test covers it yet): every base building's `requires` is met by some territory, and every
  territory can hold a food building that isn't an upgrade (308).

## Out of scope
- The upkeep rule itself (405).
- Tuning beyond the table below. Anything a sim run turns up goes in a balance item.
- Wonders: they pay no upkeep and keep their numbers.

## Design notes
Design pass on all 56 buildings. Agreed: base buildings pay, upgrades and wonders don't. Wealth buildings get +1 output
so they net what they net today. Food buildings rise with the Farm.

**Food buildings** (each also pays ⟳ −1 wealth)

| Building | Today | New | Why |
|---|---|---|---|
| Farm | ⟳ +2 food (+1 flood plain) | ⟳ +4 food (+1 flood plain) | The request |
| Fishing Huts | 2 wealth; ⟳ +1 food, housing 1, Net Fishing | **3 wealth**; ⟳ +3 food, housing 1, Net Fishing | The request. It also houses and adds a card for no food, so it costs 1 more |
| Pasture | ⟳ +2 food | ⟳ +3 food | Grassland's farm, a step under the Farm |
| Hunters' Camp | ⟳ +1 food, +1 VP, Hunt | ⟳ +2 food | Forest's food building. +1 would trail the others badly |
| Terraced Fields | ⟳ +1 food (+1 fresh water) | ⟳ +2 food (+1 fresh water) | The mountain's food building |
| Qanat Channel | ⟳ +1 food, housing 2 | ⟳ +2 food, housing 2 | The desert's food building |
| Irrigation Canals | Upgrade of Farm; 1 food + 2 wealth; ⟳ +1 food (+1 desert), housing 1 | **Building**, fresh water; 1 food + 3 wealth; ⟳ +3 food (+1 desert), housing 1; keeps the `farm` tag | A second fresh-water food building: 1 food less than the Farm, plus housing. On Oasis and Desert Floodplain (1 slot each) it is the better pick (4 food + housing), so desert water specialises in canals |
| Salt Pans | Upgrade of Fishing Huts; 2 wealth; ⟳ +1 food | **Building**, coastal; 3 wealth; ⟳ +2 food, +1 wealth | The coast's second food building. Its wealth pays its upkeep, so it nets +2 food against the Huts' +3 food −1 wealth with housing. Huts lean food; Pans balance |

**Wealth buildings** (+1 wealth, then ⟳ −1 wealth upkeep: same net)

| Building | Today | New |
|---|---|---|
| Kiln | ⟳ +1 wealth | ⟳ +2 wealth |
| Brewery | ⟳ +1 wealth, famine guard 1 | ⟳ +2 wealth, famine guard 1 |
| Reed Works | ⟳ +1 wealth, housing 1 | ⟳ +2 wealth, housing 1 |
| Weavers' Workshop | ⟳ +1 (+1 grassland) | ⟳ +2 (+1 grassland) |
| Olive Groves | ⟳ +1 (+1 coastal) | ⟳ +2 (+1 coastal) |
| Caravan Station | ⟳ +1 (+1 fresh water) | ⟳ +2 (+1 fresh water) |
| Shipyard | ⟳ +1 (+1 forest) | ⟳ +2 (+1 forest) |
| Mine | ⟳ +1 (+1 gold, tin, copper each) | ⟳ +2 (+1 each) |
| Dye Works | ⟳ +2 | ⟳ +3 |
| Market | ⟳ +1 per city (+1 gold) | ⟳ +1, +1 per city (+1 gold) |

**Pay upkeep, no number change** (they now net ⟳ −1 wealth): Shrine, Monument, Forge, Palisade, Barracks, Granary,
Scribal School, Stone Circle, Courtyard Houses (`mud_brick_houses`), Bathhouse, Courthouse, Aqueduct, Cistern. These
are the buildings the drain is meant to hit. A housing building's cost now recurs, but more food makes housing the
limit on growth, so they stay worth building.

**Palace: upkeep 2.** It is the one stand-alone building that adds an action each turn, the strongest standing effect
in the game. Every other building stays at the default 1.

**Upgrades** pay nothing and keep their numbers, except **Ploughed Fields: ⟳ +1 → +2 food**. It is now the Farm's only
upgrade, and +2 keeps its share of a 4-food Farm what +1 was of a 2-food one (half). It takes no slot, worker or
upkeep, so it is the way to deepen a farm territory without spending a slot. Harbor (+1 food, +2 wealth) is now the
Fishing Huts' only upgrade and stays as it is.

**Specialisation, territory by territory** (slots are the limit, so these are the choices):
- River Meadow and Alluvial Plain (grassland, fresh water): Farm, Irrigation Canals, Pasture all fit, about 3–5 food
  each. A breadbasket.
- Oasis and Desert Floodplain (1 slot): Irrigation Canals (4 food + housing) or a Farm (4, 5 on the floodplain).
- Coastal Plain (3 slots), Cedar Coast and Coastal Hills (2): Fishing Huts and Salt Pans for food, or Dye Works,
  Shipyard and Olive Groves for wealth.
- Delta Marsh (1 slot, coastal and fresh water): Farm, Irrigation Canals, Fishing Huts or Salt Pans all fit, so its one
  slot is a real choice.

**Wonders**: no upkeep, unchanged.

**Balance worries (for the balance item, not this one):**
- Sumer: its starting Farm sits on Delta Marsh (a flood plain), so with ⟳ +1 food per farm turn 1 would make
  2 + 5 + 1 = 8 food against 2 pop, and Irrigation Canals (farm-tagged) would stack the bonus further. 407 reworks Sumer
  and ships with this item, so Sumer never plays on these numbers.
- Egypt (+1 food per fresh water / flood plain) gains the same way; Phoenicia and Persia (wealth civs) gain from the
  drain's pressure on everyone else.
- The era-2 unlock is 8 pop or 15 wealth: pop comes sooner and wealth later, so era 2 may arrive on pop, and earlier.
- Barter (2 food → 2 wealth) becomes the main way to turn the food surplus into wealth; watch how often the bot plays it.
- Famine should come much less often. Granary and Brewery's famine guard matter less.
- The +1 unrest per wealth short could push wide strategies into Anarchy; watch Anarchy counts per strategy.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] `data/config.json` has `"building_upkeep": 1`; Palace has `"upkeep": 2`.
- [ ] Each number in the Design notes tables is what `data/cards.json` ships (Fishing Huts costs 3 wealth).
- [ ] Irrigation Canals and Salt Pans have no `upgrade_of`. Irrigation Canals requires fresh water and Salt Pans coastal.
  Irrigation and Pottery still unlock them, and they show in the Build menu as buildings taking a slot, not under
  Upgrades.
- [ ] A Farm's details list only Ploughed Fields under Upgrades, and Fishing Huts' only Harbor.
- [ ] New game as Egypt, build a Farm on the home (Desert Floodplain): the food forecast rises by 5 (4, +1 flood plain)
  and the wealth forecast drops by 1.
- [ ] Balance (the user runs it): `scripts/sim.sh --level 3 --compare <main checkout>`. Watch famine count, Anarchy
  count, turn of era 2, final VP per civ (Sumer and Egypt above all) and Barter plays.

## Log
