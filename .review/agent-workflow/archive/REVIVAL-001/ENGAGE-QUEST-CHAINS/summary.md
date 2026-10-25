# ENGAGE-QUEST-CHAINS — evidence (Q6-CHAINS)

Weekly quests, APPROVED by Jack 2026-10-21. All bounded numbers PROPOSED.

## Design choices (Jack adjusts)
- Weekly boundary: Monday 00:00 server local time. No existing weekly
  system was found (daily systems use UTC-day arithmetic), so per the brief
  the Monday fallback was taken. `QuestConfig.GetCurrentWeek` derives a
  stable week index from the most recent server-local Monday midnight.
  Verified by mirrored arithmetic: Sun 2026-10-25 23:59:59 -> wk 2963,
  Mon 2026-10-26 00:00 -> wk 2964, stable to next Monday -> wk 2965.
- 3 weekly quests from Prepare Boba / Serve Customers / Clean Spills /
  Complete Shifts at 3-5x daily targets (`GenerateWeeklyQuests`,
  deterministic per week seed). `RegularOrders` excluded per brief.
- Reward: 1 Regular Pet Capsule via `CapsuleService:GrantEarnedCapsule`
  (same insert path as the first-shift starter capsule). Granted BEFORE
  marking claimed; `InventoryFull` does not consume the claim.
- `QuestCard` weekly section reuses `QuestRow` (capsule pill, no reroll).
- Rollover race fix: `_ensureDailyQuests` re-reads `AssignedDay` after the
  yielding pass lookups and adopts the winner's list instead of overwriting
  it. Weekly ensure is yield-free by construction (no check-then-act gap).
- `ProfileTemplate`: appended `RewardCapsule?`, `WeeklyQuestData`,
  `WeeklyQuests` field + default. No renames (X10-INVITE safe).

## Gate (this lane's 4 files only; tree has other lanes' dirty files)
- stylua --check: clean (exit 0).
- selene vs HEAD baseline: 0 new findings (0 errors, 0 warnings).
- rojo build default.project.json -> %TEMP%/gate-build.rbxl: success.
- Full log: gate.log (this dir).

## Not run (per lane rules)
- No Studio / Play / TestEZ. TestEZ specs not executed.
- No commit, no push. `ActivityScript.server.luau` untouched.
