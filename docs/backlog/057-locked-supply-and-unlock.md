---
id: 057
title: Locked supply piles and the unlock op
type: feature
status: ready
branch: feat/057-locked-supply-and-unlock
---

## Goal
Techs should gate cards (TODO 7). Researching a tech gives you one free copy (the `create` op, as now) and opens that
card's pile in the supply, so you can buy more. This item adds the mechanism: supply piles that start locked, and an
`unlock` op. The content comes in 058.

## Acceptance criteria
Fixtures: the test supply adds `guildhall: {price: 2, count: 2, locked: true}`. A new TEST_CARDS tech `guilds`
("Guilds", tech, cost 2 wealth) has effects `create guildhall (discard)` and `{"op": "unlock", "card": "guildhall"}`.

- [ ] AC1 (loader, config): a supply entry may have `locked` (bool, default false). A non-bool is a load error naming
  config.json, `supply` and the card.
- [ ] AC2 (loader, op): `unlock` needs `card`, an id in the cards. An unknown id is a load error naming the card and
  the effect. `unlock` of a card with no supply pile is a load error naming config.json and the card that has the
  effect. `unlock` with `trigger: "upkeep"` is a load error.
- [ ] AC3 (locked): In a new game the Guildhall pile is locked. `supply()` still lists it with count 2,
  `supply_locked("guildhall")` is true, and `buy_error("guildhall")` is "Guildhall isn't unlocked yet." With 5 wealth,
  `buy` returns false and nothing changes.
- [ ] AC4 (unlock via a tech): Researching Guilds puts 1 Guildhall in the discard and unlocks the pile.
  `supply_locked` becomes false, then `buy("guildhall")` with 2 wealth works (count 2 → 1).
- [ ] AC5 (idempotent): Unlocking a pile that is already unlocked, or that was never locked, changes nothing and
  raises no error.
- [ ] AC6 (fork): `fork()` copies the lock state. Unlocking on the fork leaves the game's pile locked.
- [ ] AC7 (content invariant, replaces `test_every_supply_card_also_starts_in_the_deck`): every unlocked pile's card
  starts in the deck, and every locked pile is unlocked by some tech in `research_deck`.

## Out of scope
- The real content (058).
- Showing locked piles in the Supply screen. They stay hidden until unlocked; the tech tree (059) shows what a tech
  unlocks.

## Design notes
- Config: `supply.<id>.locked` (bool). `GameState.unlocked_supply` (a set of ids), or a lock flag per pile, copied in
  `copy()`.
- New API: `supply_locked(card_id) -> bool`. `supply()` keeps its shape. The UI filters locked piles out using
  `supply_locked`.
- New op `unlock` (`engine/effects/unlock_effect.gd`, `add-effect` skill). Text: short "Unlock Guildhall", tooltip
  "Guildhall can now be bought in the supply." The config check for "no supply pile" runs in `parse_config`, once
  the cards and the supply are both known.
- AC7 replaces an approved content test on purpose: locked piles make "every supply card starts in the deck" false by
  design.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_supply::test_…` |

## Manual check
- [ ] The Supply screen shows no locked piles. After researching the unlocking tech, the pile appears.

## Log
