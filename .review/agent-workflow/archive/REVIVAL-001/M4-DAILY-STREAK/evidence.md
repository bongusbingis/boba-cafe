RESULT: PASS
Files changed:
- src/shared/Configuration/DailyRewardConfig.luau (new)
- src/server/Modules/DailyRewardService.luau (new)
- src/server/Tests/DailyRewardService.spec.luau (new)

Gate check output:
```
PASS  src/shared/Configuration/DailyRewardConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/DailyRewardService.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Tests/DailyRewardService.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

Notes on behavior:
- `DailyRewardConfig.luau`:
  - 7-day schedule with escalating BobaBucks and capsules:
    - Day 1: 50 BobaBucks
    - Day 2: 75 BobaBucks
    - Day 3: 100 BobaBucks
    - Day 4: 125 BobaBucks, "Regular Pet Capsule"
    - Day 5: 150 BobaBucks
    - Day 6: 200 BobaBucks
    - Day 7: 300 BobaBucks, "Rare Pet Capsule"
  - Cooldown: 20 hours (72000s); Expiration window: 48 hours (172800s); VIP Gamepass ID: 12385781 (2x multiplier).
  - Pure helper `GetStreakStatus(streak, lastClaimTime, now)`:
    - Initial (lastClaimTime == 0): CanClaim = true, DayToClaim = 1, SecondsUntilNextClaim = 0, Expired = false.
    - Elapsed < 20h: CanClaim = false, DayToClaim = (streak % 7) + 1, SecondsUntilNextClaim = 20h - elapsed, Expired = false.
    - Elapsed > 48h: CanClaim = true, DayToClaim = 1, SecondsUntilNextClaim = 0, Expired = true.
    - Elapsed between 20h and 48h: CanClaim = true, DayToClaim = (streak % 7) + 1, SecondsUntilNextClaim = 0, Expired = false.
- `DailyRewardService.luau`:
  - Knit Service providing `GetRewardStatus` and `ClaimReward` on server and exposed through Client table.
  - Per-player in-flight claim locking (`claimsInProgress`) prevents double-claim race conditions.
  - Profile state persisted via `DataService` Replica proxy: `DailyRewards.Streak` and `DailyRewards.LastClaimTime`.
  - Currency awarded via `CurrencyService:Modify(player, "BobaBucks", amount, "DailyReward")` with 2x multiplier when `GamepassUtil.hasPass` is true.
  - Capsules awarded via `InventoryServer:AddItem(player, "Capsules", reward.Capsule)`.
  - Shim functions provided for `GamepassUtil.hasPass` and `InventoryServer:AddItem` to ensure zero runtime errors.
  - Service methods `_getService`, `_now`, `_hasPass`, and `_getInventoryServer` allow clean fake substitution in unit tests.
- `DailyRewardService.spec.luau`:
  - TestEZ suite verifying:
    - Pure `DailyRewardConfig.GetStreakStatus` evaluations (initial, cooldown, available, expired, Day 7 wrap).
    - Initial Day 1 claim for new players.
    - Cooldown rejection within 20 hours with correct remaining seconds.
    - Day 2 claim progression after 22 hours.
    - Expiration streak reset to 1 after 50 hours of inactivity.
    - Day 7 reward (300 BobaBucks + Rare Pet Capsule) and wrap to Day 1.
    - Day 4 reward (125 BobaBucks + Regular Pet Capsule).
    - VIP 2x BobaBucks multiplier application.
    - Client table proxy delegation.
