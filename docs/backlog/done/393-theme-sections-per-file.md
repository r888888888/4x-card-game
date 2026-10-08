---
id: 393
title: Split GameTheme into one file per component's looks
type: chore
status: done
branch: feat/393-theme-sections
---

## Goal
`ui/game_theme.gd` is 575 lines (past the 500 warning) and grows with every new look: 57 commits since 2026-09-01,
almost all additions (+944 / −185). It's already built of per-component sections (`_flags`, `_tech_tiles`,
`_end_turn_key`, `_select_list`, `_identity_cards`, `_upgrades`, …) on top of shared style builders (`_box`, `_rim`,
`_pressed`, `_flat`, the fonts). Give each section its own file so a new look is a new file, and `game_theme.gd` keeps
only the base theme, the shared builders and the list of sections.

## Acceptance criteria
- [x] AC1: Given the files in `ui/theme/`, when the suite runs, then a test fails naming any section file that
  `GameTheme.SECTIONS` doesn't list, and any listed one that doesn't exist. So a new section file can't be silently
  left out of the theme.
- [x] AC2: Given each section applied on its own to an empty `Theme`, when the suite runs, then a test fails naming
  any type variation that two sections both define, and any section that defines none. Each look has one owner.
- [x] AC3: `GameTheme.build()` returns the same theme as before the split: every type, and every stylebox, colour,
  constant, font and font size on it, compares equal to the pre-split build. (Checked once during the item by a
  scratch dump of `main`'s build against the branch's, recorded in the Log; the suite's existing look tests
  (`test_theme`, `test_surfaces`, `test_palette_roles`, …) pass unchanged.)
- [x] AC4: `ui/game_theme.gd` is under 250 lines, and every file in `ui/theme/` is under 200.
- [x] AC5: The public API callers use stays on `GameTheme` with the same signatures: `build()`, `rail()`,
  `dark_panel()`, `sheet()`, `focus_ring()`, `tabular()`, `heading_font()`, `verdict_font()`, `display()`, and the font
  and size constants. No file outside `ui/game_theme.gd` and `ui/theme/` changes, apart from tests and docs.

## Out of scope
- Changing any look, colour or token.
- The label variations set in `build()` with `_label(...)` (Display, Title, Heading, Body, …): they're one line each
  and are the base type scale. They stay in `game_theme.gd` unless AC4 needs them out, in which case they go together
  into one `ui/theme/labels.gd`.

## Design notes
- A section is `ui/theme/<name>.gd`: `extends RefCounted` with `static func apply(t: Theme) -> void` and a `##` header
  naming the looks it adds and their backlog ids (the doc comments on today's `_flags` etc. move with them).
  `GameTheme.SECTIONS: Array[Script]` lists them in today's call order. `build()` sets the base, then calls
  `apply(t)` on each.
- Sections call the shared builders as `GameTheme._box(...)` today; make the ones a section needs public (`box`,
  `rim`, `pressed`, `flat`), since the files no longer share a script. AC5 still holds because these are additions.
- Likely files: `flags`, `tooltips`, `identity_cards`, `upgrades`, `tech_tiles`, `icon_button`, `link`,
  `divider_tab`, `select_list` (with `_scroll_bar`), `board_frame`, `price_tag`, `big_buttons`, `end_turn_key`,
  `controls` (with `_slider`). Group two tiny ones if a file would be a few lines.
- `class_name` per section is optional. A const preload list in `SECTIONS` avoids adding global names.
- Update `docs/design/tokens.md` (it says which file holds each token) and CLAUDE.md's UI design line ("a theme type
  variation in `ui/game_theme.gd`") to point new looks at a section file in `ui/theme/`.
- `tests/test_script_size.gd` already counts subfolders of `ui/`, so the new files are covered.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_theme::test_every_section_file_is_listed_and_every_listed_one_exists` |
| AC2 | `test_theme::test_each_look_has_one_section` |
| AC3 | a scratch dump of every type and item of `GameTheme.build()` in Night and Day (783 lines, 150 type entries), before and after, diffed; plus the existing look tests unchanged |
| AC4 | line counts, checked by hand |
| AC5 | the existing callers compile and pass unchanged |

## Log
- 2026-10-07: specced from the review of the scripts that keep hitting the size limit (after 391).
- 2026-10-07: green. 14 sections in `ui/theme/` (controls 88 lines, the rest 7–54); `game_theme.gd` 578 → 150 lines,
  keeping the label scale, RichBody, DarkPanel and Sheet in `build()` (AC4 didn't need them out). AC3: a scratch dump
  of every type, variation base and item (styleboxes property by property, fonts with their features and spacing) of
  `GameTheme.build()` in Night and Day, before and after: 783 lines each, identical. Decisions: the builders only
  `controls` uses (`_box`, `_rim`, `_pressed`, `_flat`, `_slider`) moved into `controls.gd` as its own, and
  `_scroll_bar` into `select_list.gd`, so they have one owner; `_label` and `_card`, which several sections use, are
  public on `GameTheme` (`label`, `card`). `_link` no longer calls `_divider_tab`: `divider_tab` is its own section,
  listed right after `link`. `focus_ring`'s doc line had drifted above `_big_buttons`' and went back. Sections are
  const preloads (no `class_name`). `icon_button.gd` is 7 lines; left alone rather than grouped with an unrelated look.
