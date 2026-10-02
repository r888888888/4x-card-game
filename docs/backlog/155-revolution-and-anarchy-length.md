---
id: 155
title: Revolt any time; Anarchy's length follows unrest
type: feature
status: ready
branch: feat/155-revolution-and-anarchy-length
---

## Goal
Revolution becomes a reform you schedule. You can revolt whenever you like and Anarchy starts next turn. How long it
lasts depends on how restless the people are relative to the fallen government's limit: a calm reform is short, a
collapse at the limit is long. Calming shortens it, and wealth buys the rest off at a price that rises with each
turn left. Follows 154. From `spike/revolution`.

## Acceptance criteria
- [ ] AC1: When Anarchy falls, it gets ⌈max_counters × unrest ÷ L⌉ counters, between 1 and max_counters, where L is
  the fallen government's `unrest_limit()` (modifiers included). With Chiefs (5) and max_counters 4: unrest 5 → 4,
  unrest 2 → 2, unrest 1 → 1, unrest 0 → 1; with an Altar (limit 6), unrest 3 → 2.
- [ ] AC2: `anarchy_counters()` is the counters left, lowered live by calming: never more than the AC1 formula on the
  current unrest (same L), never below 1 while Anarchy rules. Given 4 counters, L 5 and unrest 5, when unrest drops to
  2, then `anarchy_counters()` is 2, and it doesn't rise again when unrest goes back up.
- [ ] AC3: At the end of each Anarchy turn (after any hand-limit discard), one counter comes off; at 0 Anarchy ends
  and the government choice (154) is owed before the next turn starts. A 1-counter Anarchy lasts exactly one turn.
  The next turn's upkeep runs under the chosen government.
- [ ] AC4: Given a government ruling and no Anarchy, `revolt_error()` is "" (no event needed). `revolt()` uses no
  action, changes nothing else this turn, and at the next turn's start (before upkeep) Anarchy falls as in AC1, the
  fallen government going to the government deck. `revolt_error()` is `"Anarchy already rules."`, `"A revolution is
  already under way."` after a revolt this turn, `"There is no government to overthrow."` with none ruling, the
  pending-decision message while one is owed, and `"The game is over."` after the end; `revolt()` then returns false
  and changes nothing.
- [ ] AC5: `order_relief()` is `{wealth: c × (c + 1)}` for c = `anarchy_counters()` (2, 6, 12, 20 for 1–4), `{}`
  without Anarchy. `restore_order_error()` is `"Order can't be restored on Anarchy's first turn."` on the turn it
  fell, and names the price when wealth is short. `restore_order()` pays, ends Anarchy, drops any renewal still owed
  this turn, and owes the government choice at once.
- [ ] AC6: Renewal (147) asks for `unrest.renewal` + (the Anarchy's turn − 1) + the `renewal` modifier cards: 1 on its
  first turn with renewal 1, 2 on its second.
- [ ] AC7 (bot): `ScriptedBot` revolts at the end of a turn when the government deck holds one it ranks higher (154's
  ranking) than the ruling one and `anarchy_counters` would be 1 (AC1 on current unrest); under Anarchy it restores
  order from the second turn when it can pay and 2+ counters are left or the next upkeep would starve.
- [ ] AC8: The Revolt button below the Realm shows whenever `revolt_error()` is ""; its tooltip says Anarchy starts
  next turn and lasts about N turns (N from the engine: AC1 on current unrest).
- [ ] AC9 (154 leftovers): a government is never played from hand. Given a government card put straight into the hand,
  `play_error` is `"A government is chosen, not played."`, with or without Anarchy. The play-a-government path goes:
  `CardPlay`'s government destination and `_replace_government`, the same-government error, `Anarchy.accept_error` and
  the government branch of `Anarchy.play_error` (whose message becomes `"Anarchy: only an order card can be
  played."`), and `ScriptedBot`'s governments-first play and 148 revolt rule. The 11 tests that put a government in hand
  (test_government 3, test_leaving_anarchy 4, test_anarchy 2, test_revolution 2) are removed or rewritten on the
  government deck, and listed at the red checkpoint.

## Out of scope
- The drain on stores (156); the lookahead bot (159).

## Design notes
- `GameState`: `revolt_pending`, `anarchy_turn` (1 = the turn it fell), `anarchy_limit` (L, recorded before the
  government falls). The counters' countdown moves from the turn's start to `end_turn`, which owes the choice like the
  hand-limit discard does (`finish_turn` after `choose_government`).
- Forced Anarchy still falls at the turn's start after upkeep when unrest is at the limit (then max_counters counters).
  A revolution falls before upkeep, so its first Anarchy turn has an Anarchy upkeep.
- Replaces 148's event requirement: events' `revolt` field is dropped (loader: unknown field warning; Calls for Reform
  and Radical Thinkers keep their `renewal` modifiers, Peasant Uprising keeps +1 unrest). Replaces 146's flat
  `unrest.relief` (dropped from the config) and 145's count-up counters.
- API: `anarchy_counters()` (now counters left), `revolt_forecast()` → expected counters, for the tooltip.
- The Anarchy card's hand-written text must follow these rules.
- AC9 was folded in from the 2026-10-01 project review: since 154 `create_card` sends a government to the government
  deck and the loader keeps governments out of the deck and supply, so no real game has one in hand (8 seeds checked:
  never). AC4's "There is no government to overthrow." also closes a soft-lock the review reproduced on today's code:
  with no government ruling, revolt → Anarchy burns out → a government choice from an empty deck that refuses every
  action. Its AC4 test is the regression test. The item now has 9 criteria.
- Builds on 169–176: the end-of-turn government choice is set in 172's `state.pending`, the new `GameState` fields are
  covered by 171's copy guard, and the order price uses 173's helpers.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] Revolt at low unrest: Anarchy next turn lasts 1 turn; the Government overlay opens at its end.
- [ ] Hit the unrest limit: 4 turns of Anarchy; renewal shortens it; Restore order shows the price falling.

## Log
- 2026-10-01: Specced from `spike/revolution`. Spike: counters by share of the limit cost 7–9% score against ⌈unrest ÷ 2⌉
  on baseline and wide; about 4 Anarchies and 1–2 revolts a game with the lookahead bot.
