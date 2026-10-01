---
id: 019
title: Condense card text and move the full wording to a hover tooltip
type: feature
status: done
branch: feat/019-condense-card-text
---

## Goal
Cards carry more words than a player needs once they know the game ("Each upkeep:" on every line,
"Settle a discovered territory with a City", a whole second line for a keyword bonus). Show a short
form on the card and keep the full wording one hover away, so the board is easier to scan without
losing anything for a new player.

## Acceptance criteria
<!-- Card names below are TEST_CARDS-style fixtures built in the test, not data/cards.json. -->
- [x] AC1: Given a building with effects `gain 1 food (upkeep)` and `gain 1 food (upkeep, keyword
  flood_plain)`, when I read `rules_text`, then it is `⟳ +1 food (+1 Flood Plain)`: upkeep lines
  start with `⟳ `, and a keyword effect that follows an effect with the same op, trigger and fields
  (other than amount) and no keyword is merged onto that line as ` (+N Keyword Name)`.
  Same for `score 1 (upkeep)` + `score 1 (upkeep, mountain)` → `⟳ +1 VP (+1 Mountain)`.
- [x] AC2: Given a keyword effect that can't be merged (first effect, or the previous one differs),
  then it is its own line `Keyword Name: <short text>`: `score 3 (play, desert)` alone →
  `Desert: +3 VP`; an upkeep one → `Mountain: ⟳ +1 VP`.
- [x] AC3: Short forms: explore 2 → `Explore 2`; settle with City → `Settle: City`;
  gain_per_tag 2 food per `city` in tableau → `+2 food per city` (other zones keep ` in <zone>`,
  e.g. `+1 food per farm in hand`); grow 1 each → `+1 pop everywhere` (grow here stays `+1 pop here`);
  requires `[fresh_water]` → first line `Needs Fresh Water`, requires `[forest, jungle]` →
  `Needs Forest/Jungle`. Gain, score, draw and create keep their current text.
- [x] AC4: Given any non-territory card, when I read the new `rules_tooltip(card_db)`, then it is
  the full wording, one line per effect: `Each upkeep: ` prefix, keyword effects end with
  ` (on Keyword Name)`, never merged, `Requires A or B` first, and explore reads
  `Explore: reveal 2 territories, keep 1`. For the AC1 building:
  `Each upkeep: +1 food\nEach upkeep: +1 food (on Flood Plain)`. The `text` override, when set,
  is returned by both `rules_text` and `rules_tooltip`.
- [x] AC5: Given a territory with 2 slots, 4 housing and keywords `[fresh_water, flood_plain]`, then
  `rules_text` is still `""` and `rules_tooltip` is
  `2 building slots, holds up to 4 pop\nKeywords: Fresh Water, Flood Plain`
  (1 slot → `1 building slot`; no keywords → no second line).
- [ ] AC6 (UI, manual): the card face uses `rules_text`; a territory's info line reads
  `▢2 ⌂4 · Fresh Water, Flood Plain`. Hovering any card (hand, tableau, territory, frontier, explore
  reveal) shows `rules_tooltip`, then a blank line, then the existing hint for that card (play hint
  or play error, idle explanation, or click hint), leaving out whichever part is empty.

## Out of scope
- Resource icons (food glyphs) or new art; changes to the type line, cost or VP line.
- Rich/styled tooltips (plain Godot `tooltip_text` is enough).
- Log text: it keeps its own wording.
- Rebalancing or renaming cards.

## Design notes
- New engine API: `CardDef.rules_tooltip(card_db) -> String`; `Effect.describe_long(card_db)`
  (defaults to `describe`, overridden by explore; settle's long form is today's text) and a merge
  helper on `Effect` (e.g. `bonus_text()` returning `"+N"` and `can_merge_with(other)`, true when
  op, trigger and every field but amount and keyword match). Only gain, score, grow and
  gain_per_tag need to support merging.
- Glyphs `⟳ ▢ ⌂` render through the default font's system fallback, like the existing `◆ ■ ● ▲`;
  check them in the running game (AC6). If one doesn't render, pick another and log it here.
- **Existing tests change.** These pin today's wording and will be moved to `rules_tooltip` (same
  expected strings, except explore) or updated to the new short form, as approved by this item:
  `test_data_loader.gd` lines 81 (explore), 104 (settle), 152, 173–175 (grow);
  `test_keywords.gd` lines 122 (Paddy), 127 (Requires), 135.
- Territory info line stays in `ui/card_view.gd` (formatting only); its explanation comes from
  `rules_tooltip`.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_text::test_upkeep_line_starts_with_cycle_mark`, `test_keyword_bonus_merges_onto_matching_line`, `test_keyword_bonus_merges_with_a_different_amount` |
| AC2 | `test_card_text::test_lone_keyword_effect_gets_its_own_line`, `test_keyword_effect_after_a_different_effect_does_not_merge`, `test_keyword_effect_after_a_keyword_effect_does_not_merge` |
| AC3 | `test_card_text::test_explore_and_settle_short_forms`, `test_per_tag_short_form`, `test_grow_short_forms`, `test_needs_line`, `test_gain_score_draw_create_keep_their_text` (guard; passes already) |
| AC4 | `test_card_text::test_tooltip_is_the_full_unmerged_wording`, `test_tooltip_long_forms`, `test_text_override_is_used_for_both`; moved to `rules_tooltip`: `test_data_loader::test_explore_defaults_to_reveal_2` (now "reveal 2 territories"), `test_settle_text`, `test_grow_text`, `test_keywords::test_keyword_effect_text`, `test_requires_text`, `test_requires_several_keywords_text` |
| AC5 | `test_card_text::test_territory_tooltip_explains_slots_housing_keywords` |
| AC6 | Manual |

## Manual check
Run `godot --path .`.
- [ ] Hand Farm reads `⟳ +1 food (+1 Flood Plain)`; hovering shows the long form, a blank line,
  then "Drag into the tableau (or double-click) to play."
- [ ] A frontier territory shows `▢2 ⌂4 · …`; hovering explains slots, housing and keywords.
- [ ] An idle building's tooltip shows its rules, then the idle explanation.
- [ ] `⟳ ▢ ⌂` render (no tofu boxes).

## Log
- Merge rule: a keyword effect merges only onto the line directly above, and only if that line has
  no keyword of its own. Other-zone per-tag reads `+1 food per farm in hand` (no "card").
- The "Needs" line uses `/` between keywords; the engine's play error still says "Forest or Jungle".
- Glyphs: all render via system fallback, but `⟳` is small at 19px (only ~60% of cap height).
  `↻` renders noticeably larger in the same fallback; swapping would change the approved AC1/AC2
  test strings, so it is left for the user to decide.
- Test count 159 → 174.

