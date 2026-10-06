# Design tokens: the guide's names in the code

The short reference for UI work. The full style guide ([mcm-style-guide.md](mcm-style-guide.md), ~34k tokens) is
the source of the values and the reasons; read it only for a task about one of its topics (motion §9, interaction
§10, a game screen §11, accessibility §12, sound §16), and only that section. Its §17 is the spike's plan from before
the restyle (177–183) and is history, not the current state.

This file says what is in the code **now**. When an item changes a token, it updates this file.
The live picture of the same is [mcm-specimen.html](mcm-specimen.html), the master of the design pages
([index.html](index.html) lists them all); an item that changes how the game looks, moves or sounds updates it too.

## Where things live

| What | Where | Rule |
|---|---|---|
| Spacing, radius | `ui/tokens.gd` (`Tokens`) | `SPACE_0`…`SPACE_9`, `RADIUS_0/1/2`, `RADIUS_FULL`, named as the guide's tokens. No numeric literal for a separation, margin or radius in `ui/` (suite checks, 193). |
| Colours | `ui/palette.gd` (`Palette`) | Named for their use. Read when drawing; never copy into a `const` (suite checks). No colour literal elsewhere in `ui/` (suite checks). |
| Day / Night | `Palette.NIGHT`, `Palette.DAY`, `Palette.use()` | A new colour needs its static var and an entry in both sets (suite checks, 192). |
| Looks (fonts, sizes, boxes) | `ui/game_theme.gd` (`GameTheme`) | A look used twice is a theme type variation, set with `theme_type_variation`. |
| Building blocks | `ui/ui_kit.gd` (`UIKit`) | `button`, `button_column`, `select_list` (217: a `SelectList`, the guide's §7.16), `heading`, `title`, `stat`, `section`, `overlay`, `setting_row`, `painted`. |
| Surfaces (341) | `ui/surfaces.gd` (`Surfaces`), `ui/surface_box.gd` (`SurfaceBox`) | Walnut grain and paper under the Palette colours, baked once per mode; a `SurfaceBox` draws its `frame` (rule, soft shadow and a fill the paper covers: without it Godot leaves a pale gap between the rule and the shadow), then the texture inside the rule. Opacities and shadow looks are `Surfaces` constants. Keys stay `StyleBoxFlat`. |
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
| `board` | `BACKGROUND` (laid at 90 % Night / 88 % Day over walnut grain: the board and the Rail, `Surfaces.BOARD`), `FRONTIER_BG` |
| `sheet` | `RAISED` (over walnut grain at the same opacity: the Strip, `Surfaces.STRIP`), `TILE` |
| paper (341) | cards, Sheets and DarkPanels: `Surfaces.PAPER`, dark gray paper under `PAPER_SHADE` (black at 30 %) in Night, white paper in Day; a dimmed card's under `DIM_BG` at 60 % (`Surfaces.DIMMED_PAPER`) |
| `well` | `FIELD` (also a selectable list's `ListWell`), `PANEL`, `CONTROL_DISABLED`, `STRIP_BG` |
| `steel` | `CONTROL` |
| `ink` | `TEXT`, `EDGE`, `STRIP_TEXT` |
| `ink-2` | `TEXT_DIM`, `PILES` |
| `ink-3` | `TEXT_DISABLED` |
| `rule` | `CONTROL_BORDER` |
| `rule-fine` | `HAIRLINE` (a fine rule within a sheet, 217); `CONTROL_DISABLED_BORDER` (Day only; Night uses its own `4a463f`) |
| `shadow` | `SHADOW` |
| `signal` / `on-signal` | `ACCENT` (End turn, a selectable list's index tab, and a modal's primary button: `AccentButton`, 3 px ink border, 251) / `TEXT_ON_ACCENT` |
| `positive` | `GAIN` |
| `danger` | `COST`, `WARN`, `UNREST` |
| `info` | `INSIGHT` |
| `focus` | `FOCUS`; in Day also `POP` |
| `caution` (Night) / `glyph-ochre` (Day) | `WEALTH` |
| `plane.*` (card types) | `ACTION` blue, `BUILDING` olive, `CITY` ochre, `TERRITORY` sage, `TECH` teal, `EVENT` brick; `CIVILIZATION` plum and `GOVERNMENT` indigo (231: no guide hue, chosen apart from the six planes), `UNIT` bronze (160, likewise); `RESEARCHED_FILL` (a researched tech tile, 222) teal; `TECH_LINK` (278) the gold border of the tiles linked to the hovered tech |
| `on-plane` | `TEXT_ON_PLANE` (text on a researched tile) |
| no guide token | `LOG_TEXT`, `DIM_*`, `FRONTIER_HATCH`, see-through layers (`DIMMER`, the era vellum (`RAISED` at 88%, `EraVellum`), `SCRIM`, `OUTLINE`, `FAINT_EDGE`, `GHOST_*`, `DROP_BG`, `HINT_BG`) |

## Type (§5.2)

Every size is a `Tokens.TYPE_*` step (no literal size in `ui/`, suite checks, 194). A repeated look is a theme
variation; set it with `theme_type_variation`.

| Guide token | Size | In the code |
|---|---|---|
| `type.display` | 40 | `Display` (Jost): the start screen's title, game over |
| `type.title` | 28 | `Title` (Jost), `UIKit.title()`; the header's `Link` |
| `type.heading` | 15 | `Heading` (SemiCondensed SemiBold, tracked), `UIKit.heading()` sets capitals; text stays as written |
| `type.body` | 20 | theme default, `Body`, `RichBody` (modal text, the log), `BarStat`, `CardTitle` (card names, semibold: 198), card rules |
| `type.body-s` | 17 | `BodySmall`; card subtitles, keywords, the reason strip |
| `type.label-caps` / `caption` | 14 | `Caption`, `StateWord`; the card badge, a toggle's ON/OFF word |
| `type.numeral` / `numeral-s` | 26 / 17 | `Stat`; small card figures (VP on a frontier card) |
| `display-xl`, `numeral-xl` | 56, 44 | tokens only; nothing uses them yet |

## Spacing, radius, borders, shadows (§6)

| Guide | Scale | In the code now |
|---|---|---|
| `space.*` | 0, 4, 8, 12, 16, 24, 32, 48, 64, 96 | `Tokens.SPACE_0`…`SPACE_9`; `UIKit.SECTION_GAP` 24, `CARD_GAP` 12, `HEADING_GAP` 8 name roles. The one exception is the guide's own: `Tokens.GLYPH_GAP` 3 (§6.7, a cost's glyph and figure). |
| `radius.*` | 0 (panels, cards, tooltips), 2 (buttons, fields), 4 (badges), full (pips, lamps) | `Tokens.RADIUS_0` (panels, cards, zones, hints, pop-ups, slot outlines), `RADIUS_1` (buttons, fields), `RADIUS_2` (the card badge), `RADIUS_FULL` (pips). |
| `border.*` | 1 hair, 2 control, 3 emphasis, 4 bar | Literals. |
| `shadow.plinth` / `travel.press` | 2,2 / 2 | `GameTheme.PLINTH` / `GameTheme.PRESS`: keys, flags, End turn (hard, unblurred) |
| soft shadows (341) | `SHADOW`, straight down, blurred: card at rest 0,4 size 8; hovered 0,8 / 16; dragged 0,14 / 24; sheet 0,16 / 32 | `Surfaces.CARD_REST`, `CARD_HOVER`, `CARD_DRAG`, `SHEET` (each with its Night / Day alpha: 0.35 / 0.20, 0.45 / 0.28, 0.50 / 0.32, 0.55 / 0.35) |
| selected (§4.4, §10.5) | 4,4 shadow, 8 px pull | `GameTheme.SELECTED_SHADOW` / `GameTheme.PULL`: `ListRow`'s pressed look |

## Motion (§9.4)

`Anim` names its constants by what moves, not by the guide's duration tokens. Nearest equivalents: `SCREEN_TIME`
0.22 s (guide `screen` 320 ms), `ODOMETER_STEP` 0.07 (`tick` 60),
`CALM_FADE_TIME` 0.15 (`quick` 120), `DEAL_STAGGER` 0.06 (`stagger.tick`).
