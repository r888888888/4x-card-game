---
id: 319
title: Governments administer up to N territories; each one past the cap adds more unrest
type: feature
status: in-progress
branch: feat/319-administration-cap
---

## Goal
Going wide gets a soft cap of about 12 settlements. Each government administers a number of territories calmly. Every
settled territory past that cap adds unrest each upkeep, and each one adds more than the last: the k-th territory past
the cap adds k (so 1, 3, 6, 10 a turn in all). One or two past the cap can be held with Temples and Courthouses;
three or four past it lead into Anarchy. Techs and wonders raise the cap. This is 282's `tolerates` (which limits going
tall) for going wide, through the same upkeep path. 320 (Settler costs more per territory) slows expansion on the way
to the cap; 321 teaches the bot both.

## Acceptance criteria
Fixtures: unrest on, a government with `unrest_limit` 20 and `"administers": 3`, ample food, unrest 0, no tiers
(so size unrest is 0).

- [ ] AC1: Admin unrest at upkeep: with 3 settled territories, `admin_unrest()` is 0 and the next turn starts with
  unrest 0. With 4 it is 1, with 5 it is 3 (1 + 2), with 6 it is 6 (1 + 2 + 3), and the next turn starts with that
  much unrest. Frontier territories don't count.
- [ ] AC2: The cap and its modifier: `admin_cap()` is the government's `administers` plus the `administers` modifier,
  never below 0. With a researched tech carrying `"modifiers": {"administers": 2}`, `admin_cap()` is 5, and 5
  territories add 0 and 6 add 1. An idle building with the modifier doesn't count (as every modifier works). With no
  government, or a government with no `administers`, `admin_cap()` is -1 (no cap).
- [ ] AC3: Order and limit: admin unrest is added at the start of upkeep with size unrest (282), before any card's
  upkeep, through the same limit stop. Given unrest 8, a limit of 10 and 5 territories (admin 3), the turn starts at
  10, not 11, and falls into Anarchy as usual. Given 4 territories (admin 1) and a working Temple-like building
  (⟳ −1 unrest), the next turn starts at unrest 0.
- [ ] AC4: When it doesn't apply: a government with no `administers` adds no admin unrest with 10 territories. Under
  Anarchy (no government) none is added. With unrest off, `admin_unrest()` is 0.
- [ ] AC5: Forecast: with 5 territories, `upkeep_forecast()[UNREST]` includes the +3 along with any size unrest and
  card upkeep unrest; with a Temple-like building it is +2.
- [ ] AC6: Loader and text: `administers` is a government-only field (on another type it gets the usual "only applies
  to governments" warning), an int ≥ 1 (else a load error naming the card, `administers` and the value). The
  government's text gains "Administers up to 3 territories.". `administers` is a valid modifier key, with the text
  "Administer 2 more territories" / "Administer 2 fewer territories". Real data (content invariants, no ids or
  numbers): every government sets `administers`. Every card whose modifiers include `administers` is a tech, a
  government, a civilization or tagged `wonder`, so building copies can't stack the cap.

## Out of scope
- The Settler's rising price (320) and the bot (321).
- A territories-versus-cap readout in the UI beyond the unrest forecast and the government text. That's a later UI
  item if playtesting wants it.
- Tuning the caps, the unrest limits or the calming buildings against the new drain: a balance item after 321.

## Design notes
- Data: government field `"administers": <int ≥ 1>` in `DataLoader.TYPE_FIELDS` for `CardDef.GOVERNMENT`; a new
  `Modifiers.ADMINISTERS` key in `MODIFIER_KEYS` with its `card_def.gd` text pair.
- Engine: `admin_cap() -> int` and `admin_unrest() -> int` on EngineQueries (with `size_unrest` in `Population`, or a
  small module if `population.gd` nears 700 lines). `admin_unrest` = over × (over + 1) / 2, where over = max(0,
  settled territories − `admin_cap()`); it is 0 when the cap is -1 or unrest is off.
- `TurnLoop.resolve_upkeep` adds it next to `size_unrest` (one `set_unrest` each, or one for both), with its own log
  line, e.g. "Overextended realm: +3 unrest.". Being in `resolve_upkeep` puts it in `upkeep_forecast` and
  `turn_forecast` with no change there. It's an engine rule, not an effect op, so `upkeep_ok` doesn't apply.
- Settled territory count: reuse whatever `realm_size()` or `Territories` already counts (territory cards in the
  tableau), so all three items count the same way.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_admin_unrest::test_territories_within_the_cap_add_no_unrest`, `test_each_territory_past_the_cap_adds_one_more_unrest_than_the_last`, `test_frontier_territories_add_no_admin_unrest` |
| AC2 | `test_admin_unrest::test_the_cap_is_the_governments_administers`, `test_a_researched_administers_modifier_raises_the_cap`, `test_only_a_working_building_raises_the_cap`, `test_without_administers_there_is_no_cap` |
| AC3 | `test_admin_unrest::test_admin_unrest_stops_at_the_unrest_limit`, `test_admin_unrest_comes_before_calming_upkeep`, `test_admin_unrest_adds_to_size_unrest` |
| AC4 | `test_admin_unrest::test_a_government_without_administers_adds_no_admin_unrest`, `test_anarchy_adds_no_admin_unrest`, `test_without_unrest_there_is_no_admin_unrest` |
| AC5 | `test_admin_unrest::test_the_forecast_counts_admin_unrest` |
| AC6 | `test_admin_unrest::test_administers_loads_and_shows_in_the_government_text`, `test_administers_only_applies_to_governments`, `test_administers_must_be_at_least_1`, `test_the_administers_modifier_loads_with_its_text`; `test_content::test_every_government_sets_administers`, `test_only_unique_cards_raise_the_admin_cap` |

## Manual check
- [ ] Shipped caps (review before merging): Chiefdom 4, Kingship 7, Theocracy 6; Code of Laws +1, Bureaucracy +2,
  Royal Road +1. That's 11 at most under Kingship, so the 12th territory costs 1 unrest a turn and the 13th 3 a turn.
- [ ] The top bar's "Unrest: N (+M)" counts admin unrest once you pass the cap. The government modal reads
  "Administers up to …", and Bureaucracy's text names its modifier.

## Log
- 2026-10-05: specced with the user from a brainstorm, choosing "admin cap" with growing unrest plus a rising Settler
  price (320). The triangular curve (k-th past the cap adds k) was chosen so the cap is soft at +1 and firm by +3 or +4.
  Assumed: none under Anarchy (as 282), and the cap modifier only on unique cards (techs, wonders, governments, civs).
- Red: AC3's limit test uses unrest 18 against the fixture's limit 20 (the spec's 8 of 10, same margin). The modifier's
  text is "Administration cap +2" / "−1" (like "Unrest limit +1"): "Administer 2 more territories" has no plural form
  for 1 in `MODIFIER_TEXT`'s "%s" pattern. `test_only_unique_cards_raise_the_admin_cap` passes already (no real card
  carries the modifier yet); it guards the data this item adds.
