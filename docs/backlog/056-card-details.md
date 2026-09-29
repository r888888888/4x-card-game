---
id: 056
title: Card details modal with a full explanation of mechanics
type: feature
status: ready
branch: feat/056-card-details
---

## Goal
A card's face and tooltip are terse (TODO 10). Clicking a card opens a larger version in a modal: the full rules, its
current state (territory, idle, passes, cost now), and a short explanation of every mechanic it uses (upkeep, workers,
slots, keywords, …). The engine generates all of it from the data, so it always matches the rules.

## Acceptance criteria
New engine API: `def_details(card_id) -> Dictionary` (any card, e.g. a supply pile) and `card_details(uid) -> Dictionary`
(a card in any zone, with its live state). Both return
`{name, type, cost, vp, rules: Array[String], state: Array[String], terms: Array[{term, text}]}`. `rules` are the
tooltip lines (`rules_tooltip`), `state` is empty for `def_details`, and `terms` are unique and in first-use order.

- [ ] AC1 (building): `def_details("farm")` has name "Farm", type "Building", cost "2 food", vp 0,
  rules ["Each upkeep: +1 food"], and `terms` with "Upkeep", "Slots" and "Workers", each with non-empty text.
- [ ] AC2 (keywords): `def_details("well")` has terms "Requires" and "Fresh Water". The Fresh Water text is generated
  from the card data and names the cards that need it or get a bonus on it (Well needs it; Paddy's bonus is on
  Flood Plain, so Paddy isn't named).
- [ ] AC3 (territory in play): For the homeland on the tableau with 2 pop, 1 Farm and population on,
  `card_details(home)` has state lines "Pop 2 / housing 7", "Slots 1 / 5 used" (plus any city slots),
  "Free workers 1", and terms "Pop", "Housing", "Slots". A rolled resource keyword on a territory shows in its rules
  and gets a term.
- [ ] AC4 (idle building): A building placed beyond its territory's pop has the state line "Idle: no free worker (skips
  upkeep)".
- [ ] AC5 (tech): A revealed tech with 1 pass whose prereq is researched shows the state line
  "Costs 2 wealth now (printed 5, −1 pass, −2 prereq)", and has terms "Passes" and "Prerequisite".
- [ ] AC6 (unknown): `card_details(-1)` and `def_details("nope")` return `{}`.

## Out of scope
- Hand-written flavour text or lore.
- Explaining rules the card doesn't touch (a full rules page).

## Design notes
- Glossary: a const map in a new `engine/glossary.gd` (term → text) for fixed mechanics: Upkeep, Slots, Workers, Pop,
  Housing, Requires, Passes, Prerequisite, Era, Explore, Settle, Grow, Frontier, and more later. Each `Effect` gets
  `terms() -> Array[String]` (default: "Upkeep" when the trigger is upkeep). Keyword terms are generated: "Fresh Water:
  a territory keyword. Needed by: Well. Bonus on it: …". A new op adds its terms under the `add-effect` skill.
- UI (after 052): the modal shows a big card view on the left, and rules, state and terms on the right. Gestures:
  - Hand, realm and frontier cards: a single click opens it once the double-click window passes with no second
    click and no drag (delayed click). Double-click and drag keep playing.
  - Explore and research choices, and the supply screen: a right-click opens it. Left-click still picks or buys.
  - The I key opens it for the focused card, anywhere. Esc or a click outside closes it.
- The modal is not a pending decision and blocks no engine action. It just sits on top.

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_card_details::test_…` |

## Manual check
- [ ] Single-click a hand card: the modal opens after a short beat. A double-click plays instead and never opens it.
- [ ] A drag never opens the modal.
- [ ] Right-click in the explore choice and in Buy Cards opens the details. Left-click still picks or buys.
- [ ] I opens the details for the keyboard-focused card; Esc closes them and gives the focus back.

## Log
