# 4X Card Game — instructions for Claude

Single-player Civilization-inspired card game prototype. Godot 4.7, GDScript.
Design and roadmap: [PLAN.md](PLAN.md). Development process: [docs/development-process.md](docs/development-process.md).

## Commands
- Run all tests: `scripts/test.sh` (exit 0 = green). Filter: `scripts/test.sh <substring of file::method>`
- Run the game: `godot --path .`
- A Stop hook runs the suite when you finish a turn and sends failures back to you.

## Architecture rules
- `engine/` is plain GDScript (`RefCounted`, no scene nodes, no UI). All game rules live here.
- `ui/` only displays state and calls engine actions; it holds no rules. If a UI change needs
  logic (a calculation, a legality check, a derived value), put that logic in the engine under TDD
  and have the UI call it.
- UI text never names content (card names, counts); ask the engine.
- Content lives in `data/*.json`; the loader validates it. Card text is generated from effects.
- Card types and the built-in resources are constants (`CardDef.TERRITORY`, `GameEngine.FOOD`, …); never write
  their strings in `engine/` or `ui/`. A field only some card types use goes in `DataLoader.TYPE_FIELDS`.
- Actions come with an error query: `foo()` has `foo_error()` returning "" when legal, else the reason
  (`play_card` pairs with `play_error`). The action refuses whenever the query is non-empty, and the UI
  calls the query instead of re-deriving the condition.
- New effect op: follow the `add-effect` skill. Only ops whose `upkeep_ok()` is true may trigger on `upkeep`: ops that
  change nothing but resources, bonus score and pop. Nobody can choose or target during upkeep, and
  `upkeep_forecast` reports only resources and `starve`.

## How work flows
Every feature or bug is a backlog item in `docs/backlog/` (see its README).
1. **Spec**: `spec` skill. Turns a request into an item with testable acceptance criteria.
2. **Build**: `tdd` skill. Branch → failing tests → **red checkpoint (stop for the user's review)**
   → minimal code → refactor → verify → close the item.

If the user asks for a behavior change with no backlog item, create one with the `spec` skill first
(a small one is fine) unless they say to skip it. Trivial non-behavioral edits (typos, comments,
docs, renames with no behavior change) need no item and no new test.

Balance is a separate, later step. A feature, bug or content item doesn't run the `balance` skill or the sim, and
doesn't tune numbers beyond what its criteria set; note balance worries in the item's Log instead. Balancing happens
in a dedicated balance item, or when the user asks.

## TDD rules (non-negotiable)
- No new or changed behavior in `engine/`, `autoload/`, or the loader without a test that failed first.
- Confirm each new test fails **for the right reason** (assertion mismatch or missing method, not a
  typo or parse error in the test) before writing production code.
- Stop at the red checkpoint and wait for approval. Before stopping, write the item id to
  `.claude/tdd-red` so the Stop hook doesn't block the expected failures. Delete it once approved.
- Write the minimum code to go green, then refactor with the suite green. Never finish a turn with
  a red suite outside the red checkpoint.
- Do not weaken, delete, or rewrite an approved test to make it pass. If a test looks wrong, stop
  and say why.
- Bugs: first write a test that reproduces the bug (use a fixed seed), and see it fail.
- Every test must assert something; runtime errors inside a test count as failures.
- Red-phase tip: when a test calls an engine method that doesn't exist yet, hold the engine in a
  variable typed `Object` (not `GameEngine`) so the file still parses and fails on the missing method.
- Type engines `Object` only in the red phase; retype them as `GameEngine` once green.

## Test conventions
- Files: `tests/test_<area>.gd`, extending `"res://tests/lib/test_case.gd"`. Helpers and
  fixtures (`make_engine`, `TEST_CARDS`, `eq`, `check`, `has_msg`, …) live there.
- Name tests after the behavior: `test_<what_happens>`; for bugs `test_bug_<id>_<what>`.
- Rules tests use `TEST_CARDS` + `make_engine`, never `data/cards.json` (balance edits must not break them).
- Content tests (`tests/test_content.gd`) assert invariants of the real data, never exact numbers from `data/`.
  A test in `test_content.gd` that names a card id is a smell: assert the invariant and put per-card facts under
  the item's Manual check.
- Before writing a helper, check `tests/lib/test_case.gd` and `tests/lib/tech_case.gd`. Tests never call
  engine members that start with `_`.
- Assert on state and return values (zones, resources, score, signals), not on log text,
  unless the log text is the behavior.
- Details: [docs/testing.md](docs/testing.md).

## Git
- One branch per item: `feat/<id>-<slug>` or `fix/<id>-<slug>`, from `main`.
- You may create the item branch and commit on it without asking: once at the red checkpoint
  (the failing tests), then at each green point (suite green). Messages: `<id>: <summary>` plus the attribution trailer.
- Ask before merging to `main`, pushing, rebasing, amending, or deleting branches.

## Style
- Match the surrounding GDScript: tabs, static types, `##` doc comments on classes and public
  functions, two blank lines between functions, and error messages that name file, card, and field.
- Scripts in `engine/` and `ui/` stay within 700 lines (the suite fails past it and prints `WARN` past 500).
  When a file crosses 700, spec an item that splits it along a real boundary; don't trim lines to fit.
