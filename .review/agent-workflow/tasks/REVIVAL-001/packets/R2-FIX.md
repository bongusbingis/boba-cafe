# R2-FIX: Close R2-SECURITY P1-1, P2-1, P2-2, P3-1
Model: sonnet   Studio: no   Depends on: none   Size: M

## Goal
- A player can't be paid real-order rates, XP or the "Serve Real Players" quest for their own order.
- Earned Daily/Treasure capsules hatch for every player, policy-restricted players included.
- A full Capsules inventory never silently eats a reward.
- A quest can't be both claimed and rerolled.

## Read (only these)
- `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md` lines 9-45: the findings and the suggested fixes.
- `src/server/Modules/CapsuleService.luau` lines 566-600 (StartHatch policy gate) and 770-825: the starter-capsule grant. Copy its capacity check (`InventoryLimits.Storage.Capsules`) and the `FreeEarned` insert pattern.
- `src/shared/Utility/GamepassUtil.luau` lines 128-138: the real `PlayerOwnsPassAsync`.
- `src/server/Modules/DailyRewardService.luau` (whole file, about 230 lines).
- `src/server/Modules/TreasureHuntService.luau` lines 1-40 and 250-300.
- `src/server/Modules/QuestService.luau` lines 160-330.
- `src/server/Modules/OrderService.luau` lines 540-780.
- `src/server/Modules/RealOrderService.luau` lines 55-80 and 194-252.

## Write scope
- `src/server/Modules/CapsuleService.luau`
- `src/server/Modules/DailyRewardService.luau`
- `src/server/Modules/TreasureHuntService.luau`
- `src/server/Modules/QuestService.luau`
- `src/server/Modules/OrderService.luau`
- `src/server/Modules/RealOrderService.luau`

## Steps
1. **One shared earned-capsule helper (P2-1, DEC-029 E16).** In CapsuleService, add:
   - `CapsuleService:HasCapsuleSpace(player): boolean`, using the same count-vs-`InventoryLimits.Storage.Capsules` check as the starter grant.
   - `CapsuleService:GrantEarnedCapsule(player, capsuleName): (boolean, string?)`. It returns `false, "InventoryFull"` when there is no space, and `false, "InternalError"` when the inventory can't be fetched or `Insert` returns nil. Otherwise it inserts `{ Name = capsuleName, Properties = { RandomSource = "FreeEarned" } }` and returns `true`. It must never throw (pcall internally).

   Optionally point the starter grant at `HasCapsuleSpace`. Don't change its flow.
2. **Remove the monkey-patches.**
   - Delete both `InventoryServer.AddItem` shims (DailyRewardService ~27-39, TreasureHuntService ~15-29).
   - Delete the `GamepassUtil.hasPass` shim (DailyRewardService ~17-25). `DailyRewardService:_hasPass` becomes the same pcall'd `GamepassUtil:PlayerOwnsPassAsync` wrapper that QuestService uses (QuestService ~56-61).
   - Remove any now-unused `InventoryServer` requires and `_getInventoryServer` helpers.
3. **Daily claim on a full inventory (Jack Q5=A, DEC-035).** In `DailyRewardService:ClaimReward`, when the reward day has a `Capsule`:
   - Before writing `Streak`/`LastClaimTime` or granting BB, call `HasCapsuleSpace`. If false, return `false, "InventoryFull", nil` and change nothing. The player can claim again once there's space; the streak isn't consumed.
   - Then call `GrantEarnedCapsule`. If it fails, return its reason and change nothing.
   - Only after that, write the streak and grant BB.

   Days without a capsule are unchanged. The client shows the returned reason. If the client has no friendly text for `"InventoryFull"`, note it in evidence; don't edit client files.
4. **Chest capsule (Q5=A).** In TreasureHuntService, replace the `AddItem` call with `GrantEarnedCapsule`. On any failure, the player keeps the BB already granted and gets no capsule. Warn only on `"InternalError"`. A full inventory is expected.
5. **Self-serve (P1-1).**
   - (a) In `OrderService:_claimNextOrder` and the auto-assign in `_tryDispatchFromQueue`, skip any order whose customer UserId equals the staff member's UserId. The order stays queued for someone else.
   - (b) In `RealOrderService:_onOrderPickedUp`, if `barista.UserId == customerId`, return before any pay multiplier, BB, XP, `AdvanceQuest` or `Progress` call.
   - (c) In `_handlePickUp`, the customer path must not let a player pick up a drink from a node they deposited into for their own order. Check whether (a) already makes this unreachable, and note the answer in evidence. If it's still reachable, refuse that pick-up through the existing Announcement path.
6. **Quest lock (P3-1).** In QuestService, replace `claimsInProgress` and `rerollsInProgress` with one `questLocks` table.
   - `ClaimQuest` and `RerollQuest` both take and release it on every return path, including the error path.
   - `PlayerRemoving` clears it.
   - After `TrySpendAsync` yields in `RerollQuest`, re-read the slot. If it's now `Completed` or `Claimed`, refund the 50 BB if it was charged and return a failure.

## Not in this packet
- P3-2 (plausible stack double-grant) stays open for a later look.
- No reward amounts, cooldowns or odds change (DEC-034).
- No UI or client edits.

## Done when
- No `AddItem` or `hasPass` assignment onto a shared module remains (`grep -n "AddItem = function\|hasPass = function" src` is empty).
- Every earned Daily/Treasure capsule is inserted with `RandomSource = "FreeEarned"` through `GrantEarnedCapsule`.
- A daily claim with a capsule reward on a full inventory returns `InventoryFull` with the streak, last-claim time and BB untouched.
- Steps 5 and 6 are in place.
- The gate passes on all changed files.

## Checks to run
`wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`

Never Play and never run TestEZ (DEC-019). Add a "Test for Jack" list to your evidence.

## STOP-AND-ASK
- If `ClaimReward`'s client caller treats every failure as fatal or blocks play, stop and report it. Don't change the client.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/R2-FIX/evidence.md` (RUNBOOK step 5, plus the answer to 5c and the Test for Jack list)
