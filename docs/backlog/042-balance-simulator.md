---
id: 042
title: Headless balance simulator and a balance skill
type: feature
status: draft
branch: feat/042-balance-simulator
---

## Goal
After a data edit, see what it did to the game across many seeds (score, expansion, pop, techs), and compare it
with `main`, instead of pinning numbers in tests. Uses the scripted bot that already lives in
`tests/test_content.gd`.

## Acceptance criteria
- [ ] AC1: The scripted bot moves to `sim/bot.gd` (`ScriptedBot.play(engine)`), with the same policy as today:
  resolve an explore choice with its first option; buy the cheapest affordable revealed tech or decline; else
  play the first playable hand card on its first valid target (Research last); else discard the hand and end
  the turn. It stops after 2000 steps. `tests/test_content.gd` uses it.
- [ ] AC2: `SimStats.run(cards, config, seeds) -> Dictionary` plays one bot game per seed and returns
  `{metric: {mean, min, max}}` for `score`, `cities` (City cards founded, not the Capital), `pop` (at game end),
  `techs` (cards in `researched`), `bought` (supply buys) and `era` (at game end). Given `TEST_CARDS` with deck
  `{"shrine": 10}`, `turn_limit` 3 and seeds [1, 2], then `score` is {mean 17, min 17, max 17} (Capital 2 + 5
  Shrines × 3 turns) and `cities` is {0, 0, 0}.
- [ ] AC3: Given the real data, when `scripts/sim.sh 5` runs, then it prints one line per AC2 metric with mean,
  min and max over seeds 1–5 and exits 0. Given data with a loader error, it prints the errors and exits 1.
- [ ] AC4: `tests/test_content.gd`'s three scripted-game tests become one 20-seed sweep (seeds 1–20) that checks:
  every game ends; wealth never goes below 0; a City beyond the Capital is founded in ≥ 9 seeds; a card
  costing wealth is played in ≥ 1 seed; a tech is bought in ≥ 1 seed.
- [ ] AC5: A `balance` skill (`.claude/skills/balance/SKILL.md`) runs the simulator on `main` and on the current
  checkout and shows the two tables side by side with the difference per metric.

## Out of scope
- A smarter bot (greedy or search), or several bot policies.
- Starvation counts and the turn an era arrived (need engine counters or signals; a later item).
- JSON output.

## Design notes
- New folder `sim/` (plain GDScript, like `engine/`). `sim/run.gd` extends `SceneTree`; `scripts/sim.sh [seeds]`
  wraps `godot --headless --path . --script res://sim/run.gd -- <seeds>`, like `scripts/test.sh`. Add it to the
  allowed commands in `.claude/settings.json`.
- `bought` counts successful `buy()` calls; the bot doesn't buy yet, so it is 0 until it does. Keep it so the
  table's shape doesn't change later.
- The skill gets `main`'s numbers from a temporary `git worktree` so the working tree is untouched, and removes it
  afterwards.
- Also add a `content-change` section to the skill: for data-only edits, no new tests; run the loader, the
  suite and the balance comparison, and update PLAN.md if a rule changed.
- Docs: PLAN.md (layout, "Later" list), README, docs/testing.md, docs/development-process.md.

## Test plan
| AC | Test |
|---|---|
| AC1 | |
| AC2 | |
| AC3 | |
| AC4 | |
| AC5 | |

## Manual check
- [ ] Run `/balance` after a small data edit (e.g. Farm cost 2 → 3) and check the comparison reads sensibly.

## Log
