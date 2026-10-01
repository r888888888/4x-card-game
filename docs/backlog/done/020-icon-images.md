---
id: 020
title: Replace text glyphs with icon images
type: feature
status: done
branch: feat/020-icon-images
---

## Goal
The glyphs from 019 and the type marks come from the system fallback font, so they render small and
uneven (`⟳` is about half the height of the letters). Draw our own small SVG icons and show them
inline in card text, so the symbols are clear at card size and match each other.

## Acceptance criteria
<!-- UI-only item. Checked in the running game. The engine keeps emitting the same glyphs. -->
- [x] AC1: Given any card showing rules text, then every `⟳` is drawn as a cycle icon, in the
  highlight colour (`#ffd966`), at the text's height and vertically centred on the line. The rest
  of the text is unchanged (`⟳ +1 food (+1 Flood Plain)` reads as [cycle icon] `+1 food (+1 Flood Plain)`).
- [x] AC2: Given a territory card, then its info line shows a slot icon before the slot count and a
  house icon before the housing number, both in the info line's colour: [slot]`2` [house]`4 · Grassland`.
- [x] AC3: Given any card, then the type line starts with an icon for its type instead of
  `◆ ■ ● ▲` (action diamond, building square, city circle, territory triangle), tinted like the
  type text today.
- [x] AC4: Given a card that can't be played or an idle building, then the reason strip starts with
  a "blocked" icon instead of `⊘`, in the strip's text colour.
- [x] AC5: Given a log line containing any of these glyphs, then it shows the same icon. (No log
  message contains one today, so this is checked with a scratch message, not in normal play.)
- [x] AC6: Card sizes, hover, drag, double-click, tooltips and keyboard focus behave as before:
  the new text controls don't take mouse input, and a card is no taller than before with the same text.

## Out of scope
- Resource icons (replacing the words "food" and "VP").
- Changing the engine's text: it keeps emitting `⟳`; tooltips keep their words.
- Changing log wording to add icons (e.g. `⟳ Capital: +2 food`). That's an engine log change and
  would be its own item.
- Downloaded icon sets; a credits file.

## Design notes
- **No engine change and no new tests**: the swap is display-only. Suite stays at 174.
- Icons: hand-written SVGs in `assets/icons/` (`upkeep.svg`, `slot.svg`, `housing.svg`,
  `action.svg`, `building.svg`, `city.svg`, `territory.svg`, `blocked.svg`), drawn white on a
  24×24 viewBox so they can be tinted. Imported as `DPITexture` (Godot 4.5+ SVG importer) so they stay
  sharp at any size. If import settings can't be written by hand reliably, load them with
  `DPITexture.create_from_string` at startup instead, and log that here.
- One glyph→icon table in the UI (e.g. `ui/icons.gd`), used by both card text and the log.
- Card text labels that can contain a glyph become `RichTextLabel` (`fit_content`, word-smart
  autowrap, no scrolling, `MOUSE_FILTER_IGNORE`), filled with `add_text` / `add_image` so card
  names are never parsed as BBCode. Set its line separation to match Label's, since the test
  showed RichTextLabel lines ~3px tighter.
- The log already uses `append_text` with BBCode; glyphs there become `[img]` tags.
- Spike (2026-09-28, scratch only): `add_image(texture, 0, 19, tint, INLINE_ALIGNMENT_CENTER)`
  in a `fit_content` RichTextLabel rendered crisp, tinted icons; rule and territory lines came out
  3–6px shorter than the Label versions.

## Test plan
| AC | Test |
|---|---|
| all | Manual (UI only). Also run by a scratch driver (not committed) in a copy of the project: card rich labels all ignore the mouse and hold no raw glyphs, a log line with all four glyphs shows icons, hover lands on the card, the tooltip is rules + hint, and double-click plays a card. 8 checks, passing on 4 random seeds; screenshots checked by eye. |

## Manual check
Run `godot --path .`.
- [ ] **AC1:** a hand Farm/Pasture shows a yellow cycle icon, the same height as the text.
- [ ] **AC2:** the starting territory's info line shows slot and house icons.
- [ ] **AC3:** hand cards of each type show their type icon on the type line.
- [ ] **AC4:** an unaffordable card's red strip starts with the blocked icon.
- [ ] **AC6:** hover, drag, double-click and arrow-key focus still work on a hand card; tooltips show.

## Log
- Hand-written `.import` files with `importer="svg"` / `type="DPITexture"` work; Godot fills in the
  rest on import. No runtime SVG loading needed.
- Type marks at full text height made the type line wrap earlier ("Building · / farm"), so each icon
  has a scale: type marks draw at 0.6 of the font size, like the small glyphs they replace. Market's
  "Building · trade" wraps exactly as it did with Label (measured).
- Line spacing: a RichTextLabel adds line_separation after the last line too, so it can't match
  Label on both one-line and wrapped text. Chose no extra spacing: one line is exactly Label's
  height (27px at 19pt), wrapped lines are 3px closer. Cards are never taller than before.
- Suite unchanged: 174 tests.

