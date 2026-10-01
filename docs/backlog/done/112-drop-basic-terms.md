---
id: 112
title: Drop the basic terms from card details
type: feature
status: done
branch: feat/112-drop-basic-terms
---

## Goal
The details modal's "How it works" section explains Upkeep on nearly every card, and Slots and Pop on every
building and territory. A player learns these in the first turn, so repeating them is noise. Only the less obvious
rules (Workers, Housing, Passes, Requires, keywords, …) stay.

## Acceptance criteria
- [x] AC1: `Glossary.BASIC` lists the terms a player learns in the first turn: Upkeep, Slots, Pop. `def_details` and
  `card_details` never list a basic term in `terms`, for any card.
- [x] AC2: the other terms are unchanged and keep their first-use order: a TEST Farm (⟳ +1 food, a building) has
  terms ["Workers"]; Well has ["Requires", "Fresh Water", "Workers"]; a territory in play still lists Housing.
- [x] AC3: a card whose only terms were basic has `terms` [] (e.g. a civilization with only upkeep effects), so the
  modal shows no "How it works" section for it.

## Out of scope
- Rewording the remaining glossary texts. A help screen that lists every term (the texts stay in `Glossary.TERMS`).

## Design notes
- `CardDetails._terms` skips `Glossary.BASIC`. The glossary keeps the texts, so a later help screen can use them.
- Existing tests whose expectations change: `test_card_details::test_farm_details_have_name_type_cost_rules_and_terms`,
  `::test_keyword_terms_name_the_cards_that_use_the_keyword`, `::test_territory_details_show_pop_slots_and_workers`.
- Assumption (instead of a question): Workers stays, since its rule (buildings go idle past the pop) isn't obvious.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_details::test_basic_terms_are_upkeep_slots_and_pop`, `::test_no_card_lists_a_basic_term` |
| AC2 | `test_card_details::test_farm_details_have_name_type_cost_rules_and_terms` (changed), `::test_keyword_terms_name_the_cards_that_use_the_keyword` (changed), `::test_territory_details_show_pop_slots_and_workers` (changed: checks Housing only) |
| AC3 | `test_card_details::test_a_card_with_only_basic_terms_has_none` |

## Manual check
- [ ] Open a Farm's and Egypt's details: no Upkeep explanation; Egypt has no "How it works" section at all.

## Log
- Built: `Glossary.BASIC`; `CardDetails._terms` skips it. Tests 744 → 747.
