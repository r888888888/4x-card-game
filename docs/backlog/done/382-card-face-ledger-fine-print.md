---
id: 382
title: Tighter card face text: one Unlocks line, a ledger of figures, and gates as fine print
type: feature
status: done
branch: feat/382-card-face-ledger-fine-print
---

## Goal
The long tail of cards overruns its face: a tech lists each card it unlocks on its own line (Sailing 8 rules), a
government spells out its figures as sentences, and conditions that gate a card rather than say what it does
(Needs, Eureka, Starts on, Built over turns) take full lines. The engine writes a tighter face instead: unlocks
merge into one line, a government's figures go in a two-column ledger, and the gates drop to a line of fine print at
the foot. In the spike's mock this takes Sailing from 8 rules to 3 plus fine print and lets Theocracy fit with its
art. The details and the long-form text are unchanged. From `spike/card-art` (option F of
`docs/design/mocks/card-overflow-options.html`).

## Acceptance criteria
<!-- Rules tests build fixture CardDefs (TEST_CARDS + make_engine); names below are the fixtures'. -->
- [x] AC1: Given a fixture tech whose effects are, in order, unlock Harbor, unlock Shipyard, create a Sea Trade in the
  discard, unlock Sea Trade and an upkeep +1 insight, when `face(card_db)` is called, then `rules` is
  `["Unlocks Harbor, Shipyard, Sea Trade", "Add a Sea Trade to your discard", "⟳ +1 insight"]`: every unlock joins
  one line at the place of the first, in effect order; a card with one unlock reads "Unlocks Harbor".
- [x] AC2: Given a fixture government with actions 3, unrest_limit 13, tolerates town and administers 6, and an
  upkeep +1 VP, when `face(card_db)`, then `ledger` is `[["Actions", "3"], ["Unrest limit", "13"],
  ["Tolerates", "Town"], ["Administers", "6"]]` and `rules` is `["⟳ +1 VP"]`. A field the card doesn't have (0 or
  empty) has no ledger row, so a card with none has an empty ledger.
- [x] AC3: Given fixture cards with, respectively, `requires` [fresh_water], a tier (Metropolis), a `prereq` (Weaving),
  a `eureka` (−4 insight with 1 Fishing Huts), a `home` (Delta Marsh) and `project` true, when `face(card_db)`, then
  each gate is a line of `fine`, never of `rules`, in the order requires, tier, prereq, eureka, home, project:
  "Needs Fresh Water", "Needs a Metropolis", "Needs Weaving", "Eureka: -4 insight with 1 Fishing Huts", "Starts on
  Delta Marsh", "Built over turns". An upgrade's "Builds on …" line is in neither (its type line already names the
  base).
- [x] AC4: Given a card with a `text` field, when `face(card_db)`, then `rules` is that text split into its lines and
  `ledger` and `fine` are empty. Given any card, `rules_tooltip(card_db)` (the long form the details and tooltips use)
  is unchanged by this item.
- [x] AC5 (UI): Given a hand-size face for the fixture government with a prereq, when built, then it shows the
  ledger (a label in caps, its figure), then the rules lines, then the fine print as one line at the foot with its
  entries joined by " · ", in a 14 px caps look; an upgrade's face leads each of its rules lines with "Also" as
  today. A tableau-size face shows the ledger and rules and no fine print. The Realm's one-line face takes its line
  from `rules`.
- [x] AC6 (UI): Given the event modal for an event card, when it shows, then its text comes from the same face
  (ledger, rules, fine print), so no screen keeps a copy of the old single-string face.

## Out of scope
- Rewording other lines (create, gains, keyword bonuses): only unlocks merge.
- Anarchy's hand-written `text`: it stays one paragraph (AC4) and keeps needing 383's tab; splitting it into lines
  is a content change for later.
- What happens when even the tighter text overflows: 383.
- Tableau overflow beyond what the tighter text fixes (the card still grows there, as today).

## Design notes
- New `CardDef.face(card_db) -> Dictionary`: `{ledger: Array (pairs [label, value]), rules: PackedStringArray,
  fine: PackedStringArray}`. It replaces `rules_text`'s role as the face's text. Its callers today:
  `CardFace.build` and `build_board`, `EventModal` (`"text"`), and `TerritoryQueries.upgrade_rules_text` (headers
  false: the upgrade face's "Also" lines). Move them to `face()`; whatever is left of `rules_text` either becomes
  `"\n".join` of the face for tests that read text, or goes, with its 84 test call sites updated in the same item
  (no behaviour of those tests changes beyond the merged unlock lines and the moved gates).
- Ledger labels and values are engine text (the UI never names content): "Actions", "Unrest limit", "Tolerates"
  (the tier's name), "Administers" (the count). The conditions match today's `rules_text` (`actions > 0`,
  `unrest_limit > 0`, `tolerates_name != ""`, `administers > 0`).
- `Built over turns` is the short form of `PROJECT_TEXT`; the details keep the full sentence.
- UI: `CardFace` lays out a `Ledger` (a two-column grid, labels in a 14 px caps variation, figures in tabular
  figures) and a `FinePrint` label (a new 14 px caps `GameTheme` variation, `TEXT_DIM`, a hairline above). The type
  size is the guide's floor (§12 rule 5).
- Docs: the guide's §6.7 card anatomy gains the ledger and fine print (on `docs/card-art-design`'s §19 changes).

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_card_text::test_every_unlock_joins_one_line_at_the_first`, `test_a_single_unlock_reads_unlocks_and_its_card`; `test_supply::test_unlock_text` (updated) |
| AC2 | `test_card_text::test_a_governments_figures_are_a_ledger`, `test_a_field_the_card_lacks_has_no_ledger_row` |
| AC3 | `test_card_text::test_gates_are_fine_print_in_order`, `test_an_upgrades_face_has_no_builds_on_line`; updated: `test_building_tiers::test_a_tiers_text_names_it_after_the_upgrade_line`, `test_civ_home::test_home_is_on_the_card_text`, `test_upgrades::test_an_upgrades_text_says_what_it_builds_on`, `test_wonder_sites::test_project_loads_on_a_building_with_its_text` |
| AC4 | `test_card_text::test_a_cards_own_text_is_its_rules_split_into_lines`, `test_the_long_form_keeps_every_line` (passes already: a guard) |
| AC5 | `test_card_faces::test_a_hand_face_shows_the_ledger_then_the_rules`, `test_a_hand_faces_gates_are_one_line_of_fine_print_at_the_foot`, `test_the_fine_print_look_is_14_px_caps_in_text_dim`, `test_a_tableau_face_has_the_ledger_but_no_fine_print`, `test_a_realm_face_takes_its_line_from_the_rules`; the "Also" lines: the existing upgrade face tests |
| AC6 | `test_event_modal::test_ending_the_turn_shows_the_drawn_event` (existing: the hook's text is `rules_text`, which becomes the face's join) |

## Manual check
- [ ] Sailing, Code of Laws, Theocracy, Sumer, Egypt and a wonder in the hand and in their details: the face reads
  as a spec sheet (Unlocks line, ledger, fine print); the details still give the long form.
- [ ] A building on the territory view (tableau face) shows no fine print.

## Log
<!-- Decisions and surprises during implementation, newest last. -->
- 2026-10-06: specced from `spike/card-art`'s mock (option F, chosen as part of I). The user chose tableau faces
  without fine print.
- 2026-10-07: red. Decisions: `rules_text(card_db)` stays as the face in one string (the ledger spelled out as
  today's sentences, then the rules, then the fine print) for tests and the event modal's hook, so AC6 holds through
  it; its `headers` parameter goes (`upgrade_rules_text` reads `face().rules`). AC5's "government with a prereq"
  isn't loadable (prereq is tech-only), so the ledger is tested on a government and the fine print on a tech.
  Ledger looks: `LedgerLabel` (14 px caps, `TYPE_LABEL_CAPS`) and `LedgerFigure`; the face's rules label is named
  `Rules`. Gates with several `requires` keep today's "/" join.
- 2026-10-07: green (2466 on main → 2479). One more existing test changed by AC3 than named at the checkpoint:
  `test_card_text::test_needs_line` now expects the gate after the rule ("⟳ +1 food\nNeeds Forest/Jungle"), since
  `rules_text` puts fine print last. Unlocks merge through `Effect.unlocked_name` (only UnlockEffect overrides it).
  Following the guide's §6.7, the fine print sits above the VP and the ledger's figures are `type.numeral-s`.
  Screenshots of Sailing (Unlocks line, two lines of fine print) and Theocracy (four ledger rows) looked right.
