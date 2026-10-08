# Mid-Century Modern Style Guide — "The Civic Planning Desk"

Spikes `spike/mcm-style-guide` and `spike/mcm-sound`. A visual, motion, interaction and sound design system for the
4X card game, with the voice of its flavor text (§18) and the direction of its card art (§19), written so a UI designer, a sound designer or a Godot developer can build it without reinterpreting
adjectives. A live specimen of the tokens and the core components (with motion, synthesized sound, and Reduce motion
and Sound switches) is in [mcm-specimen.html](mcm-specimen.html); open it in a browser.

Companion pages in this folder (open them in a browser); [index.html](index.html) lists them all:
- [mcm-specimen.html](mcm-specimen.html), the master: the game's design as built, every token and component in
  Night and Paper, with motion and sound, plus an audition board of every sound token (§14.1) and a repetition test
  (§16.8). When the game changes how something looks, moves or sounds, the specimen changes with it.
- [mocks/transitions.html](mocks/transitions.html): every screen transition in §10–11 on a mock game screen, with
  slow motion and Reduce motion.
- [mocks/](mocks/): the option pages, each comparing a few designs for one question, kept as the record of what was
  chosen and why (the index says which option each item built).
- [tools/sound-export.html](tools/sound-export.html): renders the sound tokens into the game's placeholder files.
- [card-art.md](card-art.md): every card's art file and brief (§19).

Where the game already has a concept (Palette, GameTheme, Anim, Navigator, Modal, Toasts, the top bar), the guide
names it, and §17 maps every token onto the existing code.

---

## 1. Design philosophy

**The premise.** The player sits at a planning desk built in 1962 for running a civilization. Whoever made it had
worked for Braun, Herman Miller and a national rail authority; the control room down the hall was built by the
same team. Everything is printed, machined, or lit. Nothing glows, floats or melts. Everything you hear is one of
its mechanisms at work: a key meeting its stop, a drawer on its runners, a counter's drum, a lamp's tone generator.
Nothing bleeps, whooshes or plays a jingle.

Five tenets, in order of precedence when they conflict:

1. **Legibility first.** A number the player needs this turn is readable at arm's length in under a second. Style
   never costs legibility.
2. **Things are made of something.** Every surface is paper, enamelled steel, or a lamp. Paper holds information,
   steel holds controls, lamps signal state. A surface never mixes roles.
3. **Motion and sound are mechanism.** Anything that moves does so the way a mechanism would: it accelerates
   quickly, travels a short, fixed distance, and stops firmly against a detent. Nothing wobbles, bounces or drifts.
   What you hear is that same mechanism, at the moment it makes contact: the detent, not the travel (§16).
4. **One loud thing.** At rest, at most one element on screen uses the signal colour (usually End turn). Emphasis is
   a budget, in sound as in colour: routine feedback is quiet so the rare event can be heard (§16.4).
5. **Restraint is the period.** Mid-century design is defined by what it left out. When in doubt, remove the
   ornament, keep the grid. Silence is part of the design: when in doubt, a sound is removed (§16.8).

**What it is not.** Not "retro": no CRT scanlines, chrome, boomerang wallpaper, diner turquoise, or fake wear. A
player who never saw 1960 should read it as simply *well designed*, with a warm, analogue character. The same holds for
the ear: no typewriter bells, cash registers, sci-fi bleeps, arcade chirps or lounge music. It should sound like a
well-made machine, not like a period piece.

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
| Sight and sound agree | A thing sounds like the mechanism it looks like: a key clicks, a drawer runs and stops, a sheet of paper whispers. Sound never adds a mechanism the eye can't see (§16.2). | Mute the game: every state still reads. Look away: every sound names the thing that moved. |

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
- **Sound.** Listen to these for *behaviour and timbre*, never to sample or imitate a recognisable product sound:
  Braun consumer electronics (the dry, short click of a well-damped key), rotary telephones (a dial's even detents),
  mechanical adding machines (Facit, Olivetti Divisumma: a registration clack after a run), Veeder-Root counters and
  split-flap boards (tiny ticks; a flutter that stops on the word), slide projectors (a motor-advance and a
  seat), drafting equipment (a parallel rule on its wires, vellum laid on a sheet), early computer consoles and
  control-room panels (relays behind the panel, a lamp with a tone), NASA-era instrumentation (sparse, purposeful
  tones). Lesson: every sound is the by-product of a well-made mechanism: short, damped, specific, and quiet enough to
  work beside all day. Colour and sound obey the same economy.

**Mood words, measured:** warm (backgrounds have hue 35–45°, saturation 15–25%; sound energy centred in 300 Hz–3 kHz
with the top rolled off above 6 kHz; the key switch's short snap is the one bright sound), optimistic (accents are saturated but never neon: chroma capped at ~0.15 in
OKLCH), tactile (every control shows press travel and clicks when it lands), quiet (≤ 1 moving thing at rest; no
sound at all at rest; routine sounds ≤ 100 ms and ≤ −26 dBFS).

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
| `color.shadow` | Hard offset shadows; soft card and sheet shadows | `#22211F` | `#0D0C0B` |
| `color.scrim` | Behind a modal | ink at 40% | `#000` at 60% |

**Surfaces (341).** The neutrals are laid over real materials, so the desk reads as made of something without
changing its colours. `board` (the board and the rail) and `sheet` under the top strip sit over walnut grain at 90%
(Night) / 88% (Paper): the grain only just shows, and the rail's grain runs on from the board's, so only its hairline
marks its edge. Cards, modals and overlay panels are printed on paper: dark gray paper under black at 30% in Night,
white paper as it is in Paper; a dimmed card lays `dim-bg` at 60% over its paper. Keys, flags, tooltips, tiles and
list rows stay flat. Text and the support hues keep their contrast (§4.3) on each surface's mean colour.

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
| Selected | `color.signal` + ink; a list row: a lamp | — | a card: hard 4 px shadow + index tab; a list row: a `sheet` strip + lit lamp (§7.16) |
| Primary action | `color.signal` | — | the only signal fill on screen |

Focus (teal ring) and selection (a card's shadow and orange tab; a list row's strip and lit lamp) never look alike, so a
keyboard player can see both at once.

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

Food is sage, not olive: olive is a yellowish green that sits too close to wealth's yellow in a card's cost. Sage is
also the gain colour, so a `+3` beside the food glyph is green too; the glyph, not the hue, says which resource it is.
In Paper, ochre's line value is a dark mustard (yellow can't reach 4.5:1 on warm paper), so the **wealth glyph** uses
a brighter gold, `glyph-ochre` `#A07514` (3.8:1 on `sheet`, past the 3:1 icons need). It is for icons only, never
for text.

These are the shapes the game's glyphs already use (`Icons.GLYPHS`); the guide keeps them and redraws them (§8).

### 4.6 Colour rules

1. A screen at rest uses neutrals + at most **two** support hues + signal (once). Resource colours inside the
   resource bar don't count against this; they're a key, not decoration.
2. Large areas are neutral. Support hues appear as planes no larger than a card band, a bar, or a tab. The one
   exception is a card's illustration (§19), a framed print with its own short palette.
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
- **Measure**: body text 45–70 characters. Card rules text is short by design; a text sheet's body caps at 640 px wide
  (§11.10; a ledger sheet keeps the measure inside its columns instead).
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

Controls stand on solid, unblurred offsets down and to the right (light from top-left, consistent everywhere). Paper
(cards, modal sheets, overlay panels; 341) rests on soft shadows instead: `color.shadow`, blurred, straight down,
deeper as it lifts.

| Token | Offset | Use |
|---|---|---|
| `shadow.none` | 0 | Pressed controls; a frontier card (open land, not paper) |
| `shadow.plinth` | 2, 2 | Resting controls (buttons stand on a plinth), flags |
| `shadow.lift` | 4, 4 | A selected card, a hovered tech tile or index card in a modal (a selected list row has none, §7.16) |
| `shadow.card` (soft) | 0, 4 · blur 8 | A card at rest; alpha 0.35 Night / 0.20 Paper |
| `shadow.card-hover` (soft) | 0, 8 · blur 16 | A hovered card; 0.45 / 0.28 |
| `shadow.card-drag` (soft) | 0, 14 · blur 24 | A dragged card; 0.50 / 0.32 |
| `shadow.sheet` (soft) | 0, 16 · blur 32 | Modal sheets and overlay panels; 0.55 / 0.35 |

A hard shadow is `color.shadow` at 100% in Paper (it is a printed shadow) and `#0D0C0B` in Night. In Godot:
`StyleBoxFlat.shadow_size = 0` won't draw; use `shadow_size = 1` with `shadow_offset` = the token and a
`shadow_color` with full alpha, or draw a second `Panel` offset behind. (See §17.) A soft shadow is the same colour at
the token's alpha, `shadow_size` its blur, anti-aliased (`Surfaces.lift`).

### 6.6 Panel density

- **Dense** (log, tech table, supply list): `space.4` padding, 32 px rows, `type.label`, hairline rules.
- **Regular** (modals, settings): `space.5` padding, 44 px rows.
- **Ceremonial** (victory, era change, new game): `space.7` padding, generous margins, display type.

### 6.7 Cards

Cards are **index cards**, not app tiles: square corners, `sheet` face, 2 px `ink` border (Night: `rule`), and
a **type band**: a 6 px plane-coloured strip across the top under the name, carrying the type glyph at its right
end. On a hand-size face the card's **art plate** (§19) follows the band: 16:9, full width, 1 px `ink` frame.
Rules text below a hairline. VP bottom-right with the starburst. Printed on paper, on a soft `shadow.card` at rest,
`shadow.card-hover` when hovered and `shadow.card-drag` when dragged (341).

**Cost is always top-right**, on every card type, on the name's line: one **cost entry per resource paid**, in a
fixed order: food, wealth, insight. Each entry is the resource's glyph (`icon.m` 20, the resource's hue line)
followed by its figure (`type.numeral-s`, `ink`), **grouped by spacing alone**: 3 px between a glyph and its figure,
12 px (`space.3`) between entries, and no box, tint or rule around them. The glyph starts each entry, so it does the
work a plate would. A Granary costing 1 food and 2 wealth reads `sprout 1   coin 2`. The **glyph's shape** tells food
from wealth (sprout vs coin), and the hue repeats it, so the two never depend on colour; the group's accessible name
spells it out ("Costs 1 food, 2 wealth"). A card with no cost shows nothing there (never a 0). A resource the player
is short of prints its figure in `danger`, underlined 2 px, so the reason a card is dimmed is visible on the cost
itself. If a card ever costs three resources and the entries run together, add a 1 px `rule` between entries, never a
box.

A dimmed (unplayable) card keeps full-contrast text, swaps the band for a 45° hatch in `ink-3` and adds its reason
strip as a `well` plate with ⊘ and `ink` text, not a red banner.

**Face text is a spec sheet** (382). Under the type line, in this order: a **ledger** of the card's figures (a
government's actions, unrest limit, tolerated tier, territories administered: label in 14 px caps `ink-2`, figure in
tabular `type.numeral-s`, two columns, no rules between rows); the **rules**, one effect a line, with every card the
card unlocks on one *Unlocks* line; and at the foot, above the VP, a line of **fine print** for what gates the card
rather than what it does (*Needs*, *Eureka*, *Starts on*, *Built over turns*): 14 px caps `ink-2`, entries joined by
" · ", a hairline above. Fine print is the smallest type on a card; 14 px is the floor (§12 rule 5), never less. The
long form, sentence by sentence, stays in the details. A tableau-size face shows the ledger and rules, not the fine
print.

**When the rules don't fit** (383; options compared in [mocks/card-overflow-options.html](mocks/card-overflow-options.html)),
a card keeps its size and its type size. It never grows, shrinks its rules, fades them out or slices a line.
1. **At rest** it shows whole rules while they fit (a one-paragraph rule is cut after its last whole sentence), then
   a foot under a dashed `rule`: *+3 more* on the left, *details* with its `I` key on the right (on a hand card; a
   card in a modal, whose full text is beside it, shows only *+3 more*). All of it 14 px caps.
2. **Rest the pointer** on a hand card for 120 ms without moving and the text sheet (type line to fine print) slides up
   over the art plate, only as far as the hidden text needs, at most the whole plate, and stops (120 ms `machined`).
   Its top edge is a 1 px `ink` rule. A pointer passing through moves nothing.
3. **If rules are still hidden**, the foot's dashed rule fills from left to right with a 2 px `ink` bar over 1.1 s,
   linear: a gauge, telling the player both that there is more and when it will come. It runs once and never loops.
4. **When it is full**, the **rules popover** (§11.11) opens beside the card. No click is needed; a press at any step
   cancels the reveal and goes on to play, drag or select as usual.
Cards that fit only lift on hover. A long card's art yields only while the player reads it.

### 6.8 Icon sizing

`icon.xs` 12 (inline in captions) · `icon.s` 16 (in body text, in buttons) · `icon.m` 20 (card costs, tabs) ·
`icon.l` 32 (resource bar, notifications) · `icon.xl` 48 (modal headers, era change). Icons sit on the text
baseline when inline (`Icons.fill` already scales to the font size); in controls they're centred on the cap height.
**A glyph beside a figure takes the figure's line height**: the resource bar's figures sit on a 28–32 px line, so its
glyphs are 32; a card's cost line is 22 px, so its glyphs are 20. A small glyph beside a tall figure reads as an
afterthought.

### 6.9 Alignment rules

1. Left-align everything that is read; right-align everything that is compared (numbers).
2. One alignment edge per column; a label and its value share a baseline.
3. Controls in a row align to their text baselines, not their boxes.
4. Icons align to the cap height of adjacent text.
5. Centred alignment only for single statements (modal title on a ceremonial sheet, an empty-state message).

---

## 7. Components

Each component lists anatomy, then states, then its sound. Detailed state-transition specs (visual, motion and
sound together) are in §15; motion and sound tokens in §14; the sound system in §16. "Sound: None" means silence is
the specification, not an omission.

1. **Primary button** — signal fill, `on-signal` label, 3 px `ink` border, `radius.1`, `shadow.plinth`. Max one per
   view. Sound: `ui.button.press` / `ui.button.release`, a key one size heavier (pitched 2 semitones lower).
2. **Secondary button** — `steel` fill, `ink` label, 2 px `rule` border, `shadow.plinth`. Sound: `ui.button.press`
   / `ui.button.release`.
3. **Tertiary / link** — no box. `ink-2` label; hover draws a 2 px underline in from the left (wipe). Sound: None (it
   is printed, not machined: no key, no travel).
4. **Tab** — a folder tab: square top, its rail below. Inactive tabs are `steel`; the active tab is `sheet`, joins
   the sheet below (no border between them) and carries a 3 px `ink` rail on top that slides between tabs. Sound: a
   shallow key, `ui.button.press` at −3 dB; the rail and the content change are silent (sub-navigation).
5. **Toggle** — a **lamp key** (the window bar, 219): a square latching push key with a small lamp window across the
   middle of its face, its state word (ON/OFF) beside it. ON latches it down and lights the window. It reuses the button's press, so the UI has one kind of
   key, not a separate switch control. Sound: `ui.button.press`, then the latch: `ui.toggle.on` or `ui.toggle.off`.
   §15.4.
6. **Resource counter** — caption with its lamp on the same line, then glyph + value grouped by spacing (no box),
   forecast below. Sound: `ui.counter.tick` per rolled step, `ui.resource.gain` / `ui.resource.loss` as the lamp
   pulses.
7. **Card** — §6.7. A pile of cards (deck, discard, a supply pile) is an **index pile** that deals out into a grid
   when clicked (§15.13). Sound: card stock and paper: `ui.selection`, `ui.card.lift`, `ui.card.place`; a pile
   `ui.pile.deal` / `ui.pile.gather`. Hover: None.
8. **Panel / drawer** — `sheet`, square, title block, `shadow.lift` when it overlaps content, none when docked.
   Sound: runners and a felt stop, `ui.panel.open` / `ui.panel.close`.
9. **Tooltip** — a printed tab: `ink` fill, `sheet` text (inverse) in Night and Paper alike, `radius.0`, a 6 px
   triangle notch toward the target, max 320 px wide. Sound: None (it answers a hover, and hover is silent).
10. **Notification flag** — a pennant that slides out from the left rail: a `sheet` strip, 4 px hue bar on its left
    edge, glyph, one line of text. Sound: the rail lamp's bell, `ui.notification`, in one of three patterns.
11. **Indicator lamp** — a 10–14 px disc. OFF: `well` with 1 px `rule` ring. ON: the hue's plane colour plus a 2 px
    ring of its line colour and a single small highlight dot (the only permitted radial). Lamps always sit beside a
    printed label. A lit lamp also marks the chosen row of a selectable list (§7.16); there it lights with no
    starburst, as part of the selection. Sound: None of its own; a lamp that lights to report news carries that news's
    tone (`ui.confirm`, `ui.notification`), a selection lamp the selection's tick, and a lamp going out is always silent.
12. **Progress indicator** — segmented: a `well` track divided into discrete cells (one per unit when ≤ 12, else
    percentage blocks of 10%) that fill with the hue plane. Never a smooth gradient bar. Sound: None while it fills;
    completion plays `ui.confirm`, unless the completion is itself a game event with its own sound.
13. **Gauge** — a half-dial for bounded values (unrest vs limit): a 180° arc in `rule`, coloured zones (sage / ochre /
    brick) on its outer edge, a single `ink` needle with a 2 px hub. Sound: None (the counter it mirrors already
    ticks).
14. **Modal** — a drafting sheet: `sheet`, `shadow.sheet`, title block, footer rule above its actions (primary
    right, secondary left of it), Esc / Close closes. Sound: a drafting sheet laid down and lifted,
    `ui.sheet.open` / `ui.sheet.close`; the scrim is silent.
15. **End-turn control** — §11.9 and §15.12. Sound: the desk's heaviest key and a relay behind the panel,
    `ui.endturn.press`, `ui.endturn.commit`, `ui.endturn.turn`.
16. **Selectable list** — a **lamp** list (217; quieted in 356, chosen from
    [list-quiet-options.html](mocks/list-quiet-options.html), option H; the first alternatives are in
    [list-options.html](mocks/list-options.html)): rows printed on a `well`, no box, `ink-2` label in `type.label`.
    The one selected row is marked in place, with no depth: its background fills with a `sheet` strip, its label
    inks, and a lit **indicator lamp** (§7.11, 12 px, sage) shows before its name, `space.4` in from the row's edge
    and `space.3` before the text. The other rows carry no lamp but keep its room, so no label moves. Nothing slides,
    nothing casts a shadow, and the signal colour is left to the sheet's primary action. Hover only inks the label.
    Focus keeps its teal ring, so focus and selection read apart. A click or Up / Down selects. Headings group the
    rows in `type.label-caps`; a heading after rows has `space.5` above it, and the first opens the well. A list
    beside a detail holds the detail at its tallest item's height, so changing the selection never moves the sheet.
    A list taller than its column scrolls (§7.17) and follows the selection. Sound: `ui.selection` as the lamp lights.
17. **Scroll area** — content taller (or, in the hand, wider) than its box glides rather than jumps (356, 363). A
    wheel notch gives the content a push that decays, so it eases about 120 px and coasts to rest in about half a
    second; a trackpad's stream of small pushes adds up the same way, and a sideways area takes the sideways wheel too.
    It stops dead at either end, with no bounce. When the keyboard moves a selection out of view, the area eases it
    back into view (200 ms, `machined`, no overshoot). Its **scrollbar** is a thin steel bar, upright or sideways: an
    8 px `steel` grabber, square, on a `well` track, `ink-2` under the pointer and while dragged; it shows only when
    the content overflows. Reduce motion: a notch and a follow jump (§9.5). Sound: None (moving within a screen is
    silent, §10.2). Used by every scroll area: the Build list, the Knowledge screen, the renewal ledger and the Realm
    (362), and sideways the hand (363).

---

## 8. Iconography

Icons are drawn on a **24 px grid with a 2 px live-area margin** (20 px live area), as if cut from a stencil.

| Property | Value |
|---|---|
| Stroke | 2 px at 24 px (scale with the icon: 1.5 px at 16, 2.5 px at 32). One stroke weight per icon. |
| Line caps / joins | Square caps, mitred joins. No round caps (that's the SaaS look). |
| Corners | Sharp. Curves are true circular arcs only (compass-and-ruler geometry). |
| Primitives | Circle, square, equilateral triangle, straight lines at 0°/45°/90°. No freehand. |
| Detail | ≤ 5 primitives per icon. If it needs more, it's an illustration (§19), not an icon. |
| Optical size | A solid glyph carries more weight than an outlined one, so it is drawn about 20% smaller on the grid (the unrest bolt spans 16 of the 24 units, not 20) to sit at the same visual height as its neighbours and the figure beside it. |
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
- **Sound marks contact, not travel.** A moving part is heard where it meets something: the key bottoming, the
  latch catching, the drawer reaching its stop, the digit landing. Travel itself is silent, or at most a quiet rail
  texture under a panel-sized move. Sound never precedes the motion it belongs to (§16.5).
- **Never wait on a frame that won't come.** Every transition also has a timer for its own duration; if the animation
  hasn't finished by then (a hidden or minimised window), it jumps to its end state, so input is never left locked.

### 9.2 The six primitives

| Primitive | Physical model | Property | Typical travel | Curve | Sound partner (§16.3) |
|---|---|---|---|---|---|
| **Slide** | A drawer or cabinet door on rails | position on one axis | 8–24 px for elements; panel width for panels | `ease.machined` in, `ease.release` out | Element slides: silent, or the stop only. Panel slides: a quiet rail run under the travel, a felt stop or latch at the end. |
| **Snap** | A switch or latch hitting its detent | position or state, very short | 1–4 px | `ease.snap` | A key switch's snap and bottom-out, the bottom-out at contact; a latch's detent. The most common sound in the game. |
| **Roll** | An odometer drum or split flap | a digit's vertical offset, flap rotation | one digit height per step | `ease.linear-step` per step | A tick as each digit lands (≤ 8 per roll); one flutter per split-flap word, not one per character. |
| **Wipe** | A drafting sheet or blind drawn across | clip rect / underline width | full element | `ease.machined` | Paper on paper, only for sheet-sized wipes (navigation, ceremonies). Underlines and tags wipe silently. |
| **Rotate** | A rotary control or gauge needle | rotation | ≤ 90° for controls; any for needles | `ease.machined`, needle `ease.damped` | A control: one detent per step. A needle: silent. |
| **Pulse** | A lamp switching on | brightness of a lamp; a 1–2 px ring | none | `ease.lamp` (fast on, slow decay) | Silent, unless the lamp reports news; then that news's tone, at lamp-on. Lamps go out silently. |

Scale is **not** a primitive. Nothing scales on hover. Scale is allowed only for a lamp "on" bloom (ring 1.0→1.4,
fading); the Navigator's old "grow out of the card" transition became a wipe (350) and then a slide from the right
(§10.2, 359).
Likewise, no sound exists without a primitive under it: if nothing moves or lights, nothing is heard.

### 9.3 Easing curves

| Token | cubic-bezier | Character | Godot Tween approximation |
|---|---|---|---|
| `ease.machined` | (0.2, 0, 0, 1) | Fast start, long controlled deceleration, firm stop. The default. | `TRANS_QUART`, `EASE_OUT` |
| `ease.release` | (0.4, 0, 1, 1) | Exit: accelerates away, no decel. | `TRANS_CUBIC`, `EASE_IN` |
| `ease.snap` | (0.3, 0, 0, 1) at ≤ 90 ms | A detent. | `TRANS_EXPO`, `EASE_OUT` |
| `ease.latch` | (0.5, -0.2, 0.1, 1) | A small anticipation then travel. For drawers and the end-turn release. | custom interpolator (§17) |
| `ease.linear-step` | linear | Each odometer/flap step; the curve is in the *sequence* timing, not the step. | `TRANS_LINEAR` |
| `ease.damped` | (0.3, 0.8, 0.4, 1) | Gauge needle: ~2% overshoot, one settle. | custom, or `TRANS_QUART` `EASE_OUT` |
| `ease.lamp` | on: (0, 0, 0.2, 1) 40 ms; off: (0.4, 0, 0.6, 1) | Filament: on instantly, cools slowly. | on `TRANS_EXPO` out; off `TRANS_SINE` in-out |
| `ease.settle` | (0.2, 0.9, 0.3, 1.04) | Milestones only. | custom |

**Banned**: `TRANS_BACK`, `TRANS_ELASTIC`, `TRANS_BOUNCE` and springs, except `ease.settle` for milestone moments.
The current code uses `TRANS_BACK` for the pulse, the landing squash and the pip pop; these become `ease.snap` +
`ease.lamp`.

### 9.4 Timing table

Sound onsets are milliseconds from the start of the motion; "contact" is the frame the part reaches 90% of its
travel (§16.5).

| Interaction | Duration | Primitive & values | Curve | Sound @ sync |
|---|---|---|---|---|
| Hover feedback | in 90 ms, out 140 ms | Background one value step; shadow unchanged. Links: underline wipe 0→100%. | in `machined`, out `release` | None |
| Button press | 50–70 ms down | translate (+2, +2), shadow plinth→none: the button sits into its shadow. | `snap` | `ui.button.press`: snap ≈ 24 ms, bottom-out at contact ≈ 38 ms |
| Button release | 110–140 ms up | back to (0, 0), shadow restored. | `machined` | `ui.button.release`: upstroke snap ≈ 47 ms, top-out back at rest ≈ 65 ms |
| Toggle change | 70 ms latch + 40 ms lamp | The key over-travels 3 px while held, latches 2 px down (ON) or springs back (OFF); the lamp window and the state word change as the latch lands. | `snap` key, `lamp` | `ui.button.press` @ held contact; `ui.toggle.on` @ latch lands with the lamp, ≈ 38 ms; `ui.toggle.off` @ back at rest, ≈ 65 ms |
| Navigation transition | 280–360 ms | New screen wipes in from the side of its origin (left rail → right), old slides 24 px and fades out under it. | `machined` / `release` | `ui.nav.forward`: paper texture from 0, stop @ ≈ 172 ms; back: `ui.nav.back` |
| Panel opening (drawer) | 220–280 ms open, 180–220 ms close | Slide from its rail edge; contents fade in after 40% (stagger rows 20 ms, max 6 rows). | `latch` / `release` | `ui.panel.open`: latch tick @ 0, stop @ ≈ 164 ms; `ui.panel.close`: catch @ ≈ 187 ms |
| Modal appearance | 220–260 ms | Sheet slides up 24 px + opacity 0→1 over the first 120 ms; scrim fades 160 ms. Close: 160 ms, down 12 px. | `machined` / `release` | `ui.sheet.open` peaks as the sheet settles, ≈ 130 ms; `ui.sheet.close` @ 0 (the lift) |
| Resource gain | 600–900 ms total | Delta tag (+3) snaps in beside the counter (90 ms), the counter rolls, the lamp pulses once, tag holds 600 ms then wipes out (120 ms). | `snap`, `linear-step`, `lamp` | ticks during the roll; `ui.resource.gain` / `.loss` @ lamp-on. The tag is silent. |
| Counter increment | 60–80 ms per step, ≤ 8 steps visible | Odometer roll per changed digit column; for \|Δ\| > 8, roll the last 8 steps only. | `linear-step` | `ui.counter.tick` @ each step's landing; the jump past the first steps is silent |
| Selection | 100–140 ms | Card slides 12 px up out of its row; shadow none→lift; index tab (signal) wipes in on its top edge. | `machined` | `ui.selection` @ index tab lands, ≈ 65 ms. Deselect: None |
| Card text rise (383) | 120 ms rest, then 120 ms | A long hand card's text sheet slides up over its art plate by the hidden text's height (≤ the plate); back on leave. | `machined` / `release` | None |
| Rules wait (383) | 1.1 s | The *+N more* foot's dashed rule fills left to right with a 2 px `ink` bar; full, the rules popover opens (90 ms opacity + 4 px slide). | linear | None |
| List selection | 40 ms lamp, 120 ms fill | The row's `sheet` strip fills in place and its lamp lights; nothing moves. The old row's lamp goes out over 120 ms. | `lamp`, linear | `ui.selection` @ lamp-on (0 ms). Deselect: None |
| Scroll | ≈ 500 ms per notch | A wheel notch pushes the content, which decays (friction 8 / s) over ≈ 120 px and stops dead at an end; a keyboard follow eases 200 ms. | decay; follow `machined` | None |
| Confirmation | 240–320 ms | Lamp on, then a 6-ray starburst draws out from the lamp (rays wipe 0→8 px, then fade 160 ms). | `lamp`, `machined` | `ui.confirm` @ lamp-on (0 ms); the rays are silent |
| Build ceremony (§10.8, 357) | ≈ 1.4 s, from the Build sheet's close | The card is in its slot as the sheet closes; 160 ms later a lamp ring blooms off its edge (0→12 px, fading, 450 ms), 12 rays draw out from 8 px off its edge (0→24 px in 200 ms, fade 200 ms), and 120 ms after the ring a BUILT tag snaps onto its top-right corner (4 px drop, 90 ms), holds 900 ms and wipes out to the right (140 ms). Ring and rays in the card's plane colour, the tag `signal`. | `lamp`, `snap`, `machined` / `release` | `ui.milestone.build` (`ui.milestone.recruit` for a unit) @ the ring's lamp-on; `ui.flap` as the tag lands |
| Error feedback | 240 ms | One lateral **snap**: −4, +4, 0 px (80 ms each), border turns `danger`, ⊘ appears; message stays until the cause changes or 4 s. No shaking > 4 px. | `snap` | `ui.reject`: one tap per lateral stop, ≈ 44 and ≈ 124 ms |
| Major milestone | 1.2–2.0 s, skippable | Ceremonial sheet wipes across, display type split-flaps in by character (25 ms stagger), concentric-ring or 16-ray starburst motif draws, one `settle`. Click/Esc skips to the end state. | `machined`, `settle` | `ui.milestone.*`: sheet @ 0, flutter with the type, musical accent @ the motif's completion; a skip fades it in 30 ms |

### 9.5 Reduce motion

The game has Reduce motion (`Settings.reduce_motion`). With it on:

- Slide, wipe, roll, rotate → **instant**, plus a ≤ 120 ms opacity crossfade where a change of place would
  otherwise be unclear (navigation, modals). This matches `Anim.CALM_FADE_TIME` (0.15 s → 0.12 s).
- Pulse → the lamp switches on and **stays** lit for 1.5 s (no blinking); the delta tag holds 1.5 s.
- Scroll → a wheel notch moves the content its whole step at once, and a keyboard follow jumps (§7.17).
- Press feedback remains (it is 2 px and instant feedback, not decoration), but its tween becomes a frame switch.
- Milestones skip to their end state; the starburst is drawn static.
- Looping animation of any kind (the drop-zone pulse) stops; a static 3 px outline replaces it.
- A long card's text sheet jumps up instead of sliding; the rules wait's gauge fills in three equal steps (it keeps its
  1.1 s, as it is a timer, not decoration); the rules popover appears without its slide.
- **Sound is unchanged** in kind and level. Where a motion becomes instant, its contact and its stop are the same
  frame, so it plays the stop sound only (the drawer's felt stop, the latch, the sheet settling) and drops any travel
  texture; an instant counter plays one tick and its registration, not a run. A player who reduces motion may lean on
  sound for confirmation, so Reduce motion never silences feedback (§12).

---

## 10. Interaction patterns

### 10.1 Buttons
Industrial push-buttons. Pressing moves the face **into** its shadow: +2, +2 px and the plinth shadow disappears, so
it reads as depressing into the desk. No scale, no ripple, no colour flash. Release returns in 120 ms. Keyboard
activation (Space/Enter) plays the same press/release. A held button (End turn's hold-to-skip-confirm if added)
shows a fill wiping left→right across its face.

**Sound.** Every key sits on a clicky key switch (chosen in [click-options.html](mocks/click-options.html), option G).
`ui.button.press` is two-stage, like the switch: the click jacket snaps at actuation (≈ 24 ms in), then the stem
bottoms out on the housing as the face reaches the desk (≈ 38 ms). `ui.button.release` is the switch coming back up,
quieter: the upstroke snap, then the top-out as the face reaches its stop (≈ 65 ms after release). The action still fires on release; whatever it starts makes its own sound with its own motion. Hover
and focus are silent. A press that is dragged off the button before release plays the press and
a release, but nothing fires, as the eye sees. A press on a disabled button doesn't travel and plays the dead tap of a
locked key, `ui.reject.locked`, while its reason tooltip appears at once instead of after the hover delay, so the
sound never explains anything the screen doesn't. A held button is silent while its fill wipes, and plays the release
when it commits.

### 10.2 Navigation
Screens are **sheets on rails**. The Knowledge (tech) screen comes from the right, a territory's view and the Supply
from the right as well, the log drawer from the left rail. Each sheet carries the `ScreenHeader` title bar (241): filled with the screen's colour, its left end the index tab
of the sheet underneath ("◂ Realm", the board's colour, slanted right edge) that takes you back; going back
slides it out the way it came. A sheet runs in its own width from the play area's right edge in 320 ms
(`machined`) while the sheet under it moves 24 px left, and runs back out in 260 ms (`release`). A territory's view
opens this way too (359), not out of its card: a wipe from the card's rectangle (350) was tried and dropped, since
the territory's card is small next to the sheet and the wipe read as a zoom.

**Sound.** A screen is a sheet run along a straightedge, so it sounds like paper on a rail: `ui.nav.forward`, a
soft texture that starts with the wipe and a quiet stop as the sheet lands (≈ 172 ms); `ui.nav.back`, the sheet run
back with no stop, since it slides away out of sight. Only primary screens (Knowledge, Supply, a territory) have this
sound. Moving within a screen (tabs, an era band, scrolling the tech tree) is silent apart from the key that was
pressed. There is no whoosh: the sound is never louder or longer than the sheet's motion.

### 10.3 Counters
Every changing number uses a discrete mechanism:
- **Odometer** for resources and score (digits roll vertically, increasing rolls up, decreasing rolls down).
- **Split-flap** for words and the turn number/era: each character flips through ≤ 3 intermediate glyphs.
- **Tally** for small integers shown as pips (pop, housing, actions left): pips switch on one at a time, 60 ms
  apart, left to right.
No smooth numeric interpolation (no 4.37 frames). The final value appears no later than 600 ms after the action
so a fast player is never waiting.

**Sound.** Each mechanism ticks the way it moves. An odometer plays `ui.counter.tick` as each digit lands, at most 8
per roll (the roll shows at most 8 steps; the jump before them is silent), each tick 1 dB quieter than the last, so
a run reads as one gesture; the last step doesn't tick but registers (§10.4). A split-flap word plays one `ui.flap` flutter for the whole word, never one per
character. A tally plays one tick per pip, 60 ms apart. When several counters move at once (upkeep), they share one
tick stream capped at one tick per 35 ms (§16.8). No coins, no cash-register bell.

### 10.4 Resource gain/loss
`+3` snaps in to the right of the counter in `type.numeral-s`, sage for gain, brick for loss with a `−` sign
(U+2212); the counter rolls; the resource's lamp pulses once. Several changes from one action **merge** into one
tag per resource (the engine already reports a net change, 126). Tokens flying across the screen are reserved for
the rare, important transfer (paying a cost from a card to the bar, buying a Wonder); the current per-change
floating tokens (114, 126) become delta tags.

**Sound.** The roll ticks (§10.3), then the counter registers its new total as its lamp pulses: `ui.resource.gain`,
a drum locking in with a whisper of the lamp's tone, or `ui.resource.loss`, the same lock a little lower and duller,
with no tone. The two differ as much as + and − do: enough to tell apart, not so much that losing sounds like a
punishment. A loss that matters (starving, unrest at its limit) is announced by its notification flag, not by a louder
loss. The delta tag is silent. One registration per resource per action, because the tags already merge.

### 10.5 Selection
A selected card **slides 12 px out of its row** (out of a stack, like pulling an index card up from a file),
gains `shadow.lift` and a 3 px `ink` border, and a signal-orange **index tab** (24×6 px) wipes in on its top edge.
Hover (not selected) only gives `shadow.plinth` + 4 px slide. Nothing scales. (Today's hand hover scales 1.08 and
lifts 20 px; it becomes 0 scale and 8 px.)

A row of a selectable list is not a thing to pick up, so it is selected **in place**: its strip fills and its lamp
lights (§7.16), with no slide, shadow or tab (356).

**Sound.** Selection is the most frequent act in the game, so it is nearly silent: `ui.selection`, the tiny
plastic tick of an index tab clipped onto the card, as the tab lands. Deselecting, hovering and moving the keyboard
focus across cards are silent. A drag plays `ui.card.lift` as the card leaves its row (the "click before lifting" in
§15.6), nothing while it travels, then `ui.card.place` as it lands, or `ui.reject` if the drop is refused.

### 10.6 Panels
Drawers (log, notifications history) slide from a rail with `ease.latch`. Cabinet-door panels (government overlay,
explore choice) work in two moves: the two halves **close** over the current screen from the sides and meet at a
centre seam (200 ms `machined`), hold 60 ms, then **part** to reveal the choices beneath (260 ms `latch`). Making the
choice runs the same two moves the other way: close over the choices, part onto the board.
Layered plans (tech tree eras) stack as offset sheets, 8 px right and down per layer; bringing one forward slides
it out of the stack and back on top.

**Sound.** A drawer runs on ball-bearing runners and stops against felt: `ui.panel.open` is a small latch tick as
the `latch` curve's anticipation lets go, a quiet rail run that fades as the drawer decelerates, and a soft stop at
≈ 164 ms; `ui.panel.close` runs and catches with a latch as it shuts. The sound lasts as long as the slide, never
longer. Cabinet doors are heavier partitions: `ui.cabinet.close` runs both doors and lands one damped meeting at the
seam (≈ 108 ms); after the 60 ms hold, `ui.cabinet.part` lets the latch go and stops the doors at their sides. Bringing
an era sheet forward is silent (sub-navigation).

### 10.7 Notifications
A **flag** slides out of the left rail (from x −100% to 0 in 200 ms, `machined`), holds, then slides back in
(160 ms). One at a time; queued flags stack below at 8 px gaps, max 3, older ones collapse into a count badge on
the rail. Each flag has a hue bar, glyph and one line; urgent ones (famine, anarchy) don't auto-dismiss and stay
until resolved. Flags carry no indicator lamp; the **rail** does: one lamp per notification category, which lights
(40 ms `lamp-on`) as a flag of that category arrives and stays lit while an urgent one is unresolved, so a dismissed
or collapsed flag still leaves its trace on the rail.

**Sound.** The rail lamp has a small bell and a tone generator behind it: `ui.notification` sounds once as the flag
reaches full extension, with the lamp. Priority is told by **pattern**, never by volume: information is one pulse
(●), a caution two even pulses (●●), an urgent flag a falling pair (●↘●). Queued flags sound one at a time, at least
400 ms apart; a flag that collapses into the count badge is silent; flags leaving are silent. An urgent flag sounds
once, not again while it persists: its lit lamp and its persistence are the reminder.

### 10.8 Success / confirmation
The lamp next to the control lights, then a small starburst (6 rays, 8 px) draws out from it and fades. The burst
is centred on the lamp: each ray rotates about the lamp's centre and grows outward from 1 px beyond its rim
(radius 9 → 17 px), so the lamp sits exactly in the middle of the rays. For
bigger confirmations (tech learned) the tech's tile gets a full 12-ray burst behind its glyph for 400 ms and the
tile's band fills in with a left→right wipe. Large sequences only for era changes and victory.

**Sound.** `ui.confirm`, one warm, restrained tone from the lamp's tone generator, as the lamp lights; the rays are
silent. A stronger routine confirmation (choosing a government, a treaty signed) may use the two-note form, a rising
fourth. Neither is ever layered, musical or longer than 250 ms, so a confirmation can't be mistaken for an
achievement. Learning a tech is an event, not a confirmation: it plays `ui.milestone.breakthrough` (§11.3).

**Building is an event too (357).** Building on a territory, recruiting a unit and building an upgrade end in a small
ceremony on the new card, between a confirmation and a milestone (timing in §9.4): the lamp ring and a 12-ray
starburst in the card's plane colour, then a stamp. The stamp is a tag in `signal` with `on-signal` capitals, "BUILT" or
"RECRUITED", snapped onto the card's top-right corner, and it wipes out after 900 ms. An upgrade has no card of its own
(it is a ribbon on its base), so the ring and rays play on the building it upgrades, with no stamp. Nothing moves the
card: it is in its slot as the Build sheet closes, and the ceremony starts once the sheet has cleared it (160 ms). A card
that reaches the board any other way (dealt, settled, created by an effect) keeps its usual arrival. With Reduce motion
the ring and rays are drawn at full size, static, and the tag shows without its drop; all three hold 1.5 s and go
without a wipe (§9.5). The sound is unchanged: `ui.milestone.build` (a ribbon cut: a relay, a muted-piano pickup, a
D major chord ringing out over a low D) or, for a unit, `ui.milestone.recruit` (two low drums, a drum with a snare, a
short horn call A3 → D4). Both sit at +9, under every other milestone.

### 10.9 Errors and refusals
An action the engine refuses (an invalid drop, a play the `*_error` query forbids) is refused the way a mechanism
refuses: the thing tries to go, meets a stop, and returns. Visual: border to `danger`, ⊘ and the engine's reason in
words. Motion: the error snap, −4, +4, 0 px. Sound: `ui.reject`, a muted, low double tap, one tap at each lateral
stop (≈ 44 and ≈ 124 ms), with no buzzer, no tone and nothing louder than a button press. A control that can't move
at all (disabled) plays the single dead tap `ui.reject.locked` (§10.1). The reason stays on screen until the cause
changes or 4 s pass; the sound plays once.

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
Sound at rest: nothing. The interface has no ambient bed, hum or clock tick; the desk is silent while the player
thinks, and every sound is the answer to something they did or something the turn did.

### 11.2 Resource bar
A row of **instrument cells**, each 160 px wide, divided by 1 px vertical `rule-fine` lines (like a Braun radio's
dials). Each cell: `type.label-caps` caption top-left ("FOOD") with the cell's lamp at the right end of the same
line, centred on it; glyph (32 px) + odometer value, 8 px apart with no box around the figure (the odometer clips
its digits invisibly); and
the next-upkeep forecast in `type.caption` below (`+2 next`, sage; `−1 next`, brick with ◆ caution glyph if it would
starve). Unrest shows as a small half-gauge against its limit instead of a number when the limit is ≤ 10.
Hover a cell → the forecast tooltip (the existing one). A cell whose value is at a limit or dangerous lights its
lamp (brick) and its caption reads "AT LIMIT", so the state is in words too.
Sound: each cell ticks and registers (§10.3–10.4); cells changing together share one tick stream, and their
registrations follow the same 60 ms left-to-right tally as their tags. A lamp lighting for AT LIMIT is silent; the
state that matters arrives as a caution flag with its own sound. The tooltip is silent.

### 11.3 Technology / research (Knowledge)
A **drafting sheet / chart plotter**. Eras are horizontal bands like floors on an architectural section, each with
an era title block at its left. Techs are index-card tiles on the grid; prerequisites are drawn as 1 px `ink`
orthogonal lines with 90° corners (a circuit/plot, never curves), terminating in a 4 px dot.
- Researched: filled band in teal plane, filled glyph, lamp on.
- Available: `sheet` tile, 2 px `ink` border, cost top-right as on cards; hover slides it 4 px and adds `shadow.plinth`.
- Locked: `well` tile, `ink-3` text, prerequisite lines dashed, the ⊘ glyph with "Needs Pottery".
- Future era: the band is covered by a **vellum overlay** (`sheet` at 88%) with the era name printed on it.
Learning a tech: the lines from its prerequisites draw in (wipe along the path, 240 ms), the band fills, the lamp
lights, a 12-ray burst. Newly available techs light their lamps in sequence (tally, 60 ms).
Sound: learning a tech is the game's most frequent event, so it gets the shortest Level 3 cue,
`ui.milestone.breakthrough`: a plotter pen's soft scratch under the drawing lines, then a three-note vibraphone
figure rising as the lamp lights (≈ 240 ms in), ≤ 900 ms in all. The newly available lamps light silently. If
playtests show techs arriving most turns, breakthrough steps down to Level 2 (`ui.confirm` in its two-note form) and
Level 3 is kept for eras (§16.4).

### 11.4 Production queue (Supply / building slots)
The game has no city production queue; its equivalents are the **Supply** (Buy Cards) and building slots. Treat
both as a **filing system**: a horizontal rack of slots drawn as `well` recesses with 1 px `rule` edges; filled
slots hold index cards standing upright; empty slots show a dashed outline and "EMPTY SLOT" caption. Buying a card
slides it out of the supply rack (up 16 px), then it travels (one direct slide, 300 ms) to the discard/deck counter,
which rolls. Sound: the Buy key's press and release, `ui.card.lift` as the card leaves the rack, silence in flight,
`ui.card.place` as it lands on the pile, and the pile's count tick; the wealth paid registers as a loss. If a queue is ever added: a vertical list of numbered rows (`01`, `02` in Plex Mono), the active row
with a progress segment bar and a lit lamp, reordering by drag with a 2 px ink insertion rule.

### 11.5 Diplomacy (future)
A **conference table plan**: each civ is a seat around a circle drawn in 1 px `rule`, with its emblem (a geometric
monogram in a circle) and its attitude as a lamp + word ("CORDIAL", "WARY", "HOSTILE"). Treaties are index cards
between the seats. Proposals open as a two-column **memorandum** modal: "WE OFFER" / "WE ASK", each a ledger list
with right-aligned values, a hairline total, and a signature line where the primary button (signal) sits. A
response arrives as a split-flap stamp on the memo ("ACCEPTED" sage / "DECLINED" brick) — the word is the state.
Sound: the memo is a modal (`ui.sheet.open`); the response flaps in with one `ui.flap`; a treaty accepted is a major
diplomatic event, `ui.milestone.accord`, two muted-piano chords; a refusal is a caution flag's pattern (●●), never a
rejection buzz, since the player made no error.

### 11.6 City / settlement management (territory view)
The territory replaces the Realm (105). Present it as a **site plan**: a title block (territory name, its keywords as
small caps tags), the building slots as a row of plan rooms (rectangles with 1 px walls, a room label in the corner),
and the pop meter (§11.7). Entering: a sheet from the right, as Knowledge (§10.2). Workers assigned to a building
appear as filled teal figures in the room's corner; idle buildings get a hatched floor and an ochre caution lamp
with "IDLE".
Sound: entering is navigation (`ui.nav.forward`). Placing a worker plays `ui.selection` (a marker set on a plan) as
the figure fills; the idle lamp is silent. Founding a city (settling a territory) is an event: `ui.milestone.city`, a
heavier latch, like a plan being stamped, and two marimba notes. Building on it is a smaller event, the build ceremony
(§10.8): `ui.milestone.build`.

### 11.7 Population
Pop is a **tally counter** of pips (the meter, 124). Pips are pop figures at the stats line's text size (242) in a
`well` track: filled teal for pop, outlined for housing room. Grow is a push-button labelled with its food cost in
the territory view's actions row below the meter (227). Growing: the button presses (§10.1), then the pip turns into a
lit disc (lamp on 40 ms) and the food counter rolls down. Starvation risk: the rightmost pips get a brick ring and
the meter caption reads "WILL STARVE".
Sound: the Grow button's press and release, one `ui.counter.tick` as the pip lights, then the food counter's roll and
`ui.resource.loss`. The starvation ring is silent here; the famine flag carries the alarm.

### 11.8 Map overlays (the Realm)
The Realm is a tableau, not a map, but overlays apply to it: targeting, frontier, and explanation modes are
**drafting overlays**, sheets of vellum laid over the board:
- Vellum: `sheet` at 88% over everything not relevant; relevant cards show through cut-outs (no blur).
- Valid targets: 2 px `ink` dashed outline (dash 6/4) + a lit lamp on each; invalid: unchanged under the vellum.
- Frontier (unsettled land): the existing 45° hatch, in `rule-fine`, 8 px pitch.
- Overlay in/out: the vellum wipes across from the side the drag started (180 ms).
- Sound: None. The vellum arrives because a card was picked up, and the pick-up already spoke; the target lamps light
  silently. One gesture, one sound.

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

Sound, the one sequence the player hears every turn, so it is firm but never cinematic. Its one musical moment is a
quiet chord on the turn that walks with the turns, so forty of them in a row read as a phrase, not a jingle (246):

| Moment | Visual / motion | Sound | Sync |
|---|---|---|---|
| PRESS | face travels 4 px into its plinth, 70 ms `snap` | `ui.endturn.press`: the same key switch, with a deeper bottom-out than any other key | snap ≈ 24 ms, bottom-out at contact ≈ 38 ms |
| COMMIT | release; the lamp goes out; BUSY | `ui.endturn.commit`: a two-stage relay closing behind the panel | key back at rest, ≈ 65 ms after release |
| TURN | the turn plate flaps to N+1; the event card slides in | `ui.endturn.turn`: a vibraphone chord with a slow tremolo, Dmaj9 voiced D3–E5, walking I–vi–IV–V (D, Bm, G, A) by the turn that ended: ending turn T plays chord (T − 1) mod 4; the event card's `ui.card.place` as it lands | first flap |
| UPKEEP | delta tags and rolls, 60 ms apart | the shared tick stream and one registration per resource (§10.3–10.4) | per step |
| READY | fill back to signal, lamp on | None: the lamp says ready; a sound here would nag | — |

Every sound in the sequence starts within the motion's 1.2 s, and only the chord's ring outlasts it. A click that skips the
choreography drops the sounds still to come and fades those playing in 30 ms. Pressing a BLOCKED End turn plays
`ui.reject.locked` and the reason caption is already showing.

### 11.10 Modal dialogs
Drafting sheets. Title block (4 px bar, title left, context right), body in `type.body` at max 640 px, footer above
a hairline: secondary actions right-aligned, primary rightmost. Esc and a click on the scrim close (ModalStack, 153).
A modal opened over a modal is offset +8, +8 px from the one beneath, so the stack reads as stacked paper.

**Modal layouts** (344). Every sheet is one of three; the title block and footer are the same in all of them.

| Layout | Body | Width | Used by |
|---|---|---|---|
| **Text sheet** | Text, in `type.body` | Body ≤ 640 px: the measure (§7) | Abandon, Revolt, Rename, the menu, settings, events |
| **Card sheet** | A hand-size card in the aside (left), then a text body | The aside is outside the cap; the body ≤ 640 px | Card details, the event and raid cards (`show_card`) |
| **Ledger sheet** | A list column, then `space.6` (32 px), then a detail column: the selected entry's hand-size card, then `space.5` (24 px), its flavor (italic, dim; 354), `space.5` again (360), and its lines | List 384 px + 32 + detail 264 px = 680 px; no 640 cap | The Build modal |

A ledger sheet keeps the measure inside each column instead of across the body: the list's rows wrap at the column's
384 px (a name and cost, a reason under it), and the detail's flavor and lines wrap at the card's 264 px. The list shows 12
one-line rows (480 px) before it scrolls (a scroll area, §7.17, that follows the selection), and holds that height
whatever is selected, so changing the selection never moves the sheet. Its headings (Buildings, Upgrades, Units) each
have `space.5` above them after the first, so the groups read apart. A sheet that needs more than this (several cards compared, many builds in a row) is a screen,
not a modal. In code: `Modal.BODY_MAX_WIDTH` and `Modal.LEDGER_*`.
Sound: `ui.sheet.open`, a sheet laid on the desk, peaking as it settles; `ui.sheet.close`, the sheet lifted, at once.
A stacked modal plays the same lay, 1 dB quieter (it lands on paper, not on the desk). The scrim is silent. Choosing in
a cabinet-door overlay plays the doors (§10.6) and the choice's `ui.confirm`.

### 11.11 Tooltips
Printed tabs: `ink` fill, inverse text, square corners, a 6 px notch. Appear after **400 ms** hover delay (0 ms when
moving between adjacent tooltip targets), with a 90 ms opacity + 4 px slide from the target. Content: a
`type.label-caps` heading, then `type.body-s`. Numbers in a tooltip line up in a small two-column ledger
(the upkeep forecast: one row per source, a hairline, the net).
Sound: None, in every state. A tooltip answers a hover, and hover is silent.

**The rules popover** (383) is the same printed tab, 320 px wide, beside a hand card whose rules don't fit even after
its text sheet rises (§6.7): right of the card, or left when the right has no room, its notch toward the card. It
opens after the 1.1 s gauge, not the 400 ms delay. Content: the card's name as the `type.label-caps` heading, the
long-form rules, then the play error and its detail if any. It isn't a modal: the pointer may move onto it without
closing it, and it stays until the pointer leaves both, Esc, or a press (WCAG 1.4.13: hoverable, dismissible,
persistent). It replaces a hand card's plain tooltip: a card whose rules fit has no hover popup, since its reason
strip is on the face and its details are a click or `I` away. It shares the counters' popover control (379).

### 11.12 Victory / progression
Era change and game over are **ceremonial sheets**: full-screen `sheet` (lighter than the board, so the wipe reads)
with a 4 px `ink` **straightedge** riding the wipe's leading edge, and a centred (the one allowed centring)
composition: era or result in `type.display-xl` split-flapping in; a large geometric motif (concentric rings for an
era, a 16-ray starburst for victory) drawn with wipes in 400 ms; the score in an odometer that rolls from 0 with
digits settling right-to-left. Below, a ledger of the score breakdown (category left, right-aligned VP) with a
double rule above the total. One primary button ("New game"). A click while it plays skips to the end state; the
next click continues (a click that lands before the sequence settles is remembered, never dropped). Reduce motion shows
the end state directly.
Sound: these are the Level 3 sequences, `ui.milestone.era` and `ui.milestone.victory` (§14.1, §16.7). Each layers
the mechanism under the music, in step with the picture: a brushed swish under the sheet's wipe, a flap flutter as the
title types in, a relay bank as the motif draws, then a vibraphone and muted-piano figure resolving as the `settle`
lands; the score's odometer ticks are dropped (the music carries it). Music ducks 6 dB beneath it. A skip fades the
sequence in 30 ms and plays only the final chord's tail. With Reduce motion, the final chord plays with the end state.
Defeat uses the same mechanism and a falling cadence: dignified, never mournful.

### 11.13 Deck, discard and supply piles
Every pile is an **index pile** (§15.13): face-up cards squared on the desk with up to four edges stepping out 3 px
down and right, the top card readable, and its count printed beneath as `DISCARD 7` (`type.label-caps` + Plex Mono
figure). The draw deck is the same pile face down (the card back's ring motif) and never deals out, since its order
is hidden; a supply pile shows its top copy. Clicking a face-up pile **deals it out into a grid**, the top card
staying put and the rest sliding to their places 30 ms apart; clicking again gathers them back. A pile too big for the
space it deals into (past about eight cards) **unfolds into a sheet** instead: a panel wiping out of the pile's own
rectangle with every card as a header tile (a clip rect growing from the pile's bounds to the sheet's).
Sound: `ui.pile.deal`, one short riffle of card stock across the whole deal (never one sound per card), ending as the
last card lands; `ui.pile.gather`, a shorter riffle and the soft tap of the pile squaring. The unfolding sheet plays
`ui.nav.forward`. The count ticks when it changes.

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
   Nothing on screen animates while the player is idle (the drop-zone pulse only runs during a drag). Their sounds,
   if any, are Level 1: ≤ 100 ms, the quietest in the game; hover's `ui.hover` is the quietest of them (245).
5. **Type floor**: nothing below 14 px; body is 20 px at 1080p. UI scale setting multiplies the whole type and
   spacing scale together (offer 90/100/115/130%).
6. **Focus** is always visible for keyboard play (teal ring, offset 2 px, square), never removed on mouse click.
   Focus order follows the reading order: rail → instrument strip → Realm → hand → End turn.
7. **Targets**: minimum 32×32 px hit area for anything clickable; pips grow their hit area to 32 px.
8. **Flicker**: no lamp blinks faster than 2 Hz, and no blinking at all for more than 3 cycles.
9. **Colour-vision check**: the support hues differ in lightness as well as hue (sage vs brick, teal vs ochre). Test
   with deuteranopia and protanopia simulations; danger vs positive must still separate by glyph *and* value.
10. **Never sound alone.** No information is carried by sound only. Every sound token has a visual twin that says the
    same thing, and that twin lasts at least as long as the sound (table below). A deaf player, or one playing muted,
    misses nothing.
11. **Separate volumes.** Settings (and the title screen, beside Reduce motion) offer Master, Music, Game (events) and
    Interface (clicks, panels, confirmations) levels, plus an **Interface sounds** lamp key (ON/OFF) that silences
    Levels 1 and 2 while keeping the event sounds. All four persist between launches.
12. **No sudden loud sounds.** Every bus has a limiter: Interface peaks never pass −18 dBFS, Game −10 dBFS, Master −1
    dBFS. Any musical or tonal layer attacks over ≥ 5 ms (no click at onset); a Level 3 cue opens with its quiet
    mechanism and stays ≥ 6 dB under its own peak for its first 20 ms, so an event never starts at full force.
    The first sound after launch, or after unmuting, can't be a Level 3 at full level: it ramps in over 300 ms.
13. **Reduce motion keeps sound; sound never needs motion.** Reduce motion changes no sound (§9.5). Sound is likewise
    never needed to understand a change: the static end state (rule 2) tells the whole story.
14. **Pattern before pitch.** Cues that must be told apart differ in rhythm and texture first (one pulse, two pulses,
    a falling pair; a tap, a double tap), and in pitch only second, for players who hear pitch poorly or have
    high-frequency loss. Nothing important lives above 4 kHz.
15. **Mono-safe.** Interface sounds are mono and centred; no information is in panning, so a player with one earbud
    or hearing in one ear hears everything.
16. **Nothing loops, nothing nags.** No interface sound loops or repeats on its own; an urgent flag sounds once and
    its lamp persists. Nothing sounds while the player is idle (rule 4's rule for motion, for the ear). The interface
    is muted while the window is in the background (a setting, on by default).

**Every sound's visual twin**

| Sound | Visual twin that carries the same information |
|---|---|
| `ui.button.press` / `.release` | press travel and shadow; the action's own result |
| `ui.toggle.on` / `.off` | the latched key position and the ON/OFF word beside it |
| `ui.selection`, `ui.card.lift` / `.place` | the index tab and 12 px slide; the card's new place |
| `ui.counter.tick`, `ui.flap` | the rolled digits, the flapped word |
| `ui.resource.gain` / `.loss` | the delta tag (with its sign and hue), the lamp pulse, the log line |
| `ui.panel.*`, `ui.sheet.*`, `ui.nav.*`, `ui.cabinet.*`, `ui.pile.*` | the panel, sheet, screen, doors or dealt cards themselves |
| `ui.confirm` | the lit lamp and starburst; the new state |
| `ui.reject`, `ui.reject.locked` | the error snap, `danger` border, ⊘ and the engine's reason in words |
| `ui.notification` (info / caution / urgent) | the flag (hue bar, glyph, words), the lit rail lamp; urgent flags persist |
| `ui.endturn.*` | the button's travel, its lamp, the BUSY label, the turn plate's new number |
| `ui.milestone.*` | the ceremonial sheet, the tile's burst and band, the log line |

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
| A latching lamp key with ON or OFF printed beside it | A rounded pill track with a circle thumb |
| A key switch's snap, then its bottom-out as the key meets the desk | One whisper-quiet `ui.hover` tick as the pointer enters an enabled key or actionable card | A sound on every pointer move, or a loud or musical hover |
| A drawer's rail run and felt stop, as long as its slide | A digital whoosh, or a sound that outlasts the motion |
| ≤ 8 ticks for a roll, then one registration | A tick per unit when wealth jumps by 40; a coin shower |
| A low double tap, one per error snap | A buzzer or a "wrong answer" honk |
| Priority by pattern: ●, ●●, a falling pair | Priority by volume |
| A vibraphone figure for an era or a breakthrough | A jingle for every confirmation |
| Dry Level 1 sounds; one small room for any reverb | Hall reverb on a button |
| Silence while the player thinks | An ambient UI hum or a ticking clock |
| Sounds implied by the mechanism on screen | Typewriter bells, cash registers, sci-fi bleeps, lounge music |
| A long card cut at a whole rule, with *+3 more* at its foot | A fade-out over the last line, a line sliced in half, or a card taller than its row |
| A gauge filling once in the foot before the rules popover opens | A card that trembles, pulses or changes colour to say a popup is coming |
| Card art in four flat inks on cream, overprinted where shapes cross (§19) | A painted, rendered or photographic picture; gradients and glows |
| An ancient scene drawn the way a 1958 magazine would draw it | 1950s people, cars or cocktails; boomerangs and atomic starbursts |
| Print texture inside a shape, once | Scratches, folds, stains or fake misregistration over the whole picture |

---

## 14. Design tokens

Values as they'd go into a token file. Godot equivalents in §17.

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
sound:                        # §16; per-token specs in §14.1
  ref: -26                    # dBFS peak of ui.button.press at full volume; levels are dB from it
  level:   { very-low: -8, low: 0, low-mid: 3, mid: 6, event: 12 }   # tokens may sit between steps
  bus:     { interface: [L1, L2], game: [L3], music: [] }
  volume-default: { master: 0.8, music: 0.6, game: 0.8, interface: 0.7 }
  ceiling: { interface: -18, game: -10, master: -1 }                  # dBFS peak, limiter per bus
  duration: { l1: [30, 140], l2: [100, 600], l3: [500, 2600] }        # ms
  sync:    { contact: 0.9, lead-max: 10, lag-max: 30 }               # fraction of travel; ms around the visual event
  key-switch: { snap-to-bottom-out: 14, snap-to-top-out: 18 }        # ms; the snap leads so the last stage lands on contact
  attack:  { mechanical: 1, tonal: 5, event-open: 20 }               # ms; a Level 3 stays ≥ 6 dB under its peak for event-open
  rate:    { tick-gap: 35, button-gap: 40, flag-gap: 400, voices-interface: 6, voices-game: 3 }  # ms; voices
  run:     { max-ticks: 8, tick-decay-db: 1 }                         # = the roll's 8 visible steps
  variation: { l1-variants: 4, l2-variants: 2, pitch-jitter-cents: 25, level-jitter-db: 1 }  # L1 only; never on tones
  filter:  { highpass: 150, shelf: 6000, shelf-db: -6, lowpass-l1: 10000 }  # Hz
  reverb:  { room-rt60: 400, wet: { l1: 0, l2: 0.05, l3: 0.18 }, tail-max: 800 }  # ms; one shared room
  duck:    { music-under-l3: -6, attack: 50, release: 400 }           # dB; ms
  tone:                       # D major pentatonic, so any two cues that overlap agree
    D4: 294  A4: 440  D5: 587  E5: 659  F#5: 740  A5: 880  B5: 988   # Hz
    home: E5                  # neutral (notification.info)
    up: A5                    # confirmation, activation, gain's whisper
    down: D5                  # where the urgent pair falls
```

### 14.1 Sound tokens

Every sound in the game is one of these tokens; nothing plays a file directly. Level is relative to `ui.button.press`
(0 dB = −26 dBFS peak). "st" is semitones. Duration runs from the transient to −60 dB. Sync times are for the full-motion durations of §9.4; with Reduce motion a
token plays at the instant change (§9.5). Frequency: **very high** = several per action, **high** = about once per
action or turn, **occasional** = a few per turn or fewer, **rare** = a few per game. File naming and variants: §16.10.

**Level 1 — micro-feedback** (Interface bus; dry; L1 variants and jitter apply)

| Token | Metaphor · character | Duration | Level | Pitch / timbre | Reverb | Sync point | Frequency |
|---|---|---|---|---|---|---|---|
| `ui.button.press` | A clicky key switch under ABS keycaps · two-stage: the click jacket's snap, then the stem's bottom-out 14 ms later | 50–80 ms | low (0) | a bright snap ≈ 4.5 kHz (12 ms), as loud as the bottom-out: a plastic clack ≈ 1.8 kHz over a ≈ 380 Hz case; primary button −2 st (a heavier cap) | none | bottom-out as the face reaches +2 px, ≈ 38 ms into the 70 ms press; the snap 14 ms before, at actuation | very high |
| `ui.button.release` | The switch coming back up · the upstroke snap, then the top-out 18 ms later | 40–70 ms | very low (−4) | the snap 5 dB under the press's; a lighter clack ≈ 2.2 kHz | none | top-out as the face is back at rest, ≈ 65 ms into the 120 ms release; the snap 18 ms before | very high |
| `ui.toggle.on` | The lamp key's latch catching, after the switch's press · a short, bright catch, no snap | 40–70 ms | low (0) | activation: brighter, a clack ≈ 2.4 kHz with a ≈ 3.3 kHz tick | none | latch lands at +2 px with the lamp window, ≈ 38 ms after release | occasional |
| `ui.toggle.off` | The latch letting go, the switch springing back · a soft upstroke snap, then the top-out | 50–80 ms | low (−2) | deactivation: −3 st, the snap 8 dB down, a duller clack ≈ 1.5 kHz | none | top-out as the key is back at rest, ≈ 65 ms after release; the snap 18 ms before | occasional |
| `ui.selection` | A plastic index tab clipped onto a card · a barely-there tick | 30–60 ms | very low (−8) | neutral-high, thin | none | the index tab lands, ≈ 65 ms | very high |
| `ui.card.lift` | Card stock leaving its row · a soft flick | 40–70 ms | very low (−6) | neutral; paper, 1–4 kHz | none | the card reaches −2 px, ≈ 33 ms | high |
| `ui.card.place` | An index card laid on the blotter · a soft, flat pat with a little body | 60–100 ms | low (−3) | neutral-low; ≈ 300 Hz body under paper | none | the card lands (start of its 60 ms landing snap) | high |
| `ui.hover` | A fingertip brushing a felt-lined key edge · a soft, dry, short tick | 15–25 ms | very low (−8) | neutral; ≈ 2 kHz soft tick over a ≈ 1.5× overtone, no body | none | the pointer entering an enabled key or an actionable card, including a territory view's city and buildings (342) (a press or drag in progress, a disabled key and a moving card are silent) | very high |
| `ui.counter.tick` | A drum counter's pawl advancing · a compact electromechanical tick | 30–60 ms | very low (−6; each later tick in a run −1) | neutral; ≈ 3 kHz click on a ≈ 1 kHz body; a downward roll −1 st | none | each digit lands on its next value (the last step registers instead) | very high |
| `ui.flap` | A split-flap word turning over · one short riffle of light flaps | 120–250 ms, one per word | very low (−8) | neutral-high, dry rattle | none | the first flap falls | occasional |
| `ui.resource.gain` | The counter's drum locking in, with the lamp's faint tone · "tk-clack" and a whisper of A5 | 80–140 ms | low (−3) | slightly elevated; the A5 tone 12 dB under the click | none | the last step lands, with the lamp pulse, in place of its tick | high |
| `ui.resource.loss` | The same lock, felted · lower and duller, no tone | 80–140 ms | low (−3) | −3 st; top rolled off above 2.5 kHz | none | as gain | high |
| `ui.reject.locked` | A key that won't go down · a single dead tap | 40–60 ms | very low (−4) | low; ≈ 250 Hz body, no click on top | none | pointer down (there is no travel to wait for) | occasional |

**Level 2 — structural feedback** (Interface bus; clearer identity, still restrained)

| Token | Metaphor · character | Duration | Level | Pitch / timbre | Reverb | Sync point | Frequency |
|---|---|---|---|---|---|---|---|
| `ui.panel.open` | A drawer on ball-bearing runners · latch tick, a quiet rail run, a felt stop | 220–280 ms | low-mid (+3 at the stop; the run 10 dB under it) | neutral-low; run below 4 kHz, stop ≈ 250 Hz | none | latch tick at 0 (the `latch` anticipation); stop at ≈ 164 ms of 260 | occasional |
| `ui.panel.close` | The drawer pushed shut · an accelerating run, a latch catch | 180–220 ms | low-mid (+3) | a little lower than open | none | the catch at ≈ 187 ms of 200 | occasional |
| `ui.sheet.open` | A drafting sheet laid on the desk · a soft paper lay | 120–200 ms | low (+1; a stacked sheet 1 dB less) | broadband paper, 300 Hz–4 kHz | minimal (≤ 5%) | swells from 0, peaks as the sheet settles, ≈ 130 ms of 240 | occasional |
| `ui.sheet.close` | The sheet lifted off · short and light | 80–140 ms | very low (−2) | thinner than open | none | at once: the lift starts the 160 ms close | occasional |
| `ui.nav.forward` | A sheet run along a straightedge · paper on a rail, a soft stop | 250–340 ms | low-mid (+2) | paper and a light rail; no whoosh, no pitch sweep | minimal | texture from 0; stop at ≈ 172 ms of 320 | occasional |
| `ui.nav.back` | The sheet slid back under the stack · a run with no stop | 200–280 ms | low (0) | slightly lower than forward | none | texture from 0, fading as the sheet leaves | occasional |
| `ui.cabinet.close` | Two partitions running to a centre seam · run, then one damped meeting | 200–260 ms | low-mid (+3) | low-mid body ≈ 200 Hz at the seam | minimal | the seam at ≈ 108 ms of 200 | occasional |
| `ui.cabinet.part` | The partitions released apart · latch, run, soft stops | 230–300 ms | low-mid (+2) | as close, lighter stops | minimal | latch at 0; stops at ≈ 164 ms of 260 | occasional |
| `ui.pile.deal` | Cards dealt out of a file · one riffle of card stock | 200–350 ms | low (0) | paper, 1–4 kHz | none | the first card leaves; ends as the last lands | occasional |
| `ui.pile.gather` | Cards squared back into a pile · a short riffle and a tap | 150–250 ms | low (−2) | paper; tap ≈ 300 Hz | none | the tap as the last card is home | occasional |
| `ui.confirm` | An indicator lamp with a tone generator · one warm, restrained tone; strong form: a rising fourth, E5 → A5 | 150–250 ms | low-mid (+4) | slightly elevated: A5, a soft square wave with the top rolled off above 2.5 kHz | minimal | the lamp lights (lamp-on, 0 ms) | occasional |
| `ui.reject` | A part meeting its stop twice · a muted, low double tap | 120–180 ms (taps 80 ms apart) | low-mid (+3) | slightly lower: body ≈ 200–300 Hz, no tone | none | each lateral stop of the error snap, ≈ 44 and ≈ 124 ms | occasional |
| `ui.notification` | A desk indicator lamp with a small bell · bell pulses in three patterns | info ● 200–300 ms; caution ●● 350–450 ms; urgent ●↘● 400–600 ms | mid (+6), the same for all three | info E5; caution E5, E5; urgent A5 → D5; a small bell's partials, soft attack | minimal (≤ 5%) | the flag reaches full extension with the rail lamp, ≈ 108 ms of 200 | occasional (urgent: rare) |
| `ui.endturn.press` | The same key switch under the desk's biggest key · the snap, then a firm, deep bottom-out | 80–120 ms | mid (+4) | the snap slightly lower; a deeper clack ≈ 1.3 kHz over a ≈ 200 Hz case and a 160 Hz thump | none | bottom-out at +4 px, ≈ 38 ms; the snap 14 ms before | high (once a turn) |
| `ui.endturn.commit` | A relay closing behind the panel · a two-stage clack, 12 ms apart | 80–140 ms | mid (+5) | low-mid: armature ≈ 300 Hz, contacts ≈ 1.2 kHz | none | the key back at rest and its lamp out, ≈ 65 ms after release | high (once a turn) |
| `ui.endturn.turn` | The turn's chord · a vibraphone struck once, its motor's tremolo in the tail; four files, one per chord of the I–vi–IV–V walk, picked by the turn (246) | ≈ 2.2 s | mid (+9; under every milestone) | Dmaj9 and its diatonic moves, D3–E5; top rolled off at 6 kHz | room 1.2 s, 25% | the turn plate's first flap | high (once a turn) |

**Level 3 — event feedback** (Game bus; layered, may be musical; ducks the music)

| Token | Metaphor · character | Duration | Level | Pitch / timbre | Reverb | Sync point | Frequency |
|---|---|---|---|---|---|---|---|
| `ui.milestone` | The base for every event: a relay bank, a mechanism moving, then a restrained musical accent | 500–1200 ms | event (+12) | D major pentatonic; vibraphone, marimba or muted piano over the mechanism | small room, ≤ 18% wet, ≤ 0.8 s tail | mechanism with the motion; the accent at the visual climax | rare |
| `ui.milestone.breakthrough` | A plotter pen, then a vibraphone triad rising D5–F♯5–A5 | 600–900 ms | event (+10) | vibraphone, motor off (no tremolo) | as base | pen with the prerequisite lines; triad as the lamp lights | the most frequent event (a few per era) |
| `ui.milestone.city` | A plan being stamped (a heavy latch), then two marimba notes, D4–A4 | 500–800 ms | event (+10) | marimba: wood, short decay | as base | the latch as the card becomes a city | rare |
| `ui.milestone.wonder` | A relay bank and motor, then a vibraphone chord with a small bell | 900–1200 ms | event (+12) | vibraphone D–F♯–A–E | as base | relays as the card travels; the chord as it lands | rare |
| `ui.milestone.accord` | Two muted-piano chords on the memo's stamp | 800–1200 ms | event (+10) | muted piano, A then D (a cadence) | as base | with the ACCEPTED flap | rare |
| `ui.milestone.era` | A brushed swish under the wipe, a flutter for the title, relays with the motif, vibraphone and muted piano rising to D | 1600–2000 ms (+ ≤ 0.8 s tail) | event (+12) | brushes, vibraphone, muted piano, a soft organ under the last chord | as base | swish at 0; flutter with the type; chord on the `settle` | a few per game |
| `ui.milestone.victory` | The era sequence, extended; closes on D major (add 9) | 2000–2600 ms (+ tail) | event (+12) | as era | as base | as era | once |
| `ui.milestone.defeat` | The same mechanism; a falling cadence, dignified | 2000–2600 ms (+ tail) | event (+10) | as era, ending on B minor → D | as base | as era | once |
| `ui.milestone.repelled` | A raid repelled (271): a gate barred (a heavy latch), then marimba rising D4–A4–D5 | 600–900 ms | event (+10) | marimba, as `ui.milestone.city` | as base | with the raid modal | rare (once per raid) |
| `ui.milestone.pillaged` | A raid pillaged (271): a relay drop and a low drum, then muted piano falling B3 → F♯3–B3–D4 (B minor); dignified, never an alarm | 700–1000 ms | event (+10) | muted piano, as `ui.milestone.defeat` | as base | with the raid modal | rare (once per raid) |
| `ui.milestone.build` | A building, or an upgrade, built (357): a relay, a muted-piano pickup A3–E4, then a D major chord ringing out over a low thump and a low D | ≈ 1.7 s | event (+9; under every other milestone) | muted piano D4–F♯4–A4–D5, a vibraphone A5, a soft triangle D3 under the chord | room 1.2 s, 22% | the ceremony's ring, 160 ms after the press | occasional (the most frequent event) |
| `ui.milestone.recruit` | A unit recruited (357): two low drums, a drum with a snare, then a short horn call A3 → D4 | ≈ 0.8 s | event (+9) | low toms, a snare, a soft square horn | as base | as `ui.milestone.build` | occasional |

---

## 15. Example component specifications

Notation: `REST → HOVER → PRESSED → RELEASED`; each transition gives duration, property changes, curve and sound.
Offsets are (x, y) px from rest. "Shadow" is the hard offset shadow token. A sound cell names the token (§14.1) and
when it starts, in ms from the start of that transition; "None" means silence is the specification.

### 15.1 Primary button
Anatomy: signal fill, 3 px `ink` border, `radius.1`, padding 8 × 20, `type.label` 600, `on-signal`, min height 40,
optional 16 px icon left with 8 px gap.

| State | Fill | Offset | Shadow | Border | Notes | Sound |
|---|---|---|---|---|---|---|
| REST | signal | 0, 0 | plinth (2, 2) | 3 ink | | None |
| HOVER | signal lightened 8% (Paper) / darkened 8% (Night) | 0, 0 | plinth | 3 ink | 90 ms `machined` in, 140 ms `release` out | `ui.hover` on entry (enabled only) |
| PRESSED | signal darkened 10% | +2, +2 | none | 3 ink | 70 ms `snap`. Sits into its shadow. | `ui.button.press` −2 st: snap ≈ 24 ms, bottom-out ≈ 38 ms |
| RELEASED | → HOVER (pointer still over) | 0, 0 | plinth | | 120 ms `machined`; action fires on release | `ui.button.release` −2 st, @ ≈ 65 ms |
| FOCUS | as REST + teal 2 px ring offset 2 px | | | | ring appears instantly | None |
| DISABLED | `well`, text `ink-3` | 0, 0 | none | 2 dashed `rule` | reason in tooltip (the `*_error` string) | on press: `ui.reject.locked` @ 0, and the tooltip shows at once |

The press as one event, sight and sound together:

| | REST → HOVER | HOVER → PRESSED | PRESSED → RELEASED |
|---|---|---|---|
| Visual | fill one value step | fill darkens 10%; the plinth shadow disappears | shadow returns; fill back to HOVER |
| Motion | none | +2, +2 px in 70 ms, `snap` | back to 0, 0 in 120 ms, `machined` |
| Sound | None | `ui.button.press`: a clicky key switch, the jacket's snap then the bottom-out | `ui.button.release`: the quieter upstroke snap, then the top-out |
| Timing | — | the bottom-out when the face reaches the desk (90% of travel, ≈ 38 ms), the snap 14 ms before it (actuation); never at pointer-down | the action fires on release; the top-out as the face reaches its stop (≈ 65 ms), the snap 18 ms before, so the sound marks the key, not the result |

Keyboard activation runs the same sequence. A press dragged off the button plays both sounds and fires nothing.

### 15.2 Secondary button
`steel` fill, 2 px `rule` border, `ink` label, otherwise as 15.1. HOVER: `steel` one step toward `sheet`, border →
`ink`. PRESSED: +2, +2, shadow none, fill one step toward `well`. Same timings. Same sounds at the reference pitch (a
lighter key than the primary's); a row of secondary buttons sounds identical, because they are one product's keys.

### 15.3 Tab
Anatomy: 36 px tall, padding 0 × 16, `type.label-caps`, square top, sits on a 1 px `ink` baseline. Group has one
shared 3 px `ink` **rail** that sits on the active tab's top edge. The panel's content starts on the same vertical
line as the first tab's label text (panel border + padding = tab border + padding: 1 + 16), and its top padding
equals its side padding (16), so the label and the text under it read as one column.

| Transition | Duration | Change | Curve | Sound |
|---|---|---|---|---|
| REST → HOVER | 90 ms | label `ink-2` → `ink`; 2 px underline wipes in from left | `machined` | None |
| HOVER → PRESSED | 60 ms | offset 0, +1 | `snap` | `ui.button.press` −3 dB (a shallow key), @ ≈ 33 ms |
| PRESSED → ACTIVE | 200 ms | the rail **slides** to this tab (x and width); fill `steel` → `sheet`; the baseline under it opens (tab joins the sheet); content below crossfades 120 ms with a 12 px slide in the direction of travel | `machined` | None: the rail and the content change are sub-navigation |
| ACTIVE (rest) | — | `sheet` fill, `ink` label 600, rail on top | | None |

Switching tabs with the arrow keys is silent; only a press on a tab clicks.

### 15.4 Toggle (lamp key)
A latching push key, like a control-room key with a lamp window in its face (the window bar, chosen over the legend key
in 219; see [lamp-key-options.html](mocks/lamp-key-options.html)). It is the button's press made to stay down, so the UI has
one physical idea for "a thing you press" and no separate switch control. The light is the key's only mark; its state
word sits beside it. In its row the setting's name sits left in `type.label`, and the key and its state word align
right, the word last.

Anatomy: a 32×32 key, `steel` face, 2 px `ink` border, `radius.1`, `shadow.plinth` (2, 2) at rest.
- **Lamp window**, 14×6, centred in the face. OFF: `well` with a 1 px inset `rule`. ON: the `sage` plane with a 1 px
  inset sage line. (Sage is the default; a setting whose ON state is a warning may use the caution lamp.)
- **State word**, "ON" / "OFF" in `type.label-caps`, `ink-2`, `space.4` right of the key (the row's spacing). Its box is as wide as "OFF"
  in both states, so the key doesn't move when the word changes.

| Transition | Duration | Change | Curve | Sound |
|---|---|---|---|---|
| REST → HELD | 70 ms | key over-travels to +3, +3; shadow hidden | `snap` | `ui.button.press`: snap ≈ 24 ms, bottom-out ≈ 38 ms |
| HELD → LATCHED (turning ON) | 70 ms | key settles at +2, +2, shadow stays hidden; as it lands the lamp window lights (40 ms) and the state word changes to ON | `snap`, `lamp-on` | `ui.toggle.on`, brighter, @ ≈ 38 ms, with the lamp |
| HELD → REST (turning OFF) | 120 ms | key springs back to 0, 0 and its shadow returns; the lamp fades (160 ms) and the state word changes to OFF | `machined`, `lamp-off` | `ui.toggle.off`, lower and muted: snap ≈ 47 ms, top-out ≈ 65 ms as the key reaches rest; the fading lamp is silent |
| HOVER | 90 ms | border stays `ink`; face one value step toward `sheet` | `machined` | None |
| FOCUS | instant | teal focus ring, offset 2 px | | None |
| DISABLED | — | face `well`, state word `ink-3`, dashed `rule` border, no shadow; a latched disabled key stays down | | on press: `ui.reject.locked` |
| Reduce motion | — | position and lamp switch in one frame | | unchanged: the press on press, the latch or release on release |

ON and OFF differ the way the mechanism does: the press is the key switch's (snap and bottom-out); ON adds the latch
catching (a short, bright catch), OFF lets the switch spring back (its upstroke snap and top-out, lower and muted). The difference is small but always audible side by side.

Accessibility: `role="switch"` with `aria-checked`; the state word and the latched position both carry the state, so
neither the lamp colour, the motion nor the sound is needed to read it. The **Interface sounds** setting is itself a
lamp key: turning it OFF plays `ui.toggle.off` before the bus goes quiet, so the player hears what they switched off.

### 15.5 Resource counter
Anatomy: a head line with the caption (`type.label-caps`, `ink-2`) at its left and a 12 px lamp at its right,
vertically centred on the caption; glyph (`icon.l` 32, resource hue line) then, 8 px to its right, the value in
`type.numeral` `ink`, with no box: the odometer's digit columns clip their reels invisibly. The figure is
left-aligned against its glyph and grows rightward (a right-aligned figure would drift away from a glyph it no longer
shares a box with); tabular figures keep each digit's width fixed. Forecast caption below.

`IDLE → CHANGED(+n)`:
1. 0 ms: delta tag "+3" appears right of the value, offset −4, 0 → 0, 0, 90 ms `snap`, colour sage (or brick "−2").
   Sound: None.
2. 60 ms: changed digit columns roll; each step 60–80 ms `linear-step`; ones column first, carries roll the next
   column on the same tick (odometer). Up for gain, down for loss. Max 8 steps, then jump. Sound: `ui.counter.tick`
   as each step but the last lands (a carry is one tick, not two), each 1 dB quieter than the last; the jump is
   silent. Counters rolling together share one tick stream, ticks at least 35 ms apart.
3. Last step: the lamp pulses (on 40 ms, off 300 ms) in the resource's hue. Sound: `ui.resource.gain` or
   `ui.resource.loss` at lamp-on, in place of the last step's tick.
4. +600 ms: tag wipes out right→left, 120 ms. Sound: None.
`WARNING` (forecast would starve / at limit): lamp stays lit brick, caption text changes, no motion. Sound: None
here; the caution or urgent flag that reports it sounds (§15.9).
Reduce motion: value swaps, tag and lamp hold 1.5 s. Sound: one tick and the registration, at the swap.

### 15.6 Card
Anatomy: §6.7. 2 px border; 6 px type band; name `type.label` 600; cost top-right, one glyph + figure entry per
resource, grouped by spacing (§6.7);
rules `type.body-s`; VP with starburst bottom-right.

| Transition | Duration | Offset | Shadow | Border | Other | Sound |
|---|---|---|---|---|---|---|
| REST | — | 0, 0 | card (soft, 341) | 2 ink/rule | | None |
| → HOVER | 100 ms `machined` | 0, −4 | card-hover | 2 ink | no scale | `ui.hover` on entry (hand and pickable cards) |
| → RISE (long card, 383) | 120 ms rest, 120 ms `machined` | 0, −4 | card-hover | 2 ink | text sheet over the art, as far as needed | None |
| → WAITING (still hidden) | 1.1 s linear | | | | the foot's gauge fills; then the rules popover | None |
| → PRESSED (pick up) | 60 ms `snap` | 0, −2 | none | | the card "clicks" before lifting | `ui.card.lift` @ ≈ 33 ms, once the press becomes a drag; a click that selects plays `ui.selection` instead |
| → DRAGGING | follow pointer, 0 lag beyond 1 frame | pointer | card-drag | 3 ink | tilt ≤ 3° by drag speed (today 12°: reduce) | None |
| → SELECTED | 140 ms `machined` | 0, −12 | lift | 3 ink | signal index tab wipes in 120 ms | `ui.selection` @ the tab lands, ≈ 65 ms. Deselect: None |
| → PLAYED | 280 ms `release` | slides to target/discard | lift → none | | lands with a 60 ms `snap` (no squash) | `ui.card.place` @ landing (≈ 280 ms) |
| DIMMED | instant | | none | 2 `rule` | band → hatch, reason plate | None |
| INVALID DROP | 240 ms | −4, +4, 0 lateral snaps | | danger | ⊘ + reason message | `ui.reject` @ ≈ 44 and ≈ 124 ms, one tap per stop |

### 15.7 Panel (drawer)
Anatomy: `sheet`, `radius.0`, title block (4 px bar), `space.5` padding, attached to a rail edge with a 1 px `ink` edge
on that side; `shadow.lift` on the open edge only while it overlaps content.

`CLOSED → OPENING → OPEN`: slide from −width to 0 along its rail, 260 ms `latch` (anticipation 3 px); contents fade
in starting at 40% of the slide, rows staggered 20 ms (≤ 6 rows). Sound: `ui.panel.open`, the latch tick at 0 as the
anticipation lets go, a quiet rail run fading as the drawer decelerates, the felt stop at ≈ 164 ms; the rows fading in
are silent. `OPEN → CLOSING → CLOSED`: 200 ms `release`, contents vanish at once (no reverse stagger). Sound:
`ui.panel.close`, the run accelerating and the latch catch at ≈ 187 ms. Reduce motion: instant, 120 ms fade; Sound:
only the stop (open) or the catch (close), at the change.

### 15.8 Tooltip
`ink` fill, `sheet` text, `radius.0`, 6 px notch, padding 8 × 12, max width 320.
`HIDDEN → (hover 400 ms) → SHOWN`: opacity 0→1 and offset toward the target 4 px → 0, 90 ms `machined`.
Moving to an adjacent target within 300 ms: swap content and slide to the new target, 120 ms, no fade.
`SHOWN → HIDDEN`: 80 ms opacity `release`.
Sound: None, in every state. A tooltip shown at once on a disabled control's press (§10.1) stays silent too: the
press already played `ui.reject.locked`.

### 15.9 Notification (flag)
Anatomy: 360 × 48 `sheet` strip from the left rail, 4 px hue bar at its left, `icon.l` glyph, one line
`type.label`, optional `type.caption` second line, close × right; `shadow.plinth`.

`QUEUED → ENTERING`: slide x −100% → 0, 200 ms `machined`; the rail's lamp for this category lights (lamp-on) as
the flag reaches full extension.
Sound: `ui.notification` in the flag's pattern (info ●, caution ●●, urgent ●↘●) as the flag reaches full
extension, ≈ 108 ms, with the lamp. A queued flag waits for the previous one's sound (≥ 400 ms apart).
`SHOWN`: holds `TOAST_TIME` (3 s) for info; urgent ones (famine, anarchy) persist until resolved. A flag carries no
lamp of its own: its hue bar, glyph and words already say what it is, and persisting says it's urgent.
`→ LEAVING`: slide back into the rail, 160 ms `release`; the stack below slides up 8 px per removed flag (120 ms).
Sound: None; the stack's shift is silent.
Reduce motion: appear/disappear with a 120 ms fade. Sound unchanged, at the appearance.

### 15.10 Progress indicator (segmented)
A `well` track, 8 px tall, 1 px `rule` border; N cells with 2 px gaps (N = units when ≤ 12, else 10 cells of 10%).
Filling a cell: the cell's plane colour **wipes** left→right in 120 ms `machined`; consecutive cells tick 60 ms apart.
The value in words/numbers sits right of the track ("3 / 5"). Indeterminate progress: a single lit cell steps along
the track every 120 ms (like a chaser lamp) — off with Reduce motion (show "Working…").
Sound: None while cells fill; progress is never audible as a continuous tick. The last cell filling plays
`ui.confirm` with the value label's final number, unless that completion is itself a game event (research complete
plays `ui.milestone.breakthrough`, not both). The chaser is silent.

### 15.11 Modal
Anatomy: `sheet`, `radius.0`, `shadow.sheet`, 4 px title-block bar, title `type.title` left, context
`type.label-caps` right, body by layout (§11.10: a text or card sheet's body ≤ 640 px, a ledger sheet 680 px in
two columns), footer rule, buttons right (primary rightmost).

| Transition | Duration | Change | Curve | Sound |
|---|---|---|---|---|
| CLOSED → OPENING | 240 ms | sheet offset 0, +24 → 0, 0; opacity 0 → 1 over the first 120 ms; scrim 0 → full over 160 ms | `machined` | `ui.sheet.open`, swelling from 0 and peaking as the sheet settles, ≈ 130 ms; the scrim is silent |
| OPENING → OPEN | — | focus moves to the first control | | None |
| stacked open | 240 ms | new sheet sits +8, +8 from the one beneath | `machined` | `ui.sheet.open` 1 dB quieter (paper on paper) |
| OPEN → CLOSING | 160 ms | offset → 0, +12; opacity → 0; scrim fades 160 ms | `release` | `ui.sheet.close` @ 0 (the lift) |

A modal that opens because of an event (the event card, the government choice after anarchy) lets that event's own
sound lead: the sheet's lay plays 3 dB quieter under a notification or a milestone, never instead of it.

### 15.12 End-turn button
Anatomy: 220 × 64, signal fill, 3 px `ink` border, `radius.1`, `shadow.lift` (4, 4) plinth; lamp (14 px) left; label
"END TURN" in `type.label-caps` 17 px +12%; a turn plate (Plex Mono, `type.numeral-s`) on a `well` inset at right;
caption below the button for "2 actions left" (from the engine).

| Transition | Duration | Change | Curve | Sound |
|---|---|---|---|---|
| REST (ready) | — | lamp sage on | | None |
| REST (actions left) | — | lamp ochre on; caption visible | | None |
| → HOVER | 90 ms | fill one step; caption ink-2 → ink | `machined` | None |
| → PRESSED | 70 ms | offset +4, +4; shadow → none | `snap` | `ui.endturn.press`: snap ≈ 24 ms, deep bottom-out at contact ≈ 38 ms |
| → RELEASED / COMMITTED | 120 ms | offset → 0; lamp off (160 ms `lamp-off`); button enters BUSY | `machined` | `ui.endturn.commit` @ ≈ 65 ms: the relay latches as the lamp goes out |
| BUSY (turn resolving) | ≤ 1.2 s | `steel` fill; the turn plate split-flaps to N+1; label "UPKEEP…" | | `ui.endturn.turn` at the first flap (optional); then the upkeep's ticks and registrations (§11.9) |
| → REST | 160 ms | fill → signal; lamp on (40 ms) | `lamp-on` | None |
| BLOCKED (pending decision) | instant | `steel`, ⊘, reason caption; disabled; focus skips to the decision | | on press: `ui.reject.locked` |
| REDUCED MOTION | | all of the above as instant swaps; lamp states are the record | | unchanged: press, commit, then the end state's registrations |

Press, commit and turn form one gesture that rises to the commit and then gets quieter: the press is a firmer key than
any other, the commit is the loudest sound of a routine turn, and nothing after it is louder. No musical sting, no
fanfare: a turn happens a hundred times a game.

---

### 15.13 Card stack (index pile)
Anatomy: the top card at full size; up to four card edges behind it, each offset +3, +3 px (2 px `ink` border,
`sheet` fill, stacked bottom-up); the count beneath in `type.label-caps` with a Plex Mono figure. No shadow at rest.

| Transition | Duration | Change | Curve | Sound |
|---|---|---|---|---|
| REST → HOVER | 100 ms | the top card slides 4 px up with `shadow.plinth`; the edges stay | `machined` | None |
| HOVER → DEALT | 260 ms per card, 30 ms apart | the top card stays; each card below slides from its edge offset to its grid cell (4 across, 12 px gaps), in pile order; the count hides | `machined` | `ui.pile.deal`: one riffle for the whole deal, from the first card leaving to the last landing |
| DEALT → REST | 200 ms per card, 20 ms apart, last card first | each card slides back to its edge offset; the count returns | `release` | `ui.pile.gather`: the tap as the last card is home |
| COUNT CHANGE | per §15.5 | the figure rolls; a card added lands on top with a 60 ms `snap` | `snap` | `ui.card.place` as the card lands; the count's tick |
| TOO BIG (> 8 cards) | 300 ms | instead of dealing: a sheet wipes out of the pile's rectangle (§11.13), cards as header tiles | `machined` | `ui.nav.forward` |
| Reduce motion | — | cards jump to their cells and back | | the riffle's last tap only (`ui.pile.gather`'s tap) at the change |

Dealt cards are ordinary cards: hover, select and details work on them as anywhere else. The grid never overlaps the
cards so a name is never hidden.

---

## 16. Sound design

The desk makes sound the way it moves: every sound is a mechanism the player can see, heard at the moment it makes
contact. This section is the system. The tokens are in §14.1, and each component's sounds sit beside its look and
motion in §7, §9.4, §10, §11 and §15.

### 16.1 Direction
The sound belongs to the same imagined machine as the picture: a civic planning desk of 1955–1970, built by people who
made industrial controls, office equipment and instruments. It is an *interpretation*: what a careful sound designer
would make of those mechanisms today, cleaner and quieter than any real machine, not a recording from a museum.

| Character | Means | Test |
|---|---|---|
| Crisp | transients start within 1–2 ms; no smeared attack | the waveform peaks in the first 3 ms |
| Tactile | each control has a contact sound tied to its press travel | mute and unmute: the press feels lighter without it |
| Restrained | Level 1 peaks ≤ −26 dBFS; nothing on the Interface bus above −18 dBFS | the meter |
| Warm | energy in 300 Hz–3 kHz; −6 dB shelf above 6 kHz; no harshness at 2–5 kHz. One exception: the key switch's snap (≈ 4.5 kHz, ≤ 12 ms), kept short and never louder than its bottom-out | the spectrum |
| Mechanical | built from clicks, detents, runs, stops, ticks and lamp tones | name the mechanism in one phrase; if you can't, cut the sound |
| Slightly analogue | small differences between repeats (§16.8), a little body and felt | no bit-crush, tape hiss or vinyl crackle |
| Short | Level 1 ≤ 140 ms, Level 2 ≤ 600 ms, Level 3 ≤ 2.6 s | the file length |
| Distinct | any two tokens of one level are told apart without looking | blind A/B, three listeners |
| Repetition-tolerant | passes the repetition test (§16.8) | |

**Avoid**: futuristic bleeps, arcade chirps, cartoon effects, loud cinematic impacts, glitches, digital distortion,
long reverb, a sound on every pointer move or on a hover that gets louder than a whisper, typewriter bells and cash registers, casino-style rewards, and overly literal retro
effects. If a sound would make a player say "how retro", it is wrong; if they don't notice it until it is gone, it is
right.

### 16.2 One product family: the material map
All of the desk's controls come from one product family. Each component takes its sound from **one** family, plus the
Signal family when it reports news.

| Family | Imagined mechanism | Materials | Used by | Signature | Never |
|---|---|---|---|---|---|
| **Keys** (primary controls) | ABS keycaps on clicky key switches (a click jacket that snaps at actuation); latching lamp keys | molded plastic, small springs | buttons, tabs, lamp keys, Grow, End turn (the heaviest key) | two-stage: a bright snap, then a plastic bottom-out clack 14 ms later; attack ≤ 1 ms, ≤ 80 ms, no ring | a metallic ring, a hollow clack, a typewriter's bell |
| **Rails and sheets** (navigation) | ball-bearing drawer runners, sliding partitions, drafting sheets, index cards | aluminium rails, felt stops, paper and card stock | drawers, cabinet doors, screens, modals, cards, piles | a soft run below 4 kHz, a damped stop, a paper whisper | a whoosh, any pitch sweep |
| **Counters** | drum counters, split-flap units, adding-machine registers | steel pawls, plastic drums and flaps | odometers, flaps, tallies, gain and loss | tiny ticks ≈ 3 kHz; a registration clack | coins, bells, slot-machine rolls |
| **Signals** (notifications) | indicator lamps with a tone generator, a small desk bell | sine and soft-square oscillators, a small bell | confirm, notifications, gain's whisper | pure tones from the tone ladder, soft attack, ≤ 600 ms | sirens, buzzers, chiptune |
| **Machinery** | relays, small motors, heavy latches | steel armatures and contacts | End turn's commit, the cabinet doors' latch, the base of every milestone | two-stage clacks, short motor runs below 600 Hz | engines, servos, hydraulics, sci-fi doors |
| **Ceremony** (Level 3, and the end-turn chord) | vibraphone, marimba, muted piano, brushes, a soft organ | wood and aluminium bars, wire brushes | `ui.milestone.*`, `ui.endturn.turn` | musical, in D, in a small room | orchestral hits, choirs, fanfares, lounge grooves |

A component never borrows another family's mechanism: a button never slides, a drawer never beeps, a counter never
rings a bell. A Signal tone joins a mechanism only when the mechanism reports a result (the confirm lamp has a tone; the
toggle's lamp window doesn't). Ceremony appears only at Level 3.

### 16.3 Mechanisms: what the eye sees, the ear hears
Sound and motion imply the same imaginary mechanism. Change one and you change the other.

| Physical metaphor | Components | Motion (§9.2) | Sound | Never |
|---|---|---|---|---|
| Mechanical push-button | buttons, tabs, Grow | snap in, machined out | a clicky switch: the snap, then the bottom-out; a quieter snap and top-out on return | a beep |
| Latching key | the lamp key (toggle) | snap, latch | a firm detent: a catch for ON, a spring-back for OFF | an electric "zap" |
| Sliding panel on a rail | drawers, cabinet doors | slide, `latch` curve | a quiet rail run, a felt stop or latch at the end | a whoosh |
| Drafting sheet | screens, modals | wipe, slide | a soft paper lay or run | a page-turn flourish |
| Index card | cards, piles | slide, snap | a card-stock flick, a pat, one riffle | a playing-card snap |
| Mechanical counter | odometers, tallies | roll | an electromechanical tick, then a registration | coins |
| Split-flap | the turn plate, titles, the memo's stamp | roll | one flutter per word | a clatter per character |
| Indicator lamp | confirm, the rail lamps | pulse | a short tone at lamp-on (news only) | a chime with a long tail |
| Rotary control (if one is added) | a stepped dial | rotate in steps | one detent per step, ≤ 8 per turn | a smooth whirr |
| Notification flag | flags | slide | the rail lamp's bell, in a pattern | an alarm |
| Relay and motor | End turn, milestones | snap, slide | a two-stage clack; a short motor-advance | an engine |

### 16.4 Hierarchy

| Level | Used for | How often | Duration | Loudness | Reverb | Tonal | Bus |
|---|---|---|---|---|---|---|---|
| **1 · Micro-feedback** | presses, toggles, selection, card moves, ticks, flaps, registrations | very high to high | 30–140 ms | very low to low (−8 to 0 dB; peaks ≤ −26 dBFS) | none | no (gain's 12 dB-down whisper aside) | Interface |
| **2 · Structural** | drawers, sheets, screens, cabinet doors, piles, confirm, reject, notifications, End turn | occasional; End turn once a turn | 100–600 ms | low to mid (0 to +6 dB) | ≤ 5% | confirm and notifications only | Interface |
| **3 · Event** | breakthrough, city, wonder, accord, era, victory, defeat | rare | 0.5–2.6 s | event (+10 to +12 dB) | ≤ 18%, ≤ 0.8 s tail | yes, musical | Game |

1. **Frequent never competes with important.** A Level 1 never cuts off a Level 2 or 3, and a Level 2 never cuts off a
   Level 3. While a Level 3 plays, sounds the system makes (counters rolling, flags arriving) wait for it or are
   dropped, and the music ducks 6 dB; sounds the player makes (a press) still play, 6 dB lower, because input is
   always acknowledged.
2. **The levels are audibly apart.** Level 3 peaks at least 4 dB above any Level 2 and is longer and layered, so it
   reads ≥ 8 LU louder. Level 2 sits 3–6 dB above Level 1.
3. **The more often, the smaller.** Very high frequency: ≤ 100 ms, ≤ 0 dB, one layer. High: ≤ 140 ms. Occasional:
   ≤ 600 ms, two layers at most. Rare: may be layered and musical.
4. **Routine never sounds like a reward.** No Level 1 or 2 sound is musical, holds a tone longer than 250 ms, or
   rises more than a fourth. Melody, chords and intervals belong to Level 3.
5. **A level follows meaning and frequency, not the component.** An event that turns out to be common in play moves
   down a level (§11.3) rather than getting quieter in place. The one deliberate exception is building (357): a
   building, unit or upgrade can come several times a turn, yet it is the player's main way of growing a territory and
   gets an event sound, `ui.milestone.build` / `.recruit`, at +9 (under every other milestone, level with the turn's
   chord) with a longer ring-out (a 1.2 s room, as the turn's chord). While it plays, the system's routine sounds wait
   or drop as under any Level 3.

### 16.5 Timing synchronization
Sound occurs at the perceived physical event.

1. **Contact, not input.** A sound plays when the moving part reaches 90% of its travel (`sound.sync.contact`), not
   when the pointer goes down. On the `snap` and `machined` curves that is ≈ 55% of the duration, on `latch` ≈ 63%,
   on `release` ≈ 94%.
2. **Never ahead.** A sound may lag its visual event by up to 30 ms and lead it by at most 10 ms. Late audio is
   forgiven; early audio reads as a fault.
3. **Stops, not travel.** Sound emphasizes contact and stopping points. A travel texture is allowed only under a
   panel-sized move (drawers, cabinet doors, screens), 10 dB under its stop, fading as the motion decelerates.
4. **As long as the motion.** A movement sound ends with its motion (± 30 ms, plus ≤ 60 ms of natural decay).
5. **Leaving sounds at the start.** Something that leaves (a sheet lifted, a screen slid back) sounds as it breaks
   contact, at 0 ms, and has no stop, because it hits nothing.
6. **Skipping stops sound too.** Skipping a choreography drops its pending sounds and fades the playing ones over
   30 ms.
7. **Reduce motion.** Contact and stop share one frame: the stop plays alone (§9.5).
8. **Files are cut to the transient.** Every file's transient sits at 0 ms (≤ 1 ms of pre-roll), so scheduling a sound
   at the contact frame puts its click at the contact. A two-stage sound (the key switch) carries a `lead`: it is
   scheduled that much early, so its last stage (the bottom-out or top-out) lands on contact and the snap just before,
   where actuation is. The player compensates for the platform's output latency so
   that the sound *arrives* inside the window.

| Event | Motion | Physical event | Token | Onset (ms from the motion's start) |
|---|---|---|---|---|
| Button press | 70 ms `snap`, 2 px | actuation; the face meets the desk | `ui.button.press`: snap, bottom-out | ≈ 24; ≈ 38 |
| Button release | 120 ms `machined` | the switch resets; the face returns to its stop | `ui.button.release`: snap, top-out | ≈ 47; ≈ 65 |
| Toggle ON | 70 ms latch, `snap` | the latch catches; the lamp lights | `ui.toggle.on` | ≈ 38 |
| Toggle OFF | 120 ms return, `machined` | the switch resets; the key reaches rest | `ui.toggle.off`: snap, top-out | ≈ 47; ≈ 65 |
| Tab | 60 ms `snap`, 1 px | contact | `ui.button.press` −3 dB | ≈ 33 |
| Selection | 120 ms tab wipe, `machined` | the index tab lands | `ui.selection` | ≈ 65 |
| Drag pick-up | 60 ms `snap`, 2 px | the card leaves its row | `ui.card.lift` | ≈ 33 |
| Card played | 280 ms `release` slide, 60 ms landing | the card lands | `ui.card.place` | ≈ 280 |
| Counter step | 60–80 ms linear | the digit lands | `ui.counter.tick` | each step's end, but the last |
| Gain / loss | the last step | lamp-on | `ui.resource.gain` / `.loss` | the last step's end, instead of its tick |
| Drawer open | 260 ms `latch` | the latch lets go; the drawer hits its stop | `ui.panel.open` | 0 and ≈ 164 |
| Drawer close | 200 ms `release` | the drawer shuts | `ui.panel.close` | ≈ 187 |
| Modal open | 240 ms `machined` | the sheet settles | `ui.sheet.open` | swells from 0, peaks ≈ 130 |
| Modal close | 160 ms `release` | the sheet lifts | `ui.sheet.close` | 0 |
| Screen | 320 ms `machined` wipe | the sheet lands | `ui.nav.forward` | texture 0, stop ≈ 172 |
| Cabinet close | 200 ms `machined` | the doors meet | `ui.cabinet.close` | ≈ 108 |
| Cabinet part | 260 ms `latch` | the latch; the doors stop | `ui.cabinet.part` | 0 and ≈ 164 |
| Flag | 200 ms `machined` | the flag is fully out; the rail lamp lights | `ui.notification` | ≈ 108 |
| Confirmation | lamp-on, 40 ms | the lamp lights | `ui.confirm` | 0 |
| Error | three 80 ms `snap` legs | each lateral stop | `ui.reject` | ≈ 44 and ≈ 124 |
| End turn | 70 ms `snap`, 4 px; release 120 ms | actuation and contact; the key home and its lamp out | `ui.endturn.press` (snap, bottom-out), `.commit` | ≈ 24 and ≈ 38; ≈ 65 after release |

### 16.6 Pitch, timbre and space
- **Spectrum.** High-pass Levels 1–2 at 150 Hz (the low end belongs to music and events); a −6 dB shelf above 6 kHz;
  nothing above 10 kHz at Level 1. Energy centred in 300 Hz–3 kHz: warm midrange, muted highs. The key switch's snap
  is the one deliberate exception: a 12 ms transient near 4.5 kHz that makes a key read as a key.
- **Transients and resonance.** Mechanical attacks ≤ 1 ms; tonal attacks ≥ 5 ms; a Level 3 opens quietly (its first
  20 ms ≥ 6 dB under its peak). Decays are
  short and exponential; no Level 1 body rings longer than 80 ms (low resonance).
- **Space.** One shared room for every sound that has any reverb: a small, damped room like a control room with
  acoustic tile (RT60 400 ms). Level 1 dry, Level 2 ≤ 5% wet, Level 3 ≤ 18% wet with a tail ≤ 0.8 s. No halls, plate
  shimmer or echoes.
- **Stereo.** Levels 1–2 are mono and centred. Level 3 may be stereo but never pans information.
- **Semantic pitch, used sparingly.** Most sounds aren't notes; only the confirm, the notifications, gain's whisper and
  the milestones are pitched.

| Meaning | Treatment |
|---|---|
| Neutral interaction | centred: the reference key's pitch; the home tone E5 |
| Confirmation | slightly higher: A5, or E5 → A5 |
| Rejection | slightly lower and untuned: a low body, no note |
| Gain / loss | gain adds A5's whisper; loss is 3 st lower and duller, with no tone |
| Activation (ON) | a brighter timbre (more 2–4 kHz) |
| Deactivation (OFF) | a more muted timbre (3 st lower, top rolled off) |
| Priority | pattern (●, ●●, ●↘●), never pitch or volume alone |

- **Tone ladder.** Every tonal cue uses D major pentatonic (`sound.tone`), so two cues that overlap (a confirmation
  under a notification, a flag during a breakthrough) always agree. Tones are sine or soft square with the top rolled
  off: a lamp's tone generator, not a synthesizer lead.

### 16.7 Musical treatment
- Routine interaction is non-musical. Music enters only at Level 3, with one exception: the end-turn chord
  (`ui.endturn.turn`, 246), a single struck vibraphone chord that sits under every milestone and walks I–vi–IV–V
  with the turns instead of resolving each time.
- **Palette**: vibraphone (motor off, or a slow tremolo at most), marimba, muted piano, brushes on a snare, a soft
  electric organ only under the era's final chord, and restrained analogue electronics (a sine with a slow attack) as
  glue. Used subtly: two or three of them per event, never all.
- **Not**: strings, brass fanfares, choirs, a drum kit, a groove, swing. No 1950s lounge pastiche.
- **Harmony**: D major and its pentatonic; figures of two to four notes; rising for gains (breakthrough, city, era),
  a falling cadence for defeat; resolve on D.
- **Rhythm**: free, tied to the motion rather than to a tempo. The chord at the climax lands with the motion's
  `settle`.
- **Shape**: every Level 3 begins with its mechanism (a relay, a latch, a pen, a brush) and ends in music. The machine
  performs the ceremony; the music says it mattered.
- A soundtrack, if one is added, lives on the Music bus, ducks under Level 3 and shares the restraint; the UI tones
  are soft enough not to fight its key.

### 16.8 Silence, density and repetition
Silence is an intentional part of the system. Every sound earns its place; the default is none.

**Silent by design**: hover on anything that isn't an enabled key or an actionable card (245: those tick, see `ui.hover`; so do a territory view's city, buildings and enabled free slots, 342), keyboard focus moving, tooltips, links, the scrim, lamps going out,
lamps lighting for status (AT LIMIT, IDLE, target lamps), the vellum overlay, gauge needles, the tab rail, delta
tags, a card's drag travel, deselecting, progress cells filling, the chaser, flags leaving and restacking, the READY
lamp after a turn, and idle time.

**Density**
- **One gesture, one voice per mechanism.** A click that selects plays `ui.selection`, not `ui.card.lift` and
  `ui.selection`; the vellum that a drag brings is silent because the pick-up already spoke.
- **Rate caps.** `ui.counter.tick`: at most one per 35 ms across the whole bus (extra ticks are dropped, not queued).
  `ui.hover`: at most one per 80 ms; it waits for the frame's input and gives way to a press, a release or a Level 3 event.
  A button's sounds: at most one per 40 ms. Notifications: ≥ 400 ms apart. Voices: 6 on Interface, 3 on Game; the
  oldest Level 1 voice is stolen first, never a Level 2 or 3.
- **Runs.** ≤ 8 ticks per roll, each 1 dB quieter, mirroring the roll's ≤ 8 visible steps; large changes never become
  dozens of sounds.
- **Variation.** Level 1 tokens have four variants played in random order without an immediate repeat, with ±25 cents
  and ±1 dB of jitter, so fifty presses don't sound like a machine gun. Level 2 has two variants and no pitch jitter
  (its tones mean something). Level 3 has one. `ui.endturn.turn` has four, one per chord of its walk, chosen by the
  turn rather than at random.

**Repetition test.** Every Level 1 and 2 token passes this before it ships (the specimen has a board for it):

| Scenario | Rate and length |
|---|---|
| Repeated button presses | 1 press/s for 2 minutes, then bursts of 5 at 6/s |
| Rapid resource changes | 20 upkeeps back to back, 3–4 counters each |
| Menu navigation | open and close a drawer, a modal and a screen, 20 cycles |
| Changing production values | step a value up and down 30 times in 15 s (a stepper or dial, once one exists) |
| Frequent card and unit selection | select across a hand of 8 cards, 40 selections |
| Repeated turn actions | 30 End turns in a row, with upkeep |

Run each at the default mix with music on, with three listeners, after an hour of play where possible. Pass: no
listener notices the sound as a sound after the first minute, and none finds it irritating. On a fail, simplify in
this order: shorten it, lower it 3 dB, remove its tonal or travel layer, darken it; if it still fails, it becomes
None. Removing a sound is always an acceptable fix.

### 16.9 Mix, buses and controls
- **Buses**: Master → Music, Game (Level 3 and any future gameplay sounds), Interface (Levels 1–2). Each has a volume
  in Settings (§12 rule 11) and a limiter at its ceiling (`sound.ceiling`); Interface also has an ON/OFF lamp key.
  Turning interface sounds off keeps the events: a player who dislikes clicks still hears the era change.
- **Defaults**: Master 80%, Music 60%, Game 80%, Interface 70%.
- **Ducking**: Level 3 ducks Music by 6 dB (50 ms attack, 400 ms release). Interface isn't ducked, but its
  system-driven sounds wait for the Level 3 to finish (§16.4).
- **Background**: when the window loses focus, Interface and Game fade out over 200 ms (a setting, on by default).
- **Loudness**: Level 3 cues ≈ −23 LUFS short-term at full volume, music ≈ −23 LUFS integrated; clicks are too short
  for LUFS and are set by their peak level.

### 16.10 Production
- **Sources**: record real mechanisms or synthesize, but stay inside the material map: clicky key switches under ABS
  keycaps, latching push keys, relays, a drawer on ball-bearing runners with a felt stop, card stock and drafting vellum, a
  drum counter, split-flap units, a small desk bell, a vibraphone. Don't sample or recreate recognisable proprietary
  sounds (a named product's chime, a famous projector's advance, a typewriter's bell).
- **Processing**: trim to the transient (≤ 1 ms of pre-roll), high-pass at 150 Hz (Levels 1–2), shelf the top,
  de-click, no saturation, normalise to the token's level. No reverb printed into Level 1–2 files: the room is applied
  on the bus, so every sound shares it.
- **Format**: 48 kHz, 16-bit, mono WAV for Levels 1–2 (imported uncompressed, no loop); stereo OGG for Level 3 and
  music.
- **Naming**: the token with dots as underscores, plus a variant letter: `ui_button_press_a.wav` … `_d.wav` in
  `assets/sounds/ui/`; Level 3 in `assets/sounds/events/`.
- **Prototype**: the specimen synthesizes every token in the browser (filtered noise bursts for clicks and ticks,
  shaped noise for runs and paper, partial sums for the bell and the vibraphone). Those fix timing, level and
  character, and serve as placeholders; final assets are recorded or designed to the same specs. The key switch was
  chosen by ear from the options in [click-options.html](mocks/click-options.html): option G.

---

## 17. Mapping onto this codebase (spike findings)

> **History.** This section is the spike's plan from before the restyle (items 177–183, done). It is not the
> current state of the code: for that, see [tokens.md](tokens.md).

How the guide lands in the existing UI without touching `engine/`:

| Guide | Code today | Change |
|---|---|---|
| Colour tokens | `ui/palette.gd` (`Palette`), semantic names already | Replace values with the Night set; rename toward the guide's roles (`BACKGROUND`→board, `RAISED`→sheet, `FIELD`→well, `CONTROL`→steel, `ACCENT`→signal, `GAIN`→positive…). Paper mode becomes a second const set behind a setting — `Palette`'s doc comment already anticipates "a later light theme". |
| Type scale, buttons, panels | `ui/game_theme.gd` (`GameTheme`): `Heading`, `Title`, `Stat`, `BarStat`, `DarkPanel`, `AccentButton` | Add the fonts and a `tnum` `FontVariation`; set the scale; `_box`: radius 6 → 2, add `shadow_offset` (2,2), `shadow_size` 1, pressed box with no shadow and `content_margin` shifted 2 px to fake travel (Godot styleboxes can't translate, so pressed = shadow removed + content offset; real travel needs `ActionButton`-style `position` tweens). `dark_panel` radius 24 → 0. Add `TitleBlock` and `Lamp` variations. |
| Motion tokens | `ui/anim.gd` (`Anim`): durations and sharpness | Add the duration and travel tokens; set `HOVER_SCALE`/`DRAG_SCALE` 1.0, `HOVER_LIFT` 4, `MAX_TILT` 3°; replace `LAND_SQUASH` with a 60 ms snap; `PULSE_SCALE` → lamp pulse. |
| Easing | `TRANS_BACK` in `card_motion.gd`, `ui_kit.gd`, `territory_view.gd` | `TRANS_QUART`/`EASE_OUT` (machined), `TRANS_EXPO`/`EASE_OUT` (snap). `ease.latch`/`settle` via `PropertyTweener.set_custom_interpolator` with a cubic-bezier helper in `Anim`. |
| Counters | `TopBar` stats + `UIKit.float_token` (126) | An `OdometerLabel` control (a clip `Control` with one digit strip per column) and a `DeltaTag`; tokens stop flying. |
| Navigation | `Navigator`: screens fade or slide in from the right (104, 208) | Done in 359: the territory view slides like Knowledge; 350's wipe out of the card was removed. |
| Modals | `Modal` / `ModalStack` (153) | Slide-up 24 px + fade; +8,+8 per stacked modal; square panel; title block. |
| Toasts | `ui/toasts.gd` (116) | Done in 250: flags out of the game's rail (on the right, so they slide leftward); rail lamps and the count badge not yet. |
| Reduce motion | `Settings.reduce_motion`, `UIKit.calm()`, `Anim.CALM_FADE_TIME` | Already the right switch; apply §9.5's mapping per component. |
| Toggles | `UIKit.motion_toggle()` and the settings screen's buttons | A `LegendKey` control (a square toggle `Button` with a centred lamp window; its `state_label` prints ON/OFF beside it in `UIKit.setting_row`; latched = pressed stylebox with no shadow; 182, 219). |
| Resource glyphs | `assets/icons/food.svg` etc., tinted by `Icons` | New SVGs on the 24 grid: sprout, cash coin, open book, solid bolt; wealth tinted with `glyph-ochre` in Paper. |
| Costs | the card face's cost text (`CardFace`) | One glyph + figure per resource, top-right, grouped by spacing (§6.7); the engine already reports the costs, the face only lays them out. |
| Piles | `LogDrawer`'s deck and discard counts (115, 121) | Index piles (§15.13) on the board; the deck face down, the discard dealing out on click. |
| Sound buses | None: the game has no audio today | A `default_bus_layout.tres` with Music, Game and Interface under Master, an `AudioEffectHardLimiter` on each at its ceiling (§14), and one small `AudioEffectReverb` on a send bus as the shared room (§16.6). |
| Sound tokens | — | A `Sfx` node in `ui/` (owned by `main`, like `ModalStack`) that maps each token to an `AudioStreamRandomizer`. Godot's randomizer already does §16.8's variation: `PLAYBACK_RANDOM_NO_REPEATS`, `random_pitch`, `random_volume_offset_db`. A small pool of `AudioStreamPlayer`s per bus enforces the voice caps, the tick limiter and the level rules (§16.4). Token names are constants (`Sfx.BUTTON_PRESS`), never strings at call sites, like the card types. |
| Sync | `Anim` tweens | `Anim.sound_at(tween, token, duration, curve)`: a `tween_callback` at the contact time of §16.5, computed from the duration and curve, so a sound lives in the same tween as its motion and a skipped or killed tween drops it. Output latency from `AudioServer.get_output_latency()`. |
| Keys | `UIKit.button`, `ActionButton`, the settings screen's buttons, `LegendKey` | `button_down` → press at contact; `button_up` → release; a disabled press → `ui.reject.locked`; `LegendKey.toggled` → `ui.toggle.on`/`.off`. |
| Counters, cards, piles | `OdometerLabel` (Godot spike), `CardMotion`, `DragController` | A tick per rolled step through the shared limiter, the registration with the lamp pulse; lift, selection and place in the card tweens. |
| Sheets, screens, flags | `Modal` / `ModalStack`, `Navigator`, `Toasts` | Sheet, nav and notification tokens in their open and close tweens; `Toasts` passes the flag's priority so it can choose the pattern. |
| Events | The engine's signals the UI already shows (tech learned, era, game over) | The UI plays `ui.milestone.*` where it shows them. `engine/` stays silent: sound is presentation. |
| Sound settings | `SettingsStore` (`reduce_motion`, `civilization`) | Add `volume_master`, `volume_music`, `volume_game`, `volume_interface` and `interface_sounds`, saved and validated like `reduce_motion`; sliders and the lamp key on the Settings and title screens. This touches `autoload/`, so it is a test-first item. |

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
- Iterating on the companion pages removed things more often than it added them: the bordered cost plate, the boxed
  value window, the drawn slide switch and the lamp on a notification all went, in favour of spacing, the legend key
  and the rail lamp. Glyphs had to match the height of the figure beside them, and a solid glyph had to be drawn
  smaller than an outlined one to look the same size.
- Yellow can't be a text colour on warm paper; an icon-only gold (3:1, not 4.5:1) is the honest fix.
- Sound (spike `mcm-sound`): tying every sound to a motion primitive's contact point removed most of the questions
  before they were asked. "When does it play?" has one answer (90% of travel), and "what does it sound like?" follows
  from the mechanism the eye already sees. The tokens fell out of the components, not the other way round.
- The motion system's own limits did most of the density work. In the specimen, +12 insight plays 7 ticks and a
  registration (the roll shows 8 steps; the last registers), and an upkeep over three counters plays 3 ticks and 3
  registrations. Sound needed one limit of its own, the shared 35 ms tick stream, for counters that roll together.
- Measured in the specimen (offline renders): the first synthesized clicks decayed to −60 dB in 14–37 ms, under the
  30–100 ms the tokens specify. What makes a click last is its damped body, not its transient; lengthening the body
  (≤ 80 ms, low resonance) brought every token inside its range without softening the attack.
- Raw synthesized peaks ranged from −17 to +9 dB. The levels stay the spec's only because each token is normalized
  to its level offline; recorded assets need the same discipline (§16.10).
- Two event cues (accord, city) first opened within 3 dB of their peak, a sudden loud start. The rule that a Level 3
  opens with its quiet mechanism (§12 rule 12) came from measuring that.
- The first key click was a narrow band at 1.8 kHz over a weak body, and in listening it sounded high and thin. Nine
  versions went side by side in [click-options.html](mocks/click-options.html), loudness-matched, from a lowered click to a
  dark felt thock and three two-stage clicky switches. The choice was G, the clicky switch: a bright snap and a plastic
  bottom-out 14 ms apart. It isn't darker than the first click (both centre near 2.4 kHz); what changed is that it
  is a recognisable mechanism with two stages instead of one band of noise. Its snap is the guide's one bright sound,
  so it is the first thing to check in the repetition test (§16.8). The legend key and End turn now use the same
  switch, so every key on the desk belongs to one family.
- What the measurements don't cover is taste: nobody has listened to these sounds in this spike. The synthesized
  clicks are placeholders that fix timing, length and level. The repetition test (§16.8) with real listeners, on
  recorded mechanisms, is the gate before any of this ships.

**Recommendation**
First a short Godot spike to prove the parts HTML can't: hard offset shadows and press travel in `StyleBoxFlat`,
tabular figures through a `FontVariation`, an odometer that clips its digits, and the legend key as a theme
variation. Then adopt it in four items, UI-only except the sound settings (no `engine/` changes):
1. **Tokens & theme** — new `Palette` values (Night), fonts with `tnum`, `GameTheme` radius/border/shadow, `Anim`
   timings and the easing swap. Biggest visual change for the least code.
2. **Mechanical feedback** — odometer counter + delta tags replacing floating tokens, lamps on the resource bar and
   End turn, card hover/select without scale, press travel on buttons.
3. **Sheets and rails** — title blocks, modal/drawer/navigation motion, notification flags on a left rail, the
   Knowledge screen as a drafting sheet.
4. **Sound** — the buses, the `Sfx` node with the Level 1–2 tokens, `Anim.sound_at`, and the volume settings (the
   settings part is test-first). Recorded placeholder assets for the dozen most frequent tokens; then the repetition
   test (§16.8) before anything else is added.
Paper mode and the milestone sequences (era change, victory, and their Level 3 sounds) come after, once the Night mode
has been played.

---

## 18. Voice: flavor text

Item 353. Every card but a territory, city or unit carries a line of **flavor**: the italic text that opens its details
window (and the event pop-up), before the rules, and sits under a building's card in the Build modal (354). Civilizations and governments carry a short paragraph and a real
**quote** with its source; techs carry a line and a quote; buildings, actions and events carry a line. The voice is
postwar fiction set in the ancient world: what these writers *do*, never what their worlds contain (no gin, no
commuter trains, no names from the twentieth century).

### 18.1 Reference points

| Writer | What to borrow | Example |
|---|---|---|
| Calvino | The city or the object as a riddle; a list that turns on its last item | *Market:* "…everything is for sale, and everything has been sold before: the pots, the figs, the news." |
| O'Hara | Who stands where; status in a detail of dress or manners | *Merchant Quarter:* "…where fortunes turn and everyone dresses slightly above their means." |
| Cheever | The disappointment the morning after; light falling on ordinary things | *Feast:* "…for one night the whole city eats together. In the morning the grievances are still there." |
| Highsmith | Menace said politely; the calm person you shouldn't trust | *Mercenaries' Offer:* "Hard people with foreign shields wait at the gate, courteous and patient." |
| Bradbury | Childhood, season and wonder; a line you can almost smell | *Wild Berries:* "…the children come home in the long gold evenings with purple hands and purple mouths." |
| Didion | Short declaratives; dread stated as fact | *Granary:* "The lean years always come; only the date is unknown." |

### 18.2 Rules

1. **Present tense.** A card happens now; the event pop-up shows it happening. History told as a fable ("Kingship, the
   scribes say…") is still present tense.
2. **Short.** About **120 characters** a line, a government's too; a civilization's paragraph (on the civilization
   picker) about **170**. The suite fails past 150 (civilizations 200): a line read in one glance, beside the rules, not instead of them.
3. **Vary the ending.** About one line in three ends on a **wry turn** (O'Hara, Highsmith, Cheever). The rest end on an
   **image** (Bradbury, Calvino) or a **plain fact** (Didion). A row of punchlines tires: read a card type's lines in a
   row before you add another joke.
4. **Disasters stay plain.** Plague, pestilence, famine, drought, fire, wreck and the loss of learning get no joke and
   no simile that admires them. Say what happens and stop: "The granaries echo. Families eat the seed grain, then the
   oxen, and wait for the next harvest."
5. **People, not men.** Write "people", "they" or a role (farmers, scribes, the smith, the young). Use a gendered word
   only for a real person or group (Hammurabi, the Pythia, the Greek philosophers).
6. **Keep the facts.** A line teaches one true thing about its subject (where, who, what it was made of); the voice
   colours it and never replaces it. Civilizations and techs above all. When in doubt, cite the fact in the item's Log.
7. **No rules.** A line never names a resource, a number of the game or what the card does: the rules text below it
   says that, generated from the effects.
8. **Quotes are real.** A `quote` is a real saying, accurately worded, with its source in `by` (the work, and the
   translator when the wording is theirs). Never invent one, and never put flavor-voice text in a quote.
9. **Quotes come at the card sideways**, from a deeper cut than the quotation books, and from every age. How to
   choose one: §18.5.
10. **British spelling**, as in the rest of the game: harbour, colour, storeys, travellers.

### 18.3 Do / Don't

| Do | Don't |
|---|---|
| "Strings of donkeys, later camels, sway from city to city across desert and steppe, carrying tin, cloth and news." | "Caravans are great for trade and give you lots of wealth!" (rules talk, modern cheer) |
| "From beyond the hills, drums beat through the night. No one has seen the drummers yet. No one goes to look." | "Mysterious drums echo ominously, filling everyone with a deep sense of foreboding." (tells the feeling instead of showing it) |
| "A fever comes up the river with the boats. The healers burn herbs, the streets go quiet, and the gravediggers do not rest." | A pun or a wink on a plague, a famine or a fire. |
| "Oxen lean into the yoke where people once broke the soil by hand…" | "…where men once broke the soil…" (rule 5) |

### 18.4 Checklist for a new card

- One true fact, in present tense, in about 120 characters (170 for a civilization).
- The ending: does this card type already have its third of wry turns? Then end on an image or a fact.
- A disaster? Plain.
- A quote? Run it through §18.5's checks.
- Read it aloud next to the card's rules text: it should sound like a sentence from a story, not a label.
- Does the card need art? Add its row to [card-art.md](card-art.md) (§19).

### 18.5 Choosing a quote

Civilizations, governments, techs, wonders and Anarchy carry a quote under their flavor line. The flavor says what the thing
is; the quote should make the player look at it again.

**At an angle, not on the nose.** A quote that only names or describes the card's subject (a wheel for The Wheel,
ships for Navigation, a list of crops for Olive and Vine) repeats the card's name. Find one that touches it sideways:

- an idea the thing serves: Borges's "All language is a set of symbols whose use among its speakers assumes a shared
  past" on Alphabet; Calvino's "Without stones there is no arch" on Engineering;
- the thing used as a metaphor for something else: Job's "My days are swifter than a weaver's shuttle" on Weaving;
  Proverbs' king's heart turned "as the rivers of water" on Irrigation;
- an irony or a doubt: Kafka's "A cage went in search of a bird" on Bureaucracy; Cato wondering "that a soothsayer
  doesn't laugh when he sees another soothsayer" on Priesthood; Auden's stars that don't care on Astronomy;
- a scene that makes the stakes physical: the ship's side "four fingers' breadth in thickness" on Navigation; Pliny
  unable to clasp the fallen Colossus's thumb on Bronze Working.

A literal quote stays only when it is especially pithy or strange: "Egypt is the gift of the river"; Cato's "Good
ploughing. What next? Ploughing."

**A deep cut, not a poster.** If a reader has met the line on a mug, a motto, a graduation speech or a quotation
site's front page, it's spent: "The unexamined life is not worth living", "Things fall apart", "Give me a place to
stand", "Render unto Caesar", "All that glisters is not gold", "There is no new thing under the sun", "Man is the
measure of all things". Look one layer down: the same author's less-quoted lines, a writer's aside about another
(Diogenes Laertius, Plutarch, Cicero), an epigram, a farming manual, a letter.

**Every age.** About a third of the quotes come from modern writers and poets (Larkin, Heaney, Seferis, Rilke,
Calvino, Borges, Kafka, Arendt, Sontag), the rest from the ancient world and the King James Bible. A modern line is
welcome on an ancient card: Seferis's marble head on Greece, Larkin's days on Calendar. Don't let one source
dominate: before adding a Psalm or a Proverb, count the Bible quotes already in; keep the same author off cards that
sit side by side.

**Checked against a text.** Copy the wording from a published edition or translation, never from memory or a quotation
site, and name the translator in `by` when the wording is theirs (Weaver, Keeley and Sherrard, Hicks). Cut with an
ellipsis only, never by rewording. Drop a candidate when its author is disputed (the "bronze is the mirror of the
form" line, given to both Aeschylus and Euripides) or when its translations disagree and you can't confirm one. Note
where you checked it in the item's Log.

**One card each, one or two sentences.** No two cards share a quote. A quote runs a sentence or two, about the
length of the flavor line; a longer passage gets cut at a sentence break.


---

## 19. Card illustration

Spike `spike/card-art`; items 381 (the plate), 382 (the face text) and 383 (overflow). Every card carries one picture, printed as a plate under its type band. The art list, with a
file name and a brief for each card, is [card-art.md](card-art.md).

### 19.1 Direction

The premise, carried on: the desk's cards were printed by the studio that did the agency's annual report and its
magazine advertising. Card art is **commercial print of 1950–1965**: the magazine ad, the editorial spot
illustration, the corporate annual report, the airline travel poster, the picture book. It draws the ancient world
through that lens, the way a 1958 *Fortune* spread drew a steel mill: Uruk as a few confident planes of colour,
the figures reduced to shapes, one idea per picture.

The picture is the one place on a card where colour fills an area (§4.6 rule 2). It earns that by behaving like
print: flat inks, a short palette, crisp edges and a frame.

**What it is not.** Not photographic, painterly or 3D-rendered; not a fantasy card game's dramatic oil painting. Not
"retro" pastiche: no scratches, folds, foxing, coffee stains, heavy grain or deliberate misregistration (the guide's
no-fake-wear rule, §1). No atomic kitsch: no boomerangs, no starbursts as wallpaper, no tiki. And no 1950s people:
the *drawing* is mid-century, the *world* is ancient. Nobody wears a suit, smokes or drives.

### 19.2 Reference points

Look at these for *method*, never to copy a picture.

| Source | What to borrow | For |
|---|---|---|
| Alice and Martin Provensen (*The Iliad and the Odyssey*, Golden Book, 1956) | The ancient world itself, drawn mid-century: frieze-like rows of flat figures, patterned dress, a loose ink line | actions, civilizations, events |
| Charley Harper | Animals and land reduced to geometry: a bird is a triangle and a circle; minimal detail, maximum shape | territories, hunting, fishing, herds |
| Miroslav Šašek (*This is Paris*, 1959, and the series) | Buildings and streets in a loose ink line over flat colour; a city's character in one view | buildings, cities |
| Mary Blair (Golden Books, concept art) | Bold flat colour, stylised figures, joy; colour as mood | festivals, good events |
| Container Corporation of America ads (*Great Ideas of Western Man*, 1950–75) | An abstract idea carried by one bold symbol on open ground | techs, governments |
| Erik Nitsche (General Dynamics *Atoms for Peace* posters, 1955) | Knowledge as a geometric diagram: orbits, grids, rings around an object | techs |
| Airline and rail travel posters (David Klein for TWA, the Pan Am series) | A place as one landmark in flat planes, at poster scale, with its sky | civilizations, wonders |
| Saul Bass (film titles and posters) | Cut-paper silhouettes, ragged edges, a dramatic crop; threat without gore | disasters, raids, unrest |
| Paul Rand, Alvin Lustig (book jackets, identities) | A few symbols collaged into an emblem; wit in the arrangement | governments, abstract actions |
| Giovanni Pintori (Olivetti ads) | Rhythm: one form repeated into a pattern | trade, markets, crafts |

### 19.3 Technique

| Property | Rule |
|---|---|
| Planes | Flat colour shapes with crisp, cut-paper or brush-cut edges. No gradients, no airbrush, no soft shading. |
| Overprint | Where two inks overlap they make a third, as if printed one over the other (multiply). This is the period's signature, and the only way two colours mix. |
| Line | Optional: one charcoal line weight, loose and drawn over the colour (Šašek, Provensen), not outlining every shape. |
| Texture | At most one print texture per picture, inside shapes only: halftone dots, dry brush, crayon resist or stipple. Never over the whole picture. |
| Space | Flattened: a side-on frieze, an elevation, or a high oblique view. Depth by overlap and stacking, never a vanishing-point plunge. |
| Figures | Stylised and geometric; a face is a shape, eyes a dot or nothing. Ancient dress. Never a real person's likeness: Gilgamesh or Hammurabi is a type, not a portrait. |
| Lettering | None. The game prints the name. Writing may appear only as pattern (rows of wedges on a tablet, marks on a scroll), never legible. |
| Harm | Disasters and violence by symbol or aftermath (an empty granary, a smoke column, an abandoned cart): no bodies, no blood, nothing a player has to look away from. The visual twin of §18.2 rule 4. |

### 19.4 Palette

A picture is printed in **four inks at most, plus its paper**:

| Ink | Value | Use |
|---|---|---|
| Paper | `#F3EBDB` warm cream | The ground, and all the negative space. The file is the same in both modes; Night dims it in the game (§19.7). |
| Key | `#22211F` charcoal (`ink`) | Line, silhouettes, the darkest shapes. |
| Type ink | the card type's Paper plane value (below) | The dominant hue: it covers the largest coloured area (often the sky, the ground or a backdrop plane), so the picture and the type band agree. |
| Support | one or two other plane values, used smaller | Accents: a sun, a sail, a dress. |

Type inks: action muted blue `#8AA7C4`, building olive `#A3AA6A`, city ochre `#D9A441`, territory sage `#9DB592`,
tech teal `#5E9C97`, event brick `#C9705C`, civilization plum `#B07D9C`, government indigo `#8F88B8`, unit bronze
`#A97F63`. Support inks come from the same set.

**Signal orange is never an ink** (§1 tenet 4): it stays the one loud thing on screen. Brick or ochre stands in.
Mood is set by value, not by new hues: a good event is mostly paper and light planes; a disaster drops to two inks
(charcoal and its type ink) with more charcoal.

### 19.5 Format and composition

- **The file:** `assets/cards/<card id>.png`, 1536 × 1024 px (3:2), sRGB, no alpha, no border or frame.
- **The crop:** the hand plate shows a centred **16:9 view**: the middle 84 % of the height (rows 80–944 of the
  master, 402). Compose for the middle 60 % (rows 205–819), so the subject survives any crop: the top and bottom
  fifths are bleed (sky, ground, pattern); nothing that matters goes there, though the plate now shows most of it. The 3:2 master leaves
  room for larger crops later (a full-card view, a civilization poster).
- **The thumbnail test:** the plate is 240 × 135 px on a card. Shrink the view to 120 × 68: the subject must still read.
  One subject, one silhouette, three major shapes at most.
- **Asymmetric:** the subject sits on a third, never centred by default (§2). Governments are the exception: an
  emblem is a single-message moment.
- **Negative space:** at least a third of the band is open paper or one flat plane.
- **A series per type:** within a type, one horizon height and one scale, so a hand reads as a set of stamps or a
  poster series. Territories share their horizon exactly, so a row of them reads as one strip of land.

### 19.6 By card type

| Type | The series | Composition |
|---|---|---|
| Civilization | Travel posters | The homeland as one landmark and its river or sea, at poster scale. Plum with two support inks: the richest pictures in the game. |
| Government | Emblems | The institution as a symbol (a seat, a staff, a crown, a sealed jar) in the manner of a corporate identity. Centred. Indigo. |
| City | Skylines | The city from outside its wall: roofs, a temple mound, smoke. Ochre. |
| Territory | Landscapes | Land only: no people, no buildings. Each keyword visible: fresh water a river, lake or spring; coastal the sea at one edge; flood plain bands of dark silt. Sage. |
| Building | Architecture | The building in its setting, elevation or three-quarter, a figure or two for scale. Olive. An upgrade redraws its base from the same viewpoint, grown, so a chain reads as one place maturing. |
| Wonder | Monuments | The building at monumental scale from a low viewpoint, a travel-poster hero shot. The one series that may use a period motif (radiating rays, concentric rings) behind its subject. |
| Action | People at work | Figures doing the thing, side-on, in a frieze (Provensen). Muted blue. |
| Tech | Ideas | The idea as one object on open ground, with a diagram around it: a ring, a grid, a path, an orbit (CCA, Nitsche). Teal. |
| Event | Spot illustrations | The moment, as an editorial spot: one scene, tightly cropped. Brick. Good events light, disasters dark and plain (§19.4). |
| Unit | Silhouettes | A few figures in silhouette with their arms, side-on and in step. Bronze. |

### 19.7 In the game

- **Where:** hand-size faces (264 × 360: the hand, the details modal's card, the Build modal, the event pop-up,
  Renewal) carry the plate under the type band, 240 × 135 px (16:9, 402), framed by a 1 px `ink` rule. The hand card grew 40 px
  for it (from 320); the plate's growth to 135 px (402) came from the rules' room, so longer cards follow §6.7's overflow rules. Realm, tableau and supply-pile faces
  carry none: at their size a picture costs a line of rules (§1 tenet 1).
- **Missing art:** a placeholder plate in the type's plane colour with one of the period motifs (a sun on a horizon,
  rings, a split disc, steps; picked by the card's id, so a card keeps its motif), with nothing printed on it (the file
  each card waits for is in [card-art.md](card-art.md)). It is drawn by `CardArt` (`ui/card_art.gd`), which shows the
  PNG instead once one is imported.
- **Night** lays black at 25 % over the plate (`Palette.ART_SHADE`; none in Paper), as Night lays black over the card's
  paper. Undimmed, a cream print is the brightest thing on a Night card, brighter than its text; shaded, it sits on the
  card like a print under lamplight.
- **Dimmed cards** keep their art as it is; the hatched band and the reason strip say why.
- **Long cards** keep their art at rest; it yields only while the player reads, when the text sheet rises over it
  (§6.7).

### 19.8 Prompt template

For an image generator: the shared style, then the card's brief from [card-art.md](card-art.md), then its inks.

> Mid-century modern commercial illustration, 1950s–1960s magazine and poster print. Flat screen-printed planes of
> colour with crisp cut-paper edges, overprinted inks where shapes overlap, a subtle halftone or dry-brush texture
> inside some shapes, an optional loose single-weight charcoal line. In the manner of Alice and Martin Provensen,
> Charley Harper, Miroslav Šašek and Container Corporation of America advertising. The ancient Near East and
> Mediterranean, 3000–300 BCE. **Subject:** {brief}. Printed in four inks on warm cream paper #F3EBDB: charcoal
> #22211F, {type ink} as the dominant colour, and {support inks}. Flattened perspective, asymmetric composition,
> generous negative space; the subject entirely inside the middle 60 % of the height. 3:2 landscape. No text,
> letters, numbers, border, frame, gradient, 3D rendering, photorealism, or worn, distressed or misregistered
> effects.
