---
id: 386
title: A fifth Anarchy turn that doesn't end it loses the game
type: feature
status: wontfix
branch: feat/386-anarchy-collapse
---

## Goal
The game has no way to lose: it always runs to the turn limit and counts the score. Give Anarchy teeth: if Anarchy
still rules at the end of its fifth turn, the realm collapses and the game is over as a defeat, with no score. A long
Anarchy is now a real threat to plan around (renew, play order cards) rather than a slow patch.

Builds on [384](384-simpler-anarchy.md) (the end of an Anarchy turn: −1 unrest, then at 0 it ends) and
[385](385-renewal-action.md).

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s, with `unrest.max_turns: 5`.

- [ ] AC1 (collapse): Given Anarchy on its 5th turn with 3 unrest, when the turn ends (unrest 2 after the −1, still
  above 0), the game is over: `is_over` is true, `score()` is 0, `game_over` is emitted once with 0, no next turn
  starts (the turn number stays 5 turns past the fall), and `defeat_reason()` is non-empty and names the Anarchy card.
- [ ] AC2 (saved on the last turn): Given Anarchy on its 5th turn with 1 unrest, when the turn ends unrest reaches 0,
  Anarchy ends as usual (the government choice is owed) and the game goes on; `defeat_reason()` is "".
- [ ] AC3 (not before): Given Anarchy on its 4th turn with 3 unrest, when the turn ends the game goes on under Anarchy.
- [ ] AC4 (the turn limit comes first): Given the game's last turn is Anarchy's 5th with unrest above 0, when the turn
  ends the game is over as usual: `score()` is the score as counted and `defeat_reason()` is "".
- [ ] AC5 (off without max_turns): Given no `max_turns` in the unrest block, Anarchy on its 6th turn with unrest above
  0 goes on. The loader: `unrest.max_turns`, when given, must be an integer ≥ 1 (else an error naming it).
- [ ] AC6 (warned ahead): `revolt_summary()` has a line "If it still rules after 5 turns, the realm collapses: the game
  is lost." when `max_turns` is set, and none when it isn't. `copy()` copies the defeat (the suite's copy check).

## Out of scope
- Other ways to lose; a defeat screen beyond the game-over overlay's text.
- Warnings during Anarchy ("2 turns to collapse") beyond what the UI can already show from `state.anarchy_turn`; a
  later item if wanted.

## Design notes
- Config `unrest.max_turns` (optional, integer ≥ 1; `data/config.json`: 5).
- New state `GameState.defeat` (String, "" unless lost), copied. New query `defeat_reason()`: "" or the engine's line,
  e.g. "The realm collapsed into Anarchy." with the card's name from its def (UI text never names content).
- `score()` is 0 once `defeat` is set, so `GenericBot`'s rollouts (`is_over` → `score()`) see the loss and steer clear;
  sim stats record a defeat's final score of 0 (consider a `defeats` tally in `SimStats`).
- `Anarchy.end_of_turn` (384): after the −1, at 0 Anarchy ends; else at `anarchy_turn` ≥ `max_turns` the game ends with
  the defeat (the hand is discarded and `game_over` emitted as `TurnLoop.finish_turn` does at the turn limit; share
  that code).
- UI: the game-over overlay shows `defeat_reason()` in place of "Final score" when it is non-empty (no victory sound).

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] Collapse a game (for example `godot --path . -- --turns 30 --seed 5`, revolt, renew nothing): the game-over
  overlay names the collapse and shows no score; no victory fanfare.
- [ ] Balance worry (for the user to run): how often bots collapse. `scripts/sim.sh --level 2` (final scores of 0).

## Log
- 2026-10-07: wontfix (the user's redesign): [384](../384-simpler-anarchy.md) fixes Anarchy at 3 turns, so it can't
  reach a 5th turn. A way to lose may come back as its own item.
