---
id: 374
title: Raids grow with the food and wealth you hoard
type: feature
status: in-progress
branch: feat/374-raids-scale-with-hoard
---

## Goal
Hoarding food and wealth should draw bigger raids. Today a raid's strength and its losses are fixed on the card, so
a stockpile costs nothing. After this, a raid drawn while you hold a lot is stronger, and a raid that pillages also
carries off part of your stores. That gives the player a reason to spend or invest instead of sitting on resources,
or to pay for the defence that a rich realm needs.

## Acceptance criteria
Config `raid_hoard_step` 10, `raid_plunder_pct` 20 unless stated. "Hoard" = food held + wealth held.

- [ ] AC1 (strength fixed at announcement): Given a raid printed Raid 3, food 13 and wealth 9 (hoard 22), when it is
  drawn, then its strength is 5 (3 + ⌊22 / 10⌋): `raid_strength(uid)` returns 5 and `raid_forecast()` reports
  `strength` 5. With hoard 9 it is 3, with hoard 10 it is 4, and with hoard 0 it is 3. `raid_strength` is 0 for
  anything but an active raid.
- [ ] AC2 (fixed once announced): Given that raid announced at strength 4 (hoard 15), when food and wealth then change
  (set to 0, or to 50) before it strikes, then `raid_strength` and `raid_forecast` still say 4, and it strikes at 4
  (`raid_resolved`'s `strength`): against defence 3 it pillages, against defence 4 it is repelled.
- [ ] AC3 (lines show the scaled strength): Given a raid announced at strength 5 against defence 0, then `raid_line`,
  `raid_tag` and `raid_warning` show 5 (not the printed 3), and `raid_short` is true at defence 4 and false at
  defence 5.
- [ ] AC4 (plunder on pillage): Given a pillaging raid whose own pillage effects are `lose 2 food`, with food 17 and
  wealth 7 when it strikes, when it strikes a territory with less defence than its strength, then its pillage effects
  resolve first (food 15), and then it also takes 20% of the food and the wealth left, each rounded up: −3 food (15 →
  12) and −2 wealth (7 → 5). `raid_resolved`'s `lost` is `{food: 5, wealth: 2}`, and `raid_outcome_text` lists
  −5 food and −2 wealth.
- [ ] AC5 (no plunder when repelled, or from nothing): Given the same raid repelled (defence ≥ strength), then food
  and wealth change only by its repel effects. Given a pillage with food 0 and wealth 0 when it strikes, then nothing
  is plundered and `lost` has no food or wealth entry beyond its own effects.
- [ ] AC6 (config): `raid_hoard_step` and `raid_plunder_pct` default to 0 when unset, and 0 turns that part off (with
  step 0 the strength stays the printed one; with pct 0 nothing is plundered). The loader rejects a negative value
  and a `raid_plunder_pct` over 100, naming the field.
- [ ] AC7 (copy): `GameState.copy()` / `CardInstance.copy()` keep an announced raid's strength (the copy check in the
  suite covers the new field), so a forked engine strikes at the same strength.

## Out of scope
- Tuning the shipped numbers beyond 10 / 20 (a balance item).
- Scaling with realm size, pop or anything other than food and wealth held.
- Raid pacing (`raid_min_size`, `raid_gap`): a hoard doesn't make raids come sooner or more often.
- New raid cards, and UI beyond the existing raid lines showing the scaled number.

## Design notes
- Config (`data/config.json`, `ConfigLoader`): `raid_hoard_step` (int ≥ 0, 0 = off) and `raid_plunder_pct`
  (int 0–100, 0 = off). Shipped 10 and 20.
- `CardInstance` gains the announced raid's strength (e.g. `raid_strength`, set in `Military.announce`, copied by
  `copy()`). Every reader of `def.raid.strength` for an active raid (`raid_forecast`, `raid_line`, `raid_tag`,
  `raid_short`, `raid_warning`, `_strike`) reads it instead. The card face and tooltip (`CardDef.raid_face_text`,
  `raid_text`) keep the printed strength; the tooltip may add "grows with food and wealth held" if that wording is
  easy to generate without config in `CardDef`. Otherwise it goes under Manual check.
- New engine query `raid_strength(uid)`: the announced strength of active raid uid, 0 when uid isn't an active raid.
- Plunder rounds up like `lose_pct` (268) and goes through the same `lose` path, so it lands in the outcome's `lost`
  and in `raid_outcome_text` without new text code.
- Sim bot: it sees the bigger strength through `raid_forecast` / defence as now. Plunder isn't in `upkeep_forecast`
  (it isn't upkeep), so the bot doesn't foresee it; a balance worry, not a criterion.
- PLAN.md's Raids paragraph gets the hoard rule and the two config keys.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_raids::test_374_a_raid_drawn_gains_1_strength_per_raid_hoard_step_of_food_and_wealth_held`, `test_374_raid_strength_is_0_for_anything_but_an_active_raid` |
| AC2 | `test_raids::test_374_the_strength_stays_as_announced_when_the_hoard_changes`, `test_374_the_strike_compares_defence_with_the_announced_strength` |
| AC3 | `test_raids::test_374_raid_lines_show_the_announced_strength` |
| AC4 | `test_raids::test_374_a_pillage_also_plunders_raid_plunder_pct_of_the_food_and_wealth_left` |
| AC5 | `test_raids::test_374_a_repelled_raid_plunders_nothing`, `test_374_a_pillage_plunders_nothing_from_empty_stores` (both pass before the change: guards) |
| AC6 | `test_raids::test_374_hoard_config_0_turns_each_part_off`, `test_374_hoard_config_defaults_to_0_and_rejects_bad_values` |
| AC7 | `test_raids::test_374_a_fork_keeps_the_announced_strength` (and the suite's copy check of `CardInstance`) |

## Manual check
- [ ] Play to a raid while holding 20+ food and wealth: the raid modal and warning show the higher strength, and a
  pillage takes the extra stores in its result line.
- [ ] Balance (user-run): `scripts/test.sh --balance` and the `balance` skill; watch raid repel rate and late-game
  food/wealth.

## Log
- Red: the fixture Raiders is printed 3, so AC1–AC3 use 3 (5 at hoard 22, 4 at hoard 15), not the 2 first written.
  Upkeep adds 2 food before the draw, so tests set food and wealth from `upkeep_forecast` (`hold_after_upkeep`).
