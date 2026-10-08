---
id: 384
title: Interregnum - Anarchy lasts a fixed 3 turns
type: feature
status: in-progress
branch: feat/384-simpler-anarchy
---

## Goal
Anarchy (145, 155, 156, 253) stacks eight rules on one card, and two of them are clocks for the same thing: its counters
(⌈max_counters × unrest ÷ limit⌉, lowered by calming, −1 a turn) and unrest itself. Cut it to rules a player can hold in
their head: **Anarchy lasts 3 turns.** Its card counts them down like any timed event. While it rules you may play
action cards, but nothing is grown, bought or researched; when it ends you choose a government and unrest drops to 0.
The drain, the one-action limit, the order-card-only rule and buying order all go. Revolution, renewal (reshaped by
[385](385-renewal-action.md)) and the government choice stay.

The 3 turns are the stage for what follows: the honeymoon ([399](399-honeymoon.md)) and the rival claimants (401–404).

## Acceptance criteria
Fixtures are `tests/lib/anarchy_case.gd`'s: Chiefs (limit 5), Kings (limit 7), Feast (order, −2 unrest); the unrest
block with `anarchy_turns: 3` and no `renewal` unless a criterion says so.

- [ ] AC1 (a fixed 3 turns): Given Anarchy falling at turn 2's start with 5 unrest, `event_counters(anarchy uid)` is 3 on
  turn 2, 2 on turn 3 and 1 on turn 4; at the end of turn 4 Anarchy leaves for `removed` and the government choice is
  owed before turn 5 starts (as today when counters ran out); after choosing Kings, unrest is 0 and turn 5 starts.
  Given a revolution declared with 1 unrest, Anarchy also lasts 3 turns (it falls at turn 2's start and ends at turn
  4's end).
- [ ] AC2 (unrest doesn't change its length): Given Anarchy on its first turn with 5 unrest and Feast in hand, when
  Feast is played unrest is 3 and the counters stay 3; Anarchy still ends at the end of its 3rd turn. Given unrest
  raised to 12 during Anarchy (no government, so no limit caps it), Anarchy still ends after its 3rd turn and choosing
  Chiefs sets unrest to 0.
- [ ] AC3 (action cards only): Given Anarchy ruling, `play_error` is "" for a non-order action card from `TEST_CARDS` and
  for Feast; for a unit or a government in hand it is `"Anarchy: only action cards can be played."` and `play_card`
  changes nothing. Growing, buying from the supply and researching are still refused with `NOTHING_BUILT`.
- [ ] AC4 (no buying out): Given Anarchy ruling with 4 unrest and 30 wealth, `legal_actions()` has no entry that ends
  Anarchy (no `restore_order`), and ending the turn leaves 30 wealth. The engine has no `restore_order`,
  `restore_order_error` or `order_relief`, the board no Restore order button, and the sim no `restored` metric.
- [ ] AC5 (no drain): Given Anarchy ruling (or a revolution pending) with 10 food and 10 wealth and nothing else
  changing them, when the next turn starts food and wealth are still 10, and `upkeep_forecast()` and `turn_forecast()`
  show no food or wealth lost to Anarchy.
- [ ] AC6 (no action limit): Given Anarchy ruling (no government) and two Feasts in hand, `actions_left()` is −1
  (unlimited) and both Feasts can be played in the same turn.
- [ ] AC7 (the revolt summary): Given Chiefs ruling and a revolution possible, `revolt_summary()` has the lines
  "It lasts 3 turns.", "You can play action cards; nothing can be grown, bought or researched." and "When it ends,
  choose a government; unrest drops to 0.", and no line about calming, actions per turn, stores eaten or buying order;
  with no revolution possible it is `[]`, as today.
- [ ] AC8 (loader): `unrest.anarchy_turns` is required, an integer ≥ 1 (else an error naming it); `max_counters`,
  `drain_pct` and `allowed_tag` are no longer known fields of the unrest block (an unknown-field warning, like any
  other), and the block loads without them; the real data loads with no errors or warnings.

## Out of scope
- Renewal: still as today here (owed at each turn's start, `renewal` + its turn − 1); [385](385-renewal-action.md)
  makes it a flat free action.
- The honeymoon after Anarchy ([399](399-honeymoon.md)); the claimants (401–404).
- Tuning the government limits or `anarchy_turns`; that's a balance item.

## Design notes
- Config `unrest`: add `anarchy_turns` (`data/config.json`: 3); drop `max_counters`, `drain_pct` and `allowed_tag`.
- The fall (`Anarchy._fall`) puts `anarchy_turns` counters on the card. The end of an Anarchy turn
  (`Anarchy.end_of_turn`): −1 counter; at 0 Anarchy ends (`_end`, the government choice with `ends_turn`). Calming no
  longer touches the counters.
- `choose_government` sets unrest to 0 (replacing the drop to half the new limit).
- `Anarchy.play_error`: only `CardDef.ACTION` cards; the message changes to "Anarchy: only action cards can be played."
  The `order` tag stays on Feast and Assembly of Elders as plain content.
- `data/cards.json`: Anarchy loses `"modifiers": {"actions": 1}`; its hand-written `text` becomes "Lasts 3 turns. You
  can play action cards; nothing is grown, bought or researched.\nEach turn, trash 1 card, +1 per turn so far.\nWhen it
  ends, choose a government; unrest drops to 0." (385 rewrites the renewal line.)
- Removed as unreachable: `counters_for`, `counters_left`, `calm` and the `_unrest_lowered` hook, `revolt_forecast` and
  `GameEngine.revolt_forecast`, `anarchy_counters`, `state.anarchy_limit` (and `GenericBot`'s key on it), `drain`,
  `drain_of`, `rules_next_turn` and their forecast step, and the Anarchy branch in `CardPlay.actions_per_turn` (no
  government ⇒ unlimited, as without unrest). Their tests go too (`test_anarchy_drain`, and the counter, halving, drain
  and actions cases elsewhere).
- Buying order goes (the user's call, 2026-10-06): `restore_order`, `restore_order_error`, `order_relief`,
  `Anarchy.relief`/`restore`/`restore_error`, the `order_restored` signal, the Restore order button
  (`ActionButton.restore_order`, `main.restore_order_button`), its `legal_actions` entry and the sim's `restored`
  metric. Relieve famine stays.
- The sim's `anarchy_turns` metric is now always 3 × `anarchies`; drop it.
- `GenericBot` sees the change through `turn_forecast` and the legal actions; no new action.

## Test plan
| AC | Test |
|---|---|
| AC1 | |

## Manual check
- [ ] Anarchy's card reads well and fits its face; its event panel counts 3, 2, 1.
- [ ] The Revolt modal's summary reads well with the new lines.
- [ ] Balance worry (for the user to run): every Anarchy now costs 3 turns, a calm revolution included (today about
  1), and a natural fall no more than 3 (today up to 4). `scripts/sim.sh --level 2 --compare <main checkout>`
  (anarchies, revolts, score).

## Log
- 2026-10-06: buying order removed entirely (the user, via the card-images session), in place of 2 wealth per unrest.
- 2026-10-07: redesigned (the user): Anarchy lasts a fixed 3 turns instead of until unrest reaches 0; action cards
  are playable instead of order cards only; unrest drops to 0 when the government is chosen. The red tests committed
  on this branch (789d6999) were written for "unrest is its clock" and must be rewritten against these criteria before
  the next red checkpoint; AC4–AC6 and the loader part of AC8 carry over.
