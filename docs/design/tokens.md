# Design tokens: the guide's names in the code

The short reference for UI work. The full style guide ([mcm-style-guide.md](mcm-style-guide.md), ~34k tokens) is
the source of the values and the reasons; read it only for a task about one of its topics (motion §9, interaction
§10, a game screen §11, accessibility §12, sound §16), and only that section. Its §17 is the spike's plan from before
the restyle (177–183) and is history, not the current state.

This file says what is in the code **now**. When an item changes a token, it updates this file.

## Where things live

| What | Where | Rule |
|---|---|---|
| Colours | `ui/palette.gd` (`Palette`) | Named for their use. Read when drawing; never copy into a `const` (suite checks). No colour literal elsewhere in `ui/` (suite checks). |
| Day / Night | `Palette.NIGHT`, `Palette.DAY`, `Palette.use()` | A new colour needs its static var and an entry in both sets (suite checks, 192). |
| Looks (fonts, sizes, boxes) | `ui/game_theme.gd` (`GameTheme`) | A look used twice is a theme type variation, set with `theme_type_variation`. |
| Building blocks | `ui/ui_kit.gd` (`UIKit`) | `button`, `button_column`, `heading`, `title`, `stat`, `section`, `overlay`, `setting_row`, `painted`. |
| Motion | `ui/anim.gd` (`Anim`) | Times in seconds, distances in px. Tweens ease out (`TRANS_QUART`/`EASE_OUT`); none overshoot (suite checks). Reduce motion: `UIKit.calm()`. |
| Modals, screens | `Modal` on `main.modals`, `Navigator` + `ScreenHeader` | See CLAUDE.md's UI design section. |

## Colour: which kind of colour you are setting

A colour must follow a Day mode switch. How depends on where it is set:
1. **From the theme** (a variation, a `Button`): follows by itself.
2. **Set in code each refresh** (a refresh reads `Palette.X`): follows by itself.
3. **Set in code once, at build time**: wrap it in `UIKit.painted(node, func(): …)`, or pass a role name
   (`UIKit.stat(parent, &"GAIN")`, `UIKit.overlay(parent, &"WARN")`), never a `Color` read at build time.
   `UIKit.stat` takes only a role name, and every all-caps `&"ROLE"` in `ui/` must be a Palette role (suite checks, 192).

## Colour roles: Palette name → guide token (§4)

| Guide token | Palette names |
|---|---|
| `board` | `BACKGROUND`, `FRONTIER_BG` |
| `sheet` | `RAISED`, `TILE` |
| `well` | `FIELD`, `PANEL`, `CONTROL_DISABLED`, `STRIP_BG` |
| `steel` | `CONTROL` |
| `ink` | `TEXT`, `EDGE`, `STRIP_TEXT`, `AVAILABLE` |
| `ink-2` | `TEXT_DIM`, `PILES` |
| `ink-3` | `TEXT_DISABLED`, `FUTURE` |
| `rule` | `CONTROL_BORDER`, `LOCKED` |
| `rule-fine` | `CONTROL_DISABLED_BORDER` (Day only; Night uses its own `4a463f`) |
| `shadow` | `SHADOW` |
| `signal` / `on-signal` | `ACCENT` (End turn only) / `TEXT_ON_ACCENT` |
| `positive` | `GAIN` |
| `danger` | `COST`, `WARN`, `UNREST` |
| `info` | `INSIGHT` |
| `focus` | `FOCUS`; in Day also `POP`, `RESEARCHED` |
| `caution` (Night) / `glyph-ochre` (Day) | `WEALTH` |
| `plane.*` (card types) | `ACTION` blue, `BUILDING` olive, `CITY` ochre, `TERRITORY` sage, `TECH` teal, `EVENT` brick |
| no guide token | `LOG_TEXT`, `DIM_*`, `FRONTIER_HATCH`, see-through layers (`DIMMER`, `SCRIM`, `OUTLINE`, `FAINT_EDGE`, `GHOST_*`, `DROP_BG`, `HINT_BG`) |

## Type (§5.2)

| Guide token | Size | In the code now |
|---|---|---|
| `type.display` | 40 | start screen title (literal 40) |
| `type.title` | 28 | `Title` and `Link` variations: **26** |
| `type.heading` | 15, caps, +10% | `Heading` variation: **19**, mixed case |
| `type.body` | 20 | theme default (`GameTheme.DEFAULT_FONT_SIZE`), `BarStat` |
| `type.numeral` | 26 | `Stat` variation |
| others | 56, 17, 14, 44 | not used by name; literals 15–22 on card faces, 19 for modal and log bodies |

Several sizes are off the guide's scale today; item 194 snaps them and adds the variations.

## Spacing, radius, borders, shadows (§6)

| Guide | Scale | In the code now |
|---|---|---|
| `space.*` | 0, 4, 8, 12, 16, 24, 32, 48, 64, 96 | Literals; `UIKit.SECTION_GAP` 22, `CARD_GAP` 10, `HEADING_GAP` 6 (off scale). Item 193 tokenizes and snaps them. |
| `radius.*` | 0 (panels, cards, tooltips), 2 (buttons, fields), 4 (badges), full (pips, lamps) | Panels 0, buttons 2, badge 4, pips full; drop zone 10, hint 6, error pop-up 6, slot outline 8 (off scale, 193). |
| `border.*` | 1 hair, 2 control, 3 emphasis, 4 bar | Literals. |
| `shadow.plinth` / `travel.press` | 2,2 / 2 | `GameTheme.PLINTH` / `GameTheme.PRESS` |

## Motion (§9.4)

`Anim` names its constants by what moves, not by the guide's duration tokens. Nearest equivalents: `SCREEN_TIME`
0.22 s (guide `screen` 320 ms), `ODOMETER_STEP` 0.07 (`tick` 60), `TAG_HOLD` 0.6 (`feedback` 600),
`CALM_FADE_TIME` 0.15 (`quick` 120), `DEAL_STAGGER` / `TAG_STAGGER` 0.06 (`stagger.tick`).
