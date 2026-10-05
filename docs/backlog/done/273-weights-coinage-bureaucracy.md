---
id: 273
title: Fix tech dates: Weights and Measures, Coinage, and Bureaucracy for Monarchy
type: feature
status: done
branch: feat/273-weights-coinage-bureaucracy
---

## Goal
Two techs sit at the wrong point in history. Currency is a Bronze Age tech, but coins were first struck in Lydia
around 630 BCE, in the Iron Age. What the Bronze Age actually had was standard weights: silver weighed in shekels,
grain measured in fixed units. Monarchy needs Philosophy, though kings came about 2,500 years before Greek
philosophy, and Code of Laws already gives the Kingship government. Weights and Measures takes Currency's era-2
slot. Coinage arrives in era 3, building on it. Monarchy becomes Bureaucracy: Iron Age provincial government (the
Persian satrapies and the Royal Road), the real innovation that held large empires together. Content only: no engine
change. Follows 272 (Weights and Measures needs Clay Tokens).

## Acceptance criteria
- [x] AC1 (invariant): Every `gain_per_tag` on a tech in `research_deck` counts a tag carried by at least 3 reachable
  buildings. Holds today (Mathematics counts `culture`); guards Coinage's `trade`.
- [x] AC2: The existing content invariants stay green, in particular `test_every_tech_prereq_is_in_the_research_deck`,
  `test_eras_1_and_2_each_have_2_wonders_from_their_techs`, `test_every_wonder_comes_only_from_one_tech`,
  `test_every_eureka_counts_cards_the_player_can_get` and `test_real_data_loads_without_warnings`. Afterwards no card,
  eureka or config entry names `currency` or `monarchy`.

## Out of scope
- Moving Mathematics or Astronomy into era 2 (Babylonian maths was Bronze Age work): left for now.
- Kingship and the other governments: unchanged.
- Balance tuning; the sim isn't run here.

## Design notes
Data only (`data/cards.json`, `data/config.json`). New techs need a `flavor` and a real, attributed `quote`.

| Tech | Era | Prereq | Cost | VP | Eureka | Does |
|---|---|---|---|---|---|---|
| Weights and Measures (`weights_and_measures`), replaces Currency | 2 | Clay Tokens | 16 insight | 0 | 3 cities (off 4) | creates and unlocks Market |
| Coinage (`coinage`) | 3 | Weights and Measures | 27 insight | 1 | 1 Market (off 6) | ⟳ +1 wealth per `trade` card (`gain_per_tag`) |
| Bureaucracy (`bureaucracy`), replaces Monarchy | 3 | Code of Laws | 32 insight | 2 | 5 cities (off 6) | unrest limit +2 (`modifiers.unrest_limit`); creates Royal Road |

- Currency and Monarchy are removed from cards and `research_deck`.
- Mathematics: `prereq` becomes `weights_and_measures` (was `currency`).
- Royal Road moves from Currency to Bureaucracy and becomes an era-3 wonder (Darius' road and courier relays served
  the satrapies). Era 2 keeps 5 wonders, so 265's AC1 still holds.
- `trade` cards for Coinage: Market, Caravanserai, Weavers' Workshop (272), Olive Groves (274).
- Possible quote for Weights and Measures: "A false balance is abomination to the Lord: but a just weight is his
  delight" (Proverbs 11:1). For Coinage, Herodotus says the Lydians were the first to coin gold and silver
  (Histories 1.94); quote a published translation exactly.
- No tests or engine code name these ids (checked: the test fixtures' "writing" and "optics" are their own cards).

## Test plan
| AC | Test |
|---|---|
| AC1 | `test_content::test_every_tech_gain_per_tag_counts_a_tag_on_3_buildings` (passes today: a guard) |
| AC2 | existing `test_content` invariants (unchanged); `grep` for `currency`/`monarchy` under Manual check |

## Manual check
- [ ] Review the table's numbers and names in `data/cards.json`.
- [ ] The Knowledge screen shows Weights and Measures in the Bronze Age (needs Clay Tokens), and Coinage and
  Bureaucracy in the Iron Age. No Currency or Monarchy.
- [ ] Learn Bureaucracy: the unrest limit shown in the sidebar goes up by 2 and a Royal Road copy lands in the discard.
- [ ] Coinage's quote is Godley's Loeb translation of Herodotus 1.94 verbatim (check against Perseus); Bureaucracy's
  is the New York post office's paraphrase of Herodotus 8.98, attributed "after Herodotus".
- [ ] `grep -rn 'currency"\|monarchy' data` finds nothing.
- [ ] With a Market and a Caravanserai built, learn Coinage: the forecast shows ⟳ +2 wealth more.

## Log
- Balance worries for a later balance item: Persia's wonder (Royal Road) moves to era 3, later in the game. Coinage
  grows with every `trade` building, which may beat Market. Bureaucracy loses Monarchy's ⟳ +1 wealth and 1 VP.
- Built as specced: Weights and Measures takes Currency's slot (same cost, eureka and Market), keeping Currency's
  Lydian flavor for Coinage. Bureaucracy uses the tech `modifiers.unrest_limit` (as Mysticism uses `renewal`).
  PLAN.md's wonder list updated; the design mockups in `docs/design/` still show Currency and are left as they are.
  Suite 1821 → 1822 tests.
