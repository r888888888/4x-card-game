---
id: 090
title: True upkeep-rule rationale, refreshed add-effect skill, review rules in CLAUDE.md
type: chore
status: review
branch: feat/090-upkeep-rule-docs
---

## Goal
Since 051, `upkeep_forecast` runs on a `fork()`, so nothing is "restored" after the forecast. Yet CLAUDE.md,
`Effect.upkeep_ok`, seven op comments and the `add-effect` skill still give that as the reason only some ops may
trigger on upkeep. The rule stays (decided in the 2026-09-30 project review); its reason becomes the true one.
The same pass brings `add-effect` up to date with the hooks ops have gained since it was written, and adds the
CLAUDE.md rules the review found missing. Docs only: no behavior change, no new test.

## Acceptance criteria
- [x] AC1: CLAUDE.md's upkeep bullet reads: "Only ops whose `upkeep_ok()` is true may trigger on `upkeep`: ops that
  change nothing but resources, bonus score and pop. Nobody can choose or target during upkeep, and
  `upkeep_forecast` reports only resources and `starve`." `grep -rn "restores only\|what upkeep_forecast restores\|isn't restored" engine/ CLAUDE.md .claude/skills`
  finds nothing; `Effect.upkeep_ok`'s doc comment and the op comments (`gain`, `gain_per_tag`, `score`, `grow`,
  `lose`, `lose_pop`, `unlock`) give the same reason.
- [x] AC2: `.claude/skills/add-effect/SKILL.md` says rules tests go in a new `tests/test_<op>.gd` (as 072, 081 and
  082 did), with loader rows there too, and lists the `Effect` hooks to consider: `target_zone`,
  `no_target_error` / `choose_target_error`, `opens_choice`, `needs_own_territory` (checked for techs, events,
  governments and `start` triggers), `play_block_error`, `terms()` (card details), and recording into the play
  outcome through the `GameEngine` helper.
- [x] AC3: CLAUDE.md gains, in the fitting sections: "Type engines `Object` only in the red phase; retype them as
  `GameEngine` once green." · "UI text never names content (card names, counts); ask the engine." · "A test in
  `test_content.gd` that names a card id is a smell: assert the invariant and put per-card facts under the item's
  Manual check."
- [x] AC4: `.claude/skills/project-review/scan.sh` prints a section "Public actions without a `*_error` query"
  (public `GameEngine` methods under `# --- Actions ---` with no `<name>_error` or listed pair such as
  `play_card`/`play_error`); on today's `main` it names `choose`, `decline_research` and `discard_card`.
- [x] AC5: `.claude/settings.local.json` no longer holds the one-off `sed … 00[1-6]` allow rule. The suite is green
  and unchanged in count.

## Out of scope
- Relaxing the upkeep rule (letting `draw` / `create` trigger on upkeep): rejected in the review.
- The missing error queries themselves (093).

## Design notes
- `scan.sh` action/error pairs that don't follow the `foo`/`foo_error` naming: `play_card`→`play_error`,
  `buy_tech`→`buy_tech_error`, `new_game`→`new_game_error`, `end_turn`→`end_turn_error`, `buy`→`buy_error`,
  `grow`→`grow_error`. Keep the pair list in the script.

## Test plan
| AC | Check |
|---|---|
| AC1 | grep, reading the diff |
| AC2 | reading the skill |
| AC3 | reading CLAUDE.md |
| AC4 | running `scan.sh` on `main` |
| AC5 | `scripts/test.sh` |

## Log
- 2026-09-30: Specced from the project review (finding: stale upkeep rationale; add-effect gaps).
- 2026-09-30: Done. `gain_per_keyword` carried the same stale comment and got the new reason too (eight op comments,
  not seven). The `start` check in the loader tests targets and choices, not `needs_own_territory` (a civilization
  has a territory), so the skill says that instead of listing `start` under `needs_own_territory`. The scan section
  only counts actions returning `bool`/`void`, so `civilizations()` (a query under `# --- Actions ---`) isn't
  flagged. `.claude/settings.local.json` is gitignored: the AC5 edit is local and not in the diff.
