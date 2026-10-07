---
id: 370
title: Precedent takes a card from the discard back into your hand (Code of Laws)
type: feature
status: done
branch: feat/370-precedent-recall
---

## Goal
Give the later game a way to get a key card back when it's needed: **Precedent**, an era-2 action that Code of Laws
unlocks in the supply. You choose a card in your discard pile and it goes back into your hand, and Precedent gives
+1 action so the pair costs one action overall. This needs a new effect op, `recall`, and a new decision kind,
`take` (choose one of some cards to take into your hand), which 371's Read the Stars reuses.

## Acceptance criteria
- [x] AC1: Given a TEST_CARDS card with `[{op: gain_actions, amount: 1}, {op: recall}]` in hand, 2 actions left and
  3 cards in the discard, when it is played, then `pending()` is `{kind: take, options: [the 3 discard uids]}` (the
  played card is never an option), the hand is otherwise unchanged and 2 actions are left (1 used, 1 gained).
- [x] AC2: Given AC1's owed take, when the player takes one option, then that card moves from the discard to the
  hand, the other two stay in the discard, the played card is in the discard and nothing is owed.
- [x] AC3: Given exactly one card in the discard, when the recall card is played, then that card goes to the hand at
  once and nothing is owed.
- [x] AC4: Given an empty discard, then `play_error` on the recall card is "There is no card in your discard pile to
  take back." and `play_card` refuses it (nothing paid, no action used).
- [x] AC5: Given an owed take, then every other action refuses with "Choose a card to take into your hand first."
  (the guard tables in `test_blocking.gd`); `take_error(uid)` refuses a uid that isn't an option ("That card isn't
  one of the choices.") and refuses when no take is owed ("There is no card to take."); `legal_actions()` lists one
  entry per option.
- [x] AC6: A card with `{op: recall}` loads with no fields; any field is an "unknown field" warning; the loader
  rejects it on `upkeep`, on `start` and on an event (it opens a choice). Its rules text is "Take a card from your
  discard pile into your hand".
- [x] AC7 (UI, real `main.tscn`): an owed take shows the choice overlay with each option as a card; clicking one takes
  it into the hand and closes the overlay.

## Out of scope
- Replaying a card straight from the discard (the user chose back-to-hand, 2026-10-06).
- Read the Stars and looking at the deck: 371, which reuses the `take` kind.
- Balance: the price and pile size below are first guesses.

## Design notes
- **New op `recall`** (`engine/effects/recall_effect.gd`, `add-effect` skill): no fields. `opens_choice()` true,
  `upkeep_ok()` false. `play_block_error` gives AC4's message when the discard is empty. Its `apply` calls a public
  engine helper (e.g. `EngineCore.recall(source)`). A played action is out of every zone while its effects resolve
  (`CardPlay.put_into_play` adds it to the discard after), so the options never include it; store them at play time,
  since the card is in the discard by the time the take is paid.
- **New decision kind `take`** (`add-decision` skill): `GameEngine.PENDING_TAKE`; `state.pending = {kind: take,
  options: uids, zone: "discard", source: uid}`; a public action `take(uid)` with `take_error(uid)`. Paying it moves
  the chosen card from `zone` to the hand. One option: no decision, as explore does with one territory. 371 adds a
  `rest` destination for the cards not taken; leave room for it but don't build it here.
- The take may push the hand past `hand_size`; the end-of-turn hand-limit discard handles anything over `hand_limit`.
- Bot: `legal_actions` lists the take's options (`LegalActions.DECISIONS`); GenericBot answers by value.
- **Content** (`data/cards.json`, `data/config.json`):
  - `precedent`, Precedent, action, cost —, vp 0, effects `gain_actions` 1 then `recall`. Flavor (§18, 119
    characters, ends on a plain fact): "Scribes keep the verdicts on clay. When a case comes before the judges, they read
    how the last one like it was settled."
  - Code of Laws: add `{op: unlock, card: precedent}`.
  - `supply`: `precedent` at price 4, count 4, `locked`.
- PLAN.md: the op in the card data format, the `take` kind in the decisions list, Precedent under Code of Laws.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_recall::test_recall_owes_a_take_of_each_discard_card` |
| AC2 | `test_recall::test_taking_an_option_moves_it_to_the_hand_and_leaves_the_rest_in_the_discard` |
| AC3 | `test_recall::test_a_lone_discard_card_goes_to_the_hand_at_once` |
| AC4 | `test_recall::test_recall_with_an_empty_discard_is_refused` |
| AC5 | `test_recall::test_take_error_refuses_a_card_that_isnt_a_choice_or_when_no_take_is_owed`, `test_recall::test_a_take_lists_one_entry_per_option`, `test_blocking` (a `take` scenario, action row, message column, hand-input row), `test_legal_actions::coverage` (a `take` row) |
| AC6 | `test_recall::test_recall_loads`, `test_recall::test_recall_validation`, `test_recall::test_recall_card_text` |
| AC7 | `test_recall::test_the_take_overlay_shows_the_options_and_a_click_takes_one` |

## Manual check
- [ ] Shipped data: Precedent is a locked supply pile (price 4, 4 copies) until Code of Laws; its text reads +1 action,
  take a card from your discard pile into your hand.
- [ ] `godot --path . -- --seed 5 --turns 40`: research Code of Laws, buy Precedent, play it with several cards in the
  discard. The overlay lists them, a click puts one in the hand, and the action counter shows the action given back.
- [ ] Play it with an empty discard: it can't be played, and the card says why.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- Spec: back to hand plus +1 action rather than replaying from the discard (user, 2026-10-06).
- Build: the offered cards wait in a new `offered` zone (user approved at the red checkpoint), not in place in the
  discard: recall moves the whole discard there, `take` sends the rest back to the discard. 371's look reuses it, so
  `take` needs no `rest` field. While a take is owed the discard counter reads 0 (its cards are in the overlay).
- Build: the loader now rejects any op that opens a choice on an event (no shipped event used one).
- Rules in `engine/takes.gd` (`Takes`); the Take overlay is in `ui/choice_overlays.gd` (`take_row`).
- Balance worry: none measured; price 4 and 4 copies are first guesses.
