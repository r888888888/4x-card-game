# Mid-Century Modern Style Guide — "The Civic Planning Desk"

Spike `spike/mcm-style-guide`. A visual and interaction design system for the 4X card game, written so a UI
designer or a Godot developer can build it without reinterpreting adjectives. A live specimen of the tokens and the
core components (with motion and a Reduce motion switch) is in [mcm-specimen.html](mcm-specimen.html); open it in a
browser.

Where the game already has a concept (Palette, GameTheme, Anim, Navigator, Modal, Toasts, the top bar), the guide
names it, and §16 maps every token onto the existing code.

---

## 1. Design philosophy

**The premise.** The player sits at a planning desk built in 1962 for running a civilization. Whoever made it had
worked for Braun, Herman Miller and a national rail authority; the control room down the hall was built by the
same team. Everything is printed, machined, or lit. Nothing glows, floats or melts.

Five tenets, in order of precedence when they conflict:

1. **Legibility first.** A number the player needs this turn is readable at arm's length in under a second. Style
   never costs legibility.
2. **Things are made of something.** Every surface is paper, enamelled steel, or a lamp. Paper holds information,
   steel holds controls, lamps signal state. A surface never mixes roles.
3. **Motion is mechanism.** Anything that moves does so the way a mechanism would: it accelerates quickly, travels
   a short, fixed distance, and stops firmly against a detent. Nothing wobbles, bounces or drifts.
4. **One loud thing.** At rest, at most one element on screen uses the signal colour (usually End turn). Emphasis is
   a budget.
5. **Restraint is the period.** Mid-century design is defined by what it left out. When in doubt, remove the
   ornament, keep the grid.

**What it is not.** Not "retro": no CRT scanlines, chrome, boomerang wallpaper, diner turquoise, or fake wear. A
player who never saw 1960 should read it as simply *well designed*, with a warm, analogue character.

---

## 2. Visual principles

| Principle | Rule | Implementation test |
|---|---|---|
| Flat planes | Surfaces are solid colour. No gradients except the single permitted "lamp" radial (§7.11). | Sample any panel: one colour, edge to edge. |
| Hard edges, hard shadows | Shadows are solid, offset, unblurred: a printed plinth, not a hover glow. | `shadow_size = 0`, offset > 0. |
| Thin rules | Structure is drawn with 1 px rules and 4 px bars, not boxes inside boxes. | No panel nests more than one bordered container. |
| Asymmetry | Layouts are anchored left (or to a strong column), never centred by default. Centring is for single-message moments (a modal title, the victory sheet). | The main HUD has no centred element except the turn plate. |
| Geometric vocabulary | Circle = indicator or state (lamp, pip, dial). Rectangle = container or control. Line = relation or division. Triangle = direction or warning. | A circle never holds a paragraph; a rectangle never signals on/off by itself. |
| Generous negative space | Density comes from type scale and alignment, not from reduced padding. Panels breathe; tables are tight. | Panel padding never below `space.4` (16). |
| Information as print | Labels look set in type: small caps tracking, column alignment, tabular figures. | Every number column is right-aligned on tabular figures. |
| Period motif, sparingly | Starburst, radial lines, concentric rings, a split circle. One motif per screen, only at moments that earn it. | Count motifs on a screen: ≤ 1 at rest. |

---

## 3. Mood and references

Look at these for *principles*, not for things to copy:

- **Industrial products.** Dieter Rams' Braun (SK 4, T3, ET 66 calculator): one orange or green key among greys, the
  grille of identical holes, the label set small and lowercase beside the control. Lesson: colour marks function.
- **Furniture and interiors.** Eames Storage Unit (ESU): coloured flat panels in a black steel frame; Nelson's Action
  Office; George Nelson's Marshmallow sofa. Lesson: a frame of thin dark lines holding flat planes of muted colour.
- **Information design.** Otl Aicher's 1972 pictograms (late but the reference for systematic icons), Massimo
  Vignelli's NYC subway diagram and Unimark manuals, Jock Kinneir & Margaret Calvert's British road signs, the
  Swiss posters of Josef Müller-Brockmann. Lesson: a strict grid and one or two weights carry everything.
- **Corporate identity.** IBM (Paul Rand), Herman Miller (Irving Harper), Olivetti (Giovanni Pintori), Lufthansa
  (Otl Aicher). Lesson: a short palette applied with discipline across every touchpoint.
- **Control rooms and instruments.** NASA Mission Control (1965), Saul Bass's title cards for the timing of graphic
  reveals, Solari split-flap boards, Veeder-Root tally counters, Smiths and Jaeger dashboard gauges. Lesson:
  state is shown by discrete, legible mechanisms.
- **Architecture.** Blueprints and diazo prints, title blocks on drawings, Case Study Houses, sliding shoji and
  room dividers. Lesson: layered translucent sheets; panels slide in their own track.

**Mood words, measured:** warm (backgrounds have hue 35–45°, saturation 15–25%), optimistic (accents are saturated
but never neon: chroma capped at ~0.15 in OKLCH), tactile (every control shows press travel), quiet (≤ 1 moving
thing at rest).

---

## 4. Color system

Two modes share one set of token names. **Paper** (a drafting desk by day) is the reference; **Night shift** (the
control room) is the dark mode the game ships by default today. Every value below was checked for WCAG 2.2 contrast
(ratios in §12).

### 4.1 Neutrals

| Token | Role | Paper | Night shift |
|---|---|---|---|
| `color.board` | Behind everything (the desk) | `#EFE8DA` | `#1F1E1C` |
| `color.sheet` | Panels, cards, modals (paper laid on the desk) | `#F8F4EC` | `#2A2825` |
| `color.well` | Recessed areas: fields, tracks, sunken trays | `#E3DACA` | `#171614` |
| `color.steel` | Control faces (secondary buttons, tabs) | `#DCD3C2` | `#3A3733` |
| `color.ink` | Primary text, heavy rules, the frame | `#22211F` | `#EDE6D6` |
| `color.ink-2` | Secondary text, labels, captions | `#57534B` | `#B9B1A1` |
| `color.ink-3` | Disabled text and decoration only (never information) | `#7A7468` | `#8E877A` |
| `color.rule-fine` | Decorative hairlines between rows | `#CFC6B5` | `#3A3733` |
| `color.rule` | Boundaries the player must see (control borders, inputs) | `#6F685C` | `#857D70` |
| `color.shadow` | Hard offset shadows | `#22211F` | `#0D0C0B` |
| `color.scrim` | Behind a modal | ink at 40% | `#000` at 60% |

### 4.2 Primary palette (identity)

Three colours define the brand. Everything else is support.

| Token | Name | Paper | Night | Use |
|---|---|---|---|---|
| `color.signal` | Signal orange | `#A8401B` | `#E0703F` | The one primary action on screen (End turn, Confirm). The selection index tab. Nothing else. |
| `color.on-signal` | Text on signal | `#FBF6EC` | `#1F1E1C` | Label on a signal fill. |
| `color.ink` | Charcoal | (above) | (above) | Frame, type, shadows. |
| `color.sheet` | Warm paper | (above) | (above) | Ground. |

### 4.3 Secondary palette (support hues)

Each hue has a **line** value (text, icons, 1–2 px strokes; passes 4.5:1 on `sheet`) and a **plane** value (flat
fills: card bands, bars, lamps; text on it is always `ink` in Paper, `board` in Night). In Night the line and plane
values are the same: darker planes failed 4.5:1 for text in either direction, so Night planes are light and carry
dark text. Planes are under 3:1 against `sheet` in Paper, so a plane is always framed (next rule), never floated.

| Hue | Line (Paper) | Plane (Paper) | Line (Night) | Plane (Night) |
|---|---|---|---|---|
| Teal | `#1F6A68` | `#5E9C97` | `#5FB0A9` | `#5FB0A9` |
| Ochre | `#7C5810` | `#D9A441` | `#D9A441` | `#D9A441` |
| Olive | `#56602E` | `#A3AA6A` | `#A9B26C` | `#A9B26C` |
| Muted blue | `#35597C` | `#8AA7C4` | `#86A9CC` | `#86A9CC` |
| Brick | `#9B3424` | `#C9705C` | `#E07A63` | `#E07A63` |
| Sage | `#4E6B47` | `#9DB592` | `#93B585` | `#93B585` |

**Never** place two plane colours edge to edge without a 1 px `ink` or 4 px `sheet` gap between them. That gap is the
steel frame of the Eames storage unit, and it is what stops a palette this warm from going muddy.

### 4.4 Semantic colours

| Meaning | Token | Hue | Always paired with |
|---|---|---|---|
| Gain, success, ready, researched | `color.positive` | Sage | ▲ / `+` sign, lamp ON |
| Warning, will happen next upkeep, at risk | `color.caution` | Ochre | ◆ outline glyph, hatched fill |
| Loss, error, blocked, starving, at limit | `color.danger` | Brick | ⊘ / `−` sign, solid bar |
| Information, neutral notice | `color.info` | Muted blue | ⓘ circle glyph |
| Keyboard focus | `color.focus` | Teal | 2 px ring, offset 2 px |
| Selected | `color.signal` + ink | — | hard 4 px shadow + index tab |
| Primary action | `color.signal` | — | the only signal fill on screen |

Focus (teal ring) and selection (shadow + orange tab) never look alike, so a keyboard player can see both at once.

### 4.5 Game colours

Resource and card-type colours reuse the support hues (never new ones), and each also has a glyph, so colour is
never the only cue.

| Game thing | Hue | Glyph (§8) |
|---|---|---|
| Food | Sage (green) | Sprout: a stem on a ground line with two leaves |
| Wealth | Ochre (yellow) | Cash coin: a ring with a square hole |
| Insight | Muted blue | Open book with curved pages |
| Pop | Teal | Figure: a circle over a half-disc |
| Unrest | Brick | Lightning bolt, solid: the one solid resource glyph, because unrest is the one resource that is bad to have |
| Score (VP) | Ink | Eight-point starburst |
| Action card | Muted blue | Diamond ◆ |
| Building card | Olive | Square ■ |
| City card | Ochre | Disc ● |
| Territory card | Sage | Triangle ▲ |
| Tech card | Teal | Four-point star ✦ |
| Event card | Brick | Diamond in square ❖ |

Food is sage, not olive: olive is a yellowish green that sits too close to wealth's yellow in a cost plate. Sage is
also the gain colour, so a `+3` beside the food glyph is green too; the glyph, not the hue, says which resource it is.
In Paper, ochre's line value is a dark mustard (yellow can't reach 4.5:1 on warm paper), so the **wealth glyph** uses
a brighter gold, `glyph-ochre` `#A07514` (3.8:1 on `sheet`, past the 3:1 icons need). It is for icons only, never
for text.

These are the shapes the game's glyphs already use (`Icons.GLYPHS`); the guide keeps them and redraws them (§8).

### 4.6 Colour rules

1. A screen at rest uses neutrals + at most **two** support hues + signal (once). Resource colours inside the
   resource bar don't count against this; they're a key, not decoration.
2. Large areas are neutral. Support hues appear as planes no larger than a card band, a bar, or a tab.
3. No transparency for colour mixing. Translucency is reserved for one thing: the drafting **vellum overlay**
   (§11.8), `sheet` at 88%.
4. Hover never changes hue. It changes value by one step (§7.1) or adds a rule.
5. Disabled is `ink-3` on `well` with a dashed or absent border, never just "lower opacity".

---

## 5. Typography

### 5.1 What to look for

The guide specifies characteristics, then names open-licence faces that meet them so the prototype can ship today.

| Role | Characteristics | Open-licence candidates |
|---|---|---|
| **Display** (screen titles, era names, victory) | Geometric or grotesque sans; round O, single-storey a is welcome; high x-height not required; looks good set wide in caps with +8% tracking; a Bold and a Medium. | **Jost** (Futura lineage), Josefin Sans (more decorative, use sparingly), League Spartan |
| **UI / labels / body** | Neo-grotesque or signage grotesque; open apertures (c, e, s don't close up), distinct Il1, a **Semi-Condensed** or **Condensed** width in the same family; tabular figures (`tnum`); 400/500/600/700. | **Barlow** + Barlow Semi Condensed + Barlow Condensed (built from California highway signage), Archivo (has a width axis), IBM Plex Sans + Condensed |
| **Numerals** (counters, odometers, split-flap, tables) | Monospaced or tabular lining figures, zero distinguishable from O (slashed or dotted is fine), flat-topped 3 is welcome, figures as tall as caps. | Barlow with `tnum` + `lnum`; **IBM Plex Mono** for split-flap and odometer windows |

Recommended prototype stack: **Jost** (display) · **Barlow / Barlow Semi Condensed** (UI) · **IBM Plex Mono**
(mechanical numerals). All SIL OFL. In Godot, load each as a `FontFile`, and wrap Barlow in a `FontVariation` with
`opentype_features = {"tnum": 1, "lnum": 1}` for every numeric label.

### 5.2 Scale

Base 1920×1080 (the game's layout width). The scale is a 1.2 ratio rounded to whole pixels, so Godot renders
crisply.

| Token | Size / line | Face, weight, case, tracking | Use |
|---|---|---|---|
| `type.display-xl` | 56 / 60 | Jost 500, UPPERCASE, +6% | Victory sheet, era change |
| `type.display` | 40 / 44 | Jost 500, UPPERCASE, +6% | Screen titles (Knowledge, Supply) |
| `type.title` | 28 / 34 | Jost 500, Title Case, +1% | Modal titles, card names in details |
| `type.heading` | 15 / 20 | Barlow SemiCond 600, UPPERCASE, +10% | Section labels ("THE REALM", "IN HAND") |
| `type.body` | 20 / 28 | Barlow 400, sentence case, 0 | Card rules text, modal text, log |
| `type.body-s` | 17 / 24 | Barlow 400, 0 | Tooltips, secondary rules |
| `type.label` | 17 / 20 | Barlow SemiCond 500, sentence case, +2% | Buttons, tabs, list rows |
| `type.label-caps` | 14 / 16 | Barlow SemiCond 600, UPPERCASE, +12% | Stat captions ("FOOD"), lamp labels, tab labels |
| `type.caption` | 14 / 18 | Barlow 400, 0 | Footnotes, "next upkeep" deltas |
| `type.numeral-xl` | 44 / 44 | Plex Mono 500 | End-turn turn counter, victory score |
| `type.numeral` | 26 / 28 | Barlow SemiCond 600, `tnum` | Resource bar values |
| `type.numeral-s` | 17 / 20 | Barlow SemiCond 600, `tnum` | Costs on cards, table cells |

The game's current sizes (Title 26, Stat/BarStat 20–26, default 20) are close; adopt the scale by changing
`GameTheme` only.

### 5.3 Rules

- **Uppercase** only for short labels of ≤ 3 words: headings, captions, tab labels, lamp labels, display titles.
  Never for sentences, card rules, or button labels longer than two words. Uppercase is always tracked +6% to +12%;
  lowercase is never tracked positive.
- **Tracking**: display +6%, caps labels +10–12%, body 0, numerals 0 (tabular figures already space themselves).
- **Line height**: 1.4 for body, 1.2 for labels, 1.0–1.1 for numerals and display. Paragraph spacing = one line.
- **Measure**: body text 45–70 characters. Card rules text is short by design; modal text caps at 640 px wide.
- **Hierarchy by size and case, then weight, then colour.** Use at most two weights on one surface (usually 400 +
  600). Never use colour alone to make something a heading.
- **Numerals**: every number that can change uses tabular lining figures, so the layout never shifts when 9 becomes
  10. Columns of numbers are right-aligned; a column of signed deltas aligns on the sign (pad with a figure space
  `U+2007`). Units and glyphs sit *after* the number at `type.label-caps` size (`12 ⌂`).
- **Condensed vs regular**: regular width for reading (rules text, modals, log). Semi-condensed for controls,
  labels and anything in the top bar. Full condensed only where space is genuinely short (card costs, dense
  tables) and never below 14 px.
- **Data-heavy screens** (tech tree, supply, log): one size for all data (`type.label`), hierarchy through column
  position, `ink` vs `ink-2`, and rules every row or every 3 rows (the "ledger" rhythm), never zebra fills.

---

## 6. Layout and spacing

### 6.1 Spacing scale (4 px base)

`space.0` 0 · `space.1` 4 · `space.2` 8 · `space.3` 12 · `space.4` 16 · `space.5` 24 · `space.6` 32 · `space.7` 48 ·
`space.8` 64 · `space.9` 96

- Inside a control: `space.2` vertical × `space.4` horizontal.
- Between related controls: `space.2`. Between groups: `space.5`. Between sections: `space.7`.
- Panel padding: `space.5` (dense panels `space.4`).
- Never use a value off the scale. The game's current `SECTION_GAP 22`, `CARD_GAP 10` become 24 and 12.

### 6.2 Grid

- **12 columns** at 1920: 96 px margins, 24 px gutters, 122 px columns. Content snaps to columns; the hand and the
  Realm rows may break the grid only along their own baseline.
- **8 px baseline**. Text boxes and panels start and end on it.
- **Asymmetric master layout**: a 3-column left rail (identity, government, notifications), a 9-column work area
  (Realm above, hand below). The rail stays put through navigation, giving screens a fixed point.
- **Title block.** Every screen and modal has an architectural title block: a 4 px `ink` bar across the top of the
  sheet, then title left, metadata right (turn, era) in `type.label-caps`. This is the period's most recognisable
  information-design move and replaces decorative headers.

### 6.3 Corner radius philosophy

Radius is meaning, not softness.

| Token | Value | Use |
|---|---|---|
| `radius.0` | 0 | Panels, sheets, cards, modals, tabs, tooltips, the bar. Paper is cut square. |
| `radius.1` | 2 | Buttons and fields: a machined edge, so controls read as objects rather than drawings. |
| `radius.2` | 4 | Badges and keycaps. |
| `radius.full` | 50% | Lamps, pips, dials, toggle thumbs. Only things that *indicate*. |

Nothing between 6 and 24 px. The game's current 6 px buttons and rounded overlays go square.

### 6.4 Borders

| Token | Width | Use |
|---|---|---|
| `border.hair` | 1 | Row rules, card internal dividers, tooltip edge |
| `border.control` | 2 | Buttons, fields, toggles, unselected cards |
| `border.emphasis` | 3 | Selected card, the active tab's rail, the primary button |
| `border.bar` | 4 | Title-block bars, section bars, the active rail of the turn plate |

Borders are `ink` or `rule`, or the hue's line value for type-coloured cards. Never a light border on a dark fill to
fake a highlight.

### 6.5 Shadows

Shadows are solid, unblurred offsets down and to the right (light from top-left, consistent everywhere).

| Token | Offset | Use |
|---|---|---|
| `shadow.none` | 0 | Flat paper; pressed controls |
| `shadow.plinth` | 2, 2 | Resting controls (buttons stand on a plinth) |
| `shadow.lift` | 4, 4 | Hovered card, selected card, open drawer |
| `shadow.sheet` | 8, 8 | Modal sheets, the drag ghost |

Colour `color.shadow` at 100% in Paper (it is a printed shadow) and `#0D0C0B` in Night. In Godot:
`StyleBoxFlat.shadow_size = 0` won't draw; use `shadow_size = 1` with `shadow_offset` = the token and a
`shadow_color` with full alpha, or draw a second `Panel` offset behind. (See §16.)

### 6.6 Panel density

- **Dense** (log, tech table, supply list): `space.4` padding, 32 px rows, `type.label`, hairline rules.
- **Regular** (modals, settings): `space.5` padding, 44 px rows.
- **Ceremonial** (victory, era change, new game): `space.7` padding, generous margins, display type.

### 6.7 Cards

Cards are **index cards**, not app tiles: square corners, `sheet` face, 2 px `ink` border (Night: `rule`), and
a **type band**: a 6 px plane-coloured strip across the top under the name, carrying the type glyph at its right
end. Rules text below a hairline. VP bottom-right with the starburst. No drop shadow at rest (cards lie flat);
`shadow.lift` when lifted.

**Cost is always top-right**, on every card type, on the name's line: one `well` plate (1 px inner `rule`) holding
one **cost entry per resource paid**, in a fixed order: food, wealth, insight. Each entry is the resource's glyph
(`icon.m` 20, the resource's hue line) followed by its figure (`type.numeral-s`, `ink`); entries are divided by a
1 px `rule`. A Granary costing 1 food and 2 wealth reads `[sprout 1 | coin 2]`. The **glyph's shape** tells food from
wealth (sprout vs coin), and the hue repeats it, so the two never depend on colour; the plate's accessible name
spells it out ("Costs 1 food, 2 wealth"). A card with no cost shows no plate (never a 0). A resource the player is
short of prints its figure in `danger`, underlined 2 px, so the reason a card is dimmed is visible on the cost itself.

A dimmed (unplayable) card keeps full-contrast text, swaps the band for a 45° hatch in `ink-3` and adds its reason
strip as a `well` plate with ⊘ and `ink` text, not a red banner.

### 6.8 Icon sizing

`icon.xs` 12 (inline in captions) · `icon.s` 16 (in body text, in buttons) · `icon.m` 20 (card costs, tabs) ·
`icon.l` 32 (resource bar, notifications) · `icon.xl` 48 (modal headers, era change). Icons sit on the text
baseline when inline (`Icons.fill` already scales to the font size); in controls they're centred on the cap height.
**A glyph beside a value window or plate takes that box's height**: the resource bar's windows are 32 px, so its
glyphs are 32; a card's cost plate line is 22 px, so its glyphs are 20. A small glyph beside a tall box reads as an
afterthought.

### 6.9 Alignment rules

1. Left-align everything that is read; right-align everything that is compared (numbers).
2. One alignment edge per column; a label and its value share a baseline.
3. Controls in a row align to their text baselines, not their boxes.
4. Icons align to the cap height of adjacent text.
5. Centred alignment only for single statements (modal title on a ceremonial sheet, an empty-state message).

---

## 7. Components

Each component lists anatomy, then states. Detailed state-transition specs are in §15; motion tokens in §14.

1. **Primary button** — signal fill, `on-signal` label, 3 px `ink` border, `radius.1`, `shadow.plinth`. Max one per
   view.
2. **Secondary button** — `steel` fill, `ink` label, 2 px `rule` border, `shadow.plinth`.
3. **Tertiary / link** — no box. `ink-2` label; hover draws a 2 px underline in from the left (wipe).
4. **Tab** — a folder tab: square top, its rail below. Inactive tabs are `steel`; the active tab is `sheet`, joins
   the sheet below (no border between them) and carries a 3 px `ink` rail on top that slides between tabs.
5. **Toggle** — a **legend key**: a latching push key with a lamp strip across its top and its state printed on its
   face (ON/OFF). ON latches it down and lights the strip. It reuses the button's press, so the UI has one kind of
   key, not a separate switch control. §15.4.
6. **Resource counter** — caption with its lamp on the same line, then glyph + value in a **window** (a `well` inset
   with a 1 px inner `rule`), forecast below.
7. **Card** — §6.7.
8. **Panel / drawer** — `sheet`, square, title block, `shadow.lift` when it overlaps content, none when docked.
9. **Tooltip** — a printed tab: `ink` fill, `sheet` text (inverse) in Night and Paper alike, `radius.0`, a 6 px
   triangle notch toward the target, max 320 px wide.
10. **Notification flag** — a pennant that slides out from the left rail: a `sheet` strip, 4 px hue bar on its left
    edge, glyph, one line of text.
11. **Indicator lamp** — a 10–14 px disc. OFF: `well` with 1 px `rule` ring. ON: the hue's plane colour plus a 2 px
    ring of its line colour and a single small highlight dot (the only permitted radial). Lamps always sit beside a
    printed label.
12. **Progress indicator** — segmented: a `well` track divided into discrete cells (one per unit when ≤ 12, else
    percentage blocks of 10%) that fill with the hue plane. Never a smooth gradient bar.
13. **Gauge** — a half-dial for bounded values (unrest vs limit): a 180° arc in `rule`, coloured zones (sage / ochre /
    brick) on its outer edge, a single `ink` needle with a 2 px hub.
14. **Modal** — a drafting sheet: `sheet`, `shadow.sheet`, title block, footer rule above its actions (primary
    right, secondary left of it), Esc / Close closes.
15. **End-turn control** — §11.9 and §15.12.

---

## 8. Iconography

Icons are drawn on a **24 px grid with a 2 px live-area margin** (20 px live area), as if cut from a stencil.

| Property | Value |
|---|---|
| Stroke | 2 px at 24 px (scale with the icon: 1.5 px at 16, 2.5 px at 32). One stroke weight per icon. |
| Line caps / joins | Square caps, mitred joins. No round caps (that's the SaaS look). |
| Corners | Sharp. Curves are true circular arcs only (compass-and-ruler geometry). |
| Primitives | Circle, square, equilateral triangle, straight lines at 0°/45°/90°. No freehand. |
| Detail | ≤ 5 primitives per icon. If it needs more, it's an illustration, not an icon. |
| Optical size | A solid glyph carries more weight than an outlined one, so it is drawn about 20% smaller on the grid (the unrest bolt spans 16 of the 24 units, not 20) to sit at the same visual height as its neighbours and the value window beside it. |
| Filled vs outlined | Outlined = a thing or a place (the type glyphs in text). Filled = state you have / is active (a lit lamp, the active tab, a researched tech). Toggling outline→fill is how an icon shows "on". One standing exception: the unrest bolt is always solid, so the one harmful resource never looks like the others. |
| Active / inactive | Active: `ink` (or its hue line), filled where the icon has a fill state. Inactive: `ink-2`, outlined. Disabled: `ink-3`, outlined, never with a strike-through unless it means "blocked" (⊘). |
| Colour | Single colour. Icons take the colour of their text unless they *are* the key (resource glyphs). |
| Animation | Icons don't animate by themselves. They may: switch outline→fill in one frame (snap); rotate a part about a centre in 90° steps (a dial, a refresh); pulse their lamp. Never morph, never bounce. |

The game's current set (`assets/icons/*.svg`: food, upkeep, slot, housing, worker, type marks, blocked) maps
directly; redraw them on this grid, keeping the white-SVG-tinted-at-runtime pipeline in `Icons`.

---

## 9. Motion system

### 9.1 Principles

- **Mechanical, not organic.** Moves are short (≤ 24 px for controls, ≤ one panel width for navigation), fast to
  start, decelerate into a firm stop.
- **Anticipation is tiny.** Where used, a 2–4 px pull-back over ≤ 40 ms (the latch releasing).
- **Spatial truth.** A thing leaves the way it came. Drawers return into the rail they came from; sheets slide back
  under the stack.
- **One thing moves at a time** in the player's attention. Stagger siblings by 30–60 ms instead of moving them
  together.
- **No overshoot** except the `settle` curve, reserved for major milestones (era change, victory), max 4%.

### 9.2 The six primitives

| Primitive | Physical model | Property | Typical travel | Curve |
|---|---|---|---|---|
| **Slide** | A drawer or cabinet door on rails | position on one axis | 8–24 px for elements; panel width for panels | `ease.machined` in, `ease.release` out |
| **Snap** | A switch or latch hitting its detent | position or state, very short | 1–4 px | `ease.snap` |
| **Roll** | An odometer drum or split flap | a digit's vertical offset, flap rotation | one digit height per step | `ease.linear-step` per step |
| **Wipe** | A drafting sheet or blind drawn across | clip rect / underline width | full element | `ease.machined` |
| **Rotate** | A rotary control or gauge needle | rotation | ≤ 90° for controls; any for needles | `ease.machined`, needle `ease.damped` |
| **Pulse** | A lamp switching on | brightness of a lamp; a 1–2 px ring | none | `ease.lamp` (fast on, slow decay) |

Scale is **not** a primitive. Nothing scales on hover. Scale is allowed only for a lamp "on" bloom (ring 1.0→1.4,
fading) and for the Navigator's existing "grow out of the card" transition, which should become a wipe (§11).

### 9.3 Easing curves

| Token | cubic-bezier | Character | Godot Tween approximation |
|---|---|---|---|
| `ease.machined` | (0.2, 0, 0, 1) | Fast start, long controlled deceleration, firm stop. The default. | `TRANS_QUART`, `EASE_OUT` |
| `ease.release` | (0.4, 0, 1, 1) | Exit: accelerates away, no decel. | `TRANS_CUBIC`, `EASE_IN` |
| `ease.snap` | (0.3, 0, 0, 1) at ≤ 90 ms | A detent. | `TRANS_EXPO`, `EASE_OUT` |
| `ease.latch` | (0.5, -0.2, 0.1, 1) | A small anticipation then travel. For drawers and the end-turn release. | custom interpolator (§16) |
| `ease.linear-step` | linear | Each odometer/flap step; the curve is in the *sequence* timing, not the step. | `TRANS_LINEAR` |
| `ease.damped` | (0.3, 0.8, 0.4, 1) | Gauge needle: ~2% overshoot, one settle. | custom, or `TRANS_QUART` `EASE_OUT` |
| `ease.lamp` | on: (0, 0, 0.2, 1) 40 ms; off: (0.4, 0, 0.6, 1) | Filament: on instantly, cools slowly. | on `TRANS_EXPO` out; off `TRANS_SINE` in-out |
| `ease.settle` | (0.2, 0.9, 0.3, 1.04) | Milestones only. | custom |

**Banned**: `TRANS_BACK`, `TRANS_ELASTIC`, `TRANS_BOUNCE` and springs, except `ease.settle` for milestone moments.
The current code uses `TRANS_BACK` for the pulse, the landing squash and the pip pop; these become `ease.snap` +
`ease.lamp`.

### 9.4 Timing table

| Interaction | Duration | Primitive & values | Curve |
|---|---|---|---|
| Hover feedback | in 90 ms, out 140 ms | Background one value step; shadow unchanged. Links: underline wipe 0→100%. | in `machined`, out `release` |
| Button press | 50–70 ms down | translate (+2, +2), shadow plinth→none: the button sits into its shadow. | `snap` |
| Button release | 110–140 ms up | back to (0, 0), shadow restored. | `machined` |
| Toggle change | 70 ms latch + 40 ms lamp | The key over-travels 3 px while held, latches 2 px down (ON) or springs back (OFF); the lamp strip and legend change as the latch lands. | `snap` key, `lamp` |
| Navigation transition | 280–360 ms | New screen wipes in from the side of its origin (left rail → right), old slides 24 px and fades out under it. | `machined` / `release` |
| Panel opening (drawer) | 220–280 ms open, 180–220 ms close | Slide from its rail edge; contents fade in after 40% (stagger rows 20 ms, max 6 rows). | `latch` / `release` |
| Modal appearance | 220–260 ms | Sheet slides up 24 px + opacity 0→1 over the first 120 ms; scrim fades 160 ms. Close: 160 ms, down 12 px. | `machined` / `release` |
| Resource gain | 600–900 ms total | Delta tag (+3) snaps in beside the counter (90 ms), the counter rolls, the lamp pulses once, tag holds 600 ms then wipes out (120 ms). | `snap`, `linear-step`, `lamp` |
| Counter increment | 60–80 ms per step, ≤ 8 steps visible | Odometer roll per changed digit column; for |Δ| > 8, roll the last 8 steps only. | `linear-step` |
| Selection | 100–140 ms | Card slides 12 px up out of its row; shadow none→lift; index tab (signal) wipes in on its top edge. | `machined` |
| Confirmation | 240–320 ms | Lamp on, then a 6-ray starburst draws out from the lamp (rays wipe 0→8 px, then fade 160 ms). | `lamp`, `machined` |
| Error feedback | 240 ms | One lateral **snap**: −4, +4, 0 px (80 ms each), border turns `danger`, ⊘ appears; message stays until the cause changes or 4 s. No shaking > 4 px. | `snap` |
| Major milestone | 1.2–2.0 s, skippable | Ceremonial sheet wipes across, display type split-flaps in by character (25 ms stagger), concentric-ring or 16-ray starburst motif draws, one `settle`. Click/Esc skips to the end state. | `machined`, `settle` |

### 9.5 Reduce motion

The game has Reduce motion (`Settings.reduce_motion`). With it on:

- Slide, wipe, roll, rotate → **instant**, plus a ≤ 120 ms opacity crossfade where a change of place would
  otherwise be unclear (navigation, modals). This matches `Anim.CALM_FADE_TIME` (0.15 s → 0.12 s).
- Pulse → the lamp switches on and **stays** lit for 1.5 s (no blinking); the delta tag holds 1.5 s.
- Press feedback remains (it is 2 px and instant feedback, not decoration), but its tween becomes a frame switch.
- Milestones skip to their end state; the starburst is drawn static.
- Looping animation of any kind (the drop-zone pulse) stops; a static 3 px outline replaces it.

---

## 10. Interaction patterns

### 10.1 Buttons
Industrial push-buttons. Pressing moves the face **into** its shadow: +2, +2 px and the plinth shadow disappears, so
it reads as depressing into the desk. No scale, no ripple, no colour flash. Release returns in 120 ms. Keyboard
activation (Space/Enter) plays the same press/release. A held button (End turn's hold-to-skip-confirm if added)
shows a fill wiping left→right across its face.

### 10.2 Navigation
Screens are **sheets on rails**. The Knowledge (tech) screen comes from the right, the Supply from the right as well,
the log drawer from the left rail. Each sheet carries the `ScreenHeader` breadcrumb in its title block; going back
slides it out the way it came. A screen that grows out of a card (Navigator, 104) becomes a **wipe from the card's
rectangle**: a clip rect expands from the card's bounds to the full sheet in 300 ms, with the card's type band
colour flashing in the title block bar for the first 120 ms — continuity without scaling.

### 10.3 Counters
Every changing number uses a discrete mechanism:
- **Odometer** for resources and score (digits roll vertically, increasing rolls up, decreasing rolls down).
- **Split-flap** for words and the turn number/era: each character flips through ≤ 3 intermediate glyphs.
- **Tally** for small integers shown as pips (pop, housing, actions left): pips switch on one at a time, 60 ms
  apart, left to right.
No smooth numeric interpolation (no 4.37 frames). The final value appears no later than 600 ms after the action
so a fast player is never waiting.

### 10.4 Resource gain/loss
`+3` snaps in to the right of the counter in `type.numeral-s`, sage for gain, brick for loss with a `−` sign
(U+2212); the counter rolls; the resource's lamp pulses once. Several changes from one action **merge** into one
tag per resource (the engine already reports a net change, 126). Tokens flying across the screen are reserved for
the rare, important transfer (paying a cost from a card to the bar, buying a Wonder); the current per-change
floating tokens (114, 126) become delta tags.

### 10.5 Selection
A selected card **slides 12 px out of its row** (out of a stack, like pulling an index card up from a file),
gains `shadow.lift` and a 3 px `ink` border, and a signal-orange **index tab** (24×6 px) wipes in on its top edge.
Hover (not selected) only gives `shadow.plinth` + 4 px slide. Nothing scales. (Today's hand hover scales 1.08 and
lifts 20 px; it becomes 0 scale and 8 px.)

### 10.6 Panels
Drawers (log, notifications history) slide from a rail with `ease.latch`. Cabinet-door panels (government overlay,
explore choice) **part in two halves** sliding left and right off a centre seam to reveal choices beneath, 260 ms.
Layered plans (tech tree eras) stack as offset sheets, 8 px right and down per layer; bringing one forward slides
it out of the stack and back on top.

### 10.7 Notifications
A **flag** slides out of the left rail (from x −100% to 0 in 200 ms, `machined`), holds, then slides back in
(160 ms). One at a time; queued flags stack below at 8 px gaps, max 3, older ones collapse into a count badge on
the rail. Each flag has a hue bar, glyph and one line; urgent ones (famine, anarchy) don't auto-dismiss and have a
lit brick lamp until resolved.

### 10.8 Success / confirmation
The lamp next to the control lights, then a small starburst (6 rays, 8 px) draws out from it and fades. The burst
is centred on the lamp: each ray rotates about the lamp's centre and grows outward from 1 px beyond its rim
(radius 9 → 17 px), so the lamp sits exactly in the middle of the rays. For
bigger confirmations (tech learned) the tech's tile gets a full 12-ray burst behind its glyph for 400 ms and the
tile's band fills in with a left→right wipe. Large sequences only for era changes and victory.

---

## 11. Game-specific UI examples

### 11.1 Main HUD
A desk, not a cockpit. Three zones:
- **Top: the instrument strip** (the resource bar, §11.2) across the full width on `sheet` with a 4 px `ink` bar
  below it, the **turn plate** (split-flap turn number and era) at its left end, and the global navigation (Buy
  Cards, Knowledge, Log, Menu) as secondary buttons at its right end, ending in **End turn**.
- **Left rail** (3 columns): civilization and government (a title block with the government name in display type),
  then the notification flags.
- **Work area** (9 columns): the Realm (territory cards laid on a `well` blotter, frontier hatched) above, the hand
  below, separated by a 1 px rule and `space.7`.
Motion at rest: nothing. The only animation the player sees between actions is the feedback to their action.

### 11.2 Resource bar
A row of **instrument cells**, each 160 px wide, divided by 1 px vertical `rule-fine` lines (like a Braun radio's
dials). Each cell: `type.label-caps` caption top-left ("FOOD") with the cell's lamp at the right end of the same
line, centred on it; glyph (32 px, the window's height) + odometer value in a recessed window; and
the next-upkeep forecast in `type.caption` below (`+2 next`, sage; `−1 next`, brick with ◆ caution glyph if it would
starve). Unrest shows as a small half-gauge against its limit instead of a number when the limit is ≤ 10.
Hover a cell → the forecast tooltip (the existing one). A cell whose value is at a limit or dangerous lights its
lamp (brick) and its caption reads "AT LIMIT", so the state is in words too.

### 11.3 Technology / research (Knowledge)
A **drafting sheet / chart plotter**. Eras are horizontal bands like floors on an architectural section, each with
an era title block at its left. Techs are index-card tiles on the grid; prerequisites are drawn as 1 px `ink`
orthogonal lines with 90° corners (a circuit/plot, never curves), terminating in a 4 px dot.
- Researched: filled band in teal plane, filled glyph, lamp on.
- Available: `sheet` tile, 2 px `ink` border, cost in a well plate; hover slides it 4 px and adds `shadow.plinth`.
- Locked: `well` tile, `ink-3` text, prerequisite lines dashed, the ⊘ glyph with "Needs Pottery".
- Future era: the band is covered by a **vellum overlay** (`sheet` at 88%) with the era name printed on it.
Learning a tech: the lines from its prerequisites draw in (wipe along the path, 240 ms), the band fills, the lamp
lights, a 12-ray burst. Newly available techs light their lamps in sequence (tally, 60 ms).

### 11.4 Production queue (Supply / building slots)
The game has no city production queue; its equivalents are the **Supply** (Buy Cards) and building slots. Treat
both as a **filing system**: a horizontal rack of slots drawn as `well` recesses with 1 px `rule` edges; filled
slots hold index cards standing upright; empty slots show a dashed outline and "EMPTY SLOT" caption. Buying a card
slides it out of the supply rack (up 16 px), then it travels (one direct slide, 300 ms) to the discard/deck counter,
which rolls. If a queue is ever added: a vertical list of numbered rows (`01`, `02` in Plex Mono), the active row
with a progress segment bar and a lit lamp, reordering by drag with a 2 px ink insertion rule.

### 11.5 Diplomacy (future)
A **conference table plan**: each civ is a seat around a circle drawn in 1 px `rule`, with its emblem (a geometric
monogram in a circle) and its attitude as a lamp + word ("CORDIAL", "WARY", "HOSTILE"). Treaties are index cards
between the seats. Proposals open as a two-column **memorandum** modal: "WE OFFER" / "WE ASK", each a ledger list
with right-aligned values, a hairline total, and a signature line where the primary button (signal) sits. A
response arrives as a split-flap stamp on the memo ("ACCEPTED" sage / "DECLINED" brick) — the word is the state.

### 11.6 City / settlement management (territory view)
The territory replaces the Realm (105). Present it as a **site plan**: a title block (territory name, its keywords as
small caps tags), the building slots as a row of plan rooms (rectangles with 1 px walls, a room label in the corner),
and the pop meter (§11.7). Entering: a wipe from the territory card's rect (§10.2). Workers assigned to a building
appear as filled teal figures in the room's corner; idle buildings get a hatched floor and an ochre caution lamp
with "IDLE".

### 11.7 Population
Pop is a **tally counter** of pips (the existing PipFilled/PipEmpty/GrowPip meter, 124). Pips are 14 px discs in a
`well` track: filled teal for pop, outlined for housing room, the Grow pip is a square push-button (radius.1) in the
first empty position labelled with its food cost. Growing: the button presses (§10.1), then the pip turns into a
lit disc (lamp on 40 ms) and the food counter rolls down. Starvation risk: the rightmost pips get a brick ring and
the meter caption reads "WILL STARVE".

### 11.8 Map overlays (the Realm)
The Realm is a tableau, not a map, but overlays apply to it: targeting, frontier, and explanation modes are
**drafting overlays**, sheets of vellum laid over the board:
- Vellum: `sheet` at 88% over everything not relevant; relevant cards show through cut-outs (no blur).
- Valid targets: 2 px `ink` dashed outline (dash 6/4) + a lit lamp on each; invalid: unchanged under the vellum.
- Frontier (unsettled land): the existing 45° hatch, in `rule-fine`, 8 px pitch.
- Overlay in/out: the vellum wipes across from the side the drag started (180 ms).

### 11.9 End-turn control
The one **signal** control. Bottom-right of the instrument strip (or the work area's bottom-right corner):
a 220×64 push-button, signal fill, 3 px `ink` border, `shadow.sheet`-depth plinth (4, 4) — the biggest key on the
desk, like the start key of a console. Left of its label, a lamp shows readiness:
- **Ready** (nothing owed): lamp sage, label "END TURN", the turn number in Plex Mono on a small plate.
- **Something to do first** (actions left, discard owed): lamp ochre, label still active but the caption below
  says "2 actions left"; the engine decides the text (UI text never names content).
- **Blocked** (a pending decision): `steel` fill, not signal; ⊘ and the reason; disabled.
Press: travel 4 px (twice a normal button), 70 ms; release triggers the turn. The turn plate's number split-flaps
to the next, the event card for the turn slides in from the event deck, upkeep deltas appear as tags per resource
in a tally sequence (60 ms apart, left to right). Total turn-change choreography ≤ 1.2 s, and any click skips it.

### 11.10 Modal dialogs
Drafting sheets. Title block (4 px bar, title left, context right), body in `type.body` at max 640 px, footer above
a hairline: secondary actions right-aligned, primary rightmost. Esc and a click on the scrim close (ModalStack, 153).
A modal opened over a modal is offset +8, +8 px from the one beneath, so the stack reads as stacked paper.

### 11.11 Tooltips
Printed tabs: `ink` fill, inverse text, square corners, a 6 px notch. Appear after **400 ms** hover delay (0 ms when
moving between adjacent tooltip targets), with a 90 ms opacity + 4 px slide from the target. Content: a
`type.label-caps` heading, then `type.body-s`. Numbers in a tooltip line up in a small two-column ledger
(the upkeep forecast: one row per source, a hairline, the net).

### 11.12 Victory / progression
Era change and game over are **ceremonial sheets**: full-screen `board` with a centred (the one allowed centring)
composition: era or result in `type.display-xl` split-flapping in; a large geometric motif (concentric rings for an
era, a 16-ray starburst for victory) drawn with wipes in 400 ms; the score in an odometer that rolls from 0 with
digits settling right-to-left. Below, a ledger of the score breakdown (category left, right-aligned VP) with a
double rule above the total. One primary button ("New game"). Skippable at any point; Reduce motion shows the end
state directly.

---

## 12. Accessibility

**Contrast** (WCAG 2.2, computed for the tokens above):

| Pair | Paper | Night | Requirement |
|---|---|---|---|
| `ink` on `sheet` | 14.7 | 11.8 | 4.5 (AA body) — passes AAA |
| `ink-2` on `sheet` | 7.0 | 6.9 | 4.5 |
| `ink-2` on `board` | 6.3 | 7.8 | 4.5 |
| `on-signal` on `signal` | 5.7 | 5.2 | 4.5 |
| `signal` text on `sheet` | 5.6 | 4.6 | 4.5 |
| Hue line values on `sheet` | 5.4–6.7 | 5.0–6.5 | 4.5 |
| Text on hue planes (`ink` / `board`) | 4.6–7.3 | 5.7–7.4 | 4.5 |
| `rule` (control borders) on `sheet` | 5.0 | 3.6 | 3.0 (non-text UI) |
| `ink-3` (disabled only) on `sheet` | 4.2 | 4.1 | exempt; still ≥ 3 |
| `focus` ring on `sheet` | 5.8 | 7.1 | 3.0 |

**Rules**

1. **Never colour alone.** Every semantic colour has a glyph and/or a word (§4.4). Resources have shapes. Lamps
   always have a printed label stating the state ("ON", "IDLE", "AT LIMIT").
2. **Never animation alone.** Every animated change leaves a static end state that tells the whole story: the new
   number, the lit lamp, the delta in the log. A player who looked away for the 600 ms of feedback misses nothing.
   Deltas are also written to the log.
3. **Reduce motion** (§9.5) is honoured everywhere, including milestone sequences; it is available on the title
   screen and in Settings (as today).
4. **Frequent interactions are quiet.** Hover, press, select and resource changes move ≤ 12 px and never loop.
   Nothing on screen animates while the player is idle (the drop-zone pulse only runs during a drag).
5. **Type floor**: nothing below 14 px; body is 20 px at 1080p. UI scale setting multiplies the whole type and
   spacing scale together (offer 90/100/115/130%).
6. **Focus** is always visible for keyboard play (teal ring, offset 2 px, square), never removed on mouse click.
   Focus order follows the reading order: rail → instrument strip → Realm → hand → End turn.
7. **Targets**: minimum 32×32 px hit area for anything clickable; pips grow their hit area to 32 px.
8. **Flicker**: no lamp blinks faster than 2 Hz, and no blinking at all for more than 3 cycles.
9. **Colour-vision check**: the support hues differ in lightness as well as hue (sage vs brick, teal vs ochre). Test
   with deuteranopia and protanopia simulations; danger vs positive must still separate by glyph *and* value.

---

## 13. Do / Don't

| Do | Don't |
|---|---|
| A 2 px hard offset shadow under a button | A blurred 16 px drop shadow under a floating card |
| One signal-orange button per view | Orange for links, highlights, *and* the primary action |
| Square cards with a 6 px type band | 16 px-radius cards with a gradient header |
| Odometer roll from 12 to 15, three steps | A counter tweening 12.00 → 15.00 smoothly |
| `+3` tag snapping in beside Food | Three coin sprites flying from the card to the bar |
| Selected card slides 12 px out of the row + index tab | Selected card scales to 115% with a glow |
| Lamp + "AT LIMIT" when unrest is full | Unrest number turning red with no other cue |
| Drawer slides in on its rail, stops firmly | Panel springs in, overshoots, wobbles |
| Tracked small caps for "FOOD" | Tracked lowercase body text |
| A 4 px title-block bar to start a modal | A centred title with an ornamental divider |
| Vellum overlay for targeting mode | Blur behind (glassmorphism) |
| Tabular figures in every changing number | Proportional figures that make the bar jitter |
| A 45° hatch for frontier/unavailable | A diagonal stripe in two saturated colours (warning tape) |
| A starburst once, at a tech learned | Starbursts as a background pattern |
| Plain warm off-white paper | Paper texture, coffee stains, wood grain, leather |
| Plex Mono in a split-flap window | A pixel or LCD segment font |
| Era change as a ceremonial sheet | Era change as confetti |
| Cost top-right as `[sprout 1 \| coin 2]`, a glyph per resource | A bare `3` that could be food or wealth, or costs placed differently per card type |
| A latching legend key that says ON or OFF on its face | A rounded pill track with a circle thumb |

---

## 14. Design tokens

Values as they'd go into a token file. Godot equivalents in §16.

```yaml
space:   { 0: 0, 1: 4, 2: 8, 3: 12, 4: 16, 5: 24, 6: 32, 7: 48, 8: 64, 9: 96 }  # px
radius:  { 0: 0, 1: 2, 2: 4, full: 9999 }
border:  { hair: 1, control: 2, emphasis: 3, bar: 4 }
shadow:                       # solid colour, no blur
  none:   { x: 0, y: 0 }
  plinth: { x: 2, y: 2 }
  lift:   { x: 4, y: 4 }
  sheet:  { x: 8, y: 8 }
duration:                     # ms
  instant: 0
  tick: 60        # one odometer/flap step; tally stagger
  snap: 70        # press down; error snap leg (80)
  hover: 90
  quick: 120      # release, tooltip in, reduced-motion crossfade
  toggle: 160
  small: 200      # selection, flag out, small slides
  panel: 260      # drawer, modal, cabinet doors
  screen: 320     # navigation
  emphasis: 400   # starburst, tech learned
  feedback: 600   # resource-gain total hold
  milestone: 1600 # era change, victory (skippable)
stagger:  { tick: 60, list: 20, characters: 25, siblings: 40 }
ease:
  machined:    [0.2, 0.0, 0.0, 1.0]
  release:     [0.4, 0.0, 1.0, 1.0]
  snap:        [0.3, 0.0, 0.0, 1.0]
  latch:       [0.5, -0.2, 0.1, 1.0]
  linear-step: [0.0, 0.0, 1.0, 1.0]
  damped:      [0.3, 0.8, 0.4, 1.0]
  lamp-on:     [0.0, 0.0, 0.2, 1.0]
  lamp-off:    [0.4, 0.0, 0.6, 1.0]
  settle:      [0.2, 0.9, 0.3, 1.04]   # milestones only
travel:  { press: 2, press-end-turn: 4, hover-card: 4, select-card: 12, error-snap: 4, modal-rise: 24, flag: 100% }
type:                         # size / line-height, px
  display-xl: [56, 60]   display: [40, 44]   title: [28, 34]
  heading:    [15, 20]   body:    [20, 28]   body-s: [17, 24]
  label:      [17, 20]   label-caps: [14, 16] caption: [14, 18]
  numeral-xl: [44, 44]   numeral: [26, 28]   numeral-s: [17, 20]
tracking: { display: 0.06em, caps: 0.12em, heading: 0.10em, body: 0, numeral: 0 }
icon:    { xs: 12, s: 16, m: 20, l: 32, xl: 48, stroke-at-24: 2 }  # beside a box: the box's height
lamp:    { s: 10, m: 14, l: 20 }
color.paper:
  board: "#EFE8DA"  sheet: "#F8F4EC"  well: "#E3DACA"  steel: "#DCD3C2"
  ink: "#22211F"  ink-2: "#57534B"  ink-3: "#7A7468"  rule-fine: "#CFC6B5"  rule: "#6F685C"
  shadow: "#22211F"  signal: "#A8401B"  on-signal: "#FBF6EC"  glyph-ochre: "#A07514"  # icons only
  positive: "#4E6B47"  caution: "#7C5810"  danger: "#9B3424"  info: "#35597C"  focus: "#1F6A68"
  plane: { teal: "#5E9C97", ochre: "#D9A441", olive: "#A3AA6A", blue: "#8AA7C4", brick: "#C9705C", sage: "#9DB592" }
color.night:
  board: "#1F1E1C"  sheet: "#2A2825"  well: "#171614"  steel: "#3A3733"
  ink: "#EDE6D6"  ink-2: "#B9B1A1"  ink-3: "#8E877A"  rule-fine: "#3A3733"  rule: "#857D70"
  shadow: "#0D0C0B"  signal: "#E0703F"  on-signal: "#1F1E1C"
  positive: "#93B585"  caution: "#D9A441"  danger: "#E07A63"  info: "#86A9CC"  focus: "#6CC3BC"
  plane: { teal: "#5FB0A9", ochre: "#D9A441", olive: "#A9B26C", blue: "#86A9CC", brick: "#E07A63", sage: "#93B585" }
```

---

## 15. Example component specifications

Notation: `REST → HOVER → PRESSED → RELEASED`; each transition gives duration, property changes and curve.
Offsets are (x, y) px from rest. "Shadow" is the hard offset shadow token.

### 15.1 Primary button
Anatomy: signal fill, 3 px `ink` border, `radius.1`, padding 8 × 20, `type.label` 600, `on-signal`, min height 40,
optional 16 px icon left with 8 px gap.

| State | Fill | Offset | Shadow | Border | Notes |
|---|---|---|---|---|---|
| REST | signal | 0, 0 | plinth (2, 2) | 3 ink | |
| HOVER | signal lightened 8% (Paper) / darkened 8% (Night) | 0, 0 | plinth | 3 ink | 90 ms `machined` in, 140 ms `release` out |
| PRESSED | signal darkened 10% | +2, +2 | none | 3 ink | 70 ms `snap`. Sits into its shadow. |
| RELEASED | → HOVER (pointer still over) | 0, 0 | plinth | | 120 ms `machined`; action fires on release |
| FOCUS | as REST + teal 2 px ring offset 2 px | | | | ring appears instantly |
| DISABLED | `well`, text `ink-3` | 0, 0 | none | 2 dashed `rule` | reason in tooltip (the `*_error` string) |

### 15.2 Secondary button
`steel` fill, 2 px `rule` border, `ink` label, otherwise as 15.1. HOVER: `steel` one step toward `sheet`, border →
`ink`. PRESSED: +2, +2, shadow none, fill one step toward `well`. Same timings.

### 15.3 Tab
Anatomy: 36 px tall, padding 0 × 16, `type.label-caps`, square top, sits on a 1 px `ink` baseline. Group has one
shared 3 px `ink` **rail** that sits on the active tab's top edge. The panel's content starts on the same vertical
line as the first tab's label text (panel border + padding = tab border + padding: 1 + 16), and its top padding
equals its side padding (16), so the label and the text under it read as one column.

| Transition | Duration | Change | Curve |
|---|---|---|---|
| REST → HOVER | 90 ms | label `ink-2` → `ink`; 2 px underline wipes in from left | `machined` |
| HOVER → PRESSED | 60 ms | offset 0, +1 | `snap` |
| PRESSED → ACTIVE | 200 ms | the rail **slides** to this tab (x and width); fill `steel` → `sheet`; the baseline under it opens (tab joins the sheet); content below crossfades 120 ms with a 12 px slide in the direction of travel | `machined` |
| ACTIVE (rest) | — | `sheet` fill, `ink` label 600, rail on top | |

### 15.4 Toggle (legend key)
A latching push key, like a control-room key with a lit legend. It is the button's press made to stay down, so the UI
has one physical idea for "a thing you press" and no separate switch control. The key prints its own state, so it
needs no ON/OFF word beside it; the setting's name sits to its left in `type.label`, and the key aligns right in its
row.

Anatomy: 56×36 key, `steel` face, 2 px `ink` border, `radius.1`, 4 px padding, `shadow.plinth` (2, 2) at rest. Inside,
two rows 3 px apart:
- **Lamp strip**, 6 px tall, the key's full inner width. OFF: `well` with a 1 px inset `rule`. ON: the `sage` plane
  with a 1 px inset sage line. (Sage is the default; a setting whose ON state is a warning may use the caution lamp.)
- **Legend**, "ON" / "OFF" in `type.label-caps` at 12 px, centred. OFF prints `ink-2`, ON prints `ink`.

| Transition | Duration | Change | Curve |
|---|---|---|---|
| REST → HELD | 70 ms | key over-travels to +3, +3; shadow hidden | `snap` |
| HELD → LATCHED (turning ON) | 70 ms | key settles at +2, +2, shadow stays hidden; as it lands the lamp strip lights (40 ms) and the legend changes to ON | `snap`, `lamp-on` |
| HELD → REST (turning OFF) | 120 ms | key springs back to 0, 0 and its shadow returns; the lamp fades (160 ms) and the legend changes to OFF | `machined`, `lamp-off` |
| HOVER | 90 ms | border stays `ink`; face one value step toward `sheet` | `machined` |
| FOCUS | instant | teal focus ring, offset 2 px | |
| DISABLED | — | face `well`, legend `ink-3`, dashed `rule` border, no shadow; a latched disabled key stays down | |
| Reduce motion | — | position and lamp switch in one frame | |

Accessibility: `role="switch"` with `aria-checked`; the legend and the latched position both carry the state, so
neither the lamp colour nor the motion is needed to read it.

### 15.5 Resource counter
Anatomy: a head line with the caption (`type.label-caps`, `ink-2`) at its left and a 12 px lamp at its right,
vertically centred on the caption; glyph (`icon.l` 32, the window's height, resource hue line) left of a window; the
window is `well`, 1 px inner `rule`, 2 × 6 padding (32 px tall), value in `type.numeral` `ink`, fixed width for 3
digits; forecast caption below.

`IDLE → CHANGED(+n)`:
1. 0 ms: delta tag "+3" appears right of the window, offset −4, 0 → 0, 0, 90 ms `snap`, colour sage (or brick "−2").
2. 60 ms: changed digit columns roll; each step 60–80 ms `linear-step`; ones column first, carries roll the next
   column on the same tick (odometer). Up for gain, down for loss. Max 8 steps, then jump.
3. Last step: the lamp pulses (on 40 ms, off 300 ms) in the resource's hue.
4. +600 ms: tag wipes out right→left, 120 ms.
`WARNING` (forecast would starve / at limit): lamp stays lit brick, caption text changes, no motion.
Reduce motion: value swaps, tag and lamp hold 1.5 s.

### 15.6 Card
Anatomy: §6.7. 2 px border; 6 px type band; name `type.label` 600; cost plate top-right, one glyph + figure entry
per resource (§6.7);
rules `type.body-s`; VP with starburst bottom-right.

| Transition | Duration | Offset | Shadow | Border | Other |
|---|---|---|---|---|---|
| REST | — | 0, 0 | none | 2 ink/rule | |
| → HOVER | 100 ms `machined` | 0, −4 | plinth | 2 ink | no scale |
| → PRESSED (pick up) | 60 ms `snap` | 0, −2 | none | | the card "clicks" before lifting |
| → DRAGGING | follow pointer, 0 lag beyond 1 frame | pointer | sheet (8, 8) | 3 ink | tilt ≤ 3° by drag speed (today 12°: reduce) |
| → SELECTED | 140 ms `machined` | 0, −12 | lift | 3 ink | signal index tab wipes in 120 ms |
| → PLAYED | 280 ms `release` | slides to target/discard | lift → none | | lands with a 60 ms `snap` (no squash) |
| DIMMED | instant | | none | 2 `rule` | band → hatch, reason plate |
| INVALID DROP | 240 ms | −4, +4, 0 lateral snaps | | danger | ⊘ + reason message |

### 15.7 Panel (drawer)
Anatomy: `sheet`, `radius.0`, title block (4 px bar), `space.5` padding, attached to a rail edge with a 1 px `ink` edge
on that side; `shadow.lift` on the open edge only while it overlaps content.

`CLOSED → OPENING → OPEN`: slide from −width to 0 along its rail, 260 ms `latch` (anticipation 3 px); contents fade
in starting at 40% of the slide, rows staggered 20 ms (≤ 6 rows). `OPEN → CLOSING → CLOSED`: 200 ms `release`,
contents vanish at once (no reverse stagger). Reduce motion: instant, 120 ms fade.

### 15.8 Tooltip
`ink` fill, `sheet` text, `radius.0`, 6 px notch, padding 8 × 12, max width 320.
`HIDDEN → (hover 400 ms) → SHOWN`: opacity 0→1 and offset toward the target 4 px → 0, 90 ms `machined`.
Moving to an adjacent target within 300 ms: swap content and slide to the new target, 120 ms, no fade.
`SHOWN → HIDDEN`: 80 ms opacity `release`.

### 15.9 Notification (flag)
Anatomy: 360 × 48 `sheet` strip from the left rail, 4 px hue bar at its left, `icon.l` glyph, one line
`type.label`, optional `type.caption` second line, close × right; `shadow.plinth`.

`QUEUED → ENTERING`: slide x −100% → 0, 200 ms `machined`; the rail's lamp for this category lights (lamp-on).
`SHOWN`: holds `TOAST_TIME` (3 s) for info; urgent ones (famine, anarchy) persist with a lit brick lamp.
`→ LEAVING`: slide back into the rail, 160 ms `release`; the stack below slides up 8 px per removed flag (120 ms).
Reduce motion: appear/disappear with a 120 ms fade.

### 15.10 Progress indicator (segmented)
A `well` track, 8 px tall, 1 px `rule` border; N cells with 2 px gaps (N = units when ≤ 12, else 10 cells of 10%).
Filling a cell: the cell's plane colour **wipes** left→right in 120 ms `machined`; consecutive cells tick 60 ms apart.
The value in words/numbers sits right of the track ("3 / 5"). Indeterminate progress: a single lit cell steps along
the track every 120 ms (like a chaser lamp) — off with Reduce motion (show "Working…").

### 15.11 Modal
Anatomy: `sheet`, `radius.0`, `shadow.sheet`, 4 px title-block bar, title `type.title` left, context
`type.label-caps` right, body ≤ 640 px, footer rule, buttons right (primary rightmost).

| Transition | Duration | Change | Curve |
|---|---|---|---|
| CLOSED → OPENING | 240 ms | sheet offset 0, +24 → 0, 0; opacity 0 → 1 over the first 120 ms; scrim 0 → full over 160 ms | `machined` |
| OPENING → OPEN | — | focus moves to the first control | |
| stacked open | 240 ms | new sheet sits +8, +8 from the one beneath | `machined` |
| OPEN → CLOSING | 160 ms | offset → 0, +12; opacity → 0; scrim fades 160 ms | `release` |

### 15.12 End-turn button
Anatomy: 220 × 64, signal fill, 3 px `ink` border, `radius.1`, `shadow.lift` (4, 4) plinth; lamp (14 px) left; label
"END TURN" in `type.label-caps` 17 px +12%; a turn plate (Plex Mono, `type.numeral-s`) on a `well` inset at right;
caption below the button for "2 actions left" (from the engine).

| Transition | Duration | Change | Curve |
|---|---|---|---|
| REST (ready) | — | lamp sage on | |
| REST (actions left) | — | lamp ochre on; caption visible | |
| → HOVER | 90 ms | fill one step; caption ink-2 → ink | `machined` |
| → PRESSED | 70 ms | offset +4, +4; shadow → none | `snap` |
| → RELEASED / COMMITTED | 120 ms | offset → 0; lamp off (160 ms `lamp-off`); button enters BUSY | `machined` |
| BUSY (turn resolving) | ≤ 1.2 s | `steel` fill; the turn plate split-flaps to N+1; label "UPKEEP…" | |
| → REST | 160 ms | fill → signal; lamp on (40 ms) | `lamp-on` |
| BLOCKED (pending decision) | instant | `steel`, ⊘, reason caption; disabled; focus skips to the decision | |
| REDUCED MOTION | | all of the above as instant swaps; lamp states are the record | |

---

## 16. Mapping onto this codebase (spike findings)

How the guide lands in the existing UI without touching `engine/`:

| Guide | Code today | Change |
|---|---|---|
| Colour tokens | `ui/palette.gd` (`Palette`), semantic names already | Replace values with the Night set; rename toward the guide's roles (`BACKGROUND`→board, `RAISED`→sheet, `FIELD`→well, `CONTROL`→steel, `ACCENT`→signal, `GAIN`→positive…). Paper mode becomes a second const set behind a setting — `Palette`'s doc comment already anticipates "a later light theme". |
| Type scale, buttons, panels | `ui/game_theme.gd` (`GameTheme`): `Heading`, `Title`, `Stat`, `BarStat`, `DarkPanel`, `AccentButton` | Add the fonts and a `tnum` `FontVariation`; set the scale; `_box`: radius 6 → 2, add `shadow_offset` (2,2), `shadow_size` 1, pressed box with no shadow and `content_margin` shifted 2 px to fake travel (Godot styleboxes can't translate, so pressed = shadow removed + content offset; real travel needs `ActionButton`-style `position` tweens). `dark_panel` radius 24 → 0. Add `TitleBlock`, `Lamp`, `Window` variations. |
| Motion tokens | `ui/anim.gd` (`Anim`): durations and sharpness | Add the duration and travel tokens; set `HOVER_SCALE`/`DRAG_SCALE` 1.0, `HOVER_LIFT` 4, `MAX_TILT` 3°; replace `LAND_SQUASH` with a 60 ms snap; `PULSE_SCALE` → lamp pulse. |
| Easing | `TRANS_BACK` in `card_motion.gd`, `ui_kit.gd`, `territory_view.gd` | `TRANS_QUART`/`EASE_OUT` (machined), `TRANS_EXPO`/`EASE_OUT` (snap). `ease.latch`/`settle` via `PropertyTweener.set_custom_interpolator` with a cubic-bezier helper in `Anim`. |
| Counters | `TopBar` stats + `UIKit.float_token` (126) | An `OdometerLabel` control (a clip `Control` with one digit strip per column) and a `DeltaTag`; tokens stop flying. |
| Navigation | `Navigator` grows a screen out of its card (104) | Swap the scale tween for a clip-rect wipe from the card's rect (`clip_contents` on a wrapper whose size/position tween). |
| Modals | `Modal` / `ModalStack` (153) | Slide-up 24 px + fade; +8,+8 per stacked modal; square panel; title block. |
| Toasts | `ui/toasts.gd` (116) | Become flags from the left rail; requires the left-rail layout in `BoardLayout`. |
| Reduce motion | `Settings.reduce_motion`, `UIKit.calm()`, `Anim.CALM_FADE_TIME` | Already the right switch; apply §9.5's mapping per component. |

**What I learned**
- The existing architecture is well placed for this: colours are already semantic (`Palette`), looks are already
  theme variations (`GameTheme`), timings are already centralised (`Anim`), and Reduce motion already exists. A
  restyle is mostly value changes plus four new controls (odometer, lamp, delta tag, title block).
- The biggest departures from today's feel are motion, not colour: removing hover scale (1.08), drag tilt (12°),
  `TRANS_BACK` overshoot, and flying tokens. These are what currently make the game feel "app-like".
- Godot `StyleBoxFlat` can do hard shadows (offset with `shadow_size` 1) but can't translate content on press; press
  travel needs either a content-margin trick in the pressed stylebox or a tween on the button's position.
- Paper (light) mode needs a full second palette and testing over card art; the Night mode alone is a smaller first
  step and keeps today's dark board.

**Recommendation**
Adopt it in three items, each UI-only (no `engine/` changes):
1. **Tokens & theme** — new `Palette` values (Night), fonts with `tnum`, `GameTheme` radius/border/shadow, `Anim`
   timings and the easing swap. Biggest visual change for the least code.
2. **Mechanical feedback** — odometer counter + delta tags replacing floating tokens, lamps on the resource bar and
   End turn, card hover/select without scale, press travel on buttons.
3. **Sheets and rails** — title blocks, modal/drawer/navigation motion, notification flags on a left rail, the
   Knowledge screen as a drafting sheet.
Paper mode and the milestone sequences (era change, victory) come after, once the Night mode has been played.
