---
id: 089
title: Unique cards (a card field) have no supply pile
type: feature
status: wontfix
branch: feat/089-unique-cards
---

## Goal
Since 057/058 every card a tech gives also gets a locked supply pile, so it can be bought again. That makes sense for
cards a player wants several of (Granary, Pasture, Mine, Temple, Caravan, Market, Harbor: one per territory or city),
but not for one-offs like Monument, Forge and Library, whose piles hold 1 copy anyway. The supply should only sell
common cards. A card-level `unique` field marks the one-offs: the tech's free copy is the only one.

## Acceptance criteria
<!-- AC1-AC3 are loader and text rules on TEST_CARDS plus a fixture, e.g. `obelisk`: building, cost 2 wealth,
"unique": true. AC4-AC6 are content invariants of the real data. -->
- [ ] AC1 (field): a card may set `"unique": true`; it defaults to false and `CardDef.unique` holds it. A value that
  isn't a boolean is a load error naming cards.json, the card and `unique`.
- [ ] AC2 (config): a unique card in `supply` is a load error "config.json: supply: 'obelisk' is unique (it can't be
  bought)". A unique card in `deck` with a count above 1 is a load error naming config.json, `deck` and the card.
  A unique card in `deck` with count 1, or created by an effect, loads.
- [ ] AC3 (text): a unique card's `rules_tooltip` ends with the line "Unique: can't be bought."; its short
  `rules_text` is unchanged. A card with `text` set shows only that text, as today.
- [ ] AC4 (content): Monument, Forge, Library and Pyramids are unique and have no supply pile. Masonry, Bronze Working
  and Writing still create their card in the discard and no longer `unlock` it.
- [ ] AC5 (content invariant, replaces `test_every_card_a_tech_gives_is_a_locked_pile_it_unlocks`): every card a tech
  in `research_deck` creates is unique (no pile, not unlocked), a government (no pile), or a locked supply pile that
  the same tech unlocks. The `wonder` tag no longer gets its own exemption.
- [ ] AC6 (still plays): real data loads without warnings, and the 20-seed scripted sweep passes.

## Out of scope
- Limiting unique cards in play (one Library per realm): only buying changes. No effect makes a second copy today.
- Which common cards keep piles, prices and counts: unchanged apart from dropping the three single-copy piles.
- Showing "Unique" on the card face.

## Design notes
- Data format: new optional card field `unique` (bool) in `DataLoader.CARD_FIELDS`, read in `_parse_card`; the supply
  and deck checks go next to the existing type checks in `_parse_supply` / `_parse_counts`. `data_loader.gd` is at
  ~650 of its 700 lines: if this pushes it over, spec the split first (CLAUDE.md), don't trim lines.
- Text: `CardDef.rules_tooltip` appends the unique line, like `lasts_text()` for events. The details modal (056) shows
  the tooltip, so it says it there too.
- Real data: `"unique": true` on monument, forge, library, pyramids; remove their supply piles and the three `unlock`
  effects. Pyramids keeps its `wonder` tag.
- `test_content::UNLOCKED` and `test_every_card_moved_out_of_the_deck_is_unlocked_by_a_tech` say "unlocked by a tech";
  for a unique card that now means "created by a tech". Rename or reword them in the red phase and name them at the
  checkpoint.
- PLAN.md Gating (058) section: a tech gives 1 free copy; it unlocks a pile only for common cards.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_data_loader::test_…` |

## Manual check
- [ ] Buy Cards no longer lists Monument, Forge or Library, even after researching Masonry, Bronze Working or Writing.
- [ ] Hovering a Library shows "Unique: can't be bought." as its last line.
- [ ] Balance: `balance` skill before/after (the sim bot never buys from the supply, so expect no change).

## Log
- 2026-09-29: Set to wontfix by the user.
