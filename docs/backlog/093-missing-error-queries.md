---
id: 093
title: Error queries for choose, decline_research and discard_card
type: feature
status: red-review
branch: feat/093-missing-error-queries
---

## Goal
CLAUDE.md pairs every action with a `*_error()` query that the action and the UI both use. Three actions
have none: `choose`, `decline_research` and `discard_card` return false without saying why. So the UI can't
explain a refusal. A right-click or D on a hand card while a territory or tech choice is open does nothing, and
the Decline button is always enabled. Add the queries, make the actions refuse through them, and have the UI show
the reason the way it does for a refused play.

## Acceptance criteria
- [ ] AC1: `discard_error(uid)` is "" for a hand card with nothing pending, and also while an end-of-turn discard is
  owed. It is "The game is over." after the game ends, "Choose a territory first." while an explore choice is
  open, "Buy a tech or decline first." while techs are revealed, and "That card is not in your hand." for a uid
  that isn't in the hand, checked in that order.
- [ ] AC2: `choose_error(uid)` is "" for a revealed territory while an explore choice is open. It is "There is no
  territory to choose." with no explore choice open, and "That territory isn't an option." for any other uid
  while one is open.
- [ ] AC3: `decline_research_error()` is "" while techs are revealed, and "No techs are revealed." otherwise.
- [ ] AC4: `discard_card`, `choose` and `decline_research` each return false, change nothing and emit no `changed`
  exactly when their query is non-empty (one case per query message, added to `test_changed`'s refused actions
  and `test_pending`'s blocking rule).
- [ ] AC5: In the real `main.tscn`, discarding a hand card while an explore choice is open (the right-click / D
  path, `main.discard(view)`) logs the engine's reason in the side panel and leaves the hand unchanged. The
  Decline button is disabled, with `decline_research_error()` as its tooltip, whenever that query is non-empty.
- [ ] AC6: `main.on_picked` calls `choose_error` before `choose` and shows a non-empty reason like a refused play.
  `scan.sh`'s "actions without a `*_error`" section (090) is empty.

## Out of scope
- Error queries for the helpers effects call (`explore`, `settle`, `trash`, …): they aren't player actions.
- Changing when discarding is allowed.

## Design notes
- `discard_error` starts with `_blocked_error("discard")`, which already allows discarding while a discard is owed.
- New `GameEngine` API: `discard_error(uid: int) -> String`, `choose_error(uid: int) -> String`,
  `decline_research_error() -> String`, next to their actions; the bodies live in `TurnLoop`, `Territories` and
  `Research`.
- `ChoiceOverlays.refresh` gets the engine (or the decline error) so it can set the button's state.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_action_errors::test_discard_error` |
| AC2 | `test_action_errors::test_choose_error` |
| AC3 | `test_action_errors::test_decline_research_error` |
| AC4 | `test_changed::test_actions_refuse_exactly_when_their_error_query_says_why` (one row per message); `test_pending::test_each_pending_kind_blocks_actions_as_before` (gains a `discard_error` check) |
| AC5 | `test_action_errors::test_discarding_during_an_explore_choice_logs_why`, `test_decline_is_disabled_with_the_reason_when_no_techs_are_revealed` |
| AC6 | `test_action_errors::test_picking_a_card_that_isnt_an_option_logs_why`; `scan.sh` section (checked at green) |

## Manual check
- [ ] Play an Explorer, then right-click a hand card: it shakes and the log says "Choose a territory first."
- [ ] Play Insight: Decline is enabled; declining works as before.

## Log
- 2026-09-30: Specced from the project review (CLAUDE.md action/error rule broken by three actions). UI shows the
  reason (review decision).
