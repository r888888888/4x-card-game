---
id: 140
title: Open tech tree: learn any tech whose prerequisite you have
type: feature
status: ready
branch: feat/140-open-tech-tree
---

## Goal
Research becomes something you plan, not a draw. Every tech whose prerequisite is researched is on offer in the tech
tree, and the player learns one by spending Insight, whenever they like, with no card or action. Prerequisites become
hard (no Iron Working before Bronze Working), and the Research card simply makes Insight. Reveal-2, passes and lost
techs go. Follows 139; tried on `spike/research-insight`.

## Acceptance criteria
- [ ] AC1: Given a research deck of Pottery (2 insight) and Writing (3 insight), 2 insight and 2 actions left, when
  the player calls `buy_tech` on Pottery with no card played, then Pottery is in `researched`, insight is 0, Writing
  is still in `research_deck`, Pottery's play effects have resolved and 2 actions are still left.
- [ ] AC2: Given Iron Working (prereq Bronze Working) in the research deck and Bronze Working not researched, with 20
  insight, then Iron Working's `tech_tree()` state is `GameEngine.TECH_LOCKED` and `buy_tech_error` is
  `"Iron Working needs Bronze Working first."`. When Bronze Working is bought, then Iron Working's state is
  `TECH_AVAILABLE` and it can be bought.
- [ ] AC3: `buy_tech_error` refuses, and `buy_tech` changes nothing, for: a tech not in the research deck (researched
  or in a future era) → `"That tech isn't on offer."`; too little insight → `"Pottery needs 2 insight (you have
  1)."`; the game over → `"The game is over."`; an explore choice open → `"Choose a territory first."`. While a
  hand-limit discard is owed, learning is allowed (like buying from the supply).
- [ ] AC4: Given era 2 techs waiting in `future_techs` and Pottery as the only tech left in the research deck, when
  Pottery is bought, then `era()` is 2 and the era 2 techs are in the research deck.
- [ ] AC5: The reveal is gone: a card with `{"op": "research"}` fails to load as an unknown op; `prereq_discount` is an
  unknown field (warning); `pending()` never reports a research choice; the engine has no `research_reveal` or
  `lost_techs` zone, no passes and no `TECH_LOST`, and `tech_tree()` entries carry `uid` (−1 for a future tech) and
  no `passes`. `research_card_name()` names the first deck-then-supply card whose effects gain insight.
- [ ] AC6: Given the tech tree open, then an available tech's tile has a "Learn" button, disabled with
  `buy_tech_error` as its tooltip when that is non-empty; clicking an enabled one learns the tech and the tree
  refreshes with it marked ✔ Researched. A locked tech shows 🔒 Locked and "needs Bronze Working" and has no
  Learn button. The tree's header reads `"Insight 5 · play a Research card for more"`, and the board has no research
  choice overlay.
- [ ] AC7: Given a sim game whose bot has 2 insight and Pottery learnable, when the bot takes its turn, then it learns
  the cheapest tech it can afford before playing cards (`ScriptedBot` no longer declines or buys from a reveal).

## Out of scope
- Eurekas (141) and diffusion (142).
- Iron Age content, the era-3 opener and pacing (143).
- Making Insight scale with the empire (see 143's Design notes: tall strategies research slowly).

## Design notes
- `Research.buy` takes the tech from `research_deck`; after a buy, an empty research deck adds the lowest waiting era
  (today that happens on reveal). `Research.prereq_met(def)`. `TECH_LOCKED` is computed in `tech_tree()` for a tech in
  the research deck whose prereq isn't researched.
- Removed: `reveal_techs`, `reveal_techs_error`, `decline_research`, `decline_research_error`, `research_options`,
  `tech_passes`, `MAX_PASSES`, `PENDING_RESEARCH`, `CardInstance.passes`, `CardDef.prereq_discount`, zones
  `research_reveal` and `lost_techs`, `engine/effects/research_effect.gd` and its registry entry, the research
  overlay in `ui/choice_overlays.gd` and the revealed-tech branch of `main.gd`'s `on_picked`, `CardView.set_tech_info`
  if nothing else uses it. `_DISCARD_ALLOWS` gains `"research"`. Card text: "Needs Bronze Working" replaces
  "-2 wealth with …".
- Supersedes `test_research.gd`, `test_tech_passes.gd` and the reveal parts of `test_tech_eras.gd`,
  `test_tech_tree.gd`, `test_discounts.gd`, `test_pending.gd`, `test_ui_queries.gd`, `test_button_widths.gd`,
  `test_board_labels.gd`, `test_board_row.gd` and `test_card_details.gd`; deleting or rewriting them needs the user's
  OK at the red checkpoint. Fixture: TEST_CARDS' `study` becomes `{"op": "gain", "resource": "insight", "amount":
  3}`; `play_research`, `pass_tech` and `research_engine` go.
- Content: the Research card becomes `+3 insight` (free, 1 action, as now). The Learn button is a `UIKit.button` beside
  the tile (not a card name, per the UI-text rule).
- 7 criteria, more than usual, but reveal-2 can't half-go: the engine, the UI and the bot all change with it.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|

## Manual check
- [ ] `godot --path . -- --seed 5`: play a Research card (+3 insight), open Knowledge (T), learn Pottery with its Learn
  button; the tile turns ✔ and Insight drops. Locked techs say what they need.
- [ ] A Learn button you can't afford is disabled and its tooltip says why.

## Log
