# M4-DAILY-STREAK: 7-Day Login Streak & Daily Rewards
Model: sonnet / spark   Studio: no   Depends on: none   Size: M

## Goal
Implement the 7-day daily login streak and reward claiming system (revival-plan §4.7):
- 7-day reward calendar with escalating BobaBucks and pet capsules.
- 20-hour claim cooldown and 48-hour streak expiration window.
- 2x BobaBucks bonus for VIP gamepass (12385781) owners (§6.3).
- Server-side `DailyRewardService` with atomic reward grant and streak rollover.
- Unit tests in `DailyRewardService.spec.luau`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `src/shared/Configuration/ProfileTemplate.luau` (lines 50-85, 145-165: DailyRewards schema)
- `src/server/Modules/CurrencyService.luau` (Modify method)
- `src/shared/Inventory/InventoryServer.luau` (AddItem method for Capsules)
- `src/shared/Utility/GamepassUtil.luau` (hasPass check)

## Write scope
- `src/shared/Configuration/DailyRewardConfig.luau` (new)
- `src/server/Modules/DailyRewardService.luau` (new)
- `src/server/Tests/DailyRewardService.spec.luau` (new)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-DAILY-STREAK/evidence.md` (new)

## Steps
1. Create `src/shared/Configuration/DailyRewardConfig.luau`:
   - `REWARDS`: array of 7 day entries:
     - Day 1: `{ BobaBucks = 50 }`
     - Day 2: `{ BobaBucks = 75 }`
     - Day 3: `{ BobaBucks = 100 }`
     - Day 4: `{ BobaBucks = 125, Capsule = "Regular Pet Capsule" }`
     - Day 5: `{ BobaBucks = 150 }`
     - Day 6: `{ BobaBucks = 200 }`
     - Day 7: `{ BobaBucks = 300, Capsule = "Rare Pet Capsule" }`
   - `CLAIM_COOLDOWN_SECONDS = 20 * 3600` (20 hours)
   - `STREAK_EXPIRE_SECONDS = 48 * 3600` (48 hours)
   - `VIP_GAMEPASS_ID = 12385781`
   - Pure helper `DailyRewardConfig.GetStreakStatus(streak: number, lastClaimTime: number, now: number)`:
     - If `lastClaimTime == 0`: `CanClaim = true`, `DayToClaim = 1`, `SecondsUntilNextClaim = 0`, `Expired = false`.
     - Else elapsed = `now - lastClaimTime`.
     - If elapsed < `CLAIM_COOLDOWN_SECONDS`: `CanClaim = false`, `DayToClaim = streak % 7 + 1`, `SecondsUntilNextClaim = CLAIM_COOLDOWN_SECONDS - elapsed`, `Expired = false`.
     - Else if elapsed > `STREAK_EXPIRE_SECONDS`: `CanClaim = true`, `DayToClaim = 1`, `SecondsUntilNextClaim = 0`, `Expired = true`.
     - Else: `CanClaim = true`, `DayToClaim = (streak % 7) + 1`, `SecondsUntilNextClaim = 0`, `Expired = false`.
2. Create `src/server/Modules/DailyRewardService.luau`:
   - Knit service named `"DailyRewardService"`.
   - Expose methods:
     - `GetRewardStatus(player: Player): table`:
       Reads player's `DailyRewards` profile via DataService, evaluates `DailyRewardConfig.GetStreakStatus`, checks VIP ownership via `GamepassUtil.hasPass(player, DailyRewardConfig.VIP_GAMEPASS_ID)`, and returns status summary.
     - `ClaimReward(player: Player): (boolean, string?, table?)`:
       Validates `CanClaim`. If valid:
       - Computes next streak: `if status.Expired then 1 else status.DayToClaim`.
       - Updates profile `DailyRewards.Streak = nextStreak` and `DailyRewards.LastClaimTime = os.time()`.
       - Grants BobaBucks via `CurrencyService:Modify(player, "BobaBucks", rewardBobaBucks, "DailyReward")` (multiplied by 2 if VIP).
       - If reward has Capsule, grants via `InventoryServer:AddItem(player, "Capsules", reward.Capsule)`.
       - Returns `(true, nil, { Streak = nextStreak, BobaBucks = grantAmount, Capsule = reward.Capsule })`.
   - Client table with Knit Client functions:
     - `GetRewardStatus(player)` -> calls server `GetRewardStatus`
     - `ClaimReward(player)` -> calls server `ClaimReward`
3. Create `src/server/Tests/DailyRewardService.spec.luau`:
   - TestEZ spec covering:
     - Initial state: new player claims Day 1 reward.
     - Cooldown enforcement: claim attempted before 20 hours is rejected with remaining time.
     - Successful Day 2 claim: 22 hours later advances streak to 2.
     - Expiration: 50 hours later resets streak to 1.
     - Day 7 roll-over: Day 7 wraps correctly to Day 1.
     - VIP 2x multiplier applies to BobaBucks payout.
4. Run WSL gate and verify clean output.

## Done when
- `DailyRewardConfig.luau` exports reward table and pure status calculation.
- `DailyRewardService.luau` resolves via Knit and grants soft currency & capsule rewards.
- `DailyRewardService.spec.luau` passes TestEZ tests.
- WSL gate check passes with 0 new Selene findings, StyLua ok, Rojo build ok.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/DailyRewardConfig.luau src/server/Modules/DailyRewardService.luau src/server/Tests/DailyRewardService.spec.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-DAILY-STREAK/evidence.md`
