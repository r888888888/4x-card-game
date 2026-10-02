---
id: 174
title: Prerequisite cycles are a load error; the renewal modifier key lives on Modifiers
type: feature
status: review
branch: feat/174-loader-prereq-cycles
---

## Goal
A data edit that makes techs need each other is caught on load instead of leaving them locked forever, and every
modifier key is a `Modifiers` constant. From the 2026-10-01 project review.

## Acceptance criteria
- [x] AC1: Given techs `a` (prereq `b`) and `b` (prereq `a`), loading gives one error naming the cycle:
  `cards.json: card 'a': prereq: cycle a → b → a`. A three-tech cycle gives one error too; a tech that is its own
  prereq keeps today's message ("a tech can't be its own prerequisite"); a chain with no cycle loads.
- [x] AC2: `Modifiers.RENEWAL` is the renewal key and `DataLoader.MODIFIER_KEYS` takes every key from `Modifiers`
  (`Anarchy.RENEWAL` goes). The renewal tests pass unedited.

## Design notes
- The cycle check runs in `DataLoader.parse_cards`' second pass, after the existing prereq checks; one error per cycle,
  on its first tech in card order.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_research::test_a_prereq_cycle_is_one_load_error` (two and three techs, a tail into a cycle, its own prereq, a chain) |
| AC2 | `test_modifiers::test_every_modifier_key_is_a_modifiers_constant`; test_renewal unedited |

## Log
- 2026-10-01: Specced from the project review.
- 2026-10-01: Red. Added a case the spec didn't name: a tech whose prereq leads into a cycle without being in it
  (t → b, with a ↔ b) gets no error of its own; the cycle's one error is on a, its first tech in card order.
- 2026-10-01: Green. `DataLoader._prereq_cycles` runs after the second pass: it walks each tech's prereq chain in card
  order and reports a cycle when the walk returns to the tech it started from. `Modifiers.RENEWAL` replaces
  `Anarchy.RENEWAL` in the loader, card text and renewal.
