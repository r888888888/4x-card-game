---
id: 311
title: A sample fork reshuffles what the player can't see
type: feature
status: done
branch: feat/311-sample-fork
---

## Goal
`fork()` copies the rng and the order of every deck, so a bot that plays a fork ahead (ScriptedBot's lookahead today,
313's bot tomorrow) knows which cards, events, raids and territories come next. Its choices are made with information
a player never has, which flatters the sim. After this, `sample_fork(seed)` gives a copy where the hidden orders are
reshuffled from a seed: one possible future, not the real one.

## Acceptance criteria
- [x] AC1: Given a game whose deck holds 10 cards, when `sample_fork(s)` is called, then its deck holds the same cards
  (same uids) as the game's; for seeds 1 to 20 at least one sample's order differs from the game's, and the same seed
  gives the same order twice.
- [x] AC2: The same holds for `event_deck` and `territory_deck`: same cards, an order drawn from the seed.
- [x] AC3: Everything else in the sample equals the game: hand, discard, tableau, frontier, reveal, research deck,
  researched, supply, resources, turn, pending (with its options), active events and each raid's target.
- [x] AC4: The sample's later shuffles come from the seed, not the game's rng: two samples with seeds 1 and 2, after
  their decks run out and the discard is reshuffled, may differ, and the same seed twice gives the same order.
- [x] AC5: The game is untouched: its zone orders, and the order its next reshuffle gives, are the same as without the
  call. `fork()` still copies the game exactly (its tests unchanged).

## Out of scope
- Using it in a bot: 313 (the generic bot) values candidates on sample forks; ScriptedBot's lookahead is replaced in
  314, not changed here.

## Design notes
- New action-free method on `GameEngine` beside `fork`: `sample_fork(seed: int) -> GameEngine` = `fork()`, then a new
  `SeededRng` from seed, then shuffle `deck`, `event_deck` and `territory_deck` with it. Hidden zones listed in one
  constant (`HIDDEN_ZONES`), so a new hidden zone is one entry. Add it to `STAYS` in `tests/test_engine_structure.gd`.
- The deck's contents are known to the player (a deckbuilder); only the order is hidden. Raids already announced and
  the reveal are visible, so they stay.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_game_state::test_a_sample_fork_reshuffles_the_deck_from_its_seed`, `test_engine_structure` (`sample_fork` in `game_engine.gd`) |
| AC2 | `test_game_state::test_a_sample_fork_reshuffles_the_event_and_territory_decks` |
| AC3 | `test_game_state::test_everything_the_player_sees_is_the_same_in_a_sample` |
| AC4 | `test_game_state::test_a_samples_later_shuffles_come_from_its_seed_not_the_games_rng` |
| AC5 | `test_game_state::test_a_sample_leaves_the_game_untouched` (and the existing fork tests, unchanged) |

## Log
- 2026-10-05: specced from the generic-bot spike, with 309, 310, 312–315. The spike found forks are clairvoyant.
- 2026-10-05: built as `fork()` + a new `SeededRng` + a shuffle of each of `GameEngine.HIDDEN_ZONES`. ScriptedBot's
  lookahead still uses `fork()` (clairvoyant) until 314 replaces it.
