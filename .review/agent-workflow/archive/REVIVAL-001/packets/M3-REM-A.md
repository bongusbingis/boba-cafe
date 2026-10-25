# M3-REM-A: Shift star bonus (E7) and approved-value cleanup (E1, E13)
Model: haiku   Studio: no   Depends on: none (no shared files with M4-FIXES)   Size: S

## Goal
Players earn 5/10/15 BB for a 1/2/3-star shift, and config no longer labels approved economy values "PROPOSED".

## Already built (verified, do not rebuild)
- E1 Iced/Sugar +1 each: `src/server/Modules/CustomerService/Rules.luau:149-161` (Payout); test `src/server/Tests/CustomerService.spec.luau:252`. Base table `CustomerConfig.luau:89-99` matches DEC-024 (Boba 3, Coffee 2, Cocoa 2, Tea 2, Pastry/Grab 1).
- E13 XP: `Progression.luau:13-15` (10/5/5), curve `Progression.luau:81-83` (60 + 25L + 2L^2), serve XP `ProgressionService.luau:116-124`, shift XP `ProgressionService.luau:134` using `ShiftConfig.luau:13-14` (10, +5 per star).
- E7 payout path is built: `ShiftService.luau:175` (`bonus = stars * SHIFT_BONUS_PER_STAR`), granted at `ShiftService.luau:201-205`. Only the constant is 0.

## Note on M4-FIXES
`packets/M4-FIXES.md` runs first and edits CurrencyService, RealOrderService, CustomerService/init.luau, LeaderboardService, TreasureHuntService, BadgeService, DailyRewardsDialog. This packet touches none of them (config files and ShiftService only).

## Read (only these)
- `src/shared/Configuration/ShiftConfig.luau` (whole)
- `src/server/Modules/ShiftService.luau:172-213`
- `src/shared/Configuration/CustomerConfig.luau:85-110`
- `src/shared/Configuration/RealOrderConfig.luau` (whole), `src/shared/Configuration/RatingConfig.luau:17-21`
- `src/shared/Configuration/Progression.luau:1-17`
- `src/server/Tests/ShiftService.spec.luau`: only the Bonus/summary tests (grep `Bonus`)

## Write scope
- `src/shared/Configuration/ShiftConfig.luau`
- `src/shared/Configuration/CustomerConfig.luau` (comments only)
- `src/shared/Configuration/RealOrderConfig.luau` (comments only)
- `src/shared/Configuration/RatingConfig.luau` (comments only)
- `src/shared/Configuration/Progression.luau` (comments only)
- `src/server/Tests/ShiftService.spec.luau`

## Steps
1. `ShiftConfig.luau`: set `SHIFT_BONUS_PER_STAR = 5` (E7, answers.md Batch 1: 5/10/15 BB for 1/2/3 stars, linear). Remove `-- PROPOSED (Jack)` from `SHIFT_BONUS_PER_STAR`, `SHIFT_XP`, `SHIFT_XP_PER_STAR` (E13). Replace the header line "Values marked PROPOSED ... M3 gate" with "Approved values: DEC-024 (E7, E13)".
2. `CustomerConfig.luau`: remove the PROPOSED marker only on approved values: PAY_TABLE rows lines 90-98 (E1), GRADE_MULT, FAST_MULT, FAST_FRACTION, COMBO_STEP, COMBO_CAP, RESCUE_MULT, RESCUE_FRACTION, MIN_PAY (lines 100-107, E3/E4/E6). Replace with `-- DEC-024`. Leave VARIANTS, MinLevel and ITEM_COUNT_BY_LEVEL markers (not approved).
3. `RealOrderConfig.luau` lines 7-9: replace PROPOSED with `-- DEC-024 (E5)`.
4. `RatingConfig.luau`: only `RUSH_SECONDS` and `RUSH_PAY_MULT` (lines 17, 20; E8 x2 for 120 s) become `-- DEC-024 (E8)`. Leave every other marker.
5. `Progression.luau` lines 13-15 (`XP_PER_ITEM`, `XP_PERFECT`, `XP_FAST`): replace marker with `-- DEC-024 (E13)`. Leave `MAX_LEVEL` and the level-gate tables PROPOSED. In the header comment, change "Every number is a placeholder" to "Numbers still marked PROPOSED (Jack) are placeholders".
6. `ShiftService.spec.luau`: add one test that `SHIFT_BONUS_PER_STAR * 1/2/3` equals 5/10/15 and that a 3-star `_endShift` summary has `Bonus == 15`. Mirror the existing summary test's setup; do not invent new fixtures.
7. Run the gate; fix any new finding in changed files.

## Done when
- `grep -n SHIFT_BONUS_PER_STAR src/shared/Configuration/ShiftConfig.luau` shows `= 5`.
- No "PROPOSED" remains on the lines listed in steps 1-5; markers elsewhere are untouched.
- The new spec passes.
- Diff touches only the files in Write scope.

## Checks to run
- `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. Never Play or run TestEZ (DEC-019); add a "Test for Jack" list to evidence.

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M3-REM-A/evidence.md` (RUNBOOK step 5)
