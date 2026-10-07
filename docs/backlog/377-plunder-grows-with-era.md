---
id: 377
title: Raids plunder a bigger share in later eras
type: feature
status: red-review
branch: feat/377-plunder-grows-with-era
---

## Goal
Late-game raids against wealthy civs should hurt more. Since 374 a pillage carries off a flat 20% of the food and
wealth left, so a raid costs about the same share of the stores in the Iron Age as in the Stone Age. After this, a
pillage takes half the stores in the Stone Age and the share grows with each era: a late realm sitting on big stores
loses most of them, so defence or spending matters more as the game goes on.

## Acceptance criteria
Config `raid_plunder_pct` 50 and `raid_plunder_era_pct` 10 unless stated. The plunder share is
`raid_plunder_pct + raid_plunder_era_pct × (era − 1)`, capped at 100, where era is `era()` when the raid strikes.

- [ ] AC1 (share by era): `raid_plunder_pct()` returns 50 in era 1, 60 in era 2 and 70 in era 3.
- [ ] AC2 (plunder uses it): Given a pillaging raid whose own pillage effects are `lose 2 food`, with food 17 and
  wealth 7 when it strikes (15 food left after its effects): in era 1 it plunders 8 food (15 → 7) and 4 wealth
  (7 → 3); in era 2 it plunders 9 food (15 → 6) and 5 wealth (7 → 2); in era 3 it plunders 11 food (15 → 4) and
  5 wealth (7 → 2). Each is rounded up, and `raid_resolved`'s `lost` (and `raid_outcome_text`) includes it.
- [ ] AC3 (era at the strike): Given a raid drawn in era 1 that strikes after the era has become 2, then it plunders
  at 60%. Its strength stays the one fixed when it was drawn (374).
- [ ] AC4 (cap): Given `raid_plunder_pct` 80 and `raid_plunder_era_pct` 30, then `raid_plunder_pct()` is 100 in
  era 2, and a pillage there takes all the food and wealth left.
- [ ] AC5 (off and unchanged): With `raid_plunder_era_pct` 0 (the default when unset) the share is `raid_plunder_pct`
  in every era. With `raid_plunder_pct` 0 and `raid_plunder_era_pct` 10, era 1 plunders nothing and era 2 plunders
  10%. A repelled raid plunders nothing in any era.
- [ ] AC6 (config): the loader rejects a negative or non-integer `raid_plunder_era_pct`, naming the field.

## Out of scope
- Scaling raid strength with era or realm size (raids' strength still grows only with the hoard, 374).
- Showing the plunder share in raid lines, the warning or the card tooltip.
- New raid cards (era 2–3 raids are 167) and tuning numbers beyond the shipped 50 / 10 (a balance item).

## Design notes
- Config (`data/config.json`, `ConfigLoader`): `raid_plunder_era_pct` (int ≥ 0, 0 = off), the extra percentage points
  per era above 1. Shipped 10, and `raid_plunder_pct` goes from 20 to 50 (the user's call), so 50% / 60% / 70% for
  eras 1–3. `raid_plunder_pct`'s 0–100 check stays; the sum is capped at 100 rather than rejected.
- New engine query `raid_plunder_pct()`: the share a pillage takes right now. `Military._plunder` reads it instead of
  the config key. No new state: era is already in `GameState`, so `copy()` needs nothing new.
- Sim bot: plunder isn't in any forecast (374's follow-up), so the bot still doesn't foresee it. Balance worry, not a
  criterion.
- PLAN.md's Hoards paragraph gets the era rule and the new key.

## Test plan
<!-- Filled in by Claude at the red checkpoint: AC → test name(s). -->
| AC | Test |
|---|---|
| AC1 | `test_raids::test_377_the_plunder_share_grows_by_raid_plunder_era_pct_each_era` |
| AC2 | `test_raids::test_377_a_pillage_plunders_the_share_of_the_era_it_strikes_in` |
| AC3 | `test_raids::test_377_a_raid_drawn_in_era_1_plunders_at_the_share_of_the_era_it_strikes_in` |
| AC4 | `test_raids::test_377_the_plunder_share_is_capped_at_100` |
| AC5 | `test_raids::test_377_with_raid_plunder_era_pct_0_the_share_is_raid_plunder_pct_in_every_era`, `test_377_with_raid_plunder_pct_0_only_later_eras_plunder`, `test_377_a_repelled_raid_plunders_nothing_in_a_later_era` (passes before the change: guard) |
| AC6 | `test_raids::test_377_raid_plunder_era_pct_defaults_to_0_and_rejects_bad_values` |

## Manual check
- [ ] `godot --path . -- --seed 5`: reach era 2 holding 20+ food and wealth and let a raid pillage. The raid modal's
  result line lists about 60% of each taken on top of the card's own losses.
- [ ] Shipped numbers: `raid_plunder_pct` 50 (was 20), `raid_plunder_era_pct` 10.
- [ ] Balance (user-run): `scripts/test.sh --balance` and the `balance` skill; watch `raid_food_lost`,
  `raid_wealth_lost` (375) and late-game food and wealth against main.

## Log
- Red: tests raise the era with the public `add_era(n)` after the raid is announced. The 374 tests keep their own
  20% config, so the shipped 20 → 50 change touches no existing test.
