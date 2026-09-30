---
id: 057
title: Locked supply piles and the unlock op
type: feature
status: done
branch: feat/057-locked-supply-and-unlock
---

## Goal
Techs should gate cards (TODO 7). Researching a tech gives you one free copy (the `create` op, as now) and opens that
card's pile in the supply, so you can buy more. This item adds the mechanism: supply piles that start locked, and an
`unlock` op. The content comes in 058.

## Acceptance criteria
Fixtures: the test supply adds `guildhall: {price: 2, count: 2, locked: true}`. A new TEST_CARDS tech `guilds`
("Guilds", tech, cost 2 wealth) has effects `create guildhall (discard)` and `{"op": "unlock", "card": "guildhall"}`.

- [x] AC1 (loader, config): a supply entry may have `locked` (bool, default false). A non-bool is a load error naming
  config.json, `supply` and the card.
- [x] AC2 (loader, op): `unlock` needs `card`, an id in the cards. An unknown id is a load error naming the card and
  the effect. `unlock` of a card with no supply pile is a load error naming config.json and the card that has the
  effect. `unlock` with `trigger: "upkeep"` is a load error.
- [x] AC3 (locked): In a new game the Guildhall pile is locked. `supply()` still lists it with count 2,
  `supply_locked("guildhall")` is true, and `buy_error("guildhall")` is "Guildhall isn't unlocked yet." With 5 wealth,
  `buy` returns false and nothing changes.
- [x] AC4 (unlock via a tech): Researching Guilds puts 1 Guildhall in the discard and unlocks the pile.
  `supply_locked` becomes false, then `buy("guildhall")` with 2 wealth works (count 2 → 1).
- [x] AC5 (idempotent): Unlocking a pile that is already unlocked, or that was never locked, changes nothing and
  raises no error.
- [x] AC6 (fork): `fork()` copies the lock state. Unlocking on the fork leaves the game's pile locked.
- [x] AC7 (content invariant, replaces `test_every_supply_card_also_starts_in_the_deck`): every unlocked pile's card
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
| AC1 | `test_supply::test_supply_pile_may_be_locked`, `test_supply_locked_must_be_a_bool`; changed: `test_supply_block_is_normalized` (now includes `locked: false`) |
| AC2 | `test_supply::test_unlock_op_loads`, `test_unlock_validation`, `test_unlock_of_a_card_with_no_supply_pile_is_a_config_error`; `test_forecast` `UPKEEP_UNSAFE` gets `unlock` |
| AC3 | `test_supply::test_a_locked_pile_is_listed_but_cannot_be_bought` |
| AC4 | `test_supply::test_researching_guilds_adds_a_guildhall_and_unlocks_the_pile` |
| AC5 | `test_supply::test_unlocking_twice_or_an_unlocked_pile_changes_nothing` |
| AC6 | `test_supply::test_a_fork_copies_the_locks_and_unlocks_on_its_own` |
| AC7 | `test_content::test_every_supply_pile_starts_in_the_deck_or_is_unlocked_by_a_tech` (replaces `test_every_supply_card_also_starts_in_the_deck`) |
| Text | `test_supply::test_unlock_text` |

## Manual check
- [ ] No real content uses locks until 058. To try it: in `data/config.json` add `"locked": true` to one supply pile
  and put `{"op": "unlock", "card": "<that id>"}` on an era-1 tech in the research deck. The Supply screen hides the
  pile; after researching that tech, the pile appears and can be bought. Revert the edit afterwards.

## Log
- 2026-09-29: `supply.<id>.locked` (normalized to a bool on every pile), `GameState.locked_supply`,
  `GameEngine.supply_locked` / `unlock_supply`, `engine/effects/unlock_effect.gd`. The "no supply pile" check covers
  cards the config uses (deck, research_deck, event_deck, supply, starting tableau), not every card, so fixtures that
  are loaded but unused don't need a pile. Fixtures (Guilds, Charter, Scout Charter) live in `test_supply.gd`.
- Follow-up: with every pile locked the Buy Cards button still shows and opens an empty screen (no real data does
  this yet).
