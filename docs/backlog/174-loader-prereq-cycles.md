---
id: 174
title: Prerequisite cycles are a load error; the renewal modifier key lives on Modifiers
type: feature
status: ready
branch: feat/174-loader-prereq-cycles
---

## Goal
A data edit that makes techs need each other is caught on load instead of leaving them locked forever, and every
modifier key is a `Modifiers` constant. From the 2026-10-01 project review.

## Acceptance criteria
- [ ] AC1: Given techs `a` (prereq `b`) and `b` (prereq `a`), loading gives one error naming the cycle:
  `cards.json: card 'a': prereq: cycle a → b → a`. A three-tech cycle gives one error too; a tech that is its own
  prereq keeps today's message ("a tech can't be its own prerequisite"); a chain with no cycle loads.
- [ ] AC2: `Modifiers.RENEWAL` is the renewal key and `DataLoader.MODIFIER_KEYS` takes every key from `Modifiers`
  (`Anarchy.RENEWAL` goes). The renewal tests pass unedited.

## Design notes
- The cycle check runs in `DataLoader.parse_cards`' second pass, after the existing prereq checks; one error per cycle,
  on its first tech in card order.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Log
- 2026-10-01: Specced from the project review.
