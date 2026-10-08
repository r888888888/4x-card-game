# 4X Card Game — instructions for Claude

Single-player Civilization-inspired card game prototype. Godot 4.7, GDScript.
Design and roadmap: [PLAN.md](PLAN.md). Development process: [docs/development-process.md](docs/development-process.md).

## Commands
- Run all tests: `scripts/test.sh` (exit 0 = green; ~11 s, parallel shards, `TEST_JOBS=1` for serial). Filter:
  `scripts/test.sh <substring of file::method>`
- Balance suite: `scripts/test.sh --balance` runs only `tests/balance/` (real-data bot games; not in the main suite
  or the Stop hook). It is manual, like every balance run (below): the user runs it, or asks you to.
- Balance runs (manual, below) come in levels: `scripts/sim.sh --level 1` is one game (seed 1, generic strategy, the
  starting civ), 2 every strategy, 3 every civ too, 4 ten seeds of all of it; add `--compare <checkout>` to pair with main.
- Run the game: `godot --path .` (testing: `godot --path . -- --civ sumer --turns 20 --seed 5`)
- A Stop hook runs the suite when you finish a turn and sends failures back to you.
- Card art: the `card-art` skill takes `docs/design/card-art.md` to reviewed pictures with `scripts/card_art.py`
  (`status` is free; `generate` and `fix` cost API calls, so the skill asks first).
- In a Claude Code cloud session: [docs/cloud.md](docs/cloud.md) (`scripts/cloud-setup.sh` installs Godot).

## Architecture rules
- `engine/` is plain GDScript (`RefCounted`, no scene nodes, no UI). All game rules live here.
- `ui/` only displays state and calls engine actions; it holds no rules. If a UI change needs
  logic (a calculation, a legality check, a derived value), put that logic in the engine under TDD
  and have the UI call it.
- UI text never names content (card names, counts); ask the engine.
- Content lives in `data/*.json`; the loader validates it. Card text is generated from effects.
- State that lasts between actions lives in `GameState` or `CardInstance`, never on the engine or a module, and `copy()`
  copies it (the suite checks).
- Card types and the built-in resources are constants (`CardDef.TERRITORY`, `GameEngine.FOOD`, …); never write
  their strings in `engine/` or `ui/`. A field only some card types use goes in `DataLoader.TYPE_FIELDS`
  (new card field: follow the `add-card-field` skill).
- Actions come with an error query: `foo()` has `foo_error()` returning "" when legal, else the reason
  (`play_card` pairs with `play_error`). The action refuses whenever the query is non-empty, and the UI
  calls the query instead of re-deriving the condition.
- An area (394) is a rules module held on the engine as an object (`engine.military`): its actions (with their `_error`
  twins) and queries are called on the area, and a new one goes on the area, never as a forward on `GameEngine` (the
  suite checks). Bots list an area's action as `"military.move"` and call any entry with `LegalActions.apply`.
- A decision the player owes is one `PENDING_*` kind in `pending()`; every action's `*_error` starts with
  `_blocked_error`. New decision kind: follow the `add-decision` skill.
- New effect op: follow the `add-effect` skill. Only ops whose `upkeep_ok()` is true may trigger on `upkeep`: ops that
  change nothing but resources, bonus score and pop. Nobody can choose or target during upkeep, and
  `upkeep_forecast` reports only resources and `starve`.

## UI design
- Design tokens, which file holds each, and the style guide's names for the code's: [docs/design/tokens.md](docs/design/tokens.md).
  Read the full guide (`docs/design/mcm-style-guide.md`) only for its section on your task's topic.
- Flavor text and quotes follow the guide's §18 (voice, length, endings; choosing a quote: §18.5); read it before writing any.
- Buttons are generally not full width: a `Button` sizes to its text plus padding and doesn't stretch across its
  panel or column. The exception is a stacked column of buttons in a menu or a screen (the menu, the title screen):
  they share one width, the widest button's, with the column centred in its panel (`UIKit.button()` doesn't
  stretch; build such a column with `UIKit.button_column`). Buttons that are really list
  rows or content tiles (the government overlay's cards, the Knowledge screen's techs) may fill.
- Spacing, margins, corner radii and text sizes are `Tokens` steps (`ui/tokens.gd`, the guide's scales), never numbers
  (the suite checks); a repeated text look is a `GameTheme` variation (`Body`, `Caption`, `RichBody`, …).
- Colours live in `ui/palette.gd` (`Palette`), named for what they're for; no other `ui/` script writes a colour
  literal, BBCode included: rich text colours with `Palette.bbcode` (the suite checks). A look the UI repeats is a
  theme type variation set with `theme_type_variation`, not per-control overrides: the label type scale (`Heading`,
  `Title`, `Stat`, …) in `ui/game_theme.gd` (`GameTheme`), every other look in its section file in `ui/theme/` (a new
  look: a new section, listed in `GameTheme.SECTIONS`; the suite checks).
- Focus a control from code with `FocusRing.focus(control)`, never `grab_focus()` (the suite checks): its ring stays
  hidden until the player presses Tab, and a click hides it again (230).
- A modal extends `Modal` and opens on `main.modals` (`ModalStack`), over any modal already open; only the top one
  takes keys and clicks, and Esc, Close or a click outside its panel closes just that one. Don't write a modal's own
  scrim, key handling or z-order.
- A screen you navigate to goes on an animated `Navigator` with a title, and carries a `ScreenHeader`: a breadcrumb
  naming where you are, whose parent title is the link back (118). It enters and leaves with a transition (it wipes out of
  the card it opens and back into it, or fades; only a fade with Reduce motion), and counts as closed as soon as it
  starts leaving.

## How work flows
Every feature or bug is a backlog item in `docs/backlog/` (see its README).
1. **Spec**: `spec` skill. Turns a request into an item with testable acceptance criteria.
2. **Build**: `tdd` skill. Branch → failing tests → **red checkpoint (stop for the user's review)**
   → minimal code → refactor → verify → close the item.

If the user asks for a behavior change with no backlog item, create one with the `spec` skill first
(a small one is fine) unless they say to skip it. Trivial non-behavioral edits (typos, comments,
docs, renames with no behavior change) need no item and no new test.

When a rule change makes a path unreachable, remove its code and tests in the same item, or name the item that will.

**Spikes** are the exception to all of the above: when the user asks for a spike (exploration, a
prototype, "try X"), work on a `spike/<topic>` branch from `main` with no item, no spec and no tests;
the TDD rules below don't apply there. End with a summary of what was tried and learned, plus a
recommendation (in the item's Design notes if the spike came from an item). Spikes stay unmerged by
default; real work is rebuilt test-first on an item branch. Merge a spike only when the user asks,
the suite is green, and it changes nothing in `engine/`, `autoload/` or the loader. Details:
[docs/development-process.md](docs/development-process.md#spikes).

Balance is a separate, later step, and balance runs are manual: the bot games take too long to run per change. Never
start `scripts/sim.sh`, `scripts/test.sh --balance` or the `balance` skill unless the user asks for that run in the
chat. That holds for every item, including one that changes `sim/`, a refactor and a balance item. Where a run would
tell something, put the command in the item's Manual check for the user, and note balance worries in its Log. A
feature, bug or content item doesn't tune numbers beyond what its criteria set; balancing happens in a dedicated
balance item, or when the user asks.

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
- Red-phase scaffolding (engines typed `Object`, untyped `load()`s, `has_method` and `== null` guards) is
  removed in the refactor step (the suite checks).

## Test conventions
- Files: `tests/test_<area>.gd`, extending `"res://tests/lib/test_case.gd"`. Helpers and
  fixtures (`make_engine`, `TEST_CARDS`, `eq`, `check`, `has_msg`, …) live there.
- Name tests after the behavior: `test_<what_happens>`; for bugs `test_bug_<id>_<what>`.
- The runner runs every method named `test_*` as a test, so a helper never starts with `test_` (`fixture_card`,
  not `test_card`): one that takes arguments hangs the whole suite.
- Rules tests use `TEST_CARDS` + `make_engine`, never `data/cards.json` (balance edits must not break them).
- A test that plays sim bot (GenericBot) games on the real data goes in `tests/balance/`, never the main suite; bot rules are
  tested on fixture games of a few turns.
- Content tests (`tests/test_content.gd`) assert invariants of the real data, never exact numbers from `data/`.
  A test in `test_content.gd` that names a card id is a smell: assert the invariant and put per-card facts under
  the item's Manual check.
- Before writing a helper, check `tests/lib/test_case.gd` and `tests/lib/tech_case.gd`. Tests never call
  engine members that start with `_`.
- A helper a second test file needs moves to `tests/lib/` (the suite checks copies of shared helpers).
- Assert on state and return values (zones, resources, score, signals), not on log text,
  unless the log text is the behavior.
- Details: [docs/testing.md](docs/testing.md).

## Git
- One branch per item: `feat/<id>-<slug>` or `fix/<id>-<slug>`, from `main`. Spikes: `spike/<topic>`;
  commit on them freely (messages `spike: <summary>`).
- You may create the item branch and commit on it without asking: once at the red checkpoint
  (the failing tests), then at each green point (suite green). Messages: `<id>: <summary>` plus the attribution trailer.
- Ask before merging to `main`, pushing, rebasing, amending, or deleting branches.
- After every merge to `main`, clean up without asking: remove the merged branch and its worktree, plus any other
  branch already merged into `main` (`git branch --merged main`) and its worktree (`git worktree remove`, then
  `git worktree prune`). Leave unmerged branches, and any worktree with uncommitted changes: other sessions own them.
- Other sessions work in this checkout: build items in a worktree.

## Style
- Match the surrounding GDScript: tabs, static types, `##` doc comments on classes and public
  functions, two blank lines between functions, and error messages that name file, card, and field.
- Scripts in `engine/` and `ui/` stay within 700 lines (the suite fails past it and prints `WARN` past 500).
  When a file crosses 700, spec an item that splits it along a real boundary; don't trim lines to fit.
