# M4-FIXES: Chest cooldown, Veteran badges, leaderboard feeds, daily-claim failure UI
Model: sonnet   Studio: no   Depends on: R2-FIX (Sentry PASS)   Size: M

## Goal
- Chests can't be farmed.
- Veteran means a real returning player.
- The three approved monthly boards fill with real data.
- A refused daily claim tells the player why instead of pretending it succeeded.

## Read (only these)
- `.review/agent-workflow/decisions.md` DEC-035, DEC-036 and DEC-037 (the top three entries).
- `src/server/Modules/TreasureHuntService.luau` (whole file) and `src/shared/Configuration/TreasureHuntConfig.luau`.
- `src/shared/Configuration/ProfileTemplate.luau` lines 40-150 (type and defaults; `PendingBobaBucksRefund` is the additive-field precedent, DEC-031).
- `src/server/Modules/BadgeService.luau` lines 20-60, 150-180 and 285-305.
- `src/server/Modules/LeaderboardService.luau` (whole file) and `src/shared/Configuration/LeaderboardConfig.luau`.
- `src/server/Modules/CurrencyService.luau` lines 20-64.
- `src/server/Modules/CustomerService/init.luau` lines 725-745 (the NPC serve stat).
- `src/server/Modules/RealOrderService.luau` lines 194-252 (the real-player serve).
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau` lines 190-245.
- `src/server/Tests/DailyRewardService.spec.luau`, `src/server/Tests/TreasureHuntService.spec.luau`, `src/server/Tests/BadgeService.spec.luau`: only the parts that reference changed behaviour.

## Write scope
- `src/server/Modules/TreasureHuntService.luau`
- `src/shared/Configuration/TreasureHuntConfig.luau`, `src/shared/Configuration/DailyRewardConfig.luau`, `src/shared/Configuration/QuestConfig.luau`, `src/server/Tests/QuestService.spec.luau`
- `src/shared/Configuration/ProfileTemplate.luau`
- `src/server/Modules/BadgeService.luau`
- `src/server/Modules/LeaderboardService.luau`
- `src/shared/Configuration/LeaderboardConfig.luau`
- `src/server/Modules/CurrencyService.luau`
- `src/server/Modules/CustomerService/init.luau`
- `src/server/Modules/RealOrderService.luau`
- `src/shared/UI/Components/Dialogs/DailyRewardsDialog.luau`
- the three spec files above, plus `src/server/Tests/LeaderboardService.spec.luau`
- any file holding a hard-coded reroll price (step 6), listed in evidence

## Steps
1. **Chest cooldown (Q2=A).**
   - Add `PLAYER_COOLDOWN_SECONDS = 15 * 60` to TreasureHuntConfig.
   - Add the additive profile field `LastTreasureChestTime: number` with default `0` (type and default; `Profile:Reconcile()` fills existing profiles, DEC-031 pattern).
   - In the chest-open path, before any reward: if `os.time() - LastTreasureChestTime < cooldown`, refuse. The chest stays for others. Tell the player "Next treasure chest in N min" through the announcement/notification path TreasureHuntService or OrderService already uses. If none exists, `warn` only and note it in evidence.
   - On a successful open, write `LastTreasureChestTime = os.time()` before granting.
   - Treasure Frenzy (EventService) shortens respawn only, not this cooldown.
2. **Veteran (Q3=B, DEC-037 Q12=A).**
   - `LEGACY_BADGES` becomes exactly these five, with their existing IDs and comments: FirstQuest (2124640229), Celebrity (2124640231), SakuraIsland (2124640232), ShinyPet (2124774046), HalloweenEvent (2124837610). Mark it `-- DEC-035 Q3, DEC-037 Q12`.
   - FirstStaff stays in the badge name→ID map, and the staff-rank award on join (~line 300) is unchanged.
   - Update BadgeService.spec: it should assert the five-badge list and assert that FirstStaff alone doesn't grant Veteran.
3. **Leaderboards (Q4=B).**
   - (a) Feeds:
     - `OrdersServed` +1 next to `IncrementStat(player, "CustomersServed")` in CustomerService (NPC serve).
     - `OrdersServed` +1 for the barista in `RealOrderService:_onOrderPickedUp` after the self-serve return.
     - `MostBobaBucks` +amount in `CurrencyService:Modify` when `type == "BobaBucks"` and `amount > 0`, except reasons for refunds and Robux pack receipts. List every `reason` string you excluded in evidence ("BB earned" means play-earned, so it isn't buyable).
     - `MostActive` +1 per player per minute from one loop in `LeaderboardService:KnitStart`.
     - Resolve LeaderboardService lazily (`Knit.GetService` inside a pcall) so a leaderboard failure never breaks a serve or a payment.
   - (b) Batch writes: `IncrementStat` adds into an in-memory `pending[userId][board]`. Flush with one `_updatePlayerStat` per (user, board) every `REFRESH_INTERVAL_SECONDS`, on PlayerRemoving, and in `game:BindToClose`. Never one DataStore write per serve.
   - (c) Hide `MostTips` and `TopDonators`:
     - Add `Hidden = true` to their config entries.
     - `RefreshBoards` skips hidden boards and sets those boards' SurfaceGui `Enabled = false` at runtime. Do not edit or delete place content.
     - `IncrementStat` ignores hidden boards.
   - (d) Statues (DEC-037 Q13=A). In `RefreshStatues`:
     - `topWinners` queries `OrdersServed` and `MostBobaBucks` only. It never queries a hidden board.
     - Every place where the statue would have shown Most Tips now shows the `MostBobaBucks` winner: the "Most Tips" `Leaderboard` ObjectValue target, a `Role` containing "Tip", and index fallback 2. Also match a target named "Most Boba Bucks" (the config display name; check LeaderboardConfig for the exact string).
     - A statue whose target or role is Top Donators gets no winner and is left as it is. Index fallback 1 is `OrdersServed` only.
     - Update the doc comment above the function. Don't edit place content. Note in "Test for Jack" that any sign on statue 2 still reading "Most Tips" needs a Studio relabel.
     - Update LeaderboardService.spec if it asserts the old statue mapping, and add it to the files you touch.
4. **Daily-claim failure UI.** In DailyRewardsDialog, Knit service methods return a Promise whose `:await()` yields `(promiseOk, ok, reason, result)`. The current code reads `promiseOk` as the claim result, so a refused claim shows "Claimed 0 Boba Bucks!" and fakes the cooldown.
   - Unpack correctly. Grep another client caller of a Knit service `:await()` first to confirm the convention.
   - On `reason == "InventoryFull"`, call the existing `dialogController:Toast("Your capsule inventory is full - make room to claim today's reward!")`.
   - On any other failure, toast "Couldn't claim right now - try again in a moment."
   - Leave the claim available. No new UI component or style (DEC-013): `Toast` is existing.
5. **Specs.** Update `DailyRewardService.spec` and `TreasureHuntService.spec` so they fake `CapsuleService:GrantEarnedCapsule` / `HasCapsuleSpace` instead of the removed `InventoryServer.AddItem` shim. Add one case each:
   - full inventory refuses the daily claim without changing the streak;
   - the chest cooldown refuses a second chest.

6. **Approved reward amounts (DEC-036 Q11).**
   - `DailyRewardConfig.REWARDS` BobaBucks become 30/45/60/60/90/120/180; capsules unchanged.
   - `TreasureHuntConfig`: `MIN_BOBABUCKS = 20`, `MAX_BOBABUCKS = 40`, `CAPSULE_CHANCE = 0.10`.
   - `QuestConfig`: `BobaBucks` and `XP` become arrays aligned with `Targets`. BobaOrdered and CustomersServed 25/40/60 and 15/25/35. SpillsCleaned 20/30/45 and 10/20/30. RegularOrders and ShiftsCompleted 40/75 and 25/40.
   - Both generators (`QuestConfig` ~100-109 and ~130-139) pick the reward at the rolled target's index.
   - Mark each value `-- DEC-036`. Update the Quest spec if it asserts the flat amounts.
   - `QuestConfig.REROLL_COST_BOBABUCKS = 20 -- DEC-037 Q11b`. Grep for any other hard-coded 50 BB reroll price (server, UI text, specs) and update it. List every hit in evidence.

## Not in this packet
- Statue art and board models.
- Studio edits.

## Done when
- A second chest within 15 min is refused with nothing granted.
- `LEGACY_BADGES` matches step 2.
- Nothing increments a hidden board.
- At most one DataStore write per (user, board) per flush.
- A refused daily claim shows a toast and keeps the claim button available.
- The gate passes on every changed file.

## Checks to run
`wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`

Never Play and never run TestEZ (DEC-019). Add a "Test for Jack" list.

## STOP-AND-ASK
- If the chest-open path or the leaderboard flush would need a new remote, stop and report it.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/M4-FIXES/evidence.md`
